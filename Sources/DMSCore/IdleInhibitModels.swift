import Foundation

/// Predefined duration presets for system idle inhibit (caffeinate).
public enum IdleInhibitPreset: String, Sendable, Codable, CaseIterable, Identifiable {
    case m15 = "15m"
    case m30 = "30m"
    case h1 = "1h"
    case h2 = "2h"
    case h4 = "4h"
    case indefinite = "Indefinite"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .m15: return "15 Minutes"
        case .m30: return "30 Minutes"
        case .h1: return "1 Hour"
        case .h2: return "2 Hours"
        case .h4: return "4 Hours"
        case .indefinite: return "Indefinite"
        }
    }

    public var shortLabel: String { rawValue }

    public var durationSeconds: TimeInterval? {
        switch self {
        case .m15: return 15.0 * 60.0
        case .m30: return 30.0 * 60.0
        case .h1: return 60.0 * 60.0
        case .h2: return 120.0 * 60.0
        case .h4: return 240.0 * 60.0
        case .indefinite: return nil
        }
    }
}

/// Tracks the active idle inhibit countdown and expiration state.
public struct IdleInhibitCountdown: Sendable, Codable, Equatable {
    public var preset: IdleInhibitPreset
    public var startDate: Date
    public var totalSeconds: TimeInterval?

    public init(preset: IdleInhibitPreset, startDate: Date = Date()) {
        self.preset = preset
        self.startDate = startDate
        self.totalSeconds = preset.durationSeconds
    }

    public init(preset: IdleInhibitPreset, startDate: Date, totalSeconds: TimeInterval?) {
        self.preset = preset
        self.startDate = startDate
        self.totalSeconds = totalSeconds
    }

    public func remainingSeconds(at currentDate: Date = Date()) -> TimeInterval? {
        guard let total = totalSeconds else { return nil }
        let elapsed = currentDate.timeIntervalSince(startDate)
        return max(0.0, total - elapsed)
    }

    public func isExpired(at currentDate: Date = Date()) -> Bool {
        guard let remaining = remainingSeconds(at: currentDate) else { return false }
        return remaining <= 0.0
    }

    public func progress(at currentDate: Date = Date()) -> Double {
        guard let total = totalSeconds, total > 0 else { return 0.0 }
        let elapsed = currentDate.timeIntervalSince(startDate)
        return min(1.0, max(0.0, elapsed / total))
    }

    public static func formatRemaining(seconds: TimeInterval) -> String {
        let sec = Int(max(0.0, seconds.rounded(.down)))
        let hours = sec / 3600
        let minutes = (sec % 3600) / 60
        let s = sec % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, s)
        } else {
            return "\(s)s"
        }
    }

    public static func formatRemainingShort(seconds: TimeInterval) -> String {
        let sec = Int(max(0.0, seconds.rounded(.down)))
        let hours = sec / 3600
        let minutes = (sec % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(sec)s"
        }
    }
}
