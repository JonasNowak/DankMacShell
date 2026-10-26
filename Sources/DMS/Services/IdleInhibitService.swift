import Foundation
import IOKit.pwr_mgt
import DMSCore

/// Manages system and display sleep inhibition (caffeinate) with timed presets and live countdown.
@MainActor
public final class IdleInhibitService: ObservableObject {
    public static let shared = IdleInhibitService()

    @Published public private(set) var isInhibited: Bool = false
    @Published public private(set) var activePreset: IdleInhibitPreset?
    @Published public private(set) var countdown: IdleInhibitCountdown?
    @Published public private(set) var remainingSeconds: TimeInterval?

    private var assertionID: IOPMAssertionID = 0
    private var expirationTimer: Timer?

    private init() {}

    public func toggle() {
        if isInhibited {
            disable()
        } else {
            enable(preset: .indefinite)
        }
    }

    public func enable(preset: IdleInhibitPreset = .indefinite) {
        // If changing presets while already inhibited, re-arm with new duration
        if isInhibited && assertionID != 0 {
            armPreset(preset)
            return
        }

        let reason = "DankMaterialShell Idle Inhibit" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        if result == kIOReturnSuccess {
            isInhibited = true
            ConfigStore.shared.update { $0.setSetting("sleepInhibitEnabled", value: AnyCodable(true)) }
            armPreset(preset)

            let msg = preset == .indefinite
                ? "Sleep Inhibit: Enabled (Indefinite)"
                : "Sleep Inhibit: Enabled (\(preset.label))"
            ToastCenter.shared.show(icon: "cup.and.saucer.fill", message: msg)
        }
    }

    public func disable() {
        guard isInhibited || assertionID != 0 else { return }

        stopExpirationTimer()

        if assertionID != 0 {
            _ = IOPMAssertionRelease(assertionID)
            assertionID = 0
        }

        isInhibited = false
        activePreset = nil
        countdown = nil
        remainingSeconds = nil

        ConfigStore.shared.update { $0.setSetting("sleepInhibitEnabled", value: AnyCodable(false)) }
        ToastCenter.shared.show(icon: "cup.and.saucer", message: "Sleep Inhibit: Disabled")
    }

    private func armPreset(_ preset: IdleInhibitPreset) {
        stopExpirationTimer()
        activePreset = preset

        if preset.durationSeconds != nil {
            let cd = IdleInhibitCountdown(preset: preset)
            countdown = cd
            remainingSeconds = cd.remainingSeconds()

            expirationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, let cd = self.countdown else { return }
                    if cd.isExpired() {
                        self.disable()
                        ToastCenter.shared.show(icon: "cup.and.saucer", message: "Sleep Inhibit: Expired (\(preset.rawValue))")
                    } else {
                        self.remainingSeconds = cd.remainingSeconds()
                    }
                }
            }
        } else {
            countdown = nil
            remainingSeconds = nil
        }
    }

    private func stopExpirationTimer() {
        expirationTimer?.invalidate()
        expirationTimer = nil
    }

    public var formattedRemainingTime: String? {
        guard let rem = remainingSeconds else { return nil }
        return IdleInhibitCountdown.formatRemaining(seconds: rem)
    }

    public var formattedRemainingTimeShort: String? {
        guard let rem = remainingSeconds else { return nil }
        return IdleInhibitCountdown.formatRemainingShort(seconds: rem)
    }
}
