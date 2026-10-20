import Foundation
import Combine
import DMSCore

/// Manages plugins and applets for DankMaterialShell.
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
            default: break
            }
        }

        self.applets = list
    }

    public func toggleApplet(id: String) {
        guard let idx = applets.firstIndex(where: { $0.id == id }) else { return }
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
    }

    public func installPlugin(id: String) {
        guard let idx = plugins.firstIndex(where: { $0.id == id }) else { return }
        plugins[idx].isInstalled = true
        plugins[idx].isEnabled = true
        saveLockfile()
        syncConfig()
        ToastCenter.shared.show(icon: "arrow.down.circle.fill", message: "Installed plugin: \(plugins[idx].name)")
    }

    public func uninstallPlugin(id: String) {
        guard let idx = plugins.firstIndex(where: { $0.id == id }) else { return }
        plugins[idx].isInstalled = false
        plugins[idx].isEnabled = false
        saveLockfile()
        syncConfig()
        ToastCenter.shared.show(icon: "trash.fill", message: "Uninstalled plugin: \(plugins[idx].name)")
    }

    public func togglePlugin(id: String) {
        guard let idx = plugins.firstIndex(where: { $0.id == id }) else { return }
        plugins[idx].isEnabled.toggle()
        saveLockfile()
        syncConfig()
    }

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
        if let data = try? JSONEncoder().encode(lock) {
            try? data.write(to: lockfileURL)
        }
    }

    public func restoreLockfile(from path: String? = nil) -> Bool {
        let url = path != nil ? URL(fileURLWithPath: path!) : lockfileURL
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
        return true
    }

    private func syncConfig() {
        let enabled = plugins.filter { $0.isInstalled && $0.isEnabled }.map { $0.id }
        ConfigStore.shared.update { $0.enabledPlugins = enabled }
    }
}
