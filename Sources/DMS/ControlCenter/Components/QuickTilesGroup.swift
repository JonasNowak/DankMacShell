import SwiftUI
import AppKit
import DMSCore

/// Container bundling compact 1x1 quick action tiles horizontally within a single grid slot.
/// Implements upstream DMS `QuickTilesGroup.qml`.
public struct QuickTilesGroup: View {
    @ObservedObject private var theme = ThemeStore.shared
    private let nightShift = NightShiftService.shared
    @ObservedObject private var inhibit = IdleInhibitService.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            // 1. Dark Mode / Light Mode
            QuickTileButton(
                icon: theme.isLightMode ? "sun.max.fill" : "moon.fill",
                label: theme.isLightMode ? "Light" : "Dark",
                isActive: theme.isLightMode,
                onTap: {
                    theme.toggleLightMode()
                    ConfigStore.shared.update { $0.isLightMode = theme.isLightMode }
                    ToastCenter.shared.show(
                        icon: theme.isLightMode ? "sun.max.fill" : "moon.fill",
                        message: "Switched to \(theme.isLightMode ? "Light" : "Dark") Mode"
                    )
                }
            )

            // 2. Night Shift
            QuickTileButton(
                icon: "sun.and.horizon.fill",
                label: "Night",
                isActive: nightShift.isOn,
                onTap: {
                    nightShift.toggle()
                    ToastCenter.shared.show(
                        icon: "sun.and.horizon.fill",
                        message: "Night Shift \(nightShift.isOn ? "Enabled" : "Disabled")"
                    )
                }
            )

            // 3. Caffeine / Sleep Inhibit
            QuickTileButton(
                icon: inhibit.isInhibited ? "cup.and.saucer.fill" : "cup.and.saucer",
                label: "Caffeine",
                isActive: inhibit.isInhibited,
                onTap: {
                    inhibit.toggle()
                }
            )

            // 4. Do Not Disturb / Focus
            QuickTileButton(
                icon: "moon.circle.fill",
                label: "Focus",
                isActive: false,
                onTap: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            )
        }
        .padding(6)
        .background(theme.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Compact circular/rounded icon button for QuickTilesGroup.
public struct QuickTileButton: View {
    public let icon: String
    public let label: String
    public let isActive: Bool
    public let onTap: () -> Void

    @ObservedObject private var theme = ThemeStore.shared

    public init(
        icon: String,
        label: String,
        isActive: Bool,
        onTap: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.isActive = isActive
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isActive ? theme.onPrimary : theme.primary)
                    .frame(width: 32, height: 32)
                    .background(isActive ? theme.primary : theme.surfaceContainer)
                    .clipShape(Circle())

                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(theme.onSurfaceVariant)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
