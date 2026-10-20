import SwiftUI
import Observation

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

    private init() {}

    public func show(icon: String, message: String, duration: TimeInterval = 2.5) {
        let toast = ToastItem(icon: icon, message: message, duration: duration)
        self.activeToast = toast
        ToastController.shared.show()

        Task {
            try? await Task.sleep(for: .seconds(duration))
            if self.activeToast?.id == toast.id {
                withAnimation(.easeOut(duration: 0.25)) {
                    self.activeToast = nil
                }
                try? await Task.sleep(for: .milliseconds(300))
                if self.activeToast == nil {
                    ToastController.shared.hide()
                }
            }
        }
    }
}
