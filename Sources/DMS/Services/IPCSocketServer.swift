import Foundation
import DMSCore

/// Unix domain socket server with persistent connection pool and pub/sub event streaming.
/// Listens at `~/Library/Application Support/DMS/dms.sock`.
public final class IPCSocketServer: @unchecked Sendable {
    public static let shared = IPCSocketServer()

    private var serverFD: Int32 = -1
    private let socketURL: URL
    private var isRunning: Bool = false
    private let queue = DispatchQueue(label: "io.github.jonasnowak.dms.socket", qos: .userInitiated)
    private let clientQueue = DispatchQueue(label: "io.github.jonasnowak.dms.socket.clients", qos: .userInitiated, attributes: .concurrent)

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dmsDir = appSupport.appendingPathComponent("DMS", isDirectory: true)
        try? FileManager.default.createDirectory(at: dmsDir, withIntermediateDirectories: true)
        self.socketURL = dmsDir.appendingPathComponent("dms.sock")
    }

    public func start() {
        guard !isRunning else { return }

        // Ignore SIGPIPE to prevent client disconnects from killing the daemon
        signal(SIGPIPE, SIG_IGN)

        let path = socketURL.path
        unlink(path) // Remove stale socket file

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            print("Failed to create Unix domain socket.")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = path.utf8CString
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
        unlink(socketURL.path)
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

            clientQueue.async { [weak self] in
                self?.handleClientConnection(clientFD)
            }
        }
    }

    private func handleClientConnection(_ clientFD: Int32) {
        var readBuffer = Data()
        var keepOpen = false

        defer {
            EventSubscriptionBroker.shared.unsubscribe(clientFD: clientFD)
            close(clientFD)
        }

        var chunk = [UInt8](repeating: 0, count: 4096)
        while isRunning {
            let bytesRead = read(clientFD, &chunk, chunk.count)
            guard bytesRead > 0 else { break }

            readBuffer.append(contentsOf: chunk.prefix(bytesRead))

            // Process full newline-delimited lines
            while let newlineIndex = readBuffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = readBuffer.subdata(in: 0..<newlineIndex)
                readBuffer.removeSubrange(0...newlineIndex)

                guard let rawLine = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !rawLine.isEmpty else {
                    continue
                }

                let (response, isStreaming) = processLine(rawLine, clientFD: clientFD)
                if isStreaming {
                    keepOpen = true
                }

                if let response = response {
                    let out = response.hasSuffix("\n") ? response : (response + "\n")
                    _ = out.utf8CString.withUnsafeBufferPointer { buf in
                        write(clientFD, buf.baseAddress!, buf.count - 1)
                    }
                }

                // If this was a one-shot request and the client has not subscribed to any streams, exit loop
                if !keepOpen && !EventSubscriptionBroker.shared.isSubscribed(clientFD: clientFD) {
                    return
                }
            }
        }
    }

    private func processLine(_ line: String, clientFD: Int32) -> (response: String?, isStreaming: Bool) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Pub/Sub protocol: SUBSCRIBE <topic>
        if trimmed.uppercased().hasPrefix("SUBSCRIBE ") || trimmed.hasPrefix("subscribe:") {
            let topic: String
            if trimmed.uppercased().hasPrefix("SUBSCRIBE ") {
                topic = String(trimmed.dropFirst("SUBSCRIBE ".count)).trimmingCharacters(in: .whitespaces)
            } else {
                topic = String(trimmed.dropFirst("subscribe:".count)).trimmingCharacters(in: .whitespaces)
            }

            EventSubscriptionBroker.shared.subscribe(clientFD: clientFD, topic: topic)
            let ack = "{\"status\":\"subscribed\",\"topic\":\"\(topic)\"}"
            return (ack, true)
        }

        // Pub/Sub protocol: UNSUBSCRIBE <topic>
        if trimmed.uppercased().hasPrefix("UNSUBSCRIBE ") {
            let topic = String(trimmed.dropFirst("UNSUBSCRIBE ".count)).trimmingCharacters(in: .whitespaces)
            EventSubscriptionBroker.shared.unsubscribe(clientFD: clientFD, topic: topic)
            let ack = "{\"status\":\"unsubscribed\",\"topic\":\"\(topic)\"}"
            return (ack, true)
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

        let responseText = DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                IPCCommandExecutor.execute(command)
            }
        }

        return (responseText, false)
    }

    @MainActor
    private func handleRestRequest(method: String, path: String, body: String) -> String {
        switch (method, path) {
        case ("GET", "/api/v1/audio/volume"):
            let vol = AudioService.shared.volume
            let muted = AudioService.shared.isMuted
            return "{\"status\":\"ok\",\"data\":{\"volume\":\(vol),\"isMuted\":\(muted)}}"

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
            return "{\"status\":\"ok\",\"data\":{\"volume\":\(AudioService.shared.volume),\"isMuted\":\(AudioService.shared.isMuted)}}"

        case ("GET", "/api/v1/audio/sinks"):
            let sinks = AudioService.shared.outputs.map { [
                "id": $0.id,
                "name": $0.name,
                "isDefault": $0.isDefault
            ] as [String: Any] }
            if let data = try? JSONSerialization.data(withJSONObject: sinks),
               let jsonStr = String(data: data, encoding: .utf8) {
                return "{\"status\":\"ok\",\"data\":{\"sinks\":\(jsonStr)}}"
            }
            return "{\"status\":\"ok\",\"data\":{\"sinks\":[]}}"

        case ("POST", "/api/v1/audio/sinks"):
            if let data = body.data(using: .utf8),
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let sinkID = json["id"] as? UInt32 {
                AudioService.shared.setDefaultOutput(sinkID)
                return "{\"status\":\"ok\"}"
            }
            return "{\"status\":\"error\",\"message\":\"Missing id in payload\"}"

        case ("GET", "/api/v1/network/wifi/scan"):
            let nets = WiFiService.shared.scanNetworks().map { [
                "ssid": $0.ssid,
                "bssid": $0.bssid,
                "rssi": $0.rssi,
                "isSecure": $0.isSecure,
                "isConnected": $0.isConnected
            ] as [String: Any] }
            if let data = try? JSONSerialization.data(withJSONObject: nets),
               let jsonStr = String(data: data, encoding: .utf8) {
                return "{\"status\":\"ok\",\"data\":{\"networks\":\(jsonStr)}}"
            }
            return "{\"status\":\"ok\",\"data\":{\"networks\":[]}}"

        case ("POST", "/api/v1/network/wifi/connect"):
            if let data = body.data(using: .utf8),
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let ssid = json["ssid"] as? String {
                let password = json["password"] as? String
                WiFiService.shared.connect(to: ssid, password: password)
                return "{\"status\":\"ok\"}"
            }
            return "{\"status\":\"error\",\"message\":\"Missing ssid in payload\"}"

        case ("GET", "/api/v1/bluetooth/devices"):
            let devs = BluetoothService.shared.pairedDevices().map { dev in
                var dict: [String: Any] = [
                    "id": dev.id,
                    "name": dev.name,
                    "isConnected": dev.isConnected
                ]
                if let bat = dev.batteryLevel { dict["battery"] = bat }
                return dict
            }
            if let data = try? JSONSerialization.data(withJSONObject: devs),
               let jsonStr = String(data: data, encoding: .utf8) {
                return "{\"status\":\"ok\",\"data\":{\"devices\":\(jsonStr)}}"
            }
            return "{\"status\":\"ok\",\"data\":{\"devices\":[]}}"

        case ("POST", "/api/v1/brightness/set"):
            if let data = body.data(using: .utf8),
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let val = json["value"] as? Double {
                BrightnessService.shared.set(val)
                return "{\"status\":\"ok\"}"
            }
            return "{\"status\":\"error\",\"message\":\"Missing value in payload\"}"

        case ("GET", "/api/v1/settings"), ("GET", "/api/v1/config"):
            if let data = try? ConfigStore.shared.config.encodeJSON(),
               let str = String(data: data, encoding: .utf8) {
                return "{\"status\":\"ok\",\"data\":\(str)}"
            }
            return "{\"status\":\"error\",\"message\":\"Failed to encode settings\"}"

        case ("POST", "/api/v1/settings"):
            if let data = body.data(using: .utf8),
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let key = json["key"] as? String,
               let val = json["value"] {
                ConfigStore.shared.update { cfg in
                    cfg.setSetting(key, value: AnyCodable(val))
                }
                return "{\"status\":\"ok\"}"
            }
            return "{\"status\":\"error\",\"message\":\"Missing key or value in payload\"}"

        default:
            return "{\"status\":\"error\",\"message\":\"Route not found: \(method) \(path)\"}"
        }
    }
}
