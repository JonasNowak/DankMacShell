import Foundation
import Darwin

/// Structured error types for `danksearch` / `dsearch` process spawning, IPC communication, and output parsing.
public enum DankSearchError: Error, Sendable, Equatable, CustomStringConvertible {
    case executableNotFound(String)
    case launchFailed(String)
    case timedOut(TimeInterval)
    case crashedWithSignal(Int32, stderr: String)
    case nonZeroExit(Int32, stderr: String)
    case malformedOutput(String)
    case ipcFailure(String)

    public var description: String {
        switch self {
        case .executableNotFound(let path):
            return "danksearch executable not found at '\(path)'"
        case .launchFailed(let msg):
            return "Failed to launch danksearch process: \(msg)"
        case .timedOut(let seconds):
            return String(format: "danksearch query timed out after %.2fs", seconds)
        case .crashedWithSignal(let sig, let stderr):
            let extra = stderr.isEmpty ? "" : " (\(stderr))"
            return "danksearch crashed with signal \(sig)\(extra)"
        case .nonZeroExit(let code, let stderr):
            let extra = stderr.isEmpty ? "" : " (\(stderr))"
            return "danksearch exited unexpectedly with code \(code)\(extra)"
        case .malformedOutput(let detail):
            return "danksearch returned malformed output: \(detail)"
        case .ipcFailure(let detail):
            return "danksearch IPC communication error: \(detail)"
        }
    }
}

/// Current operational health state of the `danksearch` integration.
public enum DankSearchHealthState: Sendable, Equatable {
    case healthy
    case recovering(attempt: Int)
    case degraded(reason: String, error: DankSearchError, timestamp: Date)

    public var isDegraded: Bool {
        if case .degraded = self { return true }
        return false
    }

    public var statusMessage: String? {
        switch self {
        case .healthy:
            return nil
        case .recovering(let attempt):
            return "Reconnecting to danksearch (attempt \(attempt))…"
        case .degraded(let reason, _, _):
            return reason
        }
    }
}

/// Diagnostic log entry recorded whenever `danksearch` encounters an error or recovers.
public struct DankSearchDiagnosticEntry: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let query: String
    public let backend: String
    public let error: DankSearchError?
    public let message: String
    public let recovered: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        query: String,
        backend: String,
        error: DankSearchError? = nil,
        message: String,
        recovered: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.query = query
        self.backend = backend
        self.error = error
        self.message = message
        self.recovered = recovered
    }
}

/// Result of a fault-tolerant `danksearch` query including fallback indicator and health status.
public struct DankSearchResponse: Sendable, Equatable {
    public let files: [FileItem]
    public let apps: [SearchResult]
    public let usedFallback: Bool
    public let backendUsed: String
    public let healthState: DankSearchHealthState
    public let error: DankSearchError?

    public var items: [FileItem] { files }

    public var userWarning: String? {
        if let msg = healthState.statusMessage {
            return msg
        }
        if let error {
            return "danksearch error (\(error.description)) — using Spotlight fallback"
        }
        return nil
    }

    public init(
        files: [FileItem],
        apps: [SearchResult] = [],
        usedFallback: Bool,
        backendUsed: String,
        healthState: DankSearchHealthState,
        error: DankSearchError? = nil
    ) {
        self.files = files
        self.apps = apps
        self.usedFallback = usedFallback
        self.backendUsed = backendUsed
        self.healthState = healthState
        self.error = error
    }
}

/// Output from a crash-isolated subprocess execution.
public struct SafeProcessOutput: Sendable, Equatable {
    public let stdout: Data
    public let stderr: Data
    public let terminationStatus: Int32
    public let terminatedBySignal: Bool
    public let timedOut: Bool
}

/// Crash-isolated subprocess executor that prevents pipe buffer deadlocks and enforces strict execution timeouts.
public enum SafeProcessRunner: Sendable {

    /// Executes an external binary safely off the main thread with concurrent pipe reading and a hard watchdog timeout.
    public static func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 1.5
    ) -> Result<SafeProcessOutput, DankSearchError> {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: executablePath) else {
            return .failure(.executableNotFound(executablePath))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        if let environment {
            process.environment = environment
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        let stdoutReadHandle = stdoutPipe.fileHandleForReading
        let stderrReadHandle = stderrPipe.fileHandleForReading

        do {
            try process.run()
        } catch {
            try? stdoutReadHandle.close()
            try? stderrReadHandle.close()
            return .failure(.launchFailed(error.localizedDescription))
        }

        let pid = process.processIdentifier
        let group = DispatchGroup()
        nonisolated(unsafe) var stdoutData = Data()
        nonisolated(unsafe) var stderrData = Data()

        // Read stdout and stderr concurrently BEFORE waiting for exit to prevent 64KB kernel pipe buffer deadlocks.
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stdoutData = (try? stdoutReadHandle.readToEnd()) ?? Data()
            group.leave()
        }

        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stderrData = (try? stderrReadHandle.readToEnd()) ?? Data()
            group.leave()
        }

        let exitSemaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            process.waitUntilExit()
            exitSemaphore.signal()
        }

        let waitResult = exitSemaphore.wait(timeout: .now() + max(0.02, timeout))
        var didTimeout = false

        if waitResult == .timedOut {
            didTimeout = true
            if process.isRunning {
                process.terminate()
            }
            // Give process 30ms to handle SIGTERM, then force SIGKILL so pipes close cleanly
            if exitSemaphore.wait(timeout: .now() + 0.03) == .timedOut {
                if pid > 0 {
                    kill(pid, SIGKILL)
                }
                _ = exitSemaphore.wait(timeout: .now() + 0.1)
            }
            try? stdoutReadHandle.close()
            try? stderrReadHandle.close()
        }

        // Wait briefly for pipe readers to finish draining
        _ = group.wait(timeout: .now() + 0.2)

        if didTimeout {
            return .failure(.timedOut(timeout))
        }

        let stderrString = (String(data: stderrData, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationReason == .uncaughtSignal {
            return .failure(.crashedWithSignal(process.terminationStatus, stderr: stderrString))
        }

        if process.terminationStatus != 0 {
            return .failure(.nonZeroExit(process.terminationStatus, stderr: stderrString))
        }

        return .success(SafeProcessOutput(
            stdout: stdoutData,
            stderr: stderrData,
            terminationStatus: process.terminationStatus,
            terminatedBySignal: false,
            timedOut: false
        ))
    }
}

/// Fault-tolerant `danksearch` / `dsearch` client with crash isolation, error boundaries, diagnostic logging,
/// graceful fallback to Spotlight/shallow search, and automatic service recovery on subsequent queries.
public final class DankSearchClient: @unchecked Sendable {
    public static let shared = DankSearchClient()

    /// Custom backend closure for testing or in-process IPC override.
    /// Returns raw stdout string or throws `DankSearchError`.
    public typealias BackendExecutor = @Sendable (_ query: String, _ maxResults: Int, _ timeout: TimeInterval) -> Result<Data, DankSearchError>

    private let lock = NSLock()
    private var _healthState: DankSearchHealthState = .healthy
    private var _diagnostics: [DankSearchDiagnosticEntry] = []
    private var _consecutiveFailures: Int = 0
    private var _recoveryAttempts: Int = 0
    private var _customExecutablePath: String?
    private var _customExecutor: BackendExecutor?
    private var _timeout: TimeInterval = 1.5
    private let maxDiagnosticEntries = 100

    public init(
        customExecutablePath: String? = nil,
        timeout: TimeInterval = 1.5,
        customExecutor: BackendExecutor? = nil
    ) {
        self._customExecutablePath = customExecutablePath
        self._timeout = timeout
        self._customExecutor = customExecutor
    }

    public var healthState: DankSearchHealthState {
        lock.lock()
        defer { lock.unlock() }
        return _healthState
    }

    public var diagnostics: [DankSearchDiagnosticEntry] {
        lock.lock()
        defer { lock.unlock() }
        return _diagnostics
    }

    public var consecutiveFailures: Int {
        lock.lock()
        defer { lock.unlock() }
        return _consecutiveFailures
    }

    public var timeout: TimeInterval {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _timeout
        }
        set {
            lock.lock()
            _timeout = max(0.02, newValue)
            lock.unlock()
        }
    }

    public func configure(executablePath: String? = nil, timeout: TimeInterval? = nil, customExecutor: BackendExecutor? = nil) {
        lock.lock()
        if let executablePath {
            _customExecutablePath = executablePath
        }
        if let timeout {
            _timeout = max(0.02, timeout)
        }
        _customExecutor = customExecutor
        lock.unlock()
    }

    /// Resets the client health state and restarts the service state.
    public func resetAndRecover() {
        lock.lock()
        _healthState = .healthy
        _consecutiveFailures = 0
        _recoveryAttempts = 0
        lock.unlock()
    }

    public func resetHealthState() {
        resetAndRecover()
    }

    public func clearDiagnostics() {
        lock.lock()
        _diagnostics.removeAll()
        lock.unlock()
    }

    public func resolveBinaryPath() -> String? {
        resolveExecutablePath()
    }

    /// Discovers an installed `danksearch` or `dsearch` binary in standard paths, if present.
    public func resolveExecutablePath() -> String? {
        lock.lock()
        let custom = _customExecutablePath
        lock.unlock()

        if let custom, !custom.isEmpty {
            return custom
        }

        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/danksearch",
            "/usr/local/bin/danksearch",
            "\(home)/.local/bin/danksearch",
            "/usr/bin/danksearch",
            "/opt/homebrew/bin/dsearch",
            "/usr/local/bin/dsearch",
            "\(home)/.local/bin/dsearch",
            "/usr/bin/dsearch"
        ]
        for path in candidates where fm.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    /// Parses raw output from `danksearch` (supports JSON array of objects, NDJSON, or newline-delimited file paths).
    /// Rejects corrupted/non-UTF8 or invalid JSON structures with `.malformedOutput`.
    public static func parseOutput(_ data: Data, maxResults: Int = 12, verifyFileExists: Bool = false) -> Result<[FileItem], DankSearchError> {
        guard let text = String(data: data, encoding: .utf8) else {
            return .failure(.malformedOutput("Output is not valid UTF-8 encoding"))
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .success([])
        }

        // 1. Check if output looks like JSON (starts with `[` or `{`)
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            // Try JSON array first
            if trimmed.hasPrefix("[") {
                guard let jsonArray = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) as? [[String: Any]] else {
                    return .failure(.malformedOutput("Invalid JSON array from danksearch"))
                }
                var items: [FileItem] = []
                for obj in jsonArray {
                    guard let path = (obj["path"] as? String) ?? (obj["file"] as? String),
                          !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return .failure(.malformedOutput("JSON entry missing required 'path' field"))
                    }
                    let name = (obj["name"] as? String) ?? (path as NSString).lastPathComponent
                    let isDir = (obj["isDirectory"] as? Bool) ?? (obj["is_dir"] as? Bool) ?? false
                    items.append(FileItem(name: name, path: path, isDirectory: isDir))
                    if items.count >= maxResults { break }
                }
                return .success(items)
            }

            // Try single JSON object or NDJSON lines
            let lines = trimmed.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            var items: [FileItem] = []
            for line in lines {
                guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
                    return .failure(.malformedOutput("Malformed JSON object in danksearch output"))
                }
                if let errStr = obj["error"] as? String {
                    return .failure(.malformedOutput("danksearch reported error: \(errStr)"))
                }
                if let resultsArr = obj["results"] as? [[String: Any]] {
                    for entry in resultsArr {
                        guard let path = (entry["path"] as? String) ?? (entry["file"] as? String),
                              !path.isEmpty else {
                            return .failure(.malformedOutput("Result item missing 'path' field"))
                        }
                        let name = (entry["name"] as? String) ?? (path as NSString).lastPathComponent
                        let isDir = (entry["isDirectory"] as? Bool) ?? (entry["is_dir"] as? Bool) ?? false
                        items.append(FileItem(name: name, path: path, isDirectory: isDir))
                        if items.count >= maxResults { break }
                    }
                    continue
                }
                guard let path = (obj["path"] as? String) ?? (obj["file"] as? String),
                      !path.isEmpty else {
                    return .failure(.malformedOutput("NDJSON item missing 'path' field"))
                }
                let name = (obj["name"] as? String) ?? (path as NSString).lastPathComponent
                let isDir = (obj["isDirectory"] as? Bool) ?? (obj["is_dir"] as? Bool) ?? false
                items.append(FileItem(name: name, path: path, isDirectory: isDir))
                if items.count >= maxResults { break }
            }
            return .success(items)
        }

        // 2. Plain text newline-separated paths: validate each line is a plausible absolute or tilde path
        let fm = FileManager.default
        var items: [FileItem] = []
        for rawLine in trimmed.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            // Reject garbage/corrupted output that is neither a path nor valid JSON
            guard line.hasPrefix("/") || line.hasPrefix("~") else {
                return .failure(.malformedOutput("Unrecognized non-path line: '\(line.prefix(60))'"))
            }

            let expanded = (line as NSString).expandingTildeInPath
            var isDir: ObjCBool = false
            if verifyFileExists {
                guard fm.fileExists(atPath: expanded, isDirectory: &isDir) else { continue }
            } else {
                _ = fm.fileExists(atPath: expanded, isDirectory: &isDir)
            }
            let name = (expanded as NSString).lastPathComponent
            items.append(FileItem(name: name, path: expanded, isDirectory: isDir.boolValue))
            if items.count >= maxResults {
                break
            }
        }

        return .success(items)
    }

    /// Executes a fault-tolerant file search query.
    /// Automatically recovers on the next search attempt if previously degraded, logs any errors,
    /// and degrades gracefully to Spotlight (`mdfind`) and shallow directory search on failure.
    public func searchFiles(
        query: String,
        maxResults: Int = 12,
        fallbackProvider: ((_ cleanQuery: String, _ maxResults: Int) -> [FileItem])? = nil
    ) -> DankSearchResponse {
        let provider = fallbackProvider ?? { _, _ in [] }
        let clean = AppSearch.extractFileQuery(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else {
            return DankSearchResponse(
                files: [],
                usedFallback: false,
                backendUsed: "none",
                healthState: healthState
            )
        }

        lock.lock()
        let currentTimeout = _timeout
        let customExecutor = _customExecutor
        let customPath = _customExecutablePath
        let wasDegraded = _healthState.isDegraded
        if wasDegraded {
            _recoveryAttempts += 1
            _healthState = .recovering(attempt: _recoveryAttempts)
        }
        lock.unlock()

        // 1. If a custom executor or danksearch binary is configured/installed, attempt primary danksearch query
        if let customExecutor {
            let execResult = customExecutor(clean, maxResults, currentTimeout)
            return handlePrimaryResult(
                execResult,
                query: clean,
                backendName: "danksearch",
                maxResults: maxResults,
                verifyFileExists: false,
                wasDegraded: wasDegraded,
                fallbackProvider: provider
            )
        }

        if let binPath = customPath ?? resolveExecutablePath() {
            let runResult = SafeProcessRunner.run(
                executablePath: binPath,
                arguments: ["--json", "--limit", "\(maxResults)", clean],
                timeout: currentTimeout
            ).map { $0.stdout }

            return handlePrimaryResult(
                runResult,
                query: clean,
                backendName: (binPath as NSString).lastPathComponent,
                maxResults: maxResults,
                verifyFileExists: false,
                wasDegraded: wasDegraded,
                fallbackProvider: provider
            )
        }

        // 2. No external danksearch binary present; use native Spotlight + shallow fallback
        let files = provider(clean, maxResults)
        if wasDegraded {
            recordRecovery(query: clean, backend: "spotlight")
        }
        return DankSearchResponse(
            files: files,
            usedFallback: false,
            backendUsed: "spotlight",
            healthState: healthState
        )
    }

    private func handlePrimaryResult(
        _ rawResult: Result<Data, DankSearchError>,
        query: String,
        backendName: String,
        maxResults: Int,
        verifyFileExists: Bool,
        wasDegraded: Bool,
        fallbackProvider: (_ cleanQuery: String, _ maxResults: Int) -> [FileItem]
    ) -> DankSearchResponse {
        switch rawResult {
        case .success(let data):
            switch Self.parseOutput(data, maxResults: maxResults, verifyFileExists: verifyFileExists) {
            case .success(let parsedFiles):
                if wasDegraded {
                    recordRecovery(query: query, backend: backendName)
                } else {
                    lock.lock()
                    _healthState = .healthy
                    _consecutiveFailures = 0
                    lock.unlock()
                }
                // If primary returned empty, still consult fallback if needed or return parsed
                let finalFiles = parsedFiles.isEmpty ? fallbackProvider(query, maxResults) : parsedFiles
                return DankSearchResponse(
                    files: finalFiles,
                    usedFallback: false,
                    backendUsed: backendName,
                    healthState: .healthy,
                    error: nil
                )
            case .failure(let parseError):
                return degradeAndFallback(
                    error: parseError,
                    query: query,
                    backendName: backendName,
                    maxResults: maxResults,
                    fallbackProvider: fallbackProvider
                )
            }
        case .failure(let runError):
            return degradeAndFallback(
                error: runError,
                query: query,
                backendName: backendName,
                maxResults: maxResults,
                fallbackProvider: fallbackProvider
            )
        }
    }

    private func degradeAndFallback(
        error: DankSearchError,
        query: String,
        backendName: String,
        maxResults: Int,
        fallbackProvider: (_ cleanQuery: String, _ maxResults: Int) -> [FileItem]
    ) -> DankSearchResponse {
        let now = Date()
        let reason = "danksearch unavailable (\(error.description)) — using fallback search"

        lock.lock()
        _consecutiveFailures += 1
        let newState = DankSearchHealthState.degraded(reason: reason, error: error, timestamp: now)
        _healthState = newState
        appendDiagnosticLocked(DankSearchDiagnosticEntry(
            timestamp: now,
            query: query,
            backend: backendName,
            error: error,
            message: reason,
            recovered: false
        ))
        lock.unlock()

        let fallbackFiles = fallbackProvider(query, maxResults)
        return DankSearchResponse(
            files: fallbackFiles,
            usedFallback: true,
            backendUsed: "fallback",
            healthState: newState,
            error: error
        )
    }

    private func recordRecovery(query: String, backend: String) {
        let now = Date()
        lock.lock()
        _healthState = .healthy
        _consecutiveFailures = 0
        appendDiagnosticLocked(DankSearchDiagnosticEntry(
            timestamp: now,
            query: query,
            backend: backend,
            error: nil,
            message: "danksearch service automatically recovered on query '\(query)'",
            recovered: true
        ))
        lock.unlock()
    }

    private func appendDiagnosticLocked(_ entry: DankSearchDiagnosticEntry) {
        _diagnostics.append(entry)
        if _diagnostics.count > maxDiagnosticEntries {
            _diagnostics.removeFirst(_diagnostics.count - maxDiagnosticEntries)
        }
    }
}
