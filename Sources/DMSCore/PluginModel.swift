import Foundation

/// Plugin categories matching DankMaterialShell architecture.
public enum DMSPluginType: String, Sendable, Codable, CaseIterable {
    case barWidget = "widget"
    case controlCenter = "control-center"
    case launcher = "launcher"
    case desktop = "desktop"
    case daemon = "daemon"

    public var title: String {
        switch self {
        case .barWidget: return "Bar Widget"
        case .controlCenter: return "Control Center"
        case .launcher: return "Launcher"
        case .desktop: return "Desktop Widget"
        case .daemon: return "Daemon"
        }
    }

    public var icon: String {
        switch self {
        case .barWidget: return "menubar.rectangle"
        case .controlCenter: return "slider.horizontal.3"
        case .launcher: return "magnifyingglass"
        case .desktop: return "macwindow"
        case .daemon: return "gearshape.2"
        }
    }
}

/// Metadata model for a DankMaterialShell plugin.
public struct DMSPlugin: Identifiable, Sendable, Codable, Equatable {
    public var id: String
    public var name: String
    public var description: String
    public var author: String
    public var version: String
    public var type: DMSPluginType
    public var isInstalled: Bool
    public var isEnabled: Bool
    public var icon: String
    public var repoURL: String?
    public var tags: [String]
    public var isOfficial: Bool

    public init(
        id: String,
        name: String,
        description: String,
        author: String,
        version: String,
        type: DMSPluginType,
        isInstalled: Bool = false,
        isEnabled: Bool = false,
        icon: String = "puzzlepiece.extension",
        repoURL: String? = nil,
        tags: [String] = [],
        isOfficial: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.type = type
        self.isInstalled = isInstalled
        self.isEnabled = isEnabled
        self.icon = icon
        self.repoURL = repoURL
        self.tags = tags
        self.isOfficial = isOfficial
    }
}

/// Lockfile structure matching upstream DankMaterialShell `plugins.lock.json`.
public struct DMSPluginLockfile: Sendable, Codable, Equatable {
    public var version: Int
    public var plugins: [String: DMSPluginLockEntry]

    public struct DMSPluginLockEntry: Sendable, Codable, Equatable {
        public var version: String
        public var commit: String?
        public var enabled: Bool
        public var source: String?

        public init(version: String, commit: String? = nil, enabled: Bool = true, source: String? = nil) {
            self.version = version
            self.commit = commit
            self.enabled = enabled
            self.source = source
        }
    }

    public init(version: Int = 1, plugins: [String: DMSPluginLockEntry] = [:]) {
        self.version = version
        self.plugins = plugins
    }
}

/// Built-in applet identifiers and definitions for the customizable bar.
public struct DMSApplet: Identifiable, Sendable, Codable, Equatable {
    public var id: String
    public var name: String
    public var description: String
    public var icon: String
    public var isEnabled: Bool
    public var position: DMSAppletPosition

    public enum DMSAppletPosition: String, Sendable, Codable, CaseIterable {
        case left = "Left"
        case center = "Center"
        case right = "Right"
    }

    public init(
        id: String,
        name: String,
        description: String,
        icon: String,
        isEnabled: Bool = true,
        position: DMSAppletPosition = .right
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.isEnabled = isEnabled
        self.position = position
    }
}

/// Standard catalog of built-in applets for DankBar customization.
public enum StandardApplets {
    public static let all: [DMSApplet] = [
        DMSApplet(id: "launcher", name: "DMS Launcher", description: "Spotlight launcher trigger pill", icon: "circle.grid.3x3.fill", isEnabled: true, position: .left),
        DMSApplet(id: "spaces", name: "Workspaces", description: "Virtual desktop spaces switcher", icon: "square.split.2x2", isEnabled: true, position: .left),
        DMSApplet(id: "workspaceApps", name: "Workspace Apps", description: "Running apps in current workspace", icon: "macwindow.on.rectangle", isEnabled: true, position: .left),
        DMSApplet(id: "clock", name: "Clock & Dynamic Island", description: "Live clock, date, and media snippet", icon: "clock.fill", isEnabled: true, position: .center),
        DMSApplet(id: "weather", name: "Weather Pill", description: "Current temperature and conditions", icon: "cloud.sun.fill", isEnabled: true, position: .right),
        DMSApplet(id: "cpu", name: "CPU Telemetry", description: "Live processor usage percentage", icon: "cpu", isEnabled: true, position: .right),
        DMSApplet(id: "ram", name: "RAM Telemetry", description: "Live memory utilization percentage", icon: "memorychip", isEnabled: true, position: .right),
        DMSApplet(id: "battery", name: "Battery Status", description: "Battery level and charging status", icon: "battery.100.bolt", isEnabled: true, position: .right),
        DMSApplet(id: "inhibit", name: "Caffeinate", description: "Prevent display and system sleep", icon: "cup.and.saucer.fill", isEnabled: true, position: .right),
        DMSApplet(id: "mic", name: "Microphone Mute", description: "Quick microphone mute toggle", icon: "mic.fill", isEnabled: true, position: .right),
        DMSApplet(id: "wifi", name: "Wi-Fi Status", description: "Network signal and connection status", icon: "wifi", isEnabled: true, position: .right),
        DMSApplet(id: "volume", name: "Audio Volume", description: "Output volume indicator", icon: "speaker.wave.3.fill", isEnabled: true, position: .right),
        DMSApplet(id: "controlCenter", name: "Control Center", description: "Quick settings flyout trigger", icon: "slider.horizontal.3", isEnabled: true, position: .right),
        DMSApplet(id: "powerMenu", name: "Power Menu", description: "Lock, sleep, restart, shutdown dialog", icon: "power", isEnabled: true, position: .right),
        DMSApplet(id: "notepad", name: "Quick Scratchpad", description: "Instant note editor toggle", icon: "square.and.pencil", isEnabled: false, position: .right),
        DMSApplet(id: "clipboard", name: "Clipboard History", description: "Pasteboard history drawer", icon: "doc.on.clipboard", isEnabled: false, position: .right),
        DMSApplet(id: "colorPicker", name: "Color Eyedropper", description: "Screen pixel color sampler", icon: "eyedropper", isEnabled: false, position: .right)
    ]
}

/// Official and community plugin registry for DMS.
public enum DMSPluginRegistry {
    public static let standardPlugins: [DMSPlugin] = [
        DMSPlugin(
            id: "github-notifications",
            name: "GitHub Notifications",
            description: "Live unread notification counter and pull-request alerts in the bar.",
            author: "AvengeMedia",
            version: "1.2.0",
            type: .barWidget,
            isInstalled: true,
            isEnabled: true,
            icon: "bell.badge.fill",
            repoURL: "https://github.com/AvengeMedia/dms-plugin-github"
        ),
        DMSPlugin(
            id: "pomodoro-timer",
            name: "Pomodoro Focus Timer",
            description: "Productivity timer with focus/break intervals and notification chimes.",
            author: "dms-community",
            version: "1.0.4",
            type: .barWidget,
            isInstalled: true,
            isEnabled: false,
            icon: "timer",
            repoURL: "https://github.com/dms-community/dms-pomodoro"
        ),
        DMSPlugin(
            id: "network-speed",
            name: "Net Speed Monitor",
            description: "Real-time upload and download throughput monitor on the bar.",
            author: "AvengeMedia",
            version: "2.1.0",
            type: .barWidget,
            isInstalled: true,
            isEnabled: false,
            icon: "arrow.up.arrow.down",
            repoURL: "https://github.com/AvengeMedia/dms-netspeed"
        ),
        DMSPlugin(
            id: "crypto-tracker",
            name: "Crypto Ticker",
            description: "Live BTC, ETH, and SOL price tracking with color indicators.",
            author: "crypto-dev",
            version: "0.9.1",
            type: .barWidget,
            isInstalled: false,
            isEnabled: false,
            icon: "bitcoinsign.circle.fill",
            repoURL: "https://github.com/dms-community/dms-crypto"
        ),
        DMSPlugin(
            id: "disk-usage",
            name: "Disk Space Indicator",
            description: "Monitors primary APFS container free space and warns on low storage.",
            author: "mac-tools",
            version: "1.1.2",
            type: .controlCenter,
            isInstalled: false,
            isEnabled: false,
            icon: "internaldrive.fill",
            repoURL: "https://github.com/dms-community/dms-disk-usage"
        ),
        DMSPlugin(
            id: "tailscale-status",
            name: "Tailscale VPN Pill",
            description: "Displays Tailscale mesh network connectivity and exit-node status.",
            author: "mesh-hacker",
            version: "1.3.0",
            type: .barWidget,
            isInstalled: false,
            isEnabled: false,
            icon: "shield.checkered",
            repoURL: "https://github.com/dms-community/dms-tailscale"
        ),
        DMSPlugin(
            id: "spotify-mini",
            name: "Spotify Expressive",
            description: "Expanded Spotify album artwork visualizer and playlist shortcuts.",
            author: "AvengeMedia",
            version: "2.0.1",
            type: .controlCenter,
            isInstalled: false,
            isEnabled: false,
            icon: "music.note.tv",
            repoURL: "https://github.com/AvengeMedia/dms-spotify-mini"
        ),
        DMSPlugin(
            id: "currency-converter",
            name: "Currency & Unit Converter",
            description: "Adds unit and FX currency conversions directly into the launcher.",
            author: "dms-community",
            version: "1.0.0",
            type: .launcher,
            isInstalled: false,
            isEnabled: false,
            icon: "dollarsign.circle",
            repoURL: "https://github.com/dms-community/dms-currency"
        )
    ]
}
