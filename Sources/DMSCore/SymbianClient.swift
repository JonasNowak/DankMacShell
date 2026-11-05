import Foundation
import Darwin

/// Errors that can occur when launching or interacting with the separate `dms-symbian` companion process.
public enum SymbianClientError: Error, Sendable, Equatable, CustomStringConvertible {
    case executableNotFound(String)
    case launchFailed(String)
    case timedOut(TimeInterval)
    case executionFailed(Int32, stderr: String)

    public var description: String {
        switch self {
        case .executableNotFound(let path):
            return "dms-symbian companion executable not found at '\(path)'"
        case .launchFailed(let msg):
            return "Failed to launch dms-symbian: \(msg)"
        case .timedOut(let sec):
            return String(format: "dms-symbian operation timed out after %.1fs", sec)
        case .executionFailed(let code, let stderr):
            let extra = stderr.isEmpty ? "" : " (\(stderr))"
            return "dms-symbian exited with code \(code)\(extra)"
        }
    }
}

/// Client interface for interacting with the standalone `dms-symbian` application.
/// Provides crash-isolated process launching and CLI action delegation (similar to `DankSearchClient`).
public final class SymbianClient: @unchecked Sendable {
    public static let shared = SymbianClient()

    public var customExecutablePath: String? = nil

    public init(customExecutablePath: String? = nil) {
        self.customExecutablePath = customExecutablePath
    }

    /// Resolves the filesystem path to the `dms-symbian` standalone executable.
    public func resolveExecutablePath() -> String? {
        if let custom = customExecutablePath {
            return FileManager.default.isExecutableFile(atPath: custom) ? custom : nil
        }

        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/dms-symbian",
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/dms-symbian").path,
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("dms-symbian").path,
            "/Applications/DankMacShell.app/Contents/MacOS/dms-symbian",
            "/Applications/DMS.app/Contents/MacOS/dms-symbian",
            "/usr/local/bin/dms-symbian",
            "/opt/homebrew/bin/dms-symbian",
            "\(home)/Library/Caches/DMS/build/out/Products/Debug/dms-symbian",
            "\(home)/Library/Caches/DMS/build/out/Products/Release/dms-symbian"
        ]

        let fm = FileManager.default
        for p in candidates {
            if fm.isExecutableFile(atPath: p) {
                return p
            }
        }
        return nil
    }

    /// Launches the standalone Nokia Belle USB Sync companion GUI application as a separate, crash-isolated process.
    @discardableResult
    public func launchCompanion() -> Result<Void, SymbianClientError> {
        guard let path = resolveExecutablePath() else {
            return .failure(.executableNotFound("dms-symbian"))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--gui"]
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
            return .success(())
        } catch {
            return .failure(.launchFailed(error.localizedDescription))
        }
    }

    /// Executes a headless command (e.g. `status`, `sync`, `clean`, `install`) via `SafeProcessRunner`.
    public func runAction(_ action: String, arguments: [String] = [], timeout: TimeInterval = 60.0) -> Result<String, SymbianClientError> {
        guard let path = resolveExecutablePath() else {
            return .failure(.executableNotFound("dms-symbian"))
        }

        var fullArgs = [action]
        fullArgs.append(contentsOf: arguments)

        let result = SafeProcessRunner.run(executablePath: path, arguments: fullArgs, timeout: timeout)
        switch result {
        case .success(let output):
            let str = String(data: output.stdout, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return .success(str)
        case .failure(let err):
            switch err {
            case .executableNotFound(let p):
                return .failure(.executableNotFound(p))
            case .timedOut(let t):
                return .failure(.timedOut(t))
            case .launchFailed(let msg):
                return .failure(.launchFailed(msg))
            case .crashedWithSignal(let sig, let stderr):
                return .failure(.executionFailed(sig, stderr: "crashed with signal \(sig): \(stderr)"))
            case .nonZeroExit(let code, let stderr):
                return .failure(.executionFailed(code, stderr: stderr))
            default:
                return .failure(.executionFailed(-1, stderr: err.description))
            }
        }
    }
}
