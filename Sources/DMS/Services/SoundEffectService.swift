import AppKit
import DMSCore

/// Subtle native UI sound effects (launcher open, toast notification, confirmations).
/// Gated by the `soundsEnabled` raw setting and Do Not Disturb.
@MainActor
public final class SoundEffectService: ObservableObject {
    public static let shared = SoundEffectService()

    public var isEnabled: Bool {
        (ConfigStore.shared.config.rawSettings["soundsEnabled"]?.boolValue ?? true)
            && !DoNotDisturbService.shared.isActive
    }

    private init() {}

    public func playLauncherOpen() {
        play(named: "Pop")
    }

    public func playNotification() {
        play(named: "Tink")
    }

    public func playConfirm() {
        play(named: "Glass")
    }

    private func play(named name: String) {
        guard isEnabled, let sound = NSSound(named: name) else { return }
        sound.volume = 0.35
        sound.play()
    }
}
