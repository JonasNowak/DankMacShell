import Foundation

/// User configuration for DankMaterialShell (DMS).
/// Implements the hierarchical multi-instance schema matching `SettingsSpec.js` (427 keys),
/// with support for multi-bar, multi-dock, widget options, $include fragments, and v1->v2 migrations.
public struct DMSConfig: Sendable, Codable, Equatable {
    public var version: Int
    public var theme: String
    public var isLightMode: Bool

    // MARK: - Multi-Instance Layout Arrays
    public var barConfigs: [BarConfig]
    public var dockConfigs: [DockConfig]
    public var controlCenterWidgets: [ControlCenterWidgetConfig]
    public var controlCenterColumns: Int

    // MARK: - Legacy / Direct Accessors (Backward Compatibility)
    public var barPosition: String {
        get { barConfigs.first?.position ?? "bottom" }
        set {
            if barConfigs.isEmpty {
                barConfigs = [BarConfig(position: newValue)]
            } else {
                barConfigs[0].position = newValue
            }
        }
    }
    public var barAutoHide: Bool {
        get { barConfigs.first?.autoHide ?? false }
        set {
            if !barConfigs.isEmpty { barConfigs[0].autoHide = newValue }
        }
    }
    public var barTransparent: Bool {
        get { (barConfigs.first?.transparency ?? 1.0) < 1.0 }
        set {
            if !barConfigs.isEmpty { barConfigs[0].transparency = newValue ? 0.7 : 1.0 }
        }
    }
    public var barMarginX: Double
    public var showDock: Bool {
        get { dockConfigs.first?.enabled ?? false }
        set {
            if dockConfigs.isEmpty {
                dockConfigs = [DockConfig(enabled: newValue)]
            } else {
                dockConfigs[0].enabled = newValue
            }
        }
    }

    public var showTelemetry: Bool
    public var showWeather: Bool
    public var showMedia: Bool
    public var showSpaces: Bool
    public var showWorkspaceApps: Bool
    public var showLauncher: Bool
    public var showClock: Bool
    public var showInhibit: Bool
    public var showMic: Bool
    public var showWifi: Bool
    public var showVolume: Bool
    public var showControlCenter: Bool
    public var showPowerMenu: Bool
    public var showNotepadApplet: Bool
    public var showClipboardApplet: Bool
    public var showColorPickerApplet: Bool
    public var enabledPlugins: [String]
    public var launcherHotkey: Bool
    public var dashHotkey: Bool
    public var notepadHotkey: Bool
    public var clipboardHotkey: Bool
    public var weatherLocation: String
    public var weatherUnits: String // "celsius" or "fahrenheit"
    public var webSearchProvider: String // "google", "duckduckgo", "bing"
    public var pinnedApps: [String]
    public var apps: AppOverrides

    // Dynamic key storage for remaining 427-key SettingsSpec options
    public var rawSettings: [String: AnyCodable]
    public var includes: [String]

    public struct AppOverrides: Sendable, Codable, Equatable {
        public var terminal: String
        public var browser: String
        public var fileManager: String
        public var editor: String
        public var activityMonitor: String

        public init(
            terminal: String = "Terminal",
            browser: String = "Safari",
            fileManager: String = "Finder",
            editor: String = "TextEdit",
            activityMonitor: String = "Activity Monitor"
        ) {
            self.terminal = terminal
            self.browser = browser
            self.fileManager = fileManager
            self.editor = editor
            self.activityMonitor = activityMonitor
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.terminal = try container.decodeIfPresent(String.self, forKey: .terminal) ?? "Terminal"
            self.browser = try container.decodeIfPresent(String.self, forKey: .browser) ?? "Safari"
            self.fileManager = try container.decodeIfPresent(String.self, forKey: .fileManager) ?? "Finder"
            self.editor = try container.decodeIfPresent(String.self, forKey: .editor) ?? "TextEdit"
            self.activityMonitor = try container.decodeIfPresent(String.self, forKey: .activityMonitor) ?? "Activity Monitor"
        }
    }

    public init(
        version: Int = 2,
        theme: String = "purple",
        isLightMode: Bool = false,
        barConfigs: [BarConfig] = [.default],
        dockConfigs: [DockConfig] = [.default],
        controlCenterWidgets: [ControlCenterWidgetConfig] = ControlCenterWidgetConfig.defaultWidgets,
        controlCenterColumns: Int = 8,
        barPosition: String? = nil,
        barAutoHide: Bool = false,
        barTransparent: Bool = false,
        barMarginX: Double = 8.0,
        showDock: Bool = false,
        showTelemetry: Bool = true,
        showWeather: Bool = true,
        showMedia: Bool = true,
        showSpaces: Bool = true,
        showWorkspaceApps: Bool = true,
        showLauncher: Bool = true,
        showClock: Bool = true,
        showInhibit: Bool = true,
        showMic: Bool = true,
        showWifi: Bool = true,
        showVolume: Bool = true,
        showControlCenter: Bool = true,
        showPowerMenu: Bool = true,
        showNotepadApplet: Bool = false,
        showClipboardApplet: Bool = false,
        showColorPickerApplet: Bool = false,
        enabledPlugins: [String] = ["github-notifications"],
        launcherHotkey: Bool = true,
        dashHotkey: Bool = true,
        notepadHotkey: Bool = true,
        clipboardHotkey: Bool = true,
        weatherLocation: String = "auto",
        weatherUnits: String = "celsius",
        webSearchProvider: String = "google",
        pinnedApps: [String] = [
            "com.apple.Terminal",
            "com.apple.Safari",
            "com.apple.finder"
        ],
        apps: AppOverrides = AppOverrides(),
        rawSettings: [String: AnyCodable] = [:],
        includes: [String] = []
    ) {
        self.version = version
        self.theme = theme
        self.isLightMode = isLightMode
        var bars = barConfigs
        if let barPos = barPosition, !bars.isEmpty {
            bars[0].position = barPos
            bars[0].autoHide = barAutoHide
            bars[0].transparency = barTransparent ? 0.7 : 1.0
        }
        self.barConfigs = bars
        var docks = dockConfigs
        if showDock, !docks.isEmpty {
            docks[0].enabled = true
        }
        self.dockConfigs = docks
        self.controlCenterWidgets = controlCenterWidgets
        self.controlCenterColumns = max(6, controlCenterColumns)
        self.barMarginX = barMarginX
        self.showTelemetry = showTelemetry
        self.showWeather = showWeather
        self.showMedia = showMedia
        self.showSpaces = showSpaces
        self.showWorkspaceApps = showWorkspaceApps
        self.showLauncher = showLauncher
        self.showClock = showClock
        self.showInhibit = showInhibit
        self.showMic = showMic
        self.showWifi = showWifi
        self.showVolume = showVolume
        self.showControlCenter = showControlCenter
        self.showPowerMenu = showPowerMenu
        self.showNotepadApplet = showNotepadApplet
        self.showClipboardApplet = showClipboardApplet
        self.showColorPickerApplet = showColorPickerApplet
        self.enabledPlugins = enabledPlugins
        self.launcherHotkey = launcherHotkey
        self.dashHotkey = dashHotkey
        self.notepadHotkey = notepadHotkey
        self.clipboardHotkey = clipboardHotkey
        self.weatherLocation = weatherLocation
        self.weatherUnits = weatherUnits
        self.webSearchProvider = webSearchProvider
        self.pinnedApps = pinnedApps
        self.apps = apps
        self.rawSettings = rawSettings
        self.includes = includes
    }

    enum CodingKeys: String, CodingKey {
        case version
        case theme
        case isLightMode
        case barConfigs
        case dockConfigs
        case controlCenterWidgets
        case controlCenterColumns
        case barPosition
        case barAutoHide
        case barTransparent
        case barMarginX
        case showDock
        case showTelemetry
        case showWeather
        case showMedia
        case showSpaces
        case showWorkspaceApps
        case showLauncher
        case showClock
        case showInhibit
        case showMic
        case showWifi
        case showVolume
        case showControlCenter
        case showPowerMenu
        case showNotepadApplet
        case showClipboardApplet
        case showColorPickerApplet
        case enabledPlugins
        case launcherHotkey
        case dashHotkey
        case notepadHotkey
        case clipboardHotkey
        case weatherLocation
        case weatherUnits
        case webSearchProvider
        case pinnedApps
        case apps
        case rawSettings
        case includes = "$include"
    }

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
        init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? "purple"
        self.isLightMode = try container.decodeIfPresent(Bool.self, forKey: .isLightMode) ?? false
        self.barMarginX = try container.decodeIfPresent(Double.self, forKey: .barMarginX) ?? 8.0
        self.showTelemetry = try container.decodeIfPresent(Bool.self, forKey: .showTelemetry) ?? true
        self.showWeather = try container.decodeIfPresent(Bool.self, forKey: .showWeather) ?? true
        self.showMedia = try container.decodeIfPresent(Bool.self, forKey: .showMedia) ?? true
        self.showSpaces = try container.decodeIfPresent(Bool.self, forKey: .showSpaces) ?? true
        self.showWorkspaceApps = try container.decodeIfPresent(Bool.self, forKey: .showWorkspaceApps) ?? true
        self.showLauncher = try container.decodeIfPresent(Bool.self, forKey: .showLauncher) ?? true
        self.showClock = try container.decodeIfPresent(Bool.self, forKey: .showClock) ?? true
        self.showInhibit = try container.decodeIfPresent(Bool.self, forKey: .showInhibit) ?? true
        self.showMic = try container.decodeIfPresent(Bool.self, forKey: .showMic) ?? true
        self.showWifi = try container.decodeIfPresent(Bool.self, forKey: .showWifi) ?? true
        self.showVolume = try container.decodeIfPresent(Bool.self, forKey: .showVolume) ?? true
        self.showControlCenter = try container.decodeIfPresent(Bool.self, forKey: .showControlCenter) ?? true
        self.showPowerMenu = try container.decodeIfPresent(Bool.self, forKey: .showPowerMenu) ?? true
        self.showNotepadApplet = try container.decodeIfPresent(Bool.self, forKey: .showNotepadApplet) ?? false
        self.showClipboardApplet = try container.decodeIfPresent(Bool.self, forKey: .showClipboardApplet) ?? false
        self.showColorPickerApplet = try container.decodeIfPresent(Bool.self, forKey: .showColorPickerApplet) ?? false
        self.enabledPlugins = try container.decodeIfPresent([String].self, forKey: .enabledPlugins) ?? ["github-notifications"]
        self.launcherHotkey = try container.decodeIfPresent(Bool.self, forKey: .launcherHotkey) ?? true
        self.dashHotkey = try container.decodeIfPresent(Bool.self, forKey: .dashHotkey) ?? true
        self.notepadHotkey = try container.decodeIfPresent(Bool.self, forKey: .notepadHotkey) ?? true
        self.clipboardHotkey = try container.decodeIfPresent(Bool.self, forKey: .clipboardHotkey) ?? true
        self.weatherLocation = try container.decodeIfPresent(String.self, forKey: .weatherLocation) ?? "auto"
        self.weatherUnits = try container.decodeIfPresent(String.self, forKey: .weatherUnits) ?? "celsius"
        self.webSearchProvider = try container.decodeIfPresent(String.self, forKey: .webSearchProvider) ?? "google"
        self.pinnedApps = try container.decodeIfPresent([String].self, forKey: .pinnedApps) ?? [
            "com.apple.Terminal",
            "com.apple.Safari",
            "com.apple.finder"
        ]
        self.apps = try container.decodeIfPresent(AppOverrides.self, forKey: .apps) ?? AppOverrides()
        self.controlCenterWidgets = try container.decodeIfPresent([ControlCenterWidgetConfig].self, forKey: .controlCenterWidgets) ?? ControlCenterWidgetConfig.defaultWidgets
        self.controlCenterColumns = try container.decodeIfPresent(Int.self, forKey: .controlCenterColumns) ?? 8
        if let arr = try? container.decodeIfPresent([String].self, forKey: .includes) {
            self.includes = arr
        } else if let single = try? container.decodeIfPresent(String.self, forKey: .includes) {
            self.includes = [single]
        } else {
            self.includes = []
        }

        // Dynamically decode any arbitrary root-level settings from SettingsSpec.js into rawSettings
        var raw: [String: AnyCodable] = [:]
        if let dynamicContainer = try? decoder.container(keyedBy: AnyKey.self) {
            let knownKeys = Set([
                "version", "theme", "isLightMode", "barConfigs", "dockConfigs",
                "controlCenterWidgets", "controlCenterColumns", "barPosition",
                "barAutoHide", "barTransparent", "barMarginX", "showDock",
                "showTelemetry", "showWeather", "showMedia", "showSpaces",
                "showWorkspaceApps", "showLauncher", "showClock", "showInhibit",
                "showMic", "showWifi", "showVolume", "showControlCenter",
                "showPowerMenu", "showNotepadApplet", "showClipboardApplet",
                "showColorPickerApplet", "enabledPlugins", "launcherHotkey",
                "dashHotkey", "notepadHotkey", "clipboardHotkey", "weatherLocation",
                "weatherUnits", "webSearchProvider", "pinnedApps", "apps",
                "$include", "$schema", "rawSettings"
            ])
            for key in dynamicContainer.allKeys {
                if !knownKeys.contains(key.stringValue) {
                    if let val = try? dynamicContainer.decode(AnyCodable.self, forKey: key) {
                        raw[key.stringValue] = val
                    }
                }
            }
        }
        if let explicitRaw = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .rawSettings) {
            for (k, v) in explicitRaw {
                raw[k] = v
            }
        }
        self.rawSettings = raw

        // Multi-Bar Schema & Migration from v1
        if let bars = try container.decodeIfPresent([BarConfig].self, forKey: .barConfigs), !bars.isEmpty {
            self.barConfigs = bars
        } else {
            let legacyPos = try container.decodeIfPresent(String.self, forKey: .barPosition) ?? "bottom"
            let legacyAutoHide = try container.decodeIfPresent(Bool.self, forKey: .barAutoHide) ?? false
            let legacyTrans = try container.decodeIfPresent(Bool.self, forKey: .barTransparent) ?? false
            self.barConfigs = [
                BarConfig(
                    id: "primary-bar",
                    name: "Primary Bar",
                    position: legacyPos,
                    autoHide: legacyAutoHide,
                    transparency: legacyTrans ? 0.7 : 1.0
                )
            ]
        }

        // Migration: Ensure runningApps is present in barConfigs if showWorkspaceApps is enabled and only focusedApp was defaulted
        for (bIndex, bar) in self.barConfigs.enumerated() {
            var left = bar.layout.left
            let hasRunningApps = left.contains(where: { $0.widgetId == "runningApps" || $0.widgetId == "workspaceApps" })
            if !hasRunningApps && self.showWorkspaceApps {
                if let focusedIndex = left.firstIndex(where: { $0.widgetId == "focusedApp" }) {
                    left[focusedIndex] = BarWidgetEntry(id: "runningApps", widgetId: "runningApps")
                } else {
                    left.append(BarWidgetEntry(id: "runningApps", widgetId: "runningApps"))
                }
                self.barConfigs[bIndex].layout.left = left
            }
        }

        // Multi-Dock Schema & Migration from v1
        if let docks = try container.decodeIfPresent([DockConfig].self, forKey: .dockConfigs), !docks.isEmpty {
            self.dockConfigs = docks
        } else {
            let legacyDock = try container.decodeIfPresent(Bool.self, forKey: .showDock) ?? false
            self.dockConfigs = [
                DockConfig(
                    id: "dock",
                    name: "Dock",
                    enabled: legacyDock
                )
            ]
        }

        // Upgrade version to 2 if migrated
        if self.version < 2 {
            self.version = 2
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(theme, forKey: .theme)
        try container.encode(isLightMode, forKey: .isLightMode)
        try container.encode(barConfigs, forKey: .barConfigs)
        try container.encode(dockConfigs, forKey: .dockConfigs)
        try container.encode(controlCenterWidgets, forKey: .controlCenterWidgets)
        try container.encode(controlCenterColumns, forKey: .controlCenterColumns)
        try container.encode(barMarginX, forKey: .barMarginX)
        try container.encode(showTelemetry, forKey: .showTelemetry)
        try container.encode(showWeather, forKey: .showWeather)
        try container.encode(showMedia, forKey: .showMedia)
        try container.encode(showSpaces, forKey: .showSpaces)
        try container.encode(showWorkspaceApps, forKey: .showWorkspaceApps)
        try container.encode(showLauncher, forKey: .showLauncher)
        try container.encode(showClock, forKey: .showClock)
        try container.encode(showInhibit, forKey: .showInhibit)
        try container.encode(showMic, forKey: .showMic)
        try container.encode(showWifi, forKey: .showWifi)
        try container.encode(showVolume, forKey: .showVolume)
        try container.encode(showControlCenter, forKey: .showControlCenter)
        try container.encode(showPowerMenu, forKey: .showPowerMenu)
        try container.encode(showNotepadApplet, forKey: .showNotepadApplet)
        try container.encode(showClipboardApplet, forKey: .showClipboardApplet)
        try container.encode(showColorPickerApplet, forKey: .showColorPickerApplet)
        try container.encode(enabledPlugins, forKey: .enabledPlugins)
        try container.encode(launcherHotkey, forKey: .launcherHotkey)
        try container.encode(dashHotkey, forKey: .dashHotkey)
        try container.encode(notepadHotkey, forKey: .notepadHotkey)
        try container.encode(clipboardHotkey, forKey: .clipboardHotkey)
        try container.encode(weatherLocation, forKey: .weatherLocation)
        try container.encode(weatherUnits, forKey: .weatherUnits)
        try container.encode(webSearchProvider, forKey: .webSearchProvider)
        try container.encode(pinnedApps, forKey: .pinnedApps)
        try container.encode(apps, forKey: .apps)
        if !includes.isEmpty {
            try container.encode(includes, forKey: .includes)
        }

        // Encode raw settings at root level to maintain 1:1 format parity with SettingsSpec.js
        if !rawSettings.isEmpty {
            var dynamicContainer = encoder.container(keyedBy: AnyKey.self)
            let knownKeys = Set([
                "version", "theme", "isLightMode", "barConfigs", "dockConfigs",
                "controlCenterWidgets", "controlCenterColumns", "barPosition",
                "barAutoHide", "barTransparent", "barMarginX", "showDock",
                "showTelemetry", "showWeather", "showMedia", "showSpaces",
                "showWorkspaceApps", "showLauncher", "showClock", "showInhibit",
                "showMic", "showWifi", "showVolume", "showControlCenter",
                "showPowerMenu", "showNotepadApplet", "showClipboardApplet",
                "showColorPickerApplet", "enabledPlugins", "launcherHotkey",
                "dashHotkey", "notepadHotkey", "clipboardHotkey", "weatherLocation",
                "weatherUnits", "webSearchProvider", "pinnedApps", "apps",
                "$include", "$schema", "rawSettings"
            ])
            for (k, v) in rawSettings {
                if !knownKeys.contains(k), let key = AnyKey(stringValue: k) {
                    try dynamicContainer.encode(v, forKey: key)
                }
            }
        }
    }

    public static let `default` = DMSConfig()

    /// Loads config from Data with optional base directory URL for resolving `$include` fragments.
    public static func load(from data: Data, baseDirectory: URL? = nil) -> DMSConfig {
        guard var jsonDict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .default
        }

        if let base = baseDirectory {
            var visited = Set<String>()
            resolveIncludes(in: &jsonDict, baseDirectory: base, visited: &visited)
        }

        if let processedData = try? JSONSerialization.data(withJSONObject: jsonDict) {
            let decoder = JSONDecoder()
            if let config = try? decoder.decode(DMSConfig.self, from: processedData) {
                return config
            }
        }

        return .default
    }

    private static func resolveIncludes(in dict: inout [String: Any], baseDirectory: URL, visited: inout Set<String>) {
        let includeList: [String]
        if let arr = dict["$include"] as? [String] {
            includeList = arr
        } else if let single = dict["$include"] as? String {
            includeList = [single]
        } else {
            return
        }

        var mergedDict: [String: Any] = [:]
        for fragPath in includeList {
            let fragURL = baseDirectory.appendingPathComponent(fragPath)
            let canonical = fragURL.standardizedFileURL.path
            guard !visited.contains(canonical) else { continue }
            visited.insert(canonical)

            if let fragData = try? Data(contentsOf: fragURL),
               var fragDict = (try? JSONSerialization.jsonObject(with: fragData)) as? [String: Any] {
                resolveIncludes(in: &fragDict, baseDirectory: fragURL.deletingLastPathComponent(), visited: &visited)
                deepMerge(target: &mergedDict, source: fragDict)
            }
        }
        deepMerge(target: &mergedDict, source: dict)
        dict = mergedDict
    }

    private static func deepMerge(target: inout [String: Any], source: [String: Any]) {
        for (k, v) in source {
            if let sourceSub = v as? [String: Any], let targetSub = target[k] as? [String: Any] {
                var newSub = targetSub
                deepMerge(target: &newSub, source: sourceSub)
                target[k] = newSub
            } else {
                target[k] = v
            }
        }
    }

    public func encodeJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Accessor for arbitrary settings keys from the 427-key SettingsSpec.
    public func getSetting(_ key: String) -> AnyCodable? {
        switch key {
        case "theme": return AnyCodable(theme)
        case "isLightMode": return AnyCodable(isLightMode)
        case "version": return AnyCodable(version)
        case "barPosition": return AnyCodable(barPosition)
        case "barAutoHide": return AnyCodable(barAutoHide)
        case "barTransparent": return AnyCodable(barTransparent)
        case "barMarginX": return AnyCodable(barMarginX)
        case "showDock": return AnyCodable(showDock)
        case "showTelemetry": return AnyCodable(showTelemetry)
        case "showWeather": return AnyCodable(showWeather)
        case "showMedia": return AnyCodable(showMedia)
        case "showSpaces": return AnyCodable(showSpaces)
        case "showWorkspaceApps": return AnyCodable(showWorkspaceApps)
        case "showLauncher": return AnyCodable(showLauncher)
        case "showClock": return AnyCodable(showClock)
        case "showInhibit": return AnyCodable(showInhibit)
        case "showMic": return AnyCodable(showMic)
        case "showWifi": return AnyCodable(showWifi)
        case "showVolume": return AnyCodable(showVolume)
        case "showControlCenter": return AnyCodable(showControlCenter)
        case "showPowerMenu": return AnyCodable(showPowerMenu)
        case "showNotepadApplet": return AnyCodable(showNotepadApplet)
        case "showClipboardApplet": return AnyCodable(showClipboardApplet)
        case "showColorPickerApplet": return AnyCodable(showColorPickerApplet)
        case "enabledPlugins": return AnyCodable(enabledPlugins.map { AnyCodable($0) })
        case "launcherHotkey": return AnyCodable(launcherHotkey)
        case "dashHotkey": return AnyCodable(dashHotkey)
        case "notepadHotkey": return AnyCodable(notepadHotkey)
        case "clipboardHotkey": return AnyCodable(clipboardHotkey)
        case "weatherLocation": return AnyCodable(weatherLocation)
        case "weatherUnits": return AnyCodable(weatherUnits)
        case "webSearchProvider": return AnyCodable(webSearchProvider)
        case "pinnedApps": return AnyCodable(pinnedApps.map { AnyCodable($0) })
        case "controlCenterColumns": return AnyCodable(controlCenterColumns)
        default:
            return rawSettings[key]
        }
    }

    public mutating func setSetting(_ key: String, value: AnyCodable) {
        rawSettings[key] = value
        switch key {
        case "theme":
            if let s = value.stringValue { self.theme = s }
        case "isLightMode":
            if let b = value.boolValue { self.isLightMode = b }
        case "barPosition":
            if let s = value.stringValue { self.barPosition = s }
        case "barAutoHide":
            if let b = value.boolValue { self.barAutoHide = b }
        case "barTransparent":
            if let b = value.boolValue { self.barTransparent = b }
        case "barMarginX":
            if let d = value.doubleValue { self.barMarginX = d }
        case "showDock":
            if let b = value.boolValue { self.showDock = b }
        case "showTelemetry":
            if let b = value.boolValue { self.showTelemetry = b }
        case "showWeather":
            if let b = value.boolValue { self.showWeather = b }
        case "showMedia":
            if let b = value.boolValue { self.showMedia = b }
        case "showSpaces":
            if let b = value.boolValue { self.showSpaces = b }
        case "showWorkspaceApps":
            if let b = value.boolValue { self.showWorkspaceApps = b }
        case "showLauncher":
            if let b = value.boolValue { self.showLauncher = b }
        case "showClock":
            if let b = value.boolValue { self.showClock = b }
        case "showInhibit":
            if let b = value.boolValue { self.showInhibit = b }
        case "showMic":
            if let b = value.boolValue { self.showMic = b }
        case "showWifi":
            if let b = value.boolValue { self.showWifi = b }
        case "showVolume":
            if let b = value.boolValue { self.showVolume = b }
        case "showControlCenter":
            if let b = value.boolValue { self.showControlCenter = b }
        case "showPowerMenu":
            if let b = value.boolValue { self.showPowerMenu = b }
        case "showNotepadApplet":
            if let b = value.boolValue { self.showNotepadApplet = b }
        case "showClipboardApplet":
            if let b = value.boolValue { self.showClipboardApplet = b }
        case "showColorPickerApplet":
            if let b = value.boolValue { self.showColorPickerApplet = b }
        case "launcherHotkey":
            if let b = value.boolValue { self.launcherHotkey = b }
        case "dashHotkey":
            if let b = value.boolValue { self.dashHotkey = b }
        case "notepadHotkey":
            if let b = value.boolValue { self.notepadHotkey = b }
        case "clipboardHotkey":
            if let b = value.boolValue { self.clipboardHotkey = b }
        case "weatherLocation":
            if let s = value.stringValue { self.weatherLocation = s }
        case "weatherUnits":
            if let s = value.stringValue { self.weatherUnits = s }
        case "webSearchProvider":
            if let s = value.stringValue { self.webSearchProvider = s }
        case "controlCenterColumns":
            if let i = value.intValue { self.controlCenterColumns = max(6, i) }
        case "pinnedApps":
            if let arr = value.arrayValue?.compactMap(\.stringValue) { self.pinnedApps = arr }
        case "enabledPlugins":
            if let arr = value.arrayValue?.compactMap(\.stringValue) { self.enabledPlugins = arr }
        default:
            break
        }
    }

    // MARK: - Global Theme & Customization Typed Accessors (Spec 01 / 03 / 31)

    /// Theme mode: "dark", "light", or "system". Syncs with `isLightMode`.
    public var themeMode: String {
        get {
            if let mode = rawSettings["themeMode"]?.stringValue {
                return mode
            }
            return isLightMode ? "light" : "dark"
        }
        set {
            rawSettings["themeMode"] = AnyCodable(newValue)
            if newValue == "light" {
                isLightMode = true
            } else if newValue == "dark" {
                isLightMode = false
            }
        }
    }

    /// Custom hex seed color when `theme == "custom"` (or overriding dynamic generation).
    public var themeSeedColor: String {
        get { rawSettings["themeSeedColor"]?.stringValue ?? "#D0BCFF" }
        set { rawSettings["themeSeedColor"] = AnyCodable(newValue) }
    }

    /// Matugen scheme algorithm (`scheme-tonal-spot`, `scheme-vibrant`, `scheme-expressive`, `scheme-fidelity`, `scheme-neutral`, `scheme-monochrome`).
    public var matugenScheme: MatugenScheme {
        get {
            if let raw = rawSettings["matugenScheme"]?.stringValue,
               let scheme = MatugenScheme(rawValue: raw) {
                return scheme
            }
            return .tonalSpot
        }
        set { rawSettings["matugenScheme"] = AnyCodable(newValue.rawValue) }
    }

    /// Contrast level (`-1.0` to `+1.0`, default `0.0`).
    public var matugenContrast: Double {
        get { rawSettings["matugenContrast"]?.doubleValue ?? 0.0 }
        set { rawSettings["matugenContrast"] = AnyCodable(min(1.0, max(-1.0, newValue))) }
    }

    /// Corner radius strength (`0` sharp to `100` extra rounded, default `50` per `THEME-001`).
    public var cornerRadiusStrength: Double {
        get { rawSettings["cornerRadiusStrength"]?.doubleValue ?? 50.0 }
        set { rawSettings["cornerRadiusStrength"] = AnyCodable(min(100.0, max(0.0, newValue))) }
    }

    /// Optional fixed corner radius override (`nil` or `< 0` means use scaled M3 tokens).
    public var fixedCornerRadius: Double? {
        get {
            guard let v = rawSettings["fixedCornerRadius"]?.doubleValue, v >= 0 else { return nil }
            return v
        }
        set {
            if let v = newValue, v >= 0 {
                rawSettings["fixedCornerRadius"] = AnyCodable(v)
            } else {
                rawSettings.removeValue(forKey: "fixedCornerRadius")
            }
        }
    }

    /// Global surface opacity (`0.1` to `1.0`, default `0.85`).
    public var surfaceOpacity: Double {
        get { rawSettings["surfaceOpacity"]?.doubleValue ?? 0.85 }
        set { rawSettings["surfaceOpacity"] = AnyCodable(min(1.0, max(0.1, newValue))) }
    }

    /// Popup / modal surface transparency (`0.1` to `1.0`, default `0.92`).
    public var popupTransparency: Double {
        get { rawSettings["popupTransparency"]?.doubleValue ?? 0.92 }
        set { rawSettings["popupTransparency"] = AnyCodable(min(1.0, max(0.1, newValue))) }
    }

    /// Floating window transparency (`0.1` to `1.0`, default `0.90`).
    public var floatingWindowTransparency: Double {
        get { rawSettings["floatingWindowTransparency"]?.doubleValue ?? 0.90 }
        set { rawSettings["floatingWindowTransparency"] = AnyCodable(min(1.0, max(0.1, newValue))) }
    }

    /// Blur radius (`0` to `64`, default `20`).
    public var blurRadius: Double {
        get { rawSettings["blurRadius"]?.doubleValue ?? 20.0 }
        set { rawSettings["blurRadius"] = AnyCodable(min(64.0, max(0.0, newValue))) }
    }

    /// Global border width (`0` to `4`, default `1`).
    public var borderWidth: Double {
        get { rawSettings["borderWidth"]?.doubleValue ?? 1.0 }
        set { rawSettings["borderWidth"] = AnyCodable(min(4.0, max(0.0, newValue))) }
    }

    /// Global outline opacity (`0.0` to `1.0`, default `0.15`).
    public var outlineOpacity: Double {
        get { rawSettings["outlineOpacity"]?.doubleValue ?? 0.15 }
        set { rawSettings["outlineOpacity"] = AnyCodable(min(1.0, max(0.0, newValue))) }
    }

    /// Whether drop shadows are enabled globally.
    public var shadowEnabled: Bool {
        get { rawSettings["shadowEnabled"]?.boolValue ?? true }
        set { rawSettings["shadowEnabled"] = AnyCodable(newValue) }
    }

    /// Shadow blur radius (`0` to `48`, default `16`).
    public var shadowBlurRadius: Double {
        get { rawSettings["shadowBlurRadius"]?.doubleValue ?? 16.0 }
        set { rawSettings["shadowBlurRadius"] = AnyCodable(min(48.0, max(0.0, newValue))) }
    }

    /// Shadow Y offset (`0` to `24`, default `6`).
    public var shadowOffsetY: Double {
        get { rawSettings["shadowOffsetY"]?.doubleValue ?? 6.0 }
        set { rawSettings["shadowOffsetY"] = AnyCodable(min(24.0, max(0.0, newValue))) }
    }

    /// Shadow opacity (`0.0` to `1.0`, default `0.35`).
    public var shadowOpacity: Double {
        get { rawSettings["shadowOpacity"]?.doubleValue ?? 0.35 }
        set { rawSettings["shadowOpacity"] = AnyCodable(min(1.0, max(0.0, newValue))) }
    }

    /// Body font family (`"System"` or font family name).
    public var fontFamily: String {
        get { rawSettings["fontFamily"]?.stringValue ?? "System" }
        set { rawSettings["fontFamily"] = AnyCodable(newValue) }
    }

    /// Monospace font family (`"SF Mono"` or font family name).
    public var fontFamilyMono: String {
        get { rawSettings["fontFamilyMono"]?.stringValue ?? "SF Mono" }
        set { rawSettings["fontFamilyMono"] = AnyCodable(newValue) }
    }

    /// Display/headline font family (`"System"` or font family name).
    public var fontFamilyDisplay: String {
        get { rawSettings["fontFamilyDisplay"]?.stringValue ?? "System" }
        set { rawSettings["fontFamilyDisplay"] = AnyCodable(newValue) }
    }

    /// Global font scale (`0.75` to `1.5`, default `1.0`).
    public var fontScale: Double {
        get { rawSettings["fontScale"]?.doubleValue ?? 1.0 }
        set { rawSettings["fontScale"] = AnyCodable(min(1.5, max(0.75, newValue))) }
    }

    /// Animation speed multiplier (`0.25` to `2.0`, default `1.0`).
    public var animationSpeed: Double {
        get { rawSettings["animationSpeed"]?.doubleValue ?? 1.0 }
        set { rawSettings["animationSpeed"] = AnyCodable(min(2.0, max(0.25, newValue))) }
    }

    /// Reduced motion accessibility toggle.
    public var reducedMotion: Bool {
        get { rawSettings["reducedMotion"]?.boolValue ?? false }
        set { rawSettings["reducedMotion"] = AnyCodable(newValue) }
    }

    /// Dynamic Island configuration bridged to `IslandSettings`.
    public var islandSettings: IslandSettings {
        get { IslandSettings(from: rawSettings) }
        set {
            for (k, v) in newValue.toDictionary() {
                rawSettings[k] = v
            }
        }
    }

    // MARK: - Computed M3 Token Sets

    public var shapeTokens: M3ShapeTokens {
        M3ShapeTokens(strength: Int(cornerRadiusStrength), fixedRadius: fixedCornerRadius ?? -1.0)
    }

    public var motionTokens: M3MotionTokens {
        M3MotionTokens(animationSpeed: animationSpeed, reducedMotion: reducedMotion)
    }

    public var typographyTokens: M3TypographyTokens {
        M3TypographyTokens(
            fontFamilyUI: fontFamily,
            fontFamilyMono: fontFamilyMono,
            fontFamilyDisplay: fontFamilyDisplay,
            fontScale: fontScale
        )
    }

    public var surfaceTokens: M3SurfaceTokens {
        M3SurfaceTokens(
            surfaceOpacity: surfaceOpacity,
            popupTransparency: popupTransparency,
            floatingWindowTransparency: floatingWindowTransparency,
            blurRadius: Int(blurRadius),
            borderWidth: borderWidth,
            outlineOpacity: outlineOpacity
        )
    }

    public var shadowTokens: M3ShadowTokens {
        M3ShadowTokens(
            enabled: shadowEnabled,
            blurRadius: shadowBlurRadius,
            offsetY: shadowOffsetY,
            opacity: shadowOpacity
        )
    }
}
