import Foundation
import Combine
import AppKit
import DMSCore

/// Local plugin runtime: discovers `manifest.json` plugins under
/// `~/Library/Application Support/DMS/plugins`, runs their widget commands on a
/// schedule, and dispatches click actions.
@MainActor
public final class PluginRuntimeService: ObservableObject {
    public static let shared = PluginRuntimeService()

    @Published public private(set) var manifests: [String: DMSPluginManifest] = [:]
    @Published public private(set) var widgetOutputs: [String: DMSPluginWidgetOutput] = [:]
    @Published public private(set) var activeWidgetPluginIDs: [String] = []
    @Published public private(set) var activeLauncherPluginIDs: [String] = []

    private let fileManager = FileManager.default
    private var timers: [String: Timer] = [:]

    /// `~/Library/Application Support/DMS/plugins`, created on demand.
    public var pluginsDirectoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DMS/plugins")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {}

    /// Scans immediate subdirectories of `pluginsDirectoryURL` for `manifest.json`,
    /// decodes each into `manifests`, and returns them as local `DMSPlugin` entries.
    @discardableResult
    public func discoverLocalPlugins() -> [DMSPlugin] {
        let dir = pluginsDirectoryURL
        var found: [DMSPlugin] = []
        var discovered: [String: DMSPluginManifest] = [:]

        guard let entries = try? fileManager.contentsOfDirectory(atPath: dir.path) else {
            manifests = [:]
            return []
        }

        for entry in entries.sorted() {
            let manifestURL = dir.appendingPathComponent(entry).appendingPathComponent("manifest.json")
            guard fileManager.fileExists(atPath: manifestURL.path),
                  let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(DMSPluginManifest.self, from: data) else {
                continue
            }
            discovered[manifest.id] = manifest
            var plugin = DMSPlugin(
                id: manifest.id,
                name: manifest.name,
                description: manifest.description,
                author: manifest.author,
                version: manifest.version,
                type: manifest.type,
                isInstalled: true,
                isEnabled: false,
                icon: manifest.icon,
                repoURL: nil,
                tags: [],
                isOfficial: false
            )
            plugin.isLocal = true
            found.append(plugin)
        }

        manifests = discovered
        return found
    }

    /// Reconciles running widget timers with the enabled plugin set: stops timers for
    /// disabled/removed plugins, updates the active widget/launcher ID lists, and
    /// (re)schedules each enabled local bar-widget manifest at its clamped interval.
    public func syncRunningPlugins(enabledIDs: Set<String>) {
        for (id, timer) in timers where !enabledIDs.contains(id) || manifests[id] == nil {
            timer.invalidate()
            timers.removeValue(forKey: id)
        }

        let enabledManifests = manifests.values.filter { enabledIDs.contains($0.id) }
        activeWidgetPluginIDs = enabledManifests
            .filter { $0.type == .barWidget }
            .map { $0.id }
            .sorted()
        activeLauncherPluginIDs = enabledManifests
            .filter { $0.type == .launcher }
            .map { $0.id }
            .sorted()

        for manifest in enabledManifests where manifest.type == .barWidget {
            runWidgetCommand(manifest)
            scheduleWidgetTimer(for: manifest)
        }
    }

    /// Dispatches a plugin click: `onClick ?? command`, opened as a URL when it starts
    /// with http(s)://, otherwise executed through `/bin/sh -c` (widget output is
    /// refreshed shortly after).
    public func triggerClick(pluginID: String) {
        guard let manifest = manifests[pluginID] else { return }
        let action = (manifest.onClick ?? manifest.command).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !action.isEmpty else { return }

        if action.hasPrefix("http://") || action.hasPrefix("https://"),
           let url = URL(string: action) {
            NSWorkspace.shared.open(url)
            return
        }

        Task.detached(priority: .utility) { [weak self] in
            _ = SafeProcessRunner.run(executablePath: "/bin/sh", arguments: ["-c", action], timeout: 5.0)
            try? await Task.sleep(nanoseconds: 500_000_000)
            Task { @MainActor [weak self] in
                guard let self, let manifest = self.manifests[pluginID] else { return }
                self.runWidgetCommand(manifest)
            }
        }
    }

    /// Creates `pluginsDirectoryURL` if needed and opens it in Finder.
    public func openPluginsFolder() {
        let dir = pluginsDirectoryURL
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    /// Writes the `hello-world` example bar-widget plugin (manifest + executable script).
    @discardableResult
    public func createExamplePlugin() -> URL? {
        let dir = pluginsDirectoryURL.appendingPathComponent("hello-world")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let manifestJSON = """
        {
          "id": "hello-world",
          "name": "Hello World Script",
          "description": "Sample local bar widget plugin using a shell script.",
          "author": "Local",
          "version": "1.0.0",
          "type": "widget",
          "icon": "sparkles",
          "command": "$HOME/Library/Application Support/DMS/plugins/hello-world/status.sh",
          "intervalSeconds": 30,
          "onClick": "open https://github.com/JonasNowak/DankMacShell"
        }
        """
        let manifestURL = dir.appendingPathComponent("manifest.json")
        guard fileManager.createFile(atPath: manifestURL.path, contents: manifestJSON.data(using: .utf8)) else {
            return nil
        }

        let script = "#!/bin/sh\necho '{\"text\":\"Hello DMS\",\"icon\":\"sparkles\",\"color\":\"primary\"}'\n"
        let scriptURL = dir.appendingPathComponent("status.sh")
        guard fileManager.createFile(
            atPath: scriptURL.path,
            contents: script.data(using: .utf8),
            attributes: [.posixPermissions: 0o755]
        ) else {
            return nil
        }

        return dir
    }

    // MARK: - Widget command execution

    private func scheduleWidgetTimer(for manifest: DMSPluginManifest) {
        if let existing = timers[manifest.id], existing.timeInterval == manifest.clampedInterval {
            return
        }
        timers[manifest.id]?.invalidate()
        let id = manifest.id
        let timer = Timer.scheduledTimer(withTimeInterval: manifest.clampedInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let manifest = self.manifests[id] else { return }
                self.runWidgetCommand(manifest)
            }
        }
        timers[id] = timer
    }

    private func runWidgetCommand(_ manifest: DMSPluginManifest) {
        let command = manifest.command
        let pluginID = manifest.id
        Task.detached(priority: .utility) { [weak self] in
            let result = SafeProcessRunner.run(
                executablePath: "/bin/sh",
                arguments: ["-c", command],
                timeout: 5.0
            )
            guard let output = try? result.get(),
                  let stdout = String(data: output.stdout, encoding: .utf8),
                  let parsed = DMSPluginWidgetOutput.parse(stdout: stdout) else {
                return
            }
            Task { @MainActor [weak self] in
                self?.widgetOutputs[pluginID] = parsed
            }
        }
    }
}
