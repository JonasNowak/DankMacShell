import SwiftUI
import AppKit
import DMSCore
import MaterialMacLibrary
import MaterialTokens
import MaterialComponents

/// Native `NSVisualEffectView` wrapper for silky smooth behind-window desktop blurring.
/// Delegates to `MaterialComponents.VisualEffectBlur`; appearance (Light/Dark vibrancy)
/// is driven by the bridged `MaterialTheme` from `ThemeStore.shared`.
public struct VisualEffectBlur: View {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode

    @ObservedObject private var theme = ThemeStore.shared

    public init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public var body: some View {
        MaterialComponents.VisualEffectBlur(
            material: material,
            blendingMode: blendingMode,
            blurEnabled: true
        )
        .materialTheme(theme.materialTheme)
    }
}

/// Unified Material 3 + macOS frosted glass surface background.
/// Delegates to `MaterialComponents.GlassSurfaceBackground`, layering the behind-window
/// `VisualEffectBlur` underneath the theme tonal tint and preventing dark desktop
/// wallpapers from turning Light Mode surfaces muddy gray.
public struct GlassSurfaceBackground: View {
    public var baseColor: Color?
    public var opacity: Double?
    public var forceGlass: Bool
    public var material: NSVisualEffectView.Material

    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var configStore = ConfigStore.shared

    public init(
        baseColor: Color? = nil,
        opacity: Double? = nil,
        forceGlass: Bool = false,
        material: NSVisualEffectView.Material = .popover
    ) {
        self.baseColor = baseColor
        self.opacity = opacity
        self.forceGlass = forceGlass
        self.material = material
    }

    public var body: some View {
        MaterialComponents.GlassSurfaceBackground(
            surfaceOpacity: opacity,
            blurEnabled: true,
            forceGlass: forceGlass || configStore.config.barTransparent,
            fallbackColor: baseColor,
            material: material
        )
        .materialTheme(theme.materialTheme)
    }
}

extension ThemeStore {
    /// Bridges the DMS theme store into a `MaterialTheme` so `MaterialComponents` views
    /// can be injected with `.materialTheme(theme.materialTheme)`.
    var materialTheme: MaterialTheme {
        MaterialTheme(
            palette: palette,
            shapeTokens: shapeTokens,
            motionTokens: motionTokens,
            typographyTokens: typographyTokens,
            surfaceTokens: surfaceTokens,
            shadowTokens: shadowTokens,
            isLightMode: isLightMode,
            activeThemeName: themeName
        )
    }
}
