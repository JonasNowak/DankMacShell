import SwiftUI
import AppKit
import DMSCore
import MaterialMacLibrary
import MaterialTokens
import MaterialComponents

/// Native frosted-glass wrapper. On macOS 26+ this renders an `NSGlassEffectView`
/// (Liquid Glass, resolved at runtime via `NSClassFromString` so the file compiles on
/// any SDK); on macOS 14/15 it falls back to `NSVisualEffectView`. Appearance
/// (Light/Dark vibrancy) is driven by `ThemeStore.shared`.
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
        BlurRepresentable(
            material: material,
            blendingMode: blendingMode,
            isLightMode: theme.isLightMode
        )
    }
}

/// `NSViewRepresentable` backing `VisualEffectBlur`. Uses `NSGlassEffectView` on
/// macOS 26+ when the class exists, otherwise `NSVisualEffectView`.
private struct BlurRepresentable: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var isLightMode: Bool

    /// Runtime Liquid Glass check: `NSGlassEffectView` is not in any CLT SDK, so resolve
    /// it dynamically and gate on the OS version to stay compilable everywhere.
    private static let glassViewClass: NSView.Type? = {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26,
              let cls = NSClassFromString("NSGlassEffectView") as? NSView.Type else { return nil }
        return cls
    }()

    private var resolvedMaterial: NSVisualEffectView.Material {
        if isLightMode {
            // In AppKit Light Mode, .hudWindow is forced dark charcoal and .headerView is
            // flat opaque gray. .popover produces clean, bright, translucent frosted glass.
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

    func makeNSView(context: Context) -> NSView {
        if let glassClass = Self.glassViewClass {
            context.coordinator.usedGlass = true
            let glass = glassClass.init(frame: .zero)
            configureGlass(glass, isLightMode: isLightMode)
            return glass
        }
        context.coordinator.usedGlass = false
        let view = NSVisualEffectView()
        view.material = resolvedMaterial
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        view.appearance = context.coordinator.appearance(isLightMode: isLightMode)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if context.coordinator.usedGlass {
            if let glassClass = Self.glassViewClass, nsView.isKind(of: glassClass) {
                configureGlass(nsView, isLightMode: isLightMode)
            }
            return
        }
        guard let view = nsView as? NSVisualEffectView else { return }
        // Only touch AppKit state when values actually changed — avoids re-allocating
        // NSAppearance and re-applying material on every SwiftUI frame.
        let targetAppearance = context.coordinator.appearance(isLightMode: isLightMode)
        if view.appearance?.name != targetAppearance?.name {
            view.appearance = targetAppearance
        }
        if view.material != resolvedMaterial {
            view.material = resolvedMaterial
        }
        if view.blendingMode != blendingMode {
            view.blendingMode = blendingMode
        }
    }

    private func configureGlass(_ glass: NSView, isLightMode: Bool) {
        // NSGlassEffectView is private-SDK; configure defensively via KVC.
        if glass.responds(to: NSSelectorFromString("setTintColor:")) {
            let tint = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: isLightMode ? 0.25 : 0.12)
            glass.setValue(tint, forKey: "tintColor")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var usedGlass: Bool = false
        private var cachedAppearance: NSAppearance?

        /// Cached `NSAppearance` so repeated frames don't re-allocate it.
        func appearance(isLightMode: Bool) -> NSAppearance? {
            let name: NSAppearance.Name = isLightMode ? .aqua : .darkAqua
            if cachedAppearance?.name != name {
                cachedAppearance = NSAppearance(named: name)
            }
            return cachedAppearance
        }
    }
}

/// Unified Material 3 + macOS frosted glass surface background.
/// Layers the behind-window `VisualEffectBlur` (Liquid Glass on macOS 26+) underneath
/// the theme tonal tint, preventing dark desktop wallpapers from turning Light Mode
/// surfaces muddy gray. Glass is used when `forceGlass` is set or the surface's own
/// opacity requests translucency — never merely because the bar is transparent.
public struct GlassSurfaceBackground: View {
    public var baseColor: Color?
    public var opacity: Double?
    public var forceGlass: Bool
    public var material: NSVisualEffectView.Material

    @ObservedObject private var theme = ThemeStore.shared

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
        return theme.isLightMode
            ? Color(hex: theme.palette.surfaceContainerLowest.hex)
            : Color(hex: theme.palette.surfaceContainer.hex)
    }

    private var resolvedTintColor: Color {
        Color(hex: theme.palette.primary.hex)
    }

    private var slider: Double {
        let raw = opacity ?? min(theme.surfaceTokens.popupTransparency, theme.surfaceTokens.surfaceOpacity)
        return max(0.0, min(1.0, raw))
    }

    public var body: some View {
        let s = slider
        let isGlassActive = forceGlass || s < 0.999
        Group {
            if s <= 0.005 {
                Color.clear
            } else if isGlassActive {
                ZStack {
                    // The blur effect itself scales with slider opacity down to 0
                    VisualEffectBlur(
                        material: theme.isLightMode ? .popover : material,
                        blendingMode: .behindWindow
                    )
                    .opacity(min(1.0, s / 0.35))

                    if theme.isLightMode {
                        // Luminosity lift keeps Light Mode frosted glass bright and crisp over
                        // dark wallpapers, smoothly scaling to zero when the slider reaches 0.
                        let whiteLift = forceGlass ? (s * 0.40) : (s * 0.42)
                        let tintAlpha = forceGlass ? (s * 0.65) : min(0.94, s * 0.90)
                        Color.white.opacity(whiteLift)
                        resolvedBaseColor.opacity(tintAlpha)
                        resolvedTintColor.opacity(0.08 * s)

                        // Subtle top-to-bottom glass sheen scaled with slider
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.32 * s),
                                Color.white.opacity(0.04 * s)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        let tintAlpha = forceGlass ? (s * 0.72) : s
                        resolvedBaseColor.opacity(tintAlpha)
                        resolvedTintColor.opacity(0.06 * s)

                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.07 * s),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
            } else {
                resolvedBaseColor.opacity(s)
            }
        }
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
