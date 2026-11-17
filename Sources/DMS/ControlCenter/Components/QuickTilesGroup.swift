import SwiftUI
import AppKit
import DMSCore
import MaterialMacLibrary

/// Container bundling compact 1x1 quick action tiles horizontally within a single grid slot.
/// Implements upstream DMS `QuickTilesGroup.qml`. Renders a compact `CcMetrics.tileHeight`
/// (44pt)-compatible row of M3 Expressive morphing squircle buttons; the DMS-specific service
/// bindings (light mode, night shift, caffeine, do not disturb) are wired into the buttons.
public struct QuickTilesGroup: View {
    @ObservedObject private var theme = ThemeStore.shared
    private let nightShift = NightShiftService.shared
    @ObservedObject private var inhibit = IdleInhibitService.shared
    @ObservedObject private var dnd = DoNotDisturbService.shared

    public let cols: Int

    public init(cols: Int = 8) {
        self.cols = cols
    }

    public var body: some View {
        HStack(spacing: cols <= 4 ? 4 : 8) {
            // 1. Dark Mode / Light Mode
            QuickTileIconButton(
                icon: theme.isLightMode ? "sun.max.fill" : "moon.fill",
                label: theme.isLightMode ? "Light Mode" : "Dark Mode",
                isActive: theme.isLightMode
            ) {
                theme.toggleLightMode()
                ConfigStore.shared.update { $0.isLightMode = theme.isLightMode }
                ToastCenter.shared.show(
                    icon: theme.isLightMode ? "sun.max.fill" : "moon.fill",
                    message: "Switched to \(theme.isLightMode ? "Light" : "Dark") Mode"
                )
            }
            // 2. Night Shift
            QuickTileIconButton(
                icon: "sun.and.horizon.fill",
                label: "Night Shift",
                isActive: nightShift.isOn
            ) {
                nightShift.toggle()
                ToastCenter.shared.show(
                    icon: "sun.and.horizon.fill",
                    message: "Night Shift \(nightShift.isOn ? "Enabled" : "Disabled")"
                )
            }
            // 3. Caffeine / Sleep Inhibit
            QuickTileIconButton(
                icon: inhibit.isInhibited ? "cup.and.saucer.fill" : "cup.and.saucer",
                label: "Keep Awake",
                isActive: inhibit.isInhibited
            ) {
                inhibit.toggle()
            }
            // 4. Do Not Disturb
            QuickTileIconButton(
                icon: dnd.isEnabled ? "bell.slash.fill" : "bell.slash",
                label: "Do Not Disturb",
                isActive: dnd.isEnabled
            ) {
                dnd.toggle()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.outlineVariant.opacity(0.15), lineWidth: 1)
        )
    }
}

/// Compact 30x30 M3 Expressive morphing squircle button for `QuickTilesGroup`.
/// Morphs from a circle (15pt radius) when inactive into a squircle (9pt radius) when active,
/// animated with a spring unless reduced motion is enabled.
private struct QuickTileIconButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let onTap: () -> Void

    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        Button(action: onTap) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isActive ? theme.onPrimary : theme.primary)
                .frame(width: 30, height: 30)
                .background(isActive ? theme.primary : theme.surfaceContainer)
                .clipShape(RoundedRectangle(cornerRadius: isActive ? 9 : 15, style: .continuous))
                .animation(
                    theme.motionTokens.reducedMotion ? .none : .spring(response: 0.25, dampingFraction: 0.8),
                    value: isActive
                )
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

/// Compact circular/rounded icon button for QuickTilesGroup.
/// Delegates to `MaterialComponents.MaterialQuickTileButton`.
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
        MaterialQuickTileButton(
            item: MaterialQuickTileItem(icon: icon, label: label, isActive: isActive, onTap: onTap)
        )
        .materialTheme(theme.materialTheme)
    }
}
