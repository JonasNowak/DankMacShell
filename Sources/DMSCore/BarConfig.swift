import Foundation

/// Typed per-widget styling options extracted from `BarWidgetEntry.options`.
public struct BarWidgetStyleOptions: Sendable, Codable, Equatable {
    public var compactMode: Bool
    public var showIcon: Bool
    public var showLabel: Bool
    public var customTintHex: String?
    public var customBackgroundHex: String?
    public var paddingOverride: Double?
    public var cornerRadiusOverride: Double?
    public var fontScaleOverride: Double?
    public var alias: String?
    public var fontSize: Double?
    public var bold: Bool?

    public init(
        compactMode: Bool = false,
        showIcon: Bool = true,
        showLabel: Bool = true,
        customTintHex: String? = nil,
        customBackgroundHex: String? = nil,
        paddingOverride: Double? = nil,
        cornerRadiusOverride: Double? = nil,
        fontScaleOverride: Double? = nil,
        alias: String? = nil,
        fontSize: Double? = nil,
        bold: Bool? = nil
    ) {
        self.compactMode = compactMode
        self.showIcon = showIcon
        self.showLabel = showLabel
        self.customTintHex = customTintHex
        self.customBackgroundHex = customBackgroundHex
        self.paddingOverride = paddingOverride
        self.cornerRadiusOverride = cornerRadiusOverride
        self.fontScaleOverride = fontScaleOverride
        self.alias = alias
        self.fontSize = fontSize
        self.bold = bold
    }

    public init(from options: [String: AnyCodable]) {
        self.compactMode = options["compactMode"]?.boolValue ?? false
        self.showIcon = options["showIcon"]?.boolValue ?? true
        self.showLabel = options["showLabel"]?.boolValue ?? true
        self.customTintHex = options["customTintHex"]?.stringValue
        self.customBackgroundHex = options["customBackgroundHex"]?.stringValue
        self.paddingOverride = options["paddingOverride"]?.doubleValue
        self.cornerRadiusOverride = options["cornerRadiusOverride"]?.doubleValue
        self.fontScaleOverride = options["fontScaleOverride"]?.doubleValue
        self.alias = options["alias"]?.stringValue
        self.fontSize = options["fontSize"]?.doubleValue
        self.bold = options["bold"]?.boolValue
    }

    public func toDictionary() -> [String: AnyCodable] {
        var dict: [String: AnyCodable] = [
            "compactMode": AnyCodable(compactMode),
            "showIcon": AnyCodable(showIcon),
            "showLabel": AnyCodable(showLabel)
        ]
        if let customTintHex { dict["customTintHex"] = AnyCodable(customTintHex) }
        if let customBackgroundHex { dict["customBackgroundHex"] = AnyCodable(customBackgroundHex) }
        if let paddingOverride { dict["paddingOverride"] = AnyCodable(paddingOverride) }
        if let cornerRadiusOverride { dict["cornerRadiusOverride"] = AnyCodable(cornerRadiusOverride) }
        if let fontScaleOverride { dict["fontScaleOverride"] = AnyCodable(fontScaleOverride) }
        if let alias { dict["alias"] = AnyCodable(alias) }
        if let fontSize { dict["fontSize"] = AnyCodable(fontSize) }
        if let bold { dict["bold"] = AnyCodable(bold) }
        return dict
    }
}

/// Per-widget entry hosted in a DankBar segment.
public struct BarWidgetEntry: Sendable, Codable, Equatable, Identifiable {
    public var id: String
    public var widgetId: String
    public var enabled: Bool
    public var options: [String: AnyCodable]

    public var styleOptions: BarWidgetStyleOptions {
        BarWidgetStyleOptions(from: options)
    }

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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedId = try container.decode(String.self, forKey: .id)
        self.id = decodedId
        self.widgetId = try container.decodeIfPresent(String.self, forKey: .widgetId) ?? decodedId
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.options = try container.decodeIfPresent([String: AnyCodable].self, forKey: .options) ?? [:]
    }
}

/// 3-section layout model for DankBar.
public struct BarLayout: Sendable, Codable, Equatable {
    public var left: [BarWidgetEntry]
    public var center: [BarWidgetEntry]
    public var right: [BarWidgetEntry]

    public init(
        left: [BarWidgetEntry] = [],
        center: [BarWidgetEntry] = [],
        right: [BarWidgetEntry] = []
    ) {
        self.left = left
        self.center = center
        self.right = right
    }

    public static let `default` = BarLayout(
        left: [
            BarWidgetEntry(id: "launcherButton", widgetId: "launcherButton"),
            BarWidgetEntry(id: "workspaceSwitcher", widgetId: "workspaceSwitcher"),
            BarWidgetEntry(id: "runningApps", widgetId: "runningApps")
        ],
        center: [
            BarWidgetEntry(id: "clock", widgetId: "clock", options: [
                "showDate": AnyCodable(true),
                "timeFormat": AnyCodable("12h"),
                "showSeconds": AnyCodable(false)
            ]),
            BarWidgetEntry(id: "media", widgetId: "media")
        ],
        right: [
            BarWidgetEntry(id: "weather", widgetId: "weather"),
            BarWidgetEntry(id: "cpuMonitor", widgetId: "cpuMonitor"),
            BarWidgetEntry(id: "ramMonitor", widgetId: "ramMonitor"),
            BarWidgetEntry(id: "diskUsage", widgetId: "diskUsage"),
            BarWidgetEntry(id: "audioVisualization", widgetId: "audioVisualization"),
            BarWidgetEntry(id: "capsLockIndicator", widgetId: "capsLockIndicator"),
            BarWidgetEntry(id: "battery", widgetId: "battery"),
            BarWidgetEntry(id: "wifi", widgetId: "wifi"),
            BarWidgetEntry(id: "volume", widgetId: "volume"),
            BarWidgetEntry(id: "controlCenterButton", widgetId: "controlCenterButton"),
            BarWidgetEntry(id: "powerMenuButton", widgetId: "powerMenuButton")
        ]
    )
}

/// Visual corner style for DankBar container surfaces per spec 19 (BAR-001) and spec 06 (Connected Mode).
public enum BarCornerStyle: String, Sendable, Codable, CaseIterable, Identifiable {
    case capsule = "capsule"
    case gothic = "gothic"
    case rounded = "rounded"
    case square = "square"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .capsule: return "Capsule"
        case .gothic: return "Gothic"
        case .rounded: return "Rounded"
        case .square: return "Square"
        }
    }

    public var subtitle: String {
        switch self {
        case .capsule: return "Full-radius pill capsule per M3 Expressive"
        case .gothic: return "Concave fillet arcs bridging into screen bezel"
        case .rounded: return "Continuous uniform rounded corners"
        case .square: return "Sharp 90° right angles (edge-flush)"
        }
    }

    public var icon: String {
        switch self {
        case .capsule: return "capsule"
        case .gothic: return "arrow.up.and.line.horizontal.and.arrow.down"
        case .rounded: return "square.dashed"
        case .square: return "square"
        }
    }
}

/// Hierarchical configuration for an individual DankBar instance.
public struct BarConfig: Sendable, Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var screenPreferences: [String] // ["all"] or screen names
    public var position: String // "top", "bottom", "left", "right"
    public var autoHide: Bool
    public var smartAutoHide: Bool
    public var thickness: Int // 48 for horizontal, 54 for vertical
    public var margin: Int
    public var spacing: Int
    public var horizontalPadding: Double
    public var verticalPadding: Double
    public var transparency: Double
    public var backgroundStyle: String // "surface", "glass", "transparent", "island"
    public var borderEnabled: Bool
    public var borderWidth: Double
    public var borderColor: String?
    public var cornerRadius: Double // -1 = auto/capsule, 0 = square, > 0 = fixed radius
    public var gothCorners: Bool
    public var gothFilletRadius: Double
    public var autoSquareAttachedCorners: Bool
    public var hoverOpenDelayMs: Int
    public var hoverCloseDelayMs: Int
    public var adaptToNotch: Bool
    public var simulateNotch: Bool
    public var simulatedNotchWidth: Double
    public var simulatedNotchHeight: Double
    public var layout: BarLayout
    public var widgetStyles: [String: BarWidgetStyleOptions]
    public var options: [String: AnyCodable]

    public var isVertical: Bool {
        let p = position.lowercased()
        return p == "left" || p == "right"
    }

    /// Dynamic corner style accessor bridging `cornerRadius` and `gothCorners`.
    public var cornerStyle: BarCornerStyle {
        get {
            if gothCorners {
                return .gothic
            } else if cornerRadius == 0 {
                return .square
            } else if cornerRadius > 0 {
                return .rounded
            } else {
                return .capsule
            }
        }
        set {
            switch newValue {
            case .capsule:
                gothCorners = false
                cornerRadius = -1.0
            case .gothic:
                gothCorners = true
                if cornerRadius == 0 { cornerRadius = -1.0 }
            case .rounded:
                gothCorners = false
                if cornerRadius <= 0 { cornerRadius = 16.0 }
            case .square:
                gothCorners = false
                cornerRadius = 0.0
            }
        }
    }

    public enum CodingKeys: String, CodingKey {
        case id, name, screenPreferences, position, autoHide, smartAutoHide
        case thickness, margin, spacing, horizontalPadding, verticalPadding
        case transparency, backgroundStyle, borderEnabled, borderWidth, borderColor
        case cornerRadius, gothCorners, gothFilletRadius, autoSquareAttachedCorners, cornerStyle
        case hoverOpenDelayMs, hoverCloseDelayMs, adaptToNotch, simulateNotch
        case simulatedNotchWidth, simulatedNotchHeight, layout, widgetStyles, options
    }

    public init(
        id: String = "primary-bar",
        name: String = "Primary Bar",
        screenPreferences: [String] = ["all"],
        position: String = "bottom",
        autoHide: Bool = false,
        smartAutoHide: Bool = false,
        thickness: Int = 48,
        margin: Int = 8,
        spacing: Int = 8,
        horizontalPadding: Double = 14.0,
        verticalPadding: Double = 4.0,
        transparency: Double = 1.0,
        backgroundStyle: String = "surface",
        borderEnabled: Bool = true,
        borderWidth: Double = 1.0,
        borderColor: String? = nil,
        cornerRadius: Double = -1.0,
        gothCorners: Bool = true,
        gothFilletRadius: Double = 14.0,
        autoSquareAttachedCorners: Bool = true,
        cornerStyle: BarCornerStyle? = nil,
        hoverOpenDelayMs: Int = 80,
        hoverCloseDelayMs: Int = 350,
        adaptToNotch: Bool = true,
        simulateNotch: Bool = false,
        simulatedNotchWidth: Double = 184.0,
        simulatedNotchHeight: Double = 32.0,
        layout: BarLayout = .default,
        widgetStyles: [String: BarWidgetStyleOptions] = [:],
        options: [String: AnyCodable] = [:]
    ) {
        self.id = id
        self.name = name
        self.screenPreferences = screenPreferences
        self.position = position
        self.autoHide = autoHide
        self.smartAutoHide = smartAutoHide
        self.thickness = thickness
        self.margin = margin
        self.spacing = spacing
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.transparency = transparency
        self.backgroundStyle = backgroundStyle
        self.borderEnabled = borderEnabled
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.gothCorners = gothCorners
        self.gothFilletRadius = gothFilletRadius
        self.autoSquareAttachedCorners = autoSquareAttachedCorners
        self.hoverOpenDelayMs = hoverOpenDelayMs
        self.hoverCloseDelayMs = hoverCloseDelayMs
        self.adaptToNotch = adaptToNotch
        self.simulateNotch = simulateNotch
        self.simulatedNotchWidth = simulatedNotchWidth
        self.simulatedNotchHeight = simulatedNotchHeight
        self.layout = layout
        self.widgetStyles = widgetStyles
        self.options = options

        if let explicitStyle = cornerStyle {
            self.cornerStyle = explicitStyle
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? "primary-bar"
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Primary Bar"
        self.screenPreferences = try container.decodeIfPresent([String].self, forKey: .screenPreferences) ?? ["all"]
        self.position = try container.decodeIfPresent(String.self, forKey: .position) ?? "bottom"
        self.autoHide = try container.decodeIfPresent(Bool.self, forKey: .autoHide) ?? false
        self.smartAutoHide = try container.decodeIfPresent(Bool.self, forKey: .smartAutoHide) ?? false
        self.thickness = try container.decodeIfPresent(Int.self, forKey: .thickness) ?? 48
        self.margin = try container.decodeIfPresent(Int.self, forKey: .margin) ?? 8
        self.spacing = try container.decodeIfPresent(Int.self, forKey: .spacing) ?? 8
        self.horizontalPadding = try container.decodeIfPresent(Double.self, forKey: .horizontalPadding) ?? 14.0
        self.verticalPadding = try container.decodeIfPresent(Double.self, forKey: .verticalPadding) ?? 4.0
        self.transparency = try container.decodeIfPresent(Double.self, forKey: .transparency) ?? 1.0
        self.backgroundStyle = try container.decodeIfPresent(String.self, forKey: .backgroundStyle) ?? "surface"
        self.borderEnabled = try container.decodeIfPresent(Bool.self, forKey: .borderEnabled) ?? true
        self.borderWidth = try container.decodeIfPresent(Double.self, forKey: .borderWidth) ?? 1.0
        self.borderColor = try container.decodeIfPresent(String.self, forKey: .borderColor)
        self.cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? -1.0
        self.gothCorners = try container.decodeIfPresent(Bool.self, forKey: .gothCorners) ?? true
        self.gothFilletRadius = try container.decodeIfPresent(Double.self, forKey: .gothFilletRadius) ?? 14.0
        self.autoSquareAttachedCorners = try container.decodeIfPresent(Bool.self, forKey: .autoSquareAttachedCorners) ?? true
        self.hoverOpenDelayMs = try container.decodeIfPresent(Int.self, forKey: .hoverOpenDelayMs) ?? 80
        self.hoverCloseDelayMs = try container.decodeIfPresent(Int.self, forKey: .hoverCloseDelayMs) ?? 350
        self.adaptToNotch = try container.decodeIfPresent(Bool.self, forKey: .adaptToNotch) ?? true
        self.simulateNotch = try container.decodeIfPresent(Bool.self, forKey: .simulateNotch) ?? false
        self.simulatedNotchWidth = try container.decodeIfPresent(Double.self, forKey: .simulatedNotchWidth) ?? 184.0
        self.simulatedNotchHeight = try container.decodeIfPresent(Double.self, forKey: .simulatedNotchHeight) ?? 32.0
        self.layout = try container.decodeIfPresent(BarLayout.self, forKey: .layout) ?? .default
        self.widgetStyles = try container.decodeIfPresent([String: BarWidgetStyleOptions].self, forKey: .widgetStyles) ?? [:]
        self.options = try container.decodeIfPresent([String: AnyCodable].self, forKey: .options) ?? [:]

        if let explicitStyle = try container.decodeIfPresent(BarCornerStyle.self, forKey: .cornerStyle) {
            self.cornerStyle = explicitStyle
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(screenPreferences, forKey: .screenPreferences)
        try container.encode(position, forKey: .position)
        try container.encode(autoHide, forKey: .autoHide)
        try container.encode(smartAutoHide, forKey: .smartAutoHide)
        try container.encode(thickness, forKey: .thickness)
        try container.encode(margin, forKey: .margin)
        try container.encode(spacing, forKey: .spacing)
        try container.encode(horizontalPadding, forKey: .horizontalPadding)
        try container.encode(verticalPadding, forKey: .verticalPadding)
        try container.encode(transparency, forKey: .transparency)
        try container.encode(backgroundStyle, forKey: .backgroundStyle)
        try container.encode(borderEnabled, forKey: .borderEnabled)
        try container.encode(borderWidth, forKey: .borderWidth)
        try container.encodeIfPresent(borderColor, forKey: .borderColor)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(gothCorners, forKey: .gothCorners)
        try container.encode(gothFilletRadius, forKey: .gothFilletRadius)
        try container.encode(autoSquareAttachedCorners, forKey: .autoSquareAttachedCorners)
        try container.encode(cornerStyle, forKey: .cornerStyle)
        try container.encode(hoverOpenDelayMs, forKey: .hoverOpenDelayMs)
        try container.encode(hoverCloseDelayMs, forKey: .hoverCloseDelayMs)
        try container.encode(adaptToNotch, forKey: .adaptToNotch)
        try container.encode(simulateNotch, forKey: .simulateNotch)
        try container.encode(simulatedNotchWidth, forKey: .simulatedNotchWidth)
        try container.encode(simulatedNotchHeight, forKey: .simulatedNotchHeight)
        try container.encode(layout, forKey: .layout)
        try container.encode(widgetStyles, forKey: .widgetStyles)
        try container.encode(options, forKey: .options)
    }

    public static let `default` = BarConfig()
}
