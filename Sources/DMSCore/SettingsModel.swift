import Foundation

// MARK: - Settings Category
public enum SettingsCategory: String, CaseIterable, Identifiable, Sendable {
    case personalization = "Personalization"
    case primaryBar = "Primary Bar"
    case widgetsNotifications = "Widgets & Notifications"
    case dockLauncher = "Dock & Launcher"
    case keyboardShortcuts = "Keyboard Shortcuts"
    case power = "Power & Sleep"
    case plugins = "Plugins"
    case about = "About"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .personalization: return "person.crop.circle"
        case .primaryBar: return "menubar.rectangle"
        case .widgetsNotifications: return "square.grid.2x2"
        case .dockLauncher: return "dock.rectangle"
        case .keyboardShortcuts: return "keyboard"
        case .power: return "bolt.fill"
        case .plugins: return "puzzlepiece.extension"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Settings Tab
public typealias SettingsTab = DMSSettingsTab

public enum DMSSettingsTab: String, CaseIterable, Identifiable, Sendable {
    // Personalization
    case theme = "Theme & Colors"
    case wallpaper = "Wallpaper"
    case typography = "Typography & Motion"
    case timeWeather = "Time & Weather"
    case sounds = "Sounds"

    // Primary Bar
    case barAppearance = "Appearance"
    case barSettings = "Settings"
    case barWidgets = "Widgets"
    case barWorkspaces = "Workspaces"
    case island = "Island"

    // Widgets & Notifications
    case dashboard = "Dashboard"
    case mediaPlayer = "Media Player"
    case notifications = "Notifications"
    case osd = "On-screen Displays"
    case desktopWidgets = "Desktop Widgets"

    // Dock & Launcher
    case dock = "Dock"
    case launcher = "Launcher"

    // Shortcuts
    case shortcuts = "Keyboard Shortcuts"

    // Power
    case power = "Power & Sleep"

    // Plugins
    case plugins = "Plugins"

    // About
    case about = "About"

    public var id: String {
        switch self {
        case .theme: return "theme"
        case .wallpaper: return "wallpaper"
        case .typography: return "typography"
        case .timeWeather: return "timeWeather"
        case .sounds: return "sounds"
        case .barAppearance: return "barAppearance"
        case .barSettings: return "barSettings"
        case .barWidgets: return "barWidgets"
        case .barWorkspaces: return "barWorkspaces"
        case .island: return "island"
        case .dashboard: return "dashboard"
        case .mediaPlayer: return "mediaPlayer"
        case .notifications: return "notifications"
        case .osd: return "osd"
        case .desktopWidgets: return "desktopWidgets"
        case .dock: return "dock"
        case .launcher: return "launcher"
        case .shortcuts: return "shortcuts"
        case .power: return "power"
        case .plugins: return "plugins"
        case .about: return "about"
        }
    }

    public var category: SettingsCategory {
        switch self {
        case .theme, .wallpaper, .typography, .timeWeather, .sounds:
            return .personalization
        case .barAppearance, .barSettings, .barWidgets, .barWorkspaces, .island:
            return .primaryBar
        case .dashboard, .mediaPlayer, .notifications, .osd, .desktopWidgets:
            return .widgetsNotifications
        case .dock, .launcher:
            return .dockLauncher
        case .shortcuts:
            return .keyboardShortcuts
        case .power:
            return .power
        case .plugins:
            return .plugins
        case .about:
            return .about
        }
    }

    public var icon: String {
        switch self {
        case .theme: return "paintpalette.fill"
        case .wallpaper: return "photo.fill"
        case .typography: return "textformat"
        case .timeWeather: return "clock.fill"
        case .sounds: return "speaker.wave.2.fill"
        case .barAppearance: return "sparkles"
        case .barSettings: return "slider.horizontal.3"
        case .barWidgets: return "square.grid.2x2"
        case .barWorkspaces: return "square.split.2x2"
        case .island: return "capsule.portrait"
        case .dashboard: return "gauge"
        case .mediaPlayer: return "play.rectangle.fill"
        case .notifications: return "bell.fill"
        case .osd: return "rectangle.inset.filled"
        case .desktopWidgets: return "macwindow.on.rectangle"
        case .dock: return "dock.rectangle"
        case .launcher: return "sparkle.magnifyingglass"
        case .shortcuts: return "keyboard.fill"
        case .power: return "bolt.fill"
        case .plugins: return "puzzlepiece.extension.fill"
        case .about: return "info.circle.fill"
        }
    }

    public var description: String {
        switch self {
        case .theme: return "Dynamic wallpaper theming, seed color, stock palettes, and contrast"
        case .wallpaper: return "Desktop wallpaper color extraction, carousel cycling, and blur"
        case .typography: return "UI and monospace typography, animation speeds, and reduced motion"
        case .timeWeather: return "Clock format, meteorological units, and location coordinates"
        case .sounds: return "System feedback sound effects, chimes, and volume levels"
        case .barAppearance: return "Bar screen placement, side margins, Gothic corners, and transparency"
        case .barSettings: return "Autohide behavior, reveal delay, and outer gap physics"
        case .barWidgets: return "Left, center, and right bar segment widget layout and options"
        case .barWorkspaces: return "Virtual workspaces, OmniWM window tracking, and pager style"
        case .island: return "Dynamic Island pill, compact shortcuts, overlay layer, and offsets"
        case .dashboard: return "DankDash overview widgets, calendar, and system telemetry cards"
        case .mediaPlayer: return "Now Playing visualizer, progress scrubbers, and player controls"
        case .notifications: return "Notification popout banners, display timeouts, and rules"
        case .osd: return "Floating on-screen display HUDs for volume and brightness"
        case .desktopWidgets: return "Interactive wallpaper desktop widgets and placement"
        case .dock: return "App dock, parabolic magnification, pinned apps, and trash can"
        case .launcher: return "DLauncherV2 search frecency scoring, hotkeys, and web fallbacks"
        case .shortcuts: return "Global hotkey shortcuts for launcher, dash, clipboard, and apps"
        case .power: return "Display and system sleep caffeination and idle inhibitors"
        case .plugins: return "Browse, install, and manage official and third-party DMS plugins"
        case .about: return "System architecture, subsystem diagnostics, build info, and links"
        }
    }

    public var searchKeywords: [String] {
        switch self {
        case .theme: return ["theme", "colors", "palette", "seed", "contrast", "dark", "light", "mode", "dynamic", "matugen", "m3"]
        case .wallpaper: return ["wallpaper", "background", "desktop", "image", "dynamic", "matugen", "carousel"]
        case .typography: return ["font", "typography", "motion", "animation", "scale", "reduced", "inter", "jetbrains"]
        case .timeWeather: return ["time", "clock", "weather", "celsius", "fahrenheit", "location", "forecast", "units", "12h", "24h"]
        case .sounds: return ["sounds", "audio", "effects", "volume", "bell", "chime", "alerts", "feedback"]
        case .barAppearance: return ["bar", "position", "top", "bottom", "margin", "goth", "corners", "transparent", "blur", "stretching"]
        case .barSettings: return ["bar", "autohide", "smart", "thickness", "spacing", "delay", "gap"]
        case .barWidgets: return ["widgets", "layout", "segments", "left", "center", "right", "add", "reorder", "applets"]
        case .barWorkspaces: return ["workspaces", "omniwm", "virtual", "spaces", "pager", "icons", "desktop"]
        case .island: return ["island", "dynamic", "beta", "compact", "float", "overlay", "height", "gaps", "offset", "home", "shortcuts", "pill"]
        case .dashboard: return ["dash", "dashboard", "calendar", "overview", "stats", "notes", "cards"]
        case .mediaPlayer: return ["media", "now playing", "player", "controls", "visualizer", "squiggly", "music"]
        case .notifications: return ["notifications", "banner", "timeout", "rules", "dnd", "alert", "popups"]
        case .osd: return ["osd", "hud", "volume", "brightness", "indicator", "fade", "floating"]
        case .desktopWidgets: return ["desktop", "widgets", "clock", "sticky", "monitor", "notes", "canvas"]
        case .dock: return ["dock", "icons", "magnification", "size", "auto-hide", "trash", "taskbar", "pinned"]
        case .launcher: return ["launcher", "hotkey", "frecency", "search", "math", "google", "tile", "list", "dlauncher"]
        case .shortcuts: return ["keyboard", "shortcuts", "hotkeys", "keybinds", "carbon", "option", "space"]
        case .power: return ["power", "sleep", "caffeinate", "idle", "inhibit", "battery", "display", "timeout"]
        case .plugins: return ["plugins", "registry", "official", "3rd party", "install", "browse", "lockfile"]
        case .about: return ["about", "version", "diagnostics", "build", "github", "docs", "license", "doctor"]
        }
    }

    public static func tabs(for category: SettingsCategory) -> [SettingsTab] {
        allCases.filter { $0.category == category }
    }

    public static func resolve(tab: String?) -> SettingsTab {
        guard let tab = tab?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !tab.isEmpty else {
            return .theme
        }

        // 1. Explicit aliases and legacy overrides
        switch tab {
        case "theme", "colors", "appearance", "appearance.theme", "theme & colors":
            return .theme
        case "bar.appearance", "barappearance":
            return .barAppearance
        case "wallpaper", "matugen":
            return .wallpaper
        case "typography", "fonts", "font", "motion":
            return .typography
        case "time", "weather", "timeweather", "clock":
            return .timeWeather
        case "sounds", "audio":
            return .sounds
        case "bar", "dbar", "primarybar":
            return .barAppearance
        case "barsettings", "bars":
            return .barSettings
        case "barwidgets", "widgets", "applets", "applet":
            return .barWidgets
        case "workspaces", "spaces", "omniwm":
            return .barWorkspaces
        case "island", "dank island", "dynamicisland", "dynamic island":
            return .island
        case "dash", "dashboard", "dankdash":
            return .dashboard
        case "media", "mediaplayer", "music":
            return .mediaPlayer
        case "notifications", "notify":
            return .notifications
        case "osd", "hud":
            return .osd
        case "desktopwidgets", "desktop":
            return .desktopWidgets
        case "dock", "docks":
            return .dock
        case "launcher", "dlauncher":
            return .launcher
        case "shortcuts", "keyboard", "keybinds", "hotkeys":
            return .shortcuts
        case "power", "sleep", "caffeinate", "battery":
            return .power
        case "plugins", "plugin", "registry":
            return .plugins
        case "about", "diagnostics", "doctor", "system":
            return .about
        default:
            break
        }

        // 2. Direct ID match
        if let found = allCases.first(where: { $0.id.lowercased() == tab }) {
            return found
        }

        // 3. Raw value match
        if let found = allCases.first(where: { $0.rawValue.lowercased() == tab }) {
            return found
        }

        return .theme
    }
}

// MARK: - Search Index
public struct SettingsSearchIndex {
    public static func filter(query: String) -> [DMSSettingsTab] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty {
            return DMSSettingsTab.allCases
        }

        return DMSSettingsTab.allCases.filter { tab in
            tab.rawValue.lowercased().contains(trimmed) ||
            tab.id.lowercased().contains(trimmed) ||
            tab.category.rawValue.lowercased().contains(trimmed) ||
            tab.description.lowercased().contains(trimmed) ||
            tab.searchKeywords.contains(where: { $0.lowercased().contains(trimmed) })
        }
    }
}

// MARK: - Bar Widget Metadata & Catalog
public struct BarWidgetMeta: Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var description: String
    public var icon: String
    public var defaultOptions: [String: AnyCodable]

    public init(
        id: String,
        name: String,
        description: String,
        icon: String,
        defaultOptions: [String: AnyCodable] = [:]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.defaultOptions = defaultOptions
    }
}

public struct SettingsWidgetCatalog {
    public enum Section: String, CaseIterable, Sendable {
        case left, center, right
    }

    public static let all: [BarWidgetMeta] = [
        BarWidgetMeta(
            id: "diskUsage",
            name: "Disk Usage",
            description: "Percentage disk storage used",
            icon: "internaldrive.fill"
        ),
        BarWidgetMeta(
            id: "cpuTemperature",
            name: "CPU Temperature",
            description: "CPU temperature display",
            icon: "thermometer.medium"
        ),
        BarWidgetMeta(
            id: "gpuTemperature",
            name: "GPU Temperature",
            description: "GPU temperature display",
            icon: "square.grid.3x3.topleft.filled"
        ),
        BarWidgetMeta(
            id: "systemTray",
            name: "System Tray",
            description: "System notification area icons",
            icon: "bell.badge.fill"
        ),
        BarWidgetMeta(
            id: "privacyIndicator",
            name: "Privacy Indicator",
            description: "Shows when microphone, camera, or screen sharing is active",
            icon: "shield.lefthalf.filled"
        ),
        BarWidgetMeta(
            id: "mediaControls",
            name: "Media Controls",
            description: "Control currently playing media",
            icon: "music.note"
        ),
        BarWidgetMeta(
            id: "clock",
            name: "Clock",
            description: "System clock and date display",
            icon: "clock.fill",
            defaultOptions: ["showDate": AnyCodable(true), "timeFormat": AnyCodable("12h")]
        ),
        BarWidgetMeta(
            id: "weather",
            name: "Weather",
            description: "Current conditions and temperature",
            icon: "cloud.sun.fill"
        ),
        BarWidgetMeta(
            id: "battery",
            name: "Battery",
            description: "Battery percentage and charging status",
            icon: "battery.100"
        ),
        BarWidgetMeta(
            id: "volume",
            name: "Volume",
            description: "Audio volume slider and device selector",
            icon: "speaker.wave.3.fill"
        ),
        BarWidgetMeta(
            id: "launcherButton",
            name: "Launcher Button",
            description: "Open DLauncherV2",
            icon: "sparkle.magnifyingglass"
        ),
        BarWidgetMeta(
            id: "workspaceSwitcher",
            name: "Workspaces",
            description: "Virtual workspaces switcher",
            icon: "square.split.2x2"
        ),
        BarWidgetMeta(
            id: "runningApps",
            name: "Running Apps",
            description: "Active application icons",
            icon: "app.badge"
        ),
        BarWidgetMeta(
            id: "cpuMonitor",
            name: "CPU Usage",
            description: "Real-time CPU processor load percentage",
            icon: "cpu"
        ),
        BarWidgetMeta(
            id: "ramMonitor",
            name: "RAM Usage",
            description: "Real-time memory utilization",
            icon: "memorychip"
        ),
        BarWidgetMeta(
            id: "audioVisualization",
            name: "Audio Visualizer",
            description: "Dynamic sound wave visualizer",
            icon: "waveform.path"
        ),
        BarWidgetMeta(
            id: "capsLockIndicator",
            name: "Caps Lock",
            description: "Caps lock state indicator",
            icon: "capslock.fill"
        ),
        BarWidgetMeta(
            id: "notepadApplet",
            name: "Notepad Popout",
            description: "Quick notes drawer",
            icon: "note.text"
        ),
        BarWidgetMeta(
            id: "clipboardApplet",
            name: "Clipboard Popout",
            description: "Clipboard history drawer",
            icon: "doc.on.clipboard.fill"
        ),
        BarWidgetMeta(
            id: "colorPickerApplet",
            name: "Color Eyedropper",
            description: "Color picker eyedropper tool",
            icon: "eyedropper.halffull"
        ),
        BarWidgetMeta(
            id: "focusedApp",
            name: "Focused App",
            description: "Active application icon and window title",
            icon: "macwindow"
        ),
        BarWidgetMeta(
            id: "networkMonitor",
            name: "Network Monitor",
            description: "Live network bandwidth throughput",
            icon: "arrow.up.arrow.down.circle.fill"
        ),
        BarWidgetMeta(
            id: "idleInhibitor",
            name: "Sleep Inhibitor",
            description: "Keep display awake toggle button",
            icon: "cup.and.saucer.fill"
        ),
        BarWidgetMeta(
            id: "keyboardLayoutName",
            name: "Keyboard Layout",
            description: "Active input source language indicator",
            icon: "keyboard.fill"
        ),
        BarWidgetMeta(
            id: "mediaLyricLine",
            name: "Synchronized Lyrics",
            description: "Live scrolling song lyric ticker",
            icon: "quote.bubble.fill"
        ),
        BarWidgetMeta(
            id: "monitorPill",
            name: "Monitor Pill",
            description: "Current display identifier badge",
            icon: "display"
        ),
        BarWidgetMeta(
            id: "notificationCenterButton",
            name: "Notifications Bell",
            description: "Unread notification center trigger",
            icon: "bell.fill"
        ),
        BarWidgetMeta(
            id: "controlCenterButton",
            name: "Control Center",
            description: "Quick Settings Control Center toggle",
            icon: "switch.2"
        ),
        BarWidgetMeta(
            id: "powerMenuButton",
            name: "Power Menu",
            description: "Lock, sleep, restart, and shutdown menu",
            icon: "power"
        ),
        BarWidgetMeta(
            id: "systemUpdate",
            name: "System Updates",
            description: "Pending package/system updates badge",
            icon: "arrow.down.circle.fill"
        ),
        BarWidgetMeta(
            id: "vpn",
            name: "VPN Status",
            description: "Active VPN tunnel status indicator",
            icon: "network.badge.shield.half.filled"
        ),
        BarWidgetMeta(
            id: "wifi",
            name: "Wi-Fi",
            description: "Wireless network connection indicator",
            icon: "wifi"
        ),
        BarWidgetMeta(
            id: "mic",
            name: "Microphone",
            description: "Microphone mute/gain indicator",
            icon: "mic.fill"
        ),
        BarWidgetMeta(
            id: "spacer",
            name: "Spacer",
            description: "Breaks pill grouping with spacing gap",
            icon: "arrow.left.and.right"
        ),
        BarWidgetMeta(
            id: "separator",
            name: "Separator",
            description: "Visual divider line between widget groups",
            icon: "line.diagonal"
        )
    ]

    public static func addWidget(to section: Section, widgetId: String, in layout: inout BarLayout) {
        let meta = all.first(where: { $0.id == widgetId })
        let options = meta?.defaultOptions ?? [:]
        let entry = BarWidgetEntry(id: "\(widgetId)_\(UUID().uuidString.prefix(4))", widgetId: widgetId, enabled: true, options: options)
        switch section {
        case .left: layout.left.append(entry)
        case .center: layout.center.append(entry)
        case .right: layout.right.append(entry)
        }
    }

    public static func toggleWidget(id: String, in layout: inout BarLayout) {
        if let idx = layout.left.firstIndex(where: { $0.id == id || $0.widgetId == id }) {
            layout.left[idx].enabled.toggle()
        } else if let idx = layout.center.firstIndex(where: { $0.id == id || $0.widgetId == id }) {
            layout.center[idx].enabled.toggle()
        } else if let idx = layout.right.firstIndex(where: { $0.id == id || $0.widgetId == id }) {
            layout.right[idx].enabled.toggle()
        }
    }

    public static func removeWidget(id: String, in layout: inout BarLayout) {
        layout.left.removeAll(where: { $0.id == id || $0.widgetId == id })
        layout.center.removeAll(where: { $0.id == id || $0.widgetId == id })
        layout.right.removeAll(where: { $0.id == id || $0.widgetId == id })
    }

    public static func moveWidget(in section: Section, fromIndex: Int, toIndex: Int, in layout: inout BarLayout) {
        switch section {
        case .left:
            guard fromIndex >= 0, toIndex >= 0, fromIndex < layout.left.count, toIndex < layout.left.count, fromIndex != toIndex else { return }
            let item = layout.left.remove(at: fromIndex)
            layout.left.insert(item, at: toIndex)
        case .center:
            guard fromIndex >= 0, toIndex >= 0, fromIndex < layout.center.count, toIndex < layout.center.count, fromIndex != toIndex else { return }
            let item = layout.center.remove(at: fromIndex)
            layout.center.insert(item, at: toIndex)
        case .right:
            guard fromIndex >= 0, toIndex >= 0, fromIndex < layout.right.count, toIndex < layout.right.count, fromIndex != toIndex else { return }
            let item = layout.right.remove(at: fromIndex)
            layout.right.insert(item, at: toIndex)
        }
    }

    public static func moveWidgetBetweenSections(
        id: String,
        to targetSection: Section,
        in layout: inout BarLayout
    ) {
        var found: BarWidgetEntry?
        if let idx = layout.left.firstIndex(where: { $0.id == id || $0.widgetId == id }) {
            found = layout.left.remove(at: idx)
        } else if let idx = layout.center.firstIndex(where: { $0.id == id || $0.widgetId == id }) {
            found = layout.center.remove(at: idx)
        } else if let idx = layout.right.firstIndex(where: { $0.id == id || $0.widgetId == id }) {
            found = layout.right.remove(at: idx)
        }
        guard let item = found else { return }
        switch targetSection {
        case .left: layout.left.append(item)
        case .center: layout.center.append(item)
        case .right: layout.right.append(item)
        }
    }

    public static func updateWidgetOptions(
        id: String,
        options: [String: AnyCodable],
        in layout: inout BarLayout
    ) {
        if let idx = layout.left.firstIndex(where: { $0.id == id || $0.widgetId == id }) {
            layout.left[idx].options = options
        } else if let idx = layout.center.firstIndex(where: { $0.id == id || $0.widgetId == id }) {
            layout.center[idx].options = options
        } else if let idx = layout.right.firstIndex(where: { $0.id == id || $0.widgetId == id }) {
            layout.right[idx].options = options
        }
    }

    public static func updateWidgetOption(
        id: String,
        key: String,
        value: AnyCodable,
        in layout: inout BarLayout
    ) {
        if let idx = layout.left.firstIndex(where: { $0.id == id || $0.widgetId == id }) {
            var opts = layout.left[idx].options
            opts[key] = value
            layout.left[idx].options = opts
        } else if let idx = layout.center.firstIndex(where: { $0.id == id || $0.widgetId == id }) {
            var opts = layout.center[idx].options
            opts[key] = value
            layout.center[idx].options = opts
        } else if let idx = layout.right.firstIndex(where: { $0.id == id || $0.widgetId == id }) {
            var opts = layout.right[idx].options
            opts[key] = value
            layout.right[idx].options = opts
        }
    }
}

// MARK: - Island Settings Model
public struct IslandSettings: Sendable, Codable, Equatable {
    public enum Instance: String, Sendable, Codable, CaseIterable {
        case off = "off"
        case mainBar = "mainBar"
        case notch = "notch"
        case float = "float"
    }

    public enum IslandCornerStyle: String, Sendable, Codable, CaseIterable, Identifiable {
        case capsule = "capsule"
        case gothic = "gothic"
        case square = "square"
        case rounded = "rounded"

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .capsule: return "Capsule"
            case .gothic: return "Gothic Fillets"
            case .square: return "Square Notch"
            case .rounded: return "Rounded"
            }
        }
    }

    public enum ShortcutPosition: String, Sendable, Codable, CaseIterable {
        case left = "left"
        case right = "right"
        case hidden = "hidden"
    }

    public var instance: Instance
    public var float: Bool
    public var useOverlayLayer: Bool
    private var _reservedHeight: Double
    private var _compactIslandHeight: Double
    private var _compactWidth: Double
    private var _expandedWidth: Double
    private var _expandedHeight: Double
    private var _outerGaps: Double
    private var _horizontalOffset: Double
    private var _springStiffness: Double
    private var _springDamping: Double
    public var animationCurve: IslandAnimationCurve
    public var hoverExpand: Bool
    public var hoverDelayMs: Int
    public var hoverCloseDelayMs: Int
    public var mediaLauncher: ShortcutPosition
    public var batteryControlCenter: ShortcutPosition
    public var weather: ShortcutPosition
    public var compactClockPill: Bool
    public var palette: String // "default", "bright", "dim", "primary", "glass"
    public var opacity: Double
    public var borderEnabled: Bool
    public var shadowEnabled: Bool
    public var gothCorners: Bool
    public var gothFilletRadius: Double
    public var edge: String // "top", "bottom"
    public var anchorX: Double
    public var anchorY: Double
    public var enabledActivities: [String]

    public var cornerStyle: IslandCornerStyle {
        get {
            if gothCorners {
                return .gothic
            } else {
                return .capsule
            }
        }
        set {
            switch newValue {
            case .gothic:
                gothCorners = true
            case .capsule, .square, .rounded:
                gothCorners = false
            }
        }
    }

    public var isEnabled: Bool {
        instance != .off
    }

    public var reservedHeight: Double {
        get { _reservedHeight }
        set { _reservedHeight = max(0.0, min(120.0, newValue)) }
    }

    public var compactIslandHeight: Double {
        get { _compactIslandHeight }
        set { _compactIslandHeight = max(24.0, min(64.0, newValue)) }
    }

    public var compactWidth: Double {
        get { _compactWidth }
        set { _compactWidth = max(96.0, min(320.0, newValue)) }
    }

    public var expandedWidth: Double {
        get { _expandedWidth }
        set { _expandedWidth = max(300.0, min(720.0, newValue)) }
    }

    public var expandedHeight: Double {
        get { _expandedHeight }
        set { _expandedHeight = max(110.0, min(520.0, newValue)) }
    }

    public var outerGaps: Double {
        get { _outerGaps }
        set { _outerGaps = max(0.0, min(48.0, newValue)) }
    }

    public var horizontalOffset: Double {
        get { _horizontalOffset }
        set { _horizontalOffset = max(-200.0, min(200.0, newValue)) }
    }

    public var springStiffness: Double {
        get { _springStiffness }
        set { _springStiffness = max(100.0, min(1000.0, newValue)) }
    }

    public var springDamping: Double {
        get { _springDamping }
        set { _springDamping = max(10.0, min(120.0, newValue)) }
    }

    public static let defaultActivities: [String] = [
        "home", "media", "notification", "osd", "controlCenter", "launcher", "clipboard", "powerMenu", "weather"
    ]

    public init(
        instance: Instance = .mainBar,
        float: Bool = false,
        useOverlayLayer: Bool = false,
        reservedHeight: Double = 32.0,
        compactIslandHeight: Double = 30.0,
        compactWidth: Double = 176.0,
        expandedWidth: Double = 420.0,
        expandedHeight: Double = 180.0,
        outerGaps: Double = 8.0,
        horizontalOffset: Double = 0.0,
        springStiffness: Double = 560.0,
        springDamping: Double = 37.0,
        animationCurve: IslandAnimationCurve = .expressive,
        hoverExpand: Bool = true,
        hoverDelayMs: Int = 350,
        hoverCloseDelayMs: Int = 400,
        mediaLauncher: ShortcutPosition = .left,
        batteryControlCenter: ShortcutPosition = .hidden,
        weather: ShortcutPosition = .hidden,
        compactClockPill: Bool = false,
        palette: String = "default",
        opacity: Double = 0.85,
        borderEnabled: Bool = true,
        shadowEnabled: Bool = true,
        gothCorners: Bool = true,
        gothFilletRadius: Double = 12.0,
        edge: String = "top",
        anchorX: Double = 0.5,
        anchorY: Double = 0.0,
        enabledActivities: [String] = Self.defaultActivities
    ) {
        self.instance = instance
        self.float = float
        self.useOverlayLayer = useOverlayLayer
        self._reservedHeight = max(0.0, min(120.0, reservedHeight))
        self._compactIslandHeight = max(24.0, min(64.0, compactIslandHeight))
        self._compactWidth = max(96.0, min(320.0, compactWidth))
        self._expandedWidth = max(300.0, min(720.0, expandedWidth))
        self._expandedHeight = max(110.0, min(520.0, expandedHeight))
        self._outerGaps = max(0.0, min(48.0, outerGaps))
        self._horizontalOffset = max(-200.0, min(200.0, horizontalOffset))
        self._springStiffness = max(100.0, min(1000.0, springStiffness))
        self._springDamping = max(10.0, min(120.0, springDamping))
        self.animationCurve = animationCurve
        self.hoverExpand = hoverExpand
        self.hoverDelayMs = max(50, min(1500, hoverDelayMs))
        self.hoverCloseDelayMs = max(100, min(2000, hoverCloseDelayMs))
        self.mediaLauncher = mediaLauncher
        self.batteryControlCenter = batteryControlCenter
        self.weather = weather
        self.compactClockPill = compactClockPill
        self.palette = palette
        self.opacity = max(0.2, min(1.0, opacity))
        self.borderEnabled = borderEnabled
        self.shadowEnabled = shadowEnabled
        self.gothCorners = gothCorners
        self.gothFilletRadius = max(4.0, min(32.0, gothFilletRadius))
        self.edge = edge
        self.anchorX = max(0.0, min(1.0, anchorX))
        self.anchorY = max(0.0, min(1.0, anchorY))
        self.enabledActivities = enabledActivities
    }

    public static let `default` = IslandSettings()

    public func toDictionary() -> [String: AnyCodable] {
        return [
            "islandInstance": AnyCodable(instance.rawValue),
            "islandFloat": AnyCodable(float),
            "islandUseOverlayLayer": AnyCodable(useOverlayLayer),
            "islandReservedHeight": AnyCodable(reservedHeight),
            "islandCompactHeight": AnyCodable(compactIslandHeight),
            "islandCompactWidth": AnyCodable(compactWidth),
            "islandExpandedWidth": AnyCodable(expandedWidth),
            "islandExpandedHeight": AnyCodable(expandedHeight),
            "islandOuterGaps": AnyCodable(outerGaps),
            "islandHorizontalOffset": AnyCodable(horizontalOffset),
            "islandSpringStiffness": AnyCodable(springStiffness),
            "islandSpringDamping": AnyCodable(springDamping),
            "islandAnimationCurve": AnyCodable(animationCurve.rawValue),
            "islandHoverExpand": AnyCodable(hoverExpand),
            "islandHoverDelayMs": AnyCodable(hoverDelayMs),
            "islandHoverCloseDelayMs": AnyCodable(hoverCloseDelayMs),
            "islandMediaLauncher": AnyCodable(mediaLauncher.rawValue),
            "islandBatteryControlCenter": AnyCodable(batteryControlCenter.rawValue),
            "islandWeather": AnyCodable(weather.rawValue),
            "islandCompactClockPill": AnyCodable(compactClockPill),
            "islandPalette": AnyCodable(palette),
            "islandOpacity": AnyCodable(opacity),
            "islandBorderEnabled": AnyCodable(borderEnabled),
            "islandShadowEnabled": AnyCodable(shadowEnabled),
            "islandGothCorners": AnyCodable(gothCorners),
            "islandGothFilletRadius": AnyCodable(gothFilletRadius),
            "islandEdge": AnyCodable(edge),
            "islandAnchorX": AnyCodable(anchorX),
            "islandAnchorY": AnyCodable(anchorY),
            "islandEnabledActivities": AnyCodable(enabledActivities.map { AnyCodable($0) })
        ]
    }

    public init(from dictionary: [String: AnyCodable]) {
        let instStr = dictionary["islandInstance"]?.stringValue ?? "mainBar"
        self.instance = Instance(rawValue: instStr) ?? .mainBar
        self.float = dictionary["islandFloat"]?.boolValue ?? false
        self.useOverlayLayer = dictionary["islandUseOverlayLayer"]?.boolValue ?? false

        let resH = dictionary["islandReservedHeight"]?.doubleValue ?? 32.0
        self._reservedHeight = max(0.0, min(120.0, resH))

        let compH = dictionary["islandCompactHeight"]?.doubleValue ?? 30.0
        self._compactIslandHeight = max(24.0, min(64.0, compH))

        let compW = dictionary["islandCompactWidth"]?.doubleValue ?? 176.0
        self._compactWidth = max(96.0, min(320.0, compW))

        let expW = dictionary["islandExpandedWidth"]?.doubleValue ?? 420.0
        self._expandedWidth = max(300.0, min(720.0, expW))

        let expH = dictionary["islandExpandedHeight"]?.doubleValue ?? 180.0
        self._expandedHeight = max(110.0, min(520.0, expH))

        let gaps = dictionary["islandOuterGaps"]?.doubleValue ?? 8.0
        self._outerGaps = max(0.0, min(48.0, gaps))

        let offset = dictionary["islandHorizontalOffset"]?.doubleValue ?? 0.0
        self._horizontalOffset = max(-200.0, min(200.0, offset))

        let stiff = dictionary["islandSpringStiffness"]?.doubleValue ?? 560.0
        self._springStiffness = max(100.0, min(1000.0, stiff))

        let damp = dictionary["islandSpringDamping"]?.doubleValue ?? 37.0
        self._springDamping = max(10.0, min(120.0, damp))

        let curveStr = dictionary["islandAnimationCurve"]?.stringValue ?? "expressive"
        self.animationCurve = IslandAnimationCurve(rawValue: curveStr) ?? .expressive

        self.hoverExpand = dictionary["islandHoverExpand"]?.boolValue ?? true
        self.hoverDelayMs = max(50, min(1500, dictionary["islandHoverDelayMs"]?.intValue ?? 350))
        self.hoverCloseDelayMs = max(100, min(2000, dictionary["islandHoverCloseDelayMs"]?.intValue ?? 400))

        let mlStr = dictionary["islandMediaLauncher"]?.stringValue ?? "left"
        self.mediaLauncher = ShortcutPosition(rawValue: mlStr) ?? .left

        let bccStr = dictionary["islandBatteryControlCenter"]?.stringValue ?? "hidden"
        self.batteryControlCenter = ShortcutPosition(rawValue: bccStr) ?? .hidden

        let wStr = dictionary["islandWeather"]?.stringValue ?? "hidden"
        self.weather = ShortcutPosition(rawValue: wStr) ?? .hidden

        self.compactClockPill = dictionary["islandCompactClockPill"]?.boolValue ?? false
        self.palette = dictionary["islandPalette"]?.stringValue ?? "default"
        self.opacity = max(0.2, min(1.0, dictionary["islandOpacity"]?.doubleValue ?? 0.85))
        self.borderEnabled = dictionary["islandBorderEnabled"]?.boolValue ?? true
        self.shadowEnabled = dictionary["islandShadowEnabled"]?.boolValue ?? true
        self.gothCorners = dictionary["islandGothCorners"]?.boolValue ?? true
        self.gothFilletRadius = max(4.0, min(32.0, dictionary["islandGothFilletRadius"]?.doubleValue ?? 12.0))
        self.edge = dictionary["islandEdge"]?.stringValue ?? "top"
        self.anchorX = max(0.0, min(1.0, dictionary["islandAnchorX"]?.doubleValue ?? 0.5))
        self.anchorY = max(0.0, min(1.0, dictionary["islandAnchorY"]?.doubleValue ?? 0.0))
        if let arr = dictionary["islandEnabledActivities"]?.arrayValue?.compactMap(\.stringValue), !arr.isEmpty {
            self.enabledActivities = arr
        } else {
            self.enabledActivities = Self.defaultActivities
        }
    }
}

// MARK: - Plugin Filter Model
public struct PluginFilter {
    public static func filter(
        plugins: [DMSPlugin],
        query: String,
        hideThirdParty: Bool
    ) -> [DMSPlugin] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return plugins.filter { plugin in
            if hideThirdParty && !plugin.isOfficial {
                return false
            }

            if trimmed.isEmpty {
                return true
            }

            return plugin.name.lowercased().contains(trimmed) ||
                plugin.description.lowercased().contains(trimmed) ||
                plugin.author.lowercased().contains(trimmed) ||
                plugin.tags.contains(where: { $0.lowercased().contains(trimmed) })
        }
    }
}
