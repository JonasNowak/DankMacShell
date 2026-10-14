import Foundation
import DMSCore

/// Unix domain socket server for instant IPC communication with the `dms` CLI and scripts.
public final class IPCSocketServer: @unchecked Sendable {
    public static let shared = IPCSocketServer()

    private var serverFD: Int32 = -1
    private let socketURL: URL
    private var isRunning: Bool = false
    private let queue = DispatchQueue(label: "io.github.jonasnowak.dms.socket", qos: .userInitiated)

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dmsDir = appSupport.appendingPathComponent("DMS", isDirectory: true)
        try? FileManager.default.createDirectory(at: dmsDir, withIntermediateDirectories: true)
        self.socketURL = dmsDir.appendingPathComponent("dms.sock")
    }

    public func start() {
        guard !isRunning else { return }

        let path = socketURL.path
        unlink(path) // Remove stale socket

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

        guard listen(fd, 10) == 0 else {
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

            handleClient(clientFD)
        }
    }

    private func handleClient(_ clientFD: Int32) {
        defer { close(clientFD) }

        var buffer = [CChar](repeating: 0, count: 4096)
        let bytesRead = read(clientFD, &buffer, 4095)
        guard bytesRead > 0 else { return }

        let raw = String(decoding: buffer.prefix(bytesRead).map { UInt8(bitPattern: $0) }, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = raw.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        let command = IPCCommand.parseCLI(args: tokens)

        let responseText = DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                IPCCommandExecutor.execute(command)
            }
        }

        let out = responseText.hasSuffix("\n") ? responseText : (responseText + "\n")
        _ = out.utf8CString.withUnsafeBufferPointer { buf in
            write(clientFD, buf.baseAddress!, buf.count - 1)
        }
    }
}
