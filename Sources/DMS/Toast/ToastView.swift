import SwiftUI
import AppKit
import DMSCore

public struct ToastOverlayView: View {
    @ObservedObject private var theme = ThemeStore.shared
    private let toastCenter = ToastCenter.shared

    public init() {}

    public var body: some View {
        Group {
            if let toast = toastCenter.activeToast {
                HStack(spacing: 10) {
                    Image(systemName: toast.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.primary)

                    Text(toast.message)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.onSurface)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.surfaceContainer)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(theme.outlineVariant.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                Color.clear
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toastCenter.activeToast)
    }
}
