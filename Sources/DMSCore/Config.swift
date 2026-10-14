import Foundation

/// User configuration for DankMaterialShell (DMS).
public struct DMSConfig: Sendable, Codable, Equatable {
    public var theme: String
    public var isLightMode: Bool
    public var barPosition: String // "top" or "bottom"
    public var barAutoHide: Bool
    public var barTransparent: Bool
    public var barMarginX: Double
    public var showDock: Bool
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
    }

    public init(
        theme: String = "purple",
        isLightMode: Bool = false,
        barPosition: String = "bottom",
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
        apps: AppOverrides = AppOverrides()
    ) {
        self.theme = theme
        self.isLightMode = isLightMode
        self.barPosition = barPosition
        self.barAutoHide = barAutoHide
        self.barTransparent = barTransparent
        self.barMarginX = barMarginX
        self.showDock = showDock
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
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? "purple"
        self.isLightMode = try container.decodeIfPresent(Bool.self, forKey: .isLightMode) ?? false
        self.barPosition = try container.decodeIfPresent(String.self, forKey: .barPosition) ?? "bottom"
        self.barAutoHide = try container.decodeIfPresent(Bool.self, forKey: .barAutoHide) ?? false
        self.barTransparent = try container.decodeIfPresent(Bool.self, forKey: .barTransparent) ?? false
        self.barMarginX = try container.decodeIfPresent(Double.self, forKey: .barMarginX) ?? 8.0
        self.showDock = try container.decodeIfPresent(Bool.self, forKey: .showDock) ?? false
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
    }

    public static let `default` = DMSConfig()

    public static func load(from data: Data) -> DMSConfig {
        let decoder = JSONDecoder()
        if let config = try? decoder.decode(DMSConfig.self, from: data) {
            return config
        }
        return .default
    }

    public func encodeJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
