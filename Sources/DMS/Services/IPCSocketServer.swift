import Foundation
import DMSCore

/// Thread-safe wrapper around a client socket FD.
/// The lock is held for the whole write, so `close()` can never race with `write()`
/// on a recycled FD. Shared by `IPCSocketServer`, `EventSubscriptionBroker` and the
/// pending-dmenu registry.
public final class SocketConnection: @unchecked Sendable {
    private let lock = NSLock()
    private var _fd: Int32
    private var _isClosed: Bool

    public init(fd: Int32) {
        self._fd = fd
        self._isClosed = false
    }

    public var fd: Int32 {
        lock.lock()
        defer { lock.unlock() }
        return _fd
    }

    public var isClosed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isClosed
    }

    /// Writes all bytes, handling partial writes and EINTR.
    /// Returns false when the socket is closed or the write failed
    /// (e.g. EAGAIN on a non-blocking socket with a full send buffer).
    @discardableResult
    public func writeAll(_ data: Data) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !_isClosed, _fd >= 0 else { return false }
        var offset = 0
        while offset < data.count {
            let written = data.withUnsafeBytes { raw -> Int in
                guard let base = raw.baseAddress else { return 0 }
                return write(_fd, base + offset, data.count - offset)
            }
            if written > 0 {
                offset += written
            } else if written < 0 && errno == EINTR {
                continue
            } else {
                return false
            }
        }
        return true
    }

    @discardableResult
    public func writeAll(_ string: String) -> Bool {
        writeAll(Data(string.utf8))
    }

    /// Closes the FD exactly once. Returns the closed FD, or -1 if already closed.
    @discardableResult
    public func close() -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        guard !_isClosed else { return -1 }
        _isClosed = true
        let fd = _fd
        _fd = -1
        if fd >= 0 {
            Darwin.close(fd)
        }
        return fd
    }
}

/// Unix domain socket server with persistent connection pool and pub/sub event streaming.
/// Listens at `~/Library/Application Support/DMS/dms.sock`.
public final class IPCSocketServer: @unchecked Sendable {
    public static let shared = IPCSocketServer()

    /// Maximum accepted line length on the socket (bytes).
    private static let maxLineLength = 65536
    /// Maximum concurrent client connections.
    private static let maxConnections = 64
    /// Receive timeout for request/response clients (cleared on SUBSCRIBE/dmenu upgrade).
    private static let requestTimeoutSeconds: Int = 10

    private var serverFD: Int32 = -1
    private let socketURL: URL
    private var isRunning: Bool = false
    private let queue = DispatchQueue(label: "io.github.jonasnowak.dms.socket", qos: .userInitiated)
    private let clientQueue = DispatchQueue(label: "io.github.jonasnowak.dms.socket.clients", qos: .userInitiated, attributes: .concurrent)
    private let connectionSlots = DispatchSemaphore(value: maxConnections)

    // v0.7 CLI: pending `dms dmenu` requests — requestID -> connection kept open until the user picks a line.
    private let dmenuLock = NSLock()
    private var pendingDMenu: [String: SocketConnection] = [:]

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dmsDir = appSupport.appendingPathComponent("DMS", isDirectory: true)
        try? FileManager.default.createDirectory(at: dmsDir, withIntermediateDirectories: true)
        // The DMS state directory holds the socket, lockfile and staged dmenu files: owner-only.
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dmsDir.path)
        self.socketURL = dmsDir.appendingPathComponent("dms.sock")
    }

    public func start() {
        guard !isRunning else { return }

        // Ignore SIGPIPE to prevent client disconnects from killing the daemon
        signal(SIGPIPE, SIG_IGN)

        let path = socketURL.path
        removeStaleSocket(at: path)

        // sockaddr_un.sun_path is 104 bytes including the NUL terminator.
        let pathBytes = path.utf8CString
        guard pathBytes.count < 104 else {
            print("Socket path too long for sockaddr_un.sun_path (\(pathBytes.count - 1) chars): \(path)")
            return
        }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            print("Failed to create Unix domain socket.")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let raw = UnsafeMutableRawPointer(ptr)
            _ = pathBytes.withUnsafeBufferPointer { buf in
                memcpy(raw, buf.baseAddress!, min(buf.count, 104))
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindRes = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                bind(fd, saPtr, addrLen)
            }
        }

        guard bindRes == 0 else {
            print("Failed to bind Unix domain socket to \(path).")
            close(fd)
            return
        }

        // Restrict the socket to the current user immediately after bind.
        chmod(path, 0o600)

        guard listen(fd, 64) == 0 else {
            print("Failed to listen on Unix domain socket.")
            close(fd)
            return
        }

        self.serverFD = fd
        self.isRunning = true

        queue.async { [weak self] in
            self?.acceptLoop()
        }

        print("DMS IPC Socket listening at: \(path)")
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        if serverFD >= 0 {
            close(serverFD)
            serverFD = -1
        }
        removeStaleSocket(at: socketURL.path)
        EventSubscriptionBroker.shared.closeAll()
        dmenuLock.lock()
        let pending = Array(pendingDMenu.values)
        pendingDMenu.removeAll()
        dmenuLock.unlock()
        for connection in pending {
            connection.close()
        }
    }

    /// Unlinks `path` only when it is actually a socket — never a regular file or symlink.
    private func removeStaleSocket(at path: String) {
        var st = stat()
        guard lstat(path, &st) == 0 else { return }
        if (st.st_mode & S_IFMT) == S_IFSOCK {
            unlink(path)
        }
    }

    private func acceptLoop() {
        while isRunning && serverFD >= 0 {
            var clientAddr = sockaddr_un()
            var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                    accept(serverFD, saPtr, &clientLen)
                }
            }

            guard clientFD >= 0 else {
                if !isRunning { break }
                continue
            }

            // Set SO_NOSIGPIPE so client write errors return -1/EPIPE instead of raising SIGPIPE
            var val: Int32 = 1
            setsockopt(clientFD, SOL_SOCKET, SO_NOSIGPIPE, &val, socklen_t(MemoryLayout<Int32>.size))

            // Request/response clients get a receive timeout; it is cleared once the
            // connection is upgraded to a SUBSCRIBE stream or a pending dmenu request.
            var timeout = timeval(tv_sec: Self.requestTimeoutSeconds, tv_usec: 0)
            setsockopt(clientFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

            // Cap concurrent connections; reject excess clients immediately.
            guard connectionSlots.wait(timeout: .now()) == .success else {
                close(clientFD)
                continue
            }

            clientQueue.async { [weak self] in
                defer { self?.connectionSlots.signal() }
                self?.handleClientConnection(clientFD)
            }
        }
    }

    private func handleClientConnection(_ clientFD: Int32) {
        let connection = SocketConnection(fd: clientFD)
        EventSubscriptionBroker.shared.attach(connection)

        defer {
            EventSubscriptionBroker.shared.detach(connection)
            removePendingDMenu(for: connection)
            connection.close()
        }

        var readBuffer = Data()
        var keepOpen = false

        var chunk = [UInt8](repeating: 0, count: 4096)
        while isRunning {
            let bytesRead = read(clientFD, &chunk, chunk.count)
            if bytesRead > 0 {
                readBuffer.append(contentsOf: chunk.prefix(bytesRead))
            } else if bytesRead == 0 {
                break // EOF — client disconnected
            } else if errno == EINTR {
                continue
            } else if errno == EAGAIN || errno == EWOULDBLOCK {
                // Non-blocking subscriber socket: wait for readability or hangup instead of spinning.
                var pfd = pollfd(fd: clientFD, events: Int16(POLLIN | POLLHUP | POLLERR), revents: 0)
                let pollRes = poll(&pfd, 1, 1000)
                if pollRes > 0 && (pfd.revents & Int16(POLLHUP | POLLERR)) != 0 {
                    break
                }
                continue
            } else {
                break // includes SO_RCVTIMEO expiry on idle request/response clients
            }

            // Process full newline-delimited lines
            while let newlineIndex = readBuffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = readBuffer.subdata(in: 0..<newlineIndex)
                readBuffer.removeSubrange(0...newlineIndex)

                if lineData.count > Self.maxLineLength {
                    return // protocol violation: line exceeds the cap
                }

                guard let rawLine = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !rawLine.isEmpty else {
                    continue
                }

                let (response, isStreaming) = processLine(rawLine, connection: connection)
                if isStreaming {
                    keepOpen = true
                }

                if let response = response {
                    let out = response.hasSuffix("\n") ? response : (response + "\n")
                    connection.writeAll(out)
                }

                // If this was a one-shot request and the client has not subscribed to any streams, exit loop
                if !keepOpen && !EventSubscriptionBroker.shared.isSubscribed(connection) {
                    return
                }
            }

            if readBuffer.count > Self.maxLineLength {
                return // unterminated line already over the cap
            }
        }
    }

    private func processLine(_ line: String, connection: SocketConnection) -> (response: String?, isStreaming: Bool) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Pub/Sub protocol: SUBSCRIBE <topic>
        if trimmed.uppercased().hasPrefix("SUBSCRIBE ") || trimmed.hasPrefix("subscribe:") {
            let topic: String
            if trimmed.uppercased().hasPrefix("SUBSCRIBE ") {
                topic = String(trimmed.dropFirst("SUBSCRIBE ".count)).trimmingCharacters(in: .whitespaces)
            } else {
                topic = String(trimmed.dropFirst("subscribe:".count)).trimmingCharacters(in: .whitespaces)
            }
            guard !topic.isEmpty else {
                return (Self.jsonString(["status": "error", "message": "SUBSCRIBE requires a topic"]), false)
            }
            clearReceiveTimeout(connection)
            EventSubscriptionBroker.shared.subscribe(connection: connection, topic: topic)
            return (Self.jsonString(["status": "subscribed", "topic": topic]), true)
        }

        // Pub/Sub protocol: UNSUBSCRIBE <topic>
        if trimmed.uppercased().hasPrefix("UNSUBSCRIBE ") {
            let topic = String(trimmed.dropFirst("UNSUBSCRIBE ".count)).trimmingCharacters(in: .whitespaces)
            EventSubscriptionBroker.shared.unsubscribe(connection: connection, topic: topic.isEmpty ? nil : topic)
            return (Self.jsonString(["status": "unsubscribed", "topic": topic]), true)
        }

        // REST Wire Protocol: <METHOD> <PATH> [JSON_PAYLOAD] per docs/spec/35-core-server-protocol.md
        if trimmed.hasPrefix("GET /") || trimmed.hasPrefix("POST /") || trimmed.hasPrefix("PUT /") || trimmed.hasPrefix("DELETE /") {
            let tokens = trimmed.split(separator: " ", maxSplits: 2).map(String.init)
            let method = tokens[0].uppercased()
            let path = tokens.count > 1 ? tokens[1] : ""
            let body = tokens.count > 2 ? tokens[2] : ""

            let restResponse = DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    handleRestRequest(method: method, path: path, body: body)
                }
            }
            return (restResponse, false)
        }

        // Standard CLI or IPC command
        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let command = IPCCommand.parseCLI(args: tokens)

        // v0.7 CLI: dmenu requests keep the connection open so the selection can be streamed back.
        if case .dmenu(let requestID, let prompt, _) = command {
            guard DMenuStaging.isValidRequestID(requestID) else {
                return (Self.jsonString(["status": "error", "message": "invalid dmenu requestID"]), false)
            }
            // Always derive the candidates file server-side from the validated request ID —
            // never trust a client-supplied path (it could point outside the staging directory).
            let candidatesFile = DMenuStaging.candidatesPath(for: requestID).path
            let serverCommand = IPCCommand.dmenu(requestID: requestID, prompt: prompt, candidatesFile: candidatesFile)
            clearReceiveTimeout(connection)
            registerPendingDMenu(requestID: requestID, connection: connection)
            let responseText = DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    IPCCommandExecutor.execute(serverCommand)
                }
            }
            return (responseText, true)
        }

        let responseText = DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                IPCCommandExecutor.execute(command)
            }
        }

        return (responseText, false)
    }

    /// Clears SO_RCVTIMEO once a connection is upgraded to a long-lived stream (SUBSCRIBE / dmenu).
    private func clearReceiveTimeout(_ connection: SocketConnection) {
        var zero = timeval(tv_sec: 0, tv_usec: 0)
        setsockopt(connection.fd, SOL_SOCKET, SO_RCVTIMEO, &zero, socklen_t(MemoryLayout<timeval>.size))
    }

    /// Serializes a JSON object without manual string interpolation (injection-safe).
    private static func jsonString(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"status\":\"error\"}"
        }
        return str
    }

    // MARK: - dmenu Result Delivery (v0.7 CLI)

    /// Registers a client connection as waiting for a dmenu selection.
    public func registerPendingDMenu(requestID: String, connection: SocketConnection) {
        dmenuLock.lock()
        pendingDMenu[requestID] = connection
        dmenuLock.unlock()
    }

    /// Removes all pending dmenu registrations for a disconnected connection.
    private func removePendingDMenu(for connection: SocketConnection) {
        dmenuLock.lock()
        pendingDMenu = pendingDMenu.filter { $0.value !== connection }
        dmenuLock.unlock()
    }

    /// Streams the dmenu selection back on the same persistent connection and writes the
    /// `<requestID>.result` fallback file. Called from the launcher UI when the user picks or cancels.
    public func deliverDMenuResult(requestID: String, line: String?, cancelled: Bool) {
        guard DMenuStaging.isValidRequestID(requestID) else { return }
        dmenuLock.lock()
        let connection = pendingDMenu.removeValue(forKey: requestID)
        dmenuLock.unlock()

        var payload: [String: Any] = [
            "dmenuResult": requestID,
            "cancelled": cancelled
        ]
        if let line = line {
            payload["line"] = line
            // Fallback file so a CLI that lost the connection can still read the selection.
            try? line.write(
                to: DMenuStaging.resultPath(for: requestID),
                atomically: true,
                encoding: .utf8
            )
        }

        connection?.writeAll(Self.jsonString(payload) + "\n")
    }

    // MARK: - REST Wire Protocol

    @MainActor
    private func handleRestRequest(method: String, path: String, body: String) -> String {
        func ok() -> String { Self.jsonString(["status": "ok"]) }
        func ok(_ data: Any) -> String { Self.jsonString(["status": "ok", "data": data]) }
        func err(_ message: String) -> String { Self.jsonString(["status": "error", "message": message]) }

        switch (method, path) {
        case ("GET", "/api/v1/audio/volume"):
            return ok(["volume": AudioService.shared.volume, "isMuted": AudioService.shared.isMuted])

        case ("POST", "/api/v1/audio/volume"):
            if let data = body.data(using: .utf8),
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                if let vol = json["volume"] as? Double {
                    AudioService.shared.setVolume(vol)
                }
                if let muted = json["isMuted"] as? Bool, muted != AudioService.shared.isMuted {
                    AudioService.shared.toggleMute()
                }
            }
            return ok(["volume": AudioService.shared.volume, "isMuted": AudioService.shared.isMuted])

        case ("GET", "/api/v1/audio/sinks"):
            let sinks = AudioService.shared.outputs.map { [
                "id": $0.id,
                "name": $0.name,
                "isDefault": $0.isDefault
            ] as [String: Any] }
            return ok(["sinks": sinks])

        case ("POST", "/api/v1/audio/sinks"):
            if let data = body.data(using: .utf8),
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let sinkID = json["id"] as? UInt32 {
                AudioService.shared.setDefaultOutput(sinkID)
                return ok()
            }
            return err("Missing id in payload")

        case ("GET", "/api/v1/network/wifi/scan"):
            let nets = WiFiService.shared.scanNetworks().map { [
                "ssid": $0.ssid,
                "bssid": $0.bssid,
                "rssi": $0.rssi,
                "isSecure": $0.isSecure,
                "isConnected": $0.isConnected
            ] as [String: Any] }
            return ok(["networks": nets])

        case ("POST", "/api/v1/network/wifi/connect"):
            if let data = body.data(using: .utf8),
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let ssid = json["ssid"] as? String {
                let password = json["password"] as? String
                WiFiService.shared.connect(to: ssid, password: password)
                return ok()
            }
            return err("Missing ssid in payload")

        case ("GET", "/api/v1/bluetooth/devices"):
            let devs = BluetoothService.shared.pairedDevices().map { dev -> [String: Any] in
                var dict: [String: Any] = [
                    "id": dev.id,
                    "name": dev.name,
                    "isConnected": dev.isConnected
                ]
                if let bat = dev.batteryLevel { dict["battery"] = bat }
                return dict
            }
            return ok(["devices": devs])

        case ("POST", "/api/v1/brightness/set"):
            if let data = body.data(using: .utf8),
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let val = json["value"] as? Double {
                BrightnessService.shared.set(val)
                return ok()
            }
            return err("Missing value in payload")

        case ("GET", "/api/v1/settings"), ("GET", "/api/v1/config"):
            if let data = try? ConfigStore.shared.config.encodeJSON(),
               let parsed = try? JSONSerialization.jsonObject(with: data) {
                return ok(parsed)
            }
            return err("Failed to encode settings")

        case ("POST", "/api/v1/settings"):
            if let data = body.data(using: .utf8),
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let key = json["key"] as? String,
               let val = json["value"] {
                ConfigStore.shared.update { cfg in
                    cfg.setSetting(key, value: AnyCodable(val))
                }
                return ok()
            }
            return err("Missing key or value in payload")

        default:
            return err("Route not found: \(method) \(path)")
        }
    }
}
