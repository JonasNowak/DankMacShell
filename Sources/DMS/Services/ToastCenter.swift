import SwiftUI
import Observation
import DMSCore

public struct ToastItem: Identifiable, Equatable {
    public let id = UUID()
    public let icon: String
    public let message: String
    public let duration: TimeInterval

    public init(icon: String, message: String, duration: TimeInterval = 2.5) {
        self.icon = icon
        self.message = message
        self.duration = duration
    }
}

/// In-shell toast notification manager.
@MainActor
@Observable
public final class ToastCenter {
    public static let shared = ToastCenter()

    public private(set) var activeToast: ToastItem?

    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    private init() {}

    public func show(icon: String, message: String, duration: TimeInterval = 2.5, bypassDND: Bool = false) {
        let toastsEnabled = ConfigStore.shared.config.rawSettings["toastsEnabled"]?.boolValue ?? true
        guard toastsEnabled, bypassDND || !DoNotDisturbService.shared.isActive else { return }

        let toast = ToastItem(icon: icon, message: message, duration: duration)
        self.activeToast = toast
        ToastController.shared.show()
        SoundEffectService.shared.playNotification()

        // Cancel the previous dismiss task so rapid toasts never dismiss out of order.
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            if self.activeToast?.id == toast.id {
                withAnimation(.easeOut(duration: 0.25)) {
                    self.activeToast = nil
                }
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                if self.activeToast == nil {
                    ToastController.shared.hide()
                }
            }
        }
    }
}
