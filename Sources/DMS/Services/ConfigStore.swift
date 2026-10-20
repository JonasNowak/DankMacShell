import Foundation
import Combine
import DMSCore

@MainActor
public final class ConfigStore: ObservableObject {
    public static let shared = ConfigStore()

    @Published public private(set) var config: DMSConfig

    private let configDirectory: URL
    private let configFile: URL
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var saveTask: Task<Void, Never>?

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
        if !FileManager.default.fileExists(atPath: configDirectory.path) {
            try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }

        // Migrate legacy config.json if settings.json does not exist yet
        let legacyFile = configDirectory.appendingPathComponent("config.json")
        if !FileManager.default.fileExists(atPath: configFile.path) && FileManager.default.fileExists(atPath: legacyFile.path) {
            try? FileManager.default.copyItem(at: legacyFile, to: configFile)
        }

        if !FileManager.default.fileExists(atPath: configFile.path) {
            if let data = try? DMSConfig.default.encodeJSON() {
                try? data.write(to: configFile)
            }
        }
    }

    private var suppressWatcherUntil: Date = .distantPast

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
        let loaded = DMSConfig.load(from: data, baseDirectory: configDirectory)
        if loaded != self.config {
            self.config = loaded
        }
        ThemeStore.shared.sync(with: self.config)
    }

    public func loadConfigAsync() {
        let primaryURL = configFile
        let legacyURL = configDirectory.appendingPathComponent("config.json")
        let baseDir = configDirectory

        Task.detached(priority: .utility) { [weak self] in
            let fileToLoad: URL
            if FileManager.default.fileExists(atPath: primaryURL.path) {
                fileToLoad = primaryURL
            } else if FileManager.default.fileExists(atPath: legacyURL.path) {
                fileToLoad = legacyURL
            } else {
                return
            }
            guard let data = try? Data(contentsOf: fileToLoad) else { return }
            let loaded = DMSConfig.load(from: data, baseDirectory: baseDir)
            await MainActor.run {
                guard let self = self else { return }
                if loaded != self.config {
                    self.config = loaded
                }
                ThemeStore.shared.sync(with: self.config)
            }
        }
    }

    public func update(immediate: Bool = true, _ block: (inout DMSConfig) -> Void) {
        var next = config
        block(&next)
        guard next != config else { return }
        config = next
        ThemeStore.shared.sync(with: config)
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

    /// Immediately flushes any pending debounced save to disk.
    public func flushSave() {
        saveTask?.cancel()
        saveTask = nil
        save()
    }

    /// Atomic write to disk off the main thread using a temporary file and rename.
    public func save() {
        let snapshot = config
        let targetFile = configFile
        let legacyFile = configDirectory.appendingPathComponent("config.json")
        suppressWatcherUntil = Date().addingTimeInterval(0.45)

        Task.detached(priority: .utility) {
            guard let data = try? snapshot.encodeJSON() else { return }
            let tmpFile = targetFile.appendingPathExtension("tmp")
            do {
                try data.write(to: tmpFile, options: .atomic)
                _ = try? FileManager.default.replaceItemAt(targetFile, withItemAt: tmpFile)
            } catch {
                try? data.write(to: targetFile)
            }

            // Keep config.json mirrored so both legacy and modern readers stay in sync
            try? data.write(to: legacyFile, options: .atomic)
        }
    }

    private func startWatching() {
        stopWatching()
        fileDescriptor = open(configFile.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let flags = source.data
                let isSelfSave = Date() < self.suppressWatcherUntil
                if !isSelfSave {
                    self.loadConfigAsync()
                }
                if flags.contains(.rename) || flags.contains(.delete) {
                    try? await Task.sleep(nanoseconds: 60_000_000)
                    self.startWatching()
                }
            }
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
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
