import Foundation

/// 8-Degree-of-Freedom geometry state for Dynamic Island morphing (`VectorSpringMotion.qml`).
public struct IslandGeometryVector: Sendable, Codable, Equatable {
    public var width: Double
    public var height: Double
    public var offsetX: Double
    public var offsetY: Double
    public var topLeftRadius: Double
    public var topRightRadius: Double
    public var bottomLeftRadius: Double
    public var bottomRightRadius: Double

    public init(
        width: Double = 176.0,
        height: Double = 42.0,
        offsetX: Double = 0.0,
        offsetY: Double = 0.0,
        topLeftRadius: Double = 21.0,
        topRightRadius: Double = 21.0,
        bottomLeftRadius: Double = 21.0,
        bottomRightRadius: Double = 21.0
    ) {
        self.width = width
        self.height = height
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.topLeftRadius = topLeftRadius
        self.topRightRadius = topRightRadius
        self.bottomLeftRadius = bottomLeftRadius
        self.bottomRightRadius = bottomRightRadius
    }

    public var asArray: [Double] {
        [width, height, offsetX, offsetY, topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius]
    }

    public init(array: [Double]) {
        self.width = array.count > 0 ? array[0] : 176.0
        self.height = array.count > 1 ? array[1] : 42.0
        self.offsetX = array.count > 2 ? array[2] : 0.0
        self.offsetY = array.count > 3 ? array[3] : 0.0
        self.topLeftRadius = array.count > 4 ? array[4] : 21.0
        self.topRightRadius = array.count > 5 ? array[5] : 21.0
        self.bottomLeftRadius = array.count > 6 ? array[6] : 21.0
        self.bottomRightRadius = array.count > 7 ? array[7] : 21.0
    }
}

/// Customizable animation curve presets for Dynamic Island morphing.
public enum IslandAnimationCurve: String, Sendable, Codable, CaseIterable {
    case expressive = "expressive" // Default DMS RK4 spring (stiffness 560, damping 37)
    case snappy = "snappy"         // Fast critically damped (stiffness 720, damping 52)
    case smooth = "smooth"         // Gentle fluid curve (stiffness 380, damping 38)
    case bouncy = "bouncy"         // Underdamped playful bounce (stiffness 520, damping 24)
    case linear = "linear"         // High-damping minimal overshoot (stiffness 600, damping 60)
    case custom = "custom"         // Custom spring stiffness and damping

    public var defaultStiffness: Double {
        switch self {
        case .expressive: return 560.0
        case .snappy: return 720.0
        case .smooth: return 380.0
        case .bouncy: return 520.0
        case .linear: return 600.0
        case .custom: return 560.0
        }
    }

    public var defaultDamping: Double {
        switch self {
        case .expressive: return 37.0
        case .snappy: return 52.0
        case .smooth: return 38.0
        case .bouncy: return 24.0
        case .linear: return 60.0
        case .custom: return 37.0
        }
    }

    public var swiftUIResponse: Double {
        switch self {
        case .expressive: return 0.34
        case .snappy: return 0.24
        case .smooth: return 0.44
        case .bouncy: return 0.38
        case .linear: return 0.20
        case .custom: return 0.34
        }
    }

    public var swiftUIDampingFraction: Double {
        switch self {
        case .expressive: return 0.76
        case .snappy: return 0.88
        case .smooth: return 0.92
        case .bouncy: return 0.62
        case .linear: return 1.0
        case .custom: return 0.76
        }
    }
}

/// 8-DOF Runge-Kutta 4th-order (RK4) physical spring simulation engine (`VectorSpringMotion.qml`).
public struct VectorSpringEngine: Sendable, Equatable {
    public var stiffness: Double
    public var damping: Double
    public var mass: Double
    public let positionEpsilon: Double = 0.035
    public let velocityEpsilon: Double = 0.035
    public let integrationStep: Double = 1.0 / 240.0

    public private(set) var current: IslandGeometryVector
    public var target: IslandGeometryVector
    public private(set) var velocity: [Double]

    public init(
        initial: IslandGeometryVector = IslandGeometryVector(),
        stiffness: Double = 560.0,
        damping: Double = 37.0,
        mass: Double = 1.0
    ) {
        self.stiffness = max(10.0, stiffness)
        self.damping = max(1.0, damping)
        self.mass = max(0.1, mass)
        self.current = initial
        self.target = initial
        self.velocity = Array(repeating: 0.0, count: 8)
    }

    public var isAtRest: Bool {
        let pos = current.asArray
        let tgt = target.asArray
        for i in 0..<8 {
            if abs(pos[i] - tgt[i]) > positionEpsilon || abs(velocity[i]) > velocityEpsilon {
                return false
            }
        }
        return true
    }

    /// Advances the 8-DOF spring simulation by `dt` seconds using 240Hz RK4 substeps.
    public mutating func step(dt: Double) -> IslandGeometryVector {
        guard dt > 0, !isAtRest else {
            if isAtRest {
                current = target
                velocity = Array(repeating: 0.0, count: 8)
            }
            return current
        }

        var remaining = min(dt, 0.25) // Clamp large frame spikes
        var pos = current.asArray
        let tgt = target.asArray
        let k = stiffness
        let c = damping
        let invM = 1.0 / mass

        while remaining > 1e-6 {
            let h = min(remaining, integrationStep)
            remaining -= h

            for i in 0..<8 {
                let x0 = pos[i] - tgt[i]
                let v0 = velocity[i]

                let a1 = (-k * x0 - c * v0) * invM
                let x2 = x0 + 0.5 * h * v0
                let v2 = v0 + 0.5 * h * a1
                let a2 = (-k * x2 - c * v2) * invM

                let x3 = x0 + 0.5 * h * v2
                let v3 = v0 + 0.5 * h * a2
                let a3 = (-k * x3 - c * v3) * invM

                let x4 = x0 + h * v3
                let v4 = v0 + h * a3
                let a4 = (-k * x4 - c * v4) * invM

                let newX = x0 + (h / 6.0) * (v0 + 2.0 * v2 + 2.0 * v3 + v4)
                let newV = v0 + (h / 6.0) * (a1 + 2.0 * a2 + 2.0 * a3 + a4)

                if abs(newX) <= positionEpsilon && abs(newV) <= velocityEpsilon {
                    pos[i] = tgt[i]
                    velocity[i] = 0.0
                } else {
                    pos[i] = tgt[i] + newX
                    velocity[i] = newV
                }
            }
        }

        // Clamp radii and dimensions to non-negative values
        pos[0] = max(24.0, pos[0])
        pos[1] = max(16.0, pos[1])
        for rIdx in 4..<8 {
            pos[rIdx] = max(0.0, pos[rIdx])
        }

        current = IslandGeometryVector(array: pos)
        return current
    }

    public mutating func snapToTarget() {
        current = target
        velocity = Array(repeating: 0.0, count: 8)
    }
}

/// Active content modules and states for the Dynamic Island (`IslandController.qml`).
public enum IslandActivity: String, Sendable, Codable, CaseIterable {
    case home = "home"
    case media = "media"
    case notification = "notification"
    case osd = "osd"
    case controlCenter = "controlCenter"
    case launcher = "launcher"
    case clipboard = "clipboard"
    case powerMenu = "powerMenu"
    case weather = "weather"

    public static func parse(_ raw: String?) -> IslandActivity {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty else {
            return .home
        }
        switch raw {
        case "media", "music", "player": return .media
        case "notification", "notifications", "notif": return .notification
        case "osd", "volume", "brightness", "systemlevel": return .osd
        case "cc", "controlcenter", "control-center": return .controlCenter
        case "launcher", "search", "apps": return .launcher
        case "clipboard", "clip": return .clipboard
        case "power", "powermenu", "power-menu": return .powerMenu
        case "weather", "forecast": return .weather
        default: return .home
        }
    }
}

/// Complete presentation state of the Dynamic Island (`24-island-surface-widgets.md §3`).
public enum IslandPresentationState: String, Sendable, Codable, Equatable {
    case idle
    case compactMedia
    case compactNotification
    case compactOSD
    case expandedHome
    case expandedMedia
    case expandedNotification
    case expandedOSD
    case expandedControlCenter
    case expandedLauncher
    case expandedClipboard
    case expandedPowerMenu
    case expandedWeather

    public var isExpanded: Bool {
        switch self {
        case .idle, .compactMedia, .compactNotification, .compactOSD:
            return false
        default:
            return true
        }
    }

    public var activity: IslandActivity {
        switch self {
        case .idle, .expandedHome: return .home
        case .compactMedia, .expandedMedia: return .media
        case .compactNotification, .expandedNotification: return .notification
        case .compactOSD, .expandedOSD: return .osd
        case .expandedControlCenter: return .controlCenter
        case .expandedLauncher: return .launcher
        case .expandedClipboard: return .clipboard
        case .expandedPowerMenu: return .powerMenu
        case .expandedWeather: return .weather
        }
    }
}

/// State machine governing Dynamic Island priority arbitration (`OSD` > `Notification` > `Media` > `Idle`),
/// expansion triggers, and target 8-DOF geometry calculation.
public struct IslandStateMachine: Sendable, Equatable {
    public var isMediaPlaying: Bool = false
    public var activeNotificationUntil: Date? = nil
    public var activeOSDUntil: Date? = nil
    public var isExpanded: Bool = false
    public var expandedActivity: IslandActivity = .home
    public var enabledModules: Set<IslandActivity> = Set(IslandActivity.allCases)

    public init(enabledModules: Set<IslandActivity> = Set(IslandActivity.allCases)) {
        self.enabledModules = enabledModules
    }

    /// Resolves the highest-priority active state at timestamp `now`.
    /// Priority Arbitration (`24-island-surface-widgets.md §3`):
    /// `OSD Level (3s timeout)` > `Notification Alert (5s timeout)` > `Media Playback (persistent if playing)` > `Home Idle`.
    public mutating func resolveState(at now: Date = Date()) -> IslandPresentationState {
        // Expire elapsed transient states
        if let osdEnd = activeOSDUntil, now >= osdEnd {
            activeOSDUntil = nil
        }
        if let notifEnd = activeNotificationUntil, now >= notifEnd {
            activeNotificationUntil = nil
        }

        if isExpanded {
            let act = enabledModules.contains(expandedActivity) ? expandedActivity : .home
            switch act {
            case .home: return .expandedHome
            case .media: return .expandedMedia
            case .notification: return .expandedNotification
            case .osd: return .expandedOSD
            case .controlCenter: return .expandedControlCenter
            case .launcher: return .expandedLauncher
            case .clipboard: return .expandedClipboard
            case .powerMenu: return .expandedPowerMenu
            case .weather: return .expandedWeather
            }
        }

        if activeOSDUntil != nil && enabledModules.contains(.osd) {
            return .compactOSD
        }
        if activeNotificationUntil != nil && enabledModules.contains(.notification) {
            return .compactNotification
        }
        if isMediaPlaying && enabledModules.contains(.media) {
            return .compactMedia
        }
        return .idle
    }

    public mutating func triggerOSD(at now: Date = Date(), duration: TimeInterval = 3.0) {
        guard enabledModules.contains(.osd) else { return }
        activeOSDUntil = now.addingTimeInterval(duration)
    }

    public mutating func triggerNotification(at now: Date = Date(), duration: TimeInterval = 5.0) {
        guard enabledModules.contains(.notification) else { return }
        activeNotificationUntil = now.addingTimeInterval(duration)
    }

    public mutating func expand(to activity: IslandActivity? = nil, at now: Date = Date()) {
        if let activity, enabledModules.contains(activity) {
            expandedActivity = activity
        } else {
            let current = resolveState(at: now)
            expandedActivity = current.activity
        }
        isExpanded = true
    }

    public mutating func collapse() {
        isExpanded = false
    }

    public mutating func toggle(activity: IslandActivity? = nil, at now: Date = Date()) -> Bool {
        if isExpanded {
            if let activity, expandedActivity != activity {
                expand(to: activity, at: now)
                return true
            }
            collapse()
            return false
        } else {
            expand(to: activity, at: now)
            return true
        }
    }

    /// Computes the target 8-DOF geometry vector for a given `IslandPresentationState`, `IslandSettings`, and `ScreenNotchGeometry`.
    public static func targetGeometry(
        for state: IslandPresentationState,
        settings: IslandSettings,
        notch: ScreenNotchGeometry = .standardMonitor()
    ) -> IslandGeometryVector {
        let isNotchAttached = !settings.float && (settings.instance == .notch || (settings.instance == .mainBar && notch.hasNotch))

        let wingWidth: Double = 96.0
        let baseCompactWidth = max(settings.compactWidth, isNotchAttached ? notch.notchWidth + (wingWidth * 2.0) : settings.compactWidth)
        let baseCompactHeight = max(settings.compactIslandHeight, isNotchAttached ? max(notch.notchHeight, settings.compactIslandHeight) : settings.compactIslandHeight)

        let width: Double
        let height: Double

        switch state {
        case .idle:
            width = baseCompactWidth
            height = baseCompactHeight
        case .compactMedia:
            width = max(baseCompactWidth + 44.0, isNotchAttached ? notch.notchWidth + 240.0 : 220.0)
            height = baseCompactHeight
        case .compactNotification:
            width = max(baseCompactWidth + 84.0, isNotchAttached ? notch.notchWidth + 260.0 : 260.0)
            height = max(baseCompactHeight, 44.0)
        case .compactOSD:
            width = max(baseCompactWidth + 64.0, isNotchAttached ? notch.notchWidth + 240.0 : 240.0)
            height = max(baseCompactHeight, 42.0)
        case .expandedHome,
             .expandedMedia,
             .expandedNotification,
             .expandedOSD,
             .expandedControlCenter,
             .expandedLauncher,
             .expandedClipboard,
             .expandedPowerMenu,
             .expandedWeather:
            width = settings.expandedWidth
            height = settings.expandedHeight
        }

        let compactPillRadius = height / 2.0
        let expandedRadius = 34.0
        let bottomRadius = state.isExpanded ? expandedRadius : compactPillRadius
        let topRadius = isNotchAttached ? 0.0 : bottomRadius

        return IslandGeometryVector(
            width: width,
            height: height,
            offsetX: settings.horizontalOffset,
            offsetY: isNotchAttached ? 0.0 : settings.outerGaps,
            topLeftRadius: topRadius,
            topRightRadius: topRadius,
            bottomLeftRadius: bottomRadius,
            bottomRightRadius: bottomRadius
        )
    }
}
