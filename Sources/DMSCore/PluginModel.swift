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
    public var isLocal: Bool

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
        isOfficial: Bool = true,
        isLocal: Bool = false
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
        self.isLocal = isLocal
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, author, version, type, isInstalled, isEnabled, icon, repoURL, tags, isOfficial, isLocal
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.author = try container.decode(String.self, forKey: .author)
        self.version = try container.decode(String.self, forKey: .version)
        self.type = try container.decode(DMSPluginType.self, forKey: .type)
        self.isInstalled = try container.decode(Bool.self, forKey: .isInstalled)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.icon = try container.decode(String.self, forKey: .icon)
        self.repoURL = try container.decodeIfPresent(String.self, forKey: .repoURL)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.isOfficial = try container.decodeIfPresent(Bool.self, forKey: .isOfficial) ?? true
        self.isLocal = try container.decodeIfPresent(Bool.self, forKey: .isLocal) ?? false
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
        DMSApplet(id: "colorPicker", name: "Color Eyedropper", description: "Screen pixel color sampler", icon: "eyedropper", isEnabled: false, position: .right),
        DMSApplet(id: "symbian", name: "Nokia Belle Sync", description: "Nokia C7 USB sync status pill in the bar", icon: "phone.and.waveform", isEnabled: false, position: .right)
    ]
}

/// Official and community plugin registry for DMS.
public enum DMSPluginRegistry {
    public static let standardPlugins: [DMSPlugin] = [
        DMSPlugin(
            id: "pomodoro-timer",
            name: "Pomodoro Focus Timer",
            description: "Productivity timer with focus/break intervals, DankBar countdown pill, and native Desktop Widget.",
            author: "DankMacShell",
            version: "1.1.0",
            type: .barWidget,
            isInstalled: true,
            isEnabled: false,
            icon: "timer",
            repoURL: "https://github.com/JonasNowak/DankMacShell",
            tags: ["pomodoro", "timer", "focus", "productivity"],
            isOfficial: true
        ),
        DMSPlugin(
            id: "tailscale-status",
            name: "Tailscale VPN Pill",
            description: "Live Tailscale mesh status, tailnet name, exit-node indicator, and one-click IP copy in the bar.",
            author: "DankMacShell",
            version: "1.1.0",
            type: .barWidget,
            isInstalled: true,
            isEnabled: false,
            icon: "shield.checkered",
            repoURL: "https://github.com/JonasNowak/DankMacShell",
            tags: ["tailscale", "vpn", "mesh", "network"],
            isOfficial: true
        ),
        DMSPlugin(
            id: "github-notifications",
            name: "GitHub Notifications",
            description: "Live unread GitHub notification counter via authenticated gh CLI with click-to-open inbox.",
            author: "DankMacShell",
            version: "1.1.0",
            type: .barWidget,
            isInstalled: true,
            isEnabled: false,
            icon: "bell.badge.fill",
            repoURL: "https://github.com/JonasNowak/DankMacShell",
            tags: ["github", "notifications", "pr", "dev"],
            isOfficial: true
        ),
        DMSPlugin(
            id: "symbian-belle-sync",
            name: "Nokia Belle USB Sync",
            description: "USB sync companion for Nokia C7 and Symbian Belle devices. Syncs MP3 music, stages SIS/SISX apps, and manages internal mass memory.",
            author: "DankMacShell",
            version: "1.0.0",
            type: .desktop,
            isInstalled: false,
            isEnabled: false,
            icon: "phone.and.waveform",
            repoURL: "https://github.com/JonasNowak/DankMacShell",
            tags: ["nokia", "symbian", "c7", "belle", "usb", "sync", "sisx", "mp3"],
            isOfficial: true
        )
    ]
}

/// On-disk manifest describing a locally installed DMS plugin script.
public struct DMSPluginManifest: Sendable, Codable, Equatable {
    public var id: String
    public var name: String
    public var description: String
    public var author: String
    public var version: String
    public var type: DMSPluginType
    public var icon: String
    public var command: String
    public var intervalSeconds: Double
    public var onClick: String?
    public var launcherPrefix: String?

    public init(
        id: String,
        name: String,
        description: String,
        command: String,
        author: String = "Local",
        version: String = "1.0.0",
        type: DMSPluginType = .barWidget,
        icon: String = "puzzlepiece.extension",
        intervalSeconds: Double = 30,
        onClick: String? = nil,
        launcherPrefix: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.type = type
        self.icon = icon
        self.command = command
        self.intervalSeconds = intervalSeconds
        self.onClick = onClick
        self.launcherPrefix = launcherPrefix
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, author, version, type, icon, command, intervalSeconds, onClick, launcherPrefix
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.author = try container.decodeIfPresent(String.self, forKey: .author) ?? "Local"
        self.version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0.0"
        self.type = try container.decodeIfPresent(DMSPluginType.self, forKey: .type) ?? .barWidget
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "puzzlepiece.extension"
        self.command = try container.decode(String.self, forKey: .command)
        self.intervalSeconds = try container.decodeIfPresent(Double.self, forKey: .intervalSeconds) ?? 30
        self.onClick = try container.decodeIfPresent(String.self, forKey: .onClick)
        self.launcherPrefix = try container.decodeIfPresent(String.self, forKey: .launcherPrefix)
    }

    /// Polling interval clamped to a sane range (5s...1h).
    public var clampedInterval: TimeInterval { min(3600, max(5, intervalSeconds)) }

    /// Converts the manifest into a registry entry for a locally installed plugin.
    public func toPlugin(isEnabled: Bool) -> DMSPlugin {
        DMSPlugin(
            id: id,
            name: name,
            description: description,
            author: author,
            version: version,
            type: type,
            isInstalled: true,
            isEnabled: isEnabled,
            icon: icon,
            repoURL: nil,
            tags: [],
            isOfficial: false,
            isLocal: true
        )
    }
}

/// Structured output a plugin script prints to stdout for the bar widget.
public struct DMSPluginWidgetOutput: Sendable, Codable, Equatable {
    public var text: String
    public var icon: String?
    public var color: String?
    public var tooltip: String?

    public init(text: String, icon: String? = nil, color: String? = nil, tooltip: String? = nil) {
        self.text = text
        self.icon = icon
        self.color = color
        self.tooltip = tooltip
    }

    /// Parses plugin stdout: JSON object when it starts with `{`, otherwise the
    /// first non-empty line clamped to 64 characters. Returns nil when empty.
    public static func parse(stdout: String) -> DMSPluginWidgetOutput? {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("{"),
           let data = trimmed.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(DMSPluginWidgetOutput.self, from: data),
           !decoded.text.isEmpty {
            return decoded
        }
        let line = trimmed
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            .map { String($0.trimmingCharacters(in: .whitespaces).prefix(64)) }
            ?? String(trimmed.prefix(64))
        return DMSPluginWidgetOutput(text: line)
    }
}
