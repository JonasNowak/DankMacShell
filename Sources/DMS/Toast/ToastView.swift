import SwiftUI
import AppKit
import DMSCore
import MaterialMacLibrary

/// Floating toast overlay. The pill chrome (frosted glass capsule, border, shadow) is
/// delegated to `MaterialComponents.MaterialToastCard` with the bridged `MaterialTheme`.
public struct ToastOverlayView: View {
    @ObservedObject private var theme = ThemeStore.shared
    private let toastCenter = ToastCenter.shared

    public init() {}

    public var body: some View {
        Group {
            if let toast = toastCenter.activeToast {
                MaterialToastCard(icon: toast.icon, message: toast.message, blurEnabled: true)
                    .materialTheme(theme.materialTheme)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                Color.clear
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toastCenter.activeToast)
    }
}
