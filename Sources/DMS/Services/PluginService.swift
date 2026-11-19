import Foundation
import Combine
import DMSCore

/// Manages plugins and applets for DankMacShell.
@MainActor
public final class PluginService: ObservableObject {
    public static let shared = PluginService()

    @Published public private(set) var plugins: [DMSPlugin] = []
    @Published public private(set) var applets: [DMSApplet] = []

    private let fileManager = FileManager.default

    private var lockfileURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DMS")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("plugins.lock.json")
    }

    private init() {
        loadPlugins()
        loadApplets()
    }

    public func loadPlugins() {
        var catalog = DMSPluginRegistry.standardPlugins
        let enabledIDs = Set(ConfigStore.shared.config.enabledPlugins)

        // Read lockfile if exists
        if let data = try? Data(contentsOf: lockfileURL),
           let lockfile = try? JSONDecoder().decode(DMSPluginLockfile.self, from: data) {
            for (idx, p) in catalog.enumerated() {
                if let entry = lockfile.plugins[p.id] {
                    catalog[idx].isInstalled = true
                    catalog[idx].isEnabled = entry.enabled
                    catalog[idx].version = entry.version
                } else {
                    catalog[idx].isEnabled = enabledIDs.contains(p.id)
                }
            }
        } else {
            for (idx, p) in catalog.enumerated() {
                catalog[idx].isEnabled = enabledIDs.contains(p.id)
            }
        }

        self.plugins = catalog
        updatePluginLifecycles(enabledIDs: Set(catalog.filter { $0.isInstalled && $0.isEnabled }.map { $0.id }))
    }

    public func loadApplets() {
        let config = ConfigStore.shared.config
        var list = StandardApplets.all

        for (idx, a) in list.enumerated() {
            switch a.id {
            case "launcher": list[idx].isEnabled = config.showLauncher
            case "spaces": list[idx].isEnabled = config.showSpaces
            case "workspaceApps": list[idx].isEnabled = config.showWorkspaceApps
            case "clock": list[idx].isEnabled = config.showClock
            case "weather": list[idx].isEnabled = config.showWeather
            case "cpu", "ram": list[idx].isEnabled = config.showTelemetry
            case "battery": list[idx].isEnabled = config.showTelemetry
            case "inhibit": list[idx].isEnabled = config.showInhibit
            case "mic": list[idx].isEnabled = config.showMic
            case "wifi": list[idx].isEnabled = config.showWifi
            case "volume": list[idx].isEnabled = config.showVolume
            case "controlCenter": list[idx].isEnabled = config.showControlCenter
            case "powerMenu": list[idx].isEnabled = config.showPowerMenu
            case "notepad": list[idx].isEnabled = config.showNotepadApplet
            case "clipboard": list[idx].isEnabled = config.showClipboardApplet
            case "colorPicker": list[idx].isEnabled = config.showColorPickerApplet
            case "symbian": list[idx].isEnabled = config.showSymbianApplet
            default: break
            }
        }

        self.applets = list
    }

    @discardableResult
    public func toggleApplet(id: String) -> Bool {
        guard let idx = applets.firstIndex(where: { $0.id == id }) else { return false }
        applets[idx].isEnabled.toggle()
        let newState = applets[idx].isEnabled

        ConfigStore.shared.update { cfg in
            switch id {
            case "launcher": cfg.showLauncher = newState
            case "spaces": cfg.showSpaces = newState
            case "workspaceApps": cfg.showWorkspaceApps = newState
            case "clock": cfg.showClock = newState
            case "weather": cfg.showWeather = newState
            case "cpu", "ram", "battery": cfg.showTelemetry = newState
            case "inhibit": cfg.showInhibit = newState
            case "mic": cfg.showMic = newState
            case "wifi": cfg.showWifi = newState
            case "volume": cfg.showVolume = newState
            case "controlCenter": cfg.showControlCenter = newState
            case "powerMenu": cfg.showPowerMenu = newState
            case "notepad": cfg.showNotepadApplet = newState
            case "clipboard": cfg.showClipboardApplet = newState
            case "colorPicker": cfg.showColorPickerApplet = newState
            case "symbian": cfg.showSymbianApplet = newState
            default: break
            }

            let targetWidgetIds: [String]
            switch id {
            case "launcher": targetWidgetIds = ["launcherButton"]
            case "spaces": targetWidgetIds = ["workspaceSwitcher"]
            case "workspaceApps": targetWidgetIds = ["runningApps", "workspaceApps"]
            case "clock": targetWidgetIds = ["clock"]
            case "weather": targetWidgetIds = ["weather"]
            case "cpu": targetWidgetIds = ["cpuMonitor", "telemetry"]
            case "ram": targetWidgetIds = ["ramMonitor", "ram", "memory"]
            case "battery": targetWidgetIds = ["battery"]
            case "inhibit": targetWidgetIds = ["inhibit"]
            case "mic": targetWidgetIds = ["mic"]
            case "wifi": targetWidgetIds = ["wifi"]
            case "volume": targetWidgetIds = ["volume", "audioVisualization"]
            case "controlCenter": targetWidgetIds = ["controlCenterButton"]
            case "powerMenu": targetWidgetIds = ["powerMenuButton"]
            case "notepad": targetWidgetIds = ["notepad"]
            case "clipboard": targetWidgetIds = ["clipboard"]
            case "colorPicker": targetWidgetIds = ["colorPicker"]
            case "symbian": targetWidgetIds = ["symbianApplet", "symbianButton", "symbian"]
            default: targetWidgetIds = [id]
            }

            for bIdx in cfg.barConfigs.indices {
                for lIdx in cfg.barConfigs[bIdx].layout.left.indices {
                    if targetWidgetIds.contains(cfg.barConfigs[bIdx].layout.left[lIdx].widgetId) {
                        cfg.barConfigs[bIdx].layout.left[lIdx].enabled = newState
                    }
                }
                for cIdx in cfg.barConfigs[bIdx].layout.center.indices {
                    if targetWidgetIds.contains(cfg.barConfigs[bIdx].layout.center[cIdx].widgetId) {
                        cfg.barConfigs[bIdx].layout.center[cIdx].enabled = newState
                    }
                }
                for rIdx in cfg.barConfigs[bIdx].layout.right.indices {
                    if targetWidgetIds.contains(cfg.barConfigs[bIdx].layout.right[rIdx].widgetId) {
                        cfg.barConfigs[bIdx].layout.right[rIdx].enabled = newState
                    }
                }
            }
        }
        DankBarController.shared.reposition()
        return true
    }

    @discardableResult
    public func installPlugin(id: String) -> Bool {
        guard let idx = plugins.firstIndex(where: { $0.id == id }) else { return false }
        plugins[idx].isInstalled = true
        plugins[idx].isEnabled = true
        saveLockfile()
        syncConfig()
        ToastCenter.shared.show(icon: "arrow.down.circle.fill", message: "Installed plugin: \(plugins[idx].name)")
        return true
    }

    @discardableResult
    public func uninstallPlugin(id: String) -> Bool {
        guard let idx = plugins.firstIndex(where: { $0.id == id }) else { return false }
        plugins[idx].isInstalled = false
        plugins[idx].isEnabled = false
        saveLockfile()
        syncConfig()
        ToastCenter.shared.show(icon: "trash.fill", message: "Uninstalled plugin: \(plugins[idx].name)")
        return true
    }

    public func togglePlugin(id: String) {
        guard let idx = plugins.firstIndex(where: { $0.id == id }) else { return }
        plugins[idx].isEnabled.toggle()
        saveLockfile()
        syncConfig()
    }

    /// Persists the lockfile atomically with `0600` POSIX permissions.
    public func saveLockfile() {
        var entries: [String: DMSPluginLockfile.DMSPluginLockEntry] = [:]
        for p in plugins where p.isInstalled {
            entries[p.id] = DMSPluginLockfile.DMSPluginLockEntry(
                version: p.version,
                enabled: p.isEnabled,
                source: p.repoURL
            )
        }

        let lock = DMSPluginLockfile(version: 1, plugins: entries)
        guard let data = try? JSONEncoder().encode(lock) else { return }
        let url = lockfileURL
        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        guard fileManager.createFile(atPath: tmp.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
            return
        }
        if rename(tmp.path, url.path) != 0 {
            try? fileManager.removeItem(at: tmp)
            try? data.write(to: url, options: .atomic)
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }

    public func restoreLockfile(from path: String? = nil) -> Bool {
        let rawPath = path ?? lockfileURL.path
        let url = URL(fileURLWithPath: (rawPath as NSString).expandingTildeInPath)
        guard let data = try? Data(contentsOf: url),
              let lock = try? JSONDecoder().decode(DMSPluginLockfile.self, from: data) else {
            return false
        }

        for (idx, p) in plugins.enumerated() {
            if let entry = lock.plugins[p.id] {
                plugins[idx].isInstalled = true
                plugins[idx].isEnabled = entry.enabled
                plugins[idx].version = entry.version
            } else {
                plugins[idx].isInstalled = false
                plugins[idx].isEnabled = false
            }
        }
        syncConfig()
        saveLockfile()
        return true
    }

    private func syncConfig() {
        let enabled = plugins.filter { $0.isInstalled && $0.isEnabled }.map { $0.id }
        ConfigStore.shared.update { $0.enabledPlugins = enabled }
        updatePluginLifecycles(enabledIDs: Set(enabled))
    }

    public func updatePluginLifecycles(enabledIDs: Set<String>) {
        // Reflect built-in plugin toggles into the persisted config so the applets they
        // drive follow the lockfile: symbian-belle-sync -> showSymbianApplet, plus the
        // network-speed / disk-usage / tailscale-status bar widgets.
        ConfigStore.shared.update { cfg in
            cfg.showSymbianApplet = enabledIDs.contains("symbian-belle-sync")
            cfg.setSetting("showNetworkSpeed", value: AnyCodable(enabledIDs.contains("network-speed")))
            cfg.setSetting("showDiskUsage", value: AnyCodable(enabledIDs.contains("disk-usage")))
            cfg.setSetting("showTailscaleStatus", value: AnyCodable(enabledIDs.contains("tailscale-status")))
        }
    }
}
