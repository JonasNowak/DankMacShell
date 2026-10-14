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

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.configDirectory = appSupport.appendingPathComponent("DMS", isDirectory: true)
        self.configFile = configDirectory.appendingPathComponent("config.json")
        self.config = .default

        ensureConfigExists()
        loadConfig()
        startWatching()
    }

    private func ensureConfigExists() {
        if !FileManager.default.fileExists(atPath: configDirectory.path) {
            try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }
        if !FileManager.default.fileExists(atPath: configFile.path) {
            if let data = try? DMSConfig.default.encodeJSON() {
                try? data.write(to: configFile)
            }
        }
    }

    public func loadConfig() {
        guard let data = try? Data(contentsOf: configFile) else {
            return
        }
        self.config = DMSConfig.load(from: data)
    }

    public func update(_ block: (inout DMSConfig) -> Void) {
        block(&config)
        save()
    }

    public func save() {
        if let data = try? config.encodeJSON() {
            try? data.write(to: configFile)
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
                self.loadConfig()
                ThemeStore.shared.apply(theme: self.config.theme, lightMode: self.config.isLightMode)
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
