import Foundation
import Combine
import os
import DMSCore

@MainActor
public final class ConfigStore: ObservableObject {
    public static let shared = ConfigStore()

    private nonisolated static let log = Logger(subsystem: "com.dank.macshell", category: "ConfigStore")

    @Published public private(set) var config: DMSConfig

    private let configDirectory: URL
    private let configFile: URL
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var saveTask: Task<Void, Never>?

    /// Serial queue that serializes every disk write (unique temp file + atomic rename).
    private let writeQueue = DispatchQueue(label: "com.dank.macshell.configstore.write", qos: .utility)

    /// Snapshot of the last bytes this process wrote itself, used together with the
    /// timestamp window to suppress watcher events caused by our own saves.
    private nonisolated static let lastWriteLock = NSLock()
    nonisolated(unsafe) private static var lastWrittenData: Data?

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.configDirectory = appSupport.appendingPathComponent("DMS", isDirectory: true)
        self.configFile = configDirectory.appendingPathComponent("settings.json")
        self.config = .default

        ensureConfigExists()
        loadConfig()
        startWatching()
    }

    private func ensureConfigExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: configDirectory.path) {
            try? fm.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }
        // The DMS support directory holds user settings: keep it owner-only.
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: configDirectory.path)

        // Migrate legacy config.json if settings.json does not exist yet
        let legacyFile = configDirectory.appendingPathComponent("config.json")
        if !fm.fileExists(atPath: configFile.path) && fm.fileExists(atPath: legacyFile.path) {
            try? fm.copyItem(at: legacyFile, to: configFile)
        }

        if !fm.fileExists(atPath: configFile.path) {
            if let data = try? DMSConfig.default.encodeJSON() {
                try? data.write(to: configFile)
            }
        }

        // Config files are private to the user.
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configFile.path)
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: legacyFile.path)
    }

    private var suppressWatcherUntil: Date = .distantPast

    /// Validates that `data` parses as a JSON object before handing it to `DMSConfig.load`.
    /// Returns nil for a non-empty file that fails JSON parsing (e.g. a mid-edit syntax
    /// error from an external editor) so callers keep the current in-memory config
    /// instead of factory-resetting to `.default`.
    private nonisolated static func parseConfig(_ data: Data, baseDirectory: URL) -> DMSConfig? {
        if !data.isEmpty {
            guard let obj = try? JSONSerialization.jsonObject(with: data), obj is [String: Any] else {
                return nil
            }
        }
        return DMSConfig.load(from: data, baseDirectory: baseDirectory)
    }

    public func loadConfig() {
        let fileToLoad: URL
        if FileManager.default.fileExists(atPath: configFile.path) {
            fileToLoad = configFile
        } else {
            let legacyFile = configDirectory.appendingPathComponent("config.json")
            if FileManager.default.fileExists(atPath: legacyFile.path) {
                fileToLoad = legacyFile
            } else {
                return
            }
        }
        guard let data = try? Data(contentsOf: fileToLoad) else {
            return
        }
        guard let loaded = Self.parseConfig(data, baseDirectory: configDirectory) else {
            Self.log.warning("Config file \(fileToLoad.lastPathComponent, privacy: .public) exists but is not a valid JSON object; keeping in-memory config")
            return
        }
        if loaded != self.config {
            self.config = loaded
        }
        ThemeStore.shared.sync(with: self.config)
    }

    public func loadConfigAsync() {
        let primaryURL = configFile
        let legacyURL = configDirectory.appendingPathComponent("config.json")
        let baseDir = configDirectory

        Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .utility) { () -> DMSConfig?? in
                let fileToLoad: URL
                if FileManager.default.fileExists(atPath: primaryURL.path) {
                    fileToLoad = primaryURL
                } else if FileManager.default.fileExists(atPath: legacyURL.path) {
                    fileToLoad = legacyURL
                } else {
                    return nil
                }
                guard let data = try? Data(contentsOf: fileToLoad) else { return nil }
                if !data.isEmpty, (try? JSONSerialization.jsonObject(with: data)) == nil {
                    Self.log.warning("Config file \(fileToLoad.lastPathComponent, privacy: .public) exists but is not valid JSON; keeping in-memory config")
                    return .some(nil)
                }
                return .some(Self.parseConfig(data, baseDirectory: baseDir))
            }.value

            guard let self = self, let loaded = result ?? nil else { return }
            if loaded != self.config {
                self.config = loaded
            }
            ThemeStore.shared.sync(with: self.config)
        }
    }

    public func update(immediate: Bool = true, _ block: (inout DMSConfig) -> Void) {
        var next = config
        let previousBarPosition = next.barPosition
        block(&next)
        guard next != config else { return }
        let nextBarPosition = next.barPosition
        config = next
        ThemeStore.shared.sync(with: config)
        OmniWMThemeSyncService.shared.syncBarPositionMargins(from: previousBarPosition, to: nextBarPosition)
        if immediate {
            flushSave()
        } else {
            scheduleDebouncedSave()
        }
    }

    /// Schedules an atomic write debounced by 250ms per spec SETD-002.
    public func scheduleDebouncedSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000) // 250ms
            if !Task.isCancelled {
                self.save()
            }
        }
    }

    /// Immediately flushes any pending debounced save to disk. Drains the serial write
    /// queue synchronously so `applicationWillTerminate` never loses settings on quit.
    public func flushSave() {
        saveTask?.cancel()
        saveTask = nil
        let snapshot = config
        suppressWatcherUntil = Date().addingTimeInterval(0.45)
        let dir = configDirectory
        let target = configFile
        let legacy = configDirectory.appendingPathComponent("config.json")
        writeQueue.sync {
            Self.writeToDisk(snapshot: snapshot, directory: dir, target: target, legacy: legacy)
        }
    }

    /// Atomic write to disk on the serial write queue using a unique temp file and rename.
    public func save() {
        let snapshot = config
        suppressWatcherUntil = Date().addingTimeInterval(0.45)
        let dir = configDirectory
        let target = configFile
        let legacy = configDirectory.appendingPathComponent("config.json")
        writeQueue.async {
            Self.writeToDisk(snapshot: snapshot, directory: dir, target: target, legacy: legacy)
        }
    }

    /// Serialized disk write. Runs on `writeQueue`; every file goes through a unique
    /// temp name (`.<name>.tmp-<UUID>`) plus rename so readers never see partial JSON.
    private nonisolated static func writeToDisk(snapshot: DMSConfig, directory: URL, target: URL, legacy: URL) {
        guard let data = try? snapshot.encodeJSON() else { return }
        lastWriteLock.lock()
        lastWrittenData = data
        lastWriteLock.unlock()

        let fm = FileManager.default
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        let tmpFile = directory.appendingPathComponent(".\(target.lastPathComponent).tmp-\(UUID().uuidString)")
        do {
            try data.write(to: tmpFile, options: .atomic)
            try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmpFile.path)
            _ = try? fm.replaceItemAt(target, withItemAt: tmpFile)
        } catch {
            try? data.write(to: target)
        }
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)

        // Keep config.json mirrored so both legacy and modern readers stay in sync
        let legacyTmp = directory.appendingPathComponent(".\(legacy.lastPathComponent).tmp-\(UUID().uuidString)")
        if (try? data.write(to: legacyTmp, options: .atomic)) != nil {
            try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: legacyTmp.path)
            _ = try? fm.replaceItemAt(legacy, withItemAt: legacyTmp)
        }
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: legacy.path)
    }

    /// True when the on-disk config file still matches the last bytes we wrote ourselves.
    private static func fileMatchesLastWrite(_ file: URL) -> Bool {
        lastWriteLock.lock()
        let last = lastWrittenData
        lastWriteLock.unlock()
        guard let last, let data = try? Data(contentsOf: file), !data.isEmpty else { return false }
        return data == last
    }

    private func startWatching() {
        stopWatching()
        let watchedFD = open(configFile.path, O_EVTONLY)
        guard watchedFD >= 0 else { return }
        fileDescriptor = watchedFD

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: watchedFD,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let flags = source.data
                let isSelfSave = Date() < self.suppressWatcherUntil || Self.fileMatchesLastWrite(self.configFile)
                if !isSelfSave {
                    self.loadConfigAsync()
                }
                if flags.contains(.rename) || flags.contains(.delete) {
                    try? await Task.sleep(nanoseconds: 60_000_000)
                    self.startWatching()
                }
            }
        }

        // Capture the local descriptor: `self?.fileDescriptor` may already point at a
        // NEWER fd when this source is cancelled during a re-watch, which would close
        // the wrong file descriptor.
        source.setCancelHandler { [weak self] in
            close(watchedFD)
            if self?.fileDescriptor == watchedFD {
                self?.fileDescriptor = -1
            }
        }

        source.resume()
        self.fileMonitorSource = source
    }

    private func stopWatching() {
        fileMonitorSource?.cancel()
        fileMonitorSource = nil
    }

    deinit {
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }
}
