import SwiftUI
import AppKit
import DMSCore

/// Native NSVisualEffectView wrapper for silky smooth behind-window desktop blurring.
/// Automatically synchronizes `NSAppearance` with `ThemeStore.shared.isLightMode`
/// so Light Mode and Dark Mode always render with matching vibrancy.
public struct VisualEffectBlur: NSViewRepresentable {
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

    private var resolvedMaterial: NSVisualEffectView.Material {
        if theme.isLightMode {
            // In AppKit Light Mode, .hudWindow is forced dark charcoal and .headerView is flat opaque gray.
            // .popover produces clean, bright, translucent Apple frosted glass.
            if material == .hudWindow || material == .headerView {
                return .popover
            }
            return material
        } else {
            if material == .headerView {
                return .popover
            }
            return material
        }
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = resolvedMaterial
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        view.appearance = NSAppearance(named: theme.isLightMode ? .aqua : .darkAqua)
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        let targetAppearanceName: NSAppearance.Name = theme.isLightMode ? .aqua : .darkAqua
        if nsView.appearance?.name != targetAppearanceName {
            nsView.appearance = NSAppearance(named: targetAppearanceName)
        }
        nsView.material = resolvedMaterial
        nsView.blendingMode = blendingMode
        if nsView.state != .active {
            nsView.state = .active
        }
    }
}

/// Unified Material 3 + macOS frosted glass surface background.
/// Properly layers behind-window `VisualEffectBlur` underneath the theme tonal tint
/// and prevents dark desktop wallpapers from turning Light Mode surfaces muddy gray.
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

    private var resolvedBaseColor: Color {
        if let baseColor {
            return baseColor
        }
        return theme.isLightMode ? theme.surfaceContainerLowest : theme.surfaceContainer
    }

    private var effectiveSliderOpacity: Double {
        let raw = opacity ?? min(configStore.config.popupTransparency, theme.surfaceTokens.surfaceOpacity)
        return max(0.0, min(1.0, raw))
    }

    private var isGlassEnabled: Bool {
        forceGlass
            || configStore.config.barTransparent
            || effectiveSliderOpacity < 0.999
            || theme.surfaceTokens.surfaceOpacity < 0.999
    }

    public var body: some View {
        let slider = effectiveSliderOpacity
        if slider <= 0.005 {
            Color.clear
        } else if isGlassEnabled {
            let explicitGlass = forceGlass || configStore.config.barTransparent
            ZStack {
                // The blur effect itself scales with slider opacity down to 0
                VisualEffectBlur(
                    material: theme.isLightMode ? .popover : material,
                    blendingMode: .behindWindow
                )
                .opacity(min(1.0, slider / 0.35))

                if theme.isLightMode {
                    // Luminosity lift keeps Light Mode frosted glass bright and crisp over dark wallpapers,
                    // smoothly scaling to zero when the slider reaches 0.
                    let whiteLift = explicitGlass
                        ? (slider * 0.40)
                        : (slider * 0.42)
                    let tintAlpha = explicitGlass
                        ? (slider * 0.65)
                        : min(0.94, slider * 0.90)

                    Color.white.opacity(whiteLift)
                    resolvedBaseColor.opacity(tintAlpha)

                    // Subtle top-to-bottom glass sheen scaled with slider
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.32 * slider),
                            Color.white.opacity(0.04 * slider)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    let tintAlpha = explicitGlass
                        ? (slider * 0.72)
                        : slider

                    resolvedBaseColor.opacity(tintAlpha)

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.07 * slider),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        } else {
            resolvedBaseColor
        }
    }
}

