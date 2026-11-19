import Foundation

/// High-performance, zero-idle push pub/sub event broker for persistent Unix socket streaming clients.
/// Complies with `docs/spec/35-core-server-protocol.md` and MIT-SRV-001.
public final class EventSubscriptionBroker: @unchecked Sendable {
    public static let shared = EventSubscriptionBroker()

    private let lock = NSLock()
    private var subscribers: [Int32: Set<String>] = [:]
    private var connections: [Int32: SocketConnection] = [:]
    /// Dedicated serial queue: broadcasts are delivered asynchronously so a slow
    /// subscriber can never block the caller (e.g. @MainActor services).
    private let broadcastQueue = DispatchQueue(label: "io.github.jonasnowak.dms.events.broadcast", qos: .userInitiated)

    private init() {}

    /// Registers a freshly accepted client connection.
    public func attach(_ connection: SocketConnection) {
        lock.lock()
        connections[connection.fd] = connection
        lock.unlock()
    }

    /// Detaches a connection and drops all of its subscriptions.
    public func detach(_ connection: SocketConnection) {
        lock.lock()
        let fd = connection.fd
        subscribers.removeValue(forKey: fd)
        connections.removeValue(forKey: fd)
        lock.unlock()
    }

    /// Registers a client connection for a given event topic (e.g. "events.workspaces", "events.audio", "*").
    /// Subscriber sockets are switched to O_NONBLOCK so a stalled client fails fast
    /// instead of blocking a broadcast.
    public func subscribe(connection: SocketConnection, topic: String) {
        let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let fd = connection.fd
        let flags = fcntl(fd, F_GETFL)
        if flags >= 0 {
            _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        }
        lock.lock()
        subscribers[fd, default: []].insert(cleanTopic)
        lock.unlock()
    }

    /// Unsubscribes a client from a specific topic or removes the client entirely.
    public func unsubscribe(connection: SocketConnection, topic: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        let fd = connection.fd
        if let topic = topic {
            let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            subscribers[fd]?.remove(cleanTopic)
            if subscribers[fd]?.isEmpty == true {
                subscribers.removeValue(forKey: fd)
            }
        } else {
            subscribers.removeValue(forKey: fd)
        }
    }

    /// Returns whether the client has active subscriptions.
    public func isSubscribed(_ connection: SocketConnection) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !(subscribers[connection.fd]?.isEmpty ?? true)
    }

    /// Broadcasts an event to all subscribed client sockets. The delivery runs on a dedicated
    /// serial queue; subscribers whose (non-blocking) socket can't take the write are
    /// disconnected instead of stalling the broadcast.
    public func broadcast(event: String, payload: [String: Any]) {
        let topic = event.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var envelope: [String: Any] = [
            "event": topic,
            "timestamp": Date().timeIntervalSince1970
        ]
        for (k, v) in payload {
            envelope[k] = v
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: envelope),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        let data = Data((jsonString + "\n").utf8)

        broadcastQueue.async { [weak self] in
            self?.deliver(data, topic: topic)
        }
    }

    private func deliver(_ data: Data, topic: String) {
        lock.lock()
        let activeSubscribers = subscribers
        let activeConnections = connections
        lock.unlock()

        var staleClients: [Int32] = []
        for (fd, topics) in activeSubscribers {
            let matches = topics.contains("*") || topics.contains(topic) || topics.contains("events.*")
            guard matches, let connection = activeConnections[fd] else { continue }
            // Non-blocking socket: a full send buffer fails immediately -> stalled subscriber.
            if !connection.writeAll(data) {
                staleClients.append(fd)
            }
        }

        if !staleClients.isEmpty {
            lock.lock()
            for fd in staleClients {
                subscribers.removeValue(forKey: fd)
                connections.removeValue(forKey: fd)?.close()
            }
            lock.unlock()
        }
    }

    /// Closes every subscriber connection (used on daemon shutdown).
    public func closeAll() {
        lock.lock()
        let all = connections
        subscribers.removeAll()
        connections.removeAll()
        lock.unlock()
        for (_, connection) in all {
            connection.close()
        }
    }
}
