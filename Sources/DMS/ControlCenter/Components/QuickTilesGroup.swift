import SwiftUI
import AppKit
import DMSCore
import MaterialMacLibrary

/// Container bundling compact 1x1 quick action tiles horizontally within a single grid slot.
/// Implements upstream DMS `QuickTilesGroup.qml`. Tile chrome is delegated to
/// `MaterialComponents.MaterialQuickTilesGrid` / `MaterialQuickTileButton` with the bridged
/// `MaterialTheme`; the DMS-specific service bindings (light mode, night shift, caffeine,
/// focus) are wired into the data-driven tile items.
public struct QuickTilesGroup: View {
    @ObservedObject private var theme = ThemeStore.shared
    private let nightShift = NightShiftService.shared
    @ObservedObject private var inhibit = IdleInhibitService.shared

    public init() {}

    public var body: some View {
        MaterialQuickTilesGrid(items: [
            // 1. Dark Mode / Light Mode
            MaterialQuickTileItem(
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
            ),
            // 2. Night Shift
            MaterialQuickTileItem(
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
            ),
            // 3. Caffeine / Sleep Inhibit
            MaterialQuickTileItem(
                icon: inhibit.isInhibited ? "cup.and.saucer.fill" : "cup.and.saucer",
                label: "Caffeine",
                isActive: inhibit.isInhibited,
                onTap: {
                    inhibit.toggle()
                }
            ),
            // 4. Do Not Disturb / Focus
            MaterialQuickTileItem(
                icon: "moon.circle.fill",
                label: "Focus",
                isActive: false,
                onTap: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            ),
        ])
        .materialTheme(theme.materialTheme)
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
