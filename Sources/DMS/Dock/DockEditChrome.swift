import SwiftUI
import AppKit
import DMSCore

/// Floating interactive edit bar shown during dock edit mode.
/// Offers "Add Widget", "Settings", and "Done" actions with keyboard focus traps.
public struct DockEditChrome: View {
    public let title: String
    public let onAddWidget: () -> Void
    public let onSettings: () -> Void
    public let onDone: () -> Void

    @ObservedObject private var theme = ThemeStore.shared

    public init(
        title: String,
        onAddWidget: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.title = title
        self.onAddWidget = onAddWidget
        self.onSettings = onSettings
        self.onDone = onDone
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(theme.onPrimaryContainer)
                .padding(.horizontal, 6)

            Button {
                onAddWidget()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Widget")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.onPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.primary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                onSettings()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.onSurface)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.surfaceContainerHigh)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(theme.onSecondaryContainer)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(theme.secondaryContainer)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(theme.surfaceContainer)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(theme.outlineVariant.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
}
