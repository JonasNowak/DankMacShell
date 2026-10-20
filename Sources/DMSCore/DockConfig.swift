import Foundation

/// Widget item hosted inside a desktop dock instance.
public struct DockWidgetEntry: Sendable, Codable, Equatable, Identifiable {
    public var id: String
    public var widgetId: String
    public var enabled: Bool
    public var options: [String: AnyCodable]

    public init(
        id: String,
        widgetId: String? = nil,
        enabled: Bool = true,
        options: [String: AnyCodable] = [:]
    ) {
        self.id = id
        self.widgetId = widgetId ?? id
        self.enabled = enabled
        self.options = options
    }
}

/// Hierarchical configuration for an individual Desktop Dock instance.
/// Strictly implements upstream DMS `quickshell/Common/settings/DockConfig.js`.
public struct DockConfig: Sendable, Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var enabled: Bool
    public var screenPreferences: [String]
    public var showOnLastDisplay: Bool
    public var position: Int // 0=top, 1=bottom, 2=left, 3=right
    public var mode: String // "compact", "taskbar"
    public var taskbarAlign: String // "start", "center", "end"
    public var widgetExpansion: String // "popout", "inline"
    public var iconSize: Int // px
    public var spacing: Int // internal padding
    public var itemSpacing: Int // space between icons
    public var margin: Int // screen edge distance
    public var bottomGap: Int // cross-axis offset
    public var transparency: Double
    public var followInterfaceStyle: Bool
    public var autoHide: Bool
    public var smartAutoHide: Bool
    public var useOverlayLayer: Bool
    public var groupByApp: Bool
    public var separatePinnedAndRunningApps: Bool
    public var indicatorStyle: String // "circle", "line", "pill", "dot"
    public var borderEnabled: Bool
    public var borderColor: String
    public var borderOpacity: Double
    public var borderThickness: Double
    public var launcherEnabled: Bool
    public var maxVisibleApps: Int
    public var showTrash: Bool
    public var trashFileManager: String
    public var trashCustomCommand: String
    public var magnification: Bool
    public var magnificationScale: Double // 105 to 160 (% scale, e.g. 130.0)
    public var magnificationProfile: String // "parabolic", "cosine", "gaussian"
    public var magnificationExpand: Bool
    public var order: [String]
    public var widgets: [DockWidgetEntry]
    public var options: [String: AnyCodable]

    public var isVertical: Bool {
        return position == 2 || position == 3
    }

    public var edgeString: String {
        switch position {
        case 0: return "top"
        case 1: return "bottom"
        case 2: return "left"
        case 3: return "right"
        default: return "bottom"
        }
    }

    public init(
        id: String = "dock",
        name: String = "Dock",
        enabled: Bool = false,
        screenPreferences: [String] = ["all"],
        showOnLastDisplay: Bool = true,
        position: Int = 1,
        mode: String = "compact",
        taskbarAlign: String = "center",
        widgetExpansion: String = "popout",
        iconSize: Int = 42,
        spacing: Int = 8,
        itemSpacing: Int = 8,
        margin: Int = 8,
        bottomGap: Int = 0,
        transparency: Double = 1.0,
        followInterfaceStyle: Bool = true,
        autoHide: Bool = false,
        smartAutoHide: Bool = false,
        useOverlayLayer: Bool = false,
        groupByApp: Bool = false,
        separatePinnedAndRunningApps: Bool = false,
        indicatorStyle: String = "circle",
        borderEnabled: Bool = false,
        borderColor: String = "surfaceText",
        borderOpacity: Double = 1.0,
        borderThickness: Double = 1.0,
        launcherEnabled: Bool = true,
        maxVisibleApps: Int = 0,
        showTrash: Bool = false,
        trashFileManager: String = "default",
        trashCustomCommand: String = "",
        magnification: Bool = false,
        magnificationScale: Double = 130.0,
        magnificationProfile: String = "parabolic",
        magnificationExpand: Bool = false,
        order: [String] = [],
        widgets: [DockWidgetEntry] = [],
        options: [String: AnyCodable] = [:]
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.screenPreferences = screenPreferences
        self.showOnLastDisplay = showOnLastDisplay
        self.position = position
        self.mode = mode
        self.taskbarAlign = taskbarAlign
        self.widgetExpansion = widgetExpansion
        self.iconSize = iconSize
        self.spacing = spacing
        self.itemSpacing = itemSpacing
        self.margin = margin
        self.bottomGap = bottomGap
        self.transparency = transparency
        self.followInterfaceStyle = followInterfaceStyle
        self.autoHide = autoHide
        self.smartAutoHide = smartAutoHide
        self.useOverlayLayer = useOverlayLayer
        self.groupByApp = groupByApp
        self.separatePinnedAndRunningApps = separatePinnedAndRunningApps
        self.indicatorStyle = indicatorStyle
        self.borderEnabled = borderEnabled
        self.borderColor = borderColor
        self.borderOpacity = borderOpacity
        self.borderThickness = borderThickness
        self.launcherEnabled = launcherEnabled
        self.maxVisibleApps = maxVisibleApps
        self.showTrash = showTrash
        self.trashFileManager = trashFileManager
        self.trashCustomCommand = trashCustomCommand
        self.magnification = magnification
        self.magnificationScale = magnificationScale
        self.magnificationProfile = magnificationProfile
        self.magnificationExpand = magnificationExpand
        self.order = order
        self.widgets = widgets.isEmpty ? [
            DockWidgetEntry(id: "\(id)_launcher", widgetId: "dockLauncher", enabled: true),
            DockWidgetEntry(id: "\(id)_apps", widgetId: "appsDock", enabled: true),
            DockWidgetEntry(id: "\(id)_trash", widgetId: "dockTrash", enabled: true)
        ] : widgets
        self.options = options
    }

    public static let `default` = DockConfig()

    /// Resolves the winning DockConfig for a given screen and edge.
    public static func resolveEdge(
        configs: [DockConfig],
        screenName: String,
        screenModel: String? = nil,
        allScreens: [String] = [],
        edge: String
    ) -> DockConfig? {
        let edges = ["top", "bottom", "left", "right"]
        let onEdge = configs.filter { $0.position >= 0 && $0.position < edges.count && edges[$0.position] == edge }
        let enabled = onEdge.filter { $0.enabled }

        // 1. Explicit screen match
        if let explicit = enabled.first(where: { cfg in
            cfg.screenPreferences.contains(screenName) || (screenModel != nil && cfg.screenPreferences.contains(screenModel!))
        }) {
            return explicit
        }

        // 2. Fallback to "all"
        if let fallback = enabled.first(where: { $0.screenPreferences.contains("all") }) {
            return fallback
        }

        // 3. Fallback to showOnLastDisplay if single display
        if allScreens.count <= 1 {
            return enabled.first(where: { $0.showOnLastDisplay && !$0.screenPreferences.isEmpty })
        }

        return nil
    }

    /// Resolves all active docks for a screen across all 4 edges.
    public static func resolveAll(
        configs: [DockConfig],
        screenName: String,
        screenModel: String? = nil,
        allScreens: [String] = []
    ) -> [DockConfig] {
        let edges = ["top", "bottom", "left", "right"]
        return edges.compactMap { resolveEdge(configs: configs, screenName: screenName, screenModel: screenModel, allScreens: allScreens, edge: $0) }
    }
}
