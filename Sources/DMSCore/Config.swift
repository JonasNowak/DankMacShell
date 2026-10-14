import Foundation

/// User configuration for DankMaterialShell (DMS).
public struct DMSConfig: Sendable, Codable, Equatable {
    public var theme: String
    public var isLightMode: Bool
    public var barPosition: String // "top" or "bottom"
    public var barAutoHide: Bool
    public var barTransparent: Bool
    public var showDock: Bool
    public var showTelemetry: Bool
    public var launcherHotkey: Bool
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
        showDock: Bool = true,
        showTelemetry: Bool = true,
        launcherHotkey: Bool = true,
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
        self.showDock = showDock
        self.showTelemetry = showTelemetry
        self.launcherHotkey = launcherHotkey
        self.pinnedApps = pinnedApps
        self.apps = apps
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
