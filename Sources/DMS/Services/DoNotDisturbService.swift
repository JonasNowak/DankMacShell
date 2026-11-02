import Foundation
import AppKit
import DMSCore

/// Duration presets for Do Not Disturb / Focus mode.
public enum DNDPreset: String, CaseIterable, Identifiable, Sendable {
    case m15 = "15m"
    case m30 = "30m"
    case h1 = "1h"
    case h2 = "2h"
    case tomorrow = "Until tomorrow"
    case indefinite = "Indefinite"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .m15: return "15 Minutes"
        case .m30: return "30 Minutes"
        case .h1: return "1 Hour"
        case .h2: return "2 Hours"
        case .tomorrow: return "Until Tomorrow Morning"
        case .indefinite: return "Until Turned Off"
        }
    }

    public func targetEndDate(from now: Date = Date()) -> Date? {
        switch self {
        case .m15: return now.addingTimeInterval(15 * 60)
        case .m30: return now.addingTimeInterval(30 * 60)
        case .h1: return now.addingTimeInterval(60 * 60)
        case .h2: return now.addingTimeInterval(120 * 60)
        case .tomorrow:
            let calendar = Calendar.current
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.day = (comps.day ?? 0) + 1
            comps.hour = 7
            comps.minute = 0
            return calendar.date(from: comps) ?? now.addingTimeInterval(8 * 3600)
        case .indefinite: return nil
        }
    }
}

/// Service managing Do Not Disturb state, timed expiration, and live countdowns.
@MainActor
public final class DoNotDisturbService: ObservableObject {
    public static let shared = DoNotDisturbService()

    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var activePreset: DNDPreset = .indefinite
    @Published public private(set) var endDate: Date?
    @Published public private(set) var remainingSeconds: TimeInterval?

    private var countdownTimer: Timer?

    private init() {}

    public func toggle() {
        if isEnabled {
            disable()
        } else {
            enable(preset: .indefinite)
        }
    }

    public func enable(preset: DNDPreset) {
        self.isEnabled = true
        self.activePreset = preset
        self.endDate = preset.targetEndDate()
        updateRemaining()

        countdownTimer?.invalidate()
        if endDate != nil {
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if let end = self.endDate, Date() >= end {
                        self.disable()
                        ToastCenter.shared.show(icon: "bell", message: "Do Not Disturb expired")
                    } else {
                        self.updateRemaining()
                    }
                }
            }
        }
        ToastCenter.shared.show(icon: "bell.slash.fill", message: "Do Not Disturb: \(preset.label)")
    }

    public func disable() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isEnabled = false
        endDate = nil
        remainingSeconds = nil
        ToastCenter.shared.show(icon: "bell", message: "Do Not Disturb: Off")
    }

    private func updateRemaining() {
        guard let end = endDate else {
            remainingSeconds = nil
            return
        }
        remainingSeconds = max(0, end.timeIntervalSince(Date()))
    }

    public func openFocusSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
            if NSWorkspace.shared.open(url) { return }
        }
        if let legacy = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(legacy)
        }
    }
}
