import Foundation

/// High-performance, zero-idle push pub/sub event broker for persistent Unix socket streaming clients.
/// Complies with `docs/spec/35-core-server-protocol.md` and MIT-SRV-001.
public final class EventSubscriptionBroker: @unchecked Sendable {
    public static let shared = EventSubscriptionBroker()

    private let lock = NSLock()
    private var subscribers: [Int32: Set<String>] = [:]

    private init() {}

    /// Registers a client file descriptor for a given event topic (e.g. "events.workspaces", "events.audio", "*").
    public func subscribe(clientFD: Int32, topic: String) {
        lock.lock()
        defer { lock.unlock() }
        let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if subscribers[clientFD] != nil {
            subscribers[clientFD]?.insert(cleanTopic)
        } else {
            subscribers[clientFD] = [cleanTopic]
        }
    }

    /// Unsubscribes a client from a specific topic or removes the client entirely.
    public func unsubscribe(clientFD: Int32, topic: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        if let topic = topic {
            let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            subscribers[clientFD]?.remove(cleanTopic)
            if subscribers[clientFD]?.isEmpty == true {
                subscribers.removeValue(forKey: clientFD)
            }
        } else {
            subscribers.removeValue(forKey: clientFD)
        }
    }

    /// Returns whether the client has active subscriptions.
    public func isSubscribed(clientFD: Int32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !(subscribers[clientFD]?.isEmpty ?? true)
    }

    /// Broadcasts an event immediately to all subscribed client sockets with <1ms latency.
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

        let line = jsonString + "\n"
        var staleClients: [Int32] = []

        lock.lock()
        let activeSubscribers = subscribers
        lock.unlock()

        line.utf8CString.withUnsafeBufferPointer { buf in
            guard let baseAddr = buf.baseAddress else { return }
            let len = buf.count - 1

            for (fd, topics) in activeSubscribers {
                let matches = topics.contains("*") || topics.contains(topic) || topics.contains("events.*")
                if matches {
                    let sent = write(fd, baseAddr, len)
                    if sent < 0 {
                        staleClients.append(fd)
                    }
                }
            }
        }

        if !staleClients.isEmpty {
            lock.lock()
            for fd in staleClients {
                subscribers.removeValue(forKey: fd)
                shutdown(fd, SHUT_RDWR)
            }
            lock.unlock()
        }
    }
}
