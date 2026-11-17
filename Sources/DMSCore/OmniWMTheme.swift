import Foundation
import DankThemeEngine

/// Defines how DankMacShell derives the two colors for OmniWM's active window border gradient.
public enum OmniWMGradientMode: String, Codable, CaseIterable, Sendable {
    /// Primary dominant brand color to Tertiary harmonic accent (M3 Expressive +60°/+120° HCT rotation).
    case expressive = "expressive"
    /// Primary dominant color to Secondary analogous tone within the same hue family.
    case analogous = "analogous"
    /// PrimaryContainer ambient shadow to Primary high-luminance highlight (simulates directional top-left illumination).
    case luminance = "luminance"
    /// Top 2 distinct dominant color clusters extracted directly from the active desktop wallpaper.
    case dualWallpaper = "dualWallpaper"
    /// Disables gradient (`borders.gradient.enabled = false`) and applies solid primary border.
    case solid = "solid"

    public var displayName: String {
        switch self {
        case .expressive: return "Expressive (Primary → Tertiary)"
        case .analogous: return "Analogous (Primary → Secondary)"
        case .luminance: return "Luminance (Container → Primary)"
        case .dualWallpaper: return "Dual Wallpaper Seeds"
        case .solid: return "Solid Accent"
        }
    }

    public var subtitle: String {
        switch self {
        case .expressive: return "Vibrant, high-contrast iridescent flow matching M3 Expressive"
        case .analogous: return "Subtle, smooth monochromatic tonal transition"
        case .luminance: return "Directional lighting effect (ambient shadow to highlight)"
        case .dualWallpaper: return "Two dominant color clusters extracted from the wallpaper"
        case .solid: return "Single solid primary border (gradient disabled)"
        }
    }
}

public extension OmniWMGradientMode {
    /// Converts to the `DankThemeEngine` gradient mode (identical raw values).
    var dteMode: DTEOmniWMGradientMode { DTEOmniWMGradientMode(rawValue: rawValue) ?? .expressive }

    /// Creates a mode from a `DankThemeEngine` gradient mode.
    init(dte: DTEOmniWMGradientMode) {
        self = OmniWMGradientMode(rawValue: dte.rawValue) ?? .expressive
    }
}

/// OmniWM window border gradient direction.
public enum OmniWMGradientDirection: String, Codable, CaseIterable, Sendable {
    case topLeftToBottomRight = "topLeftToBottomRight"
    case topRightToBottomLeft = "topRightToBottomLeft"

    public var displayName: String {
        switch self {
        case .topLeftToBottomRight: return "Top-Left ↘ Bottom-Right"
        case .topRightToBottomLeft: return "Top-Right ↙ Bottom-Left"
        }
    }
}

public extension OmniWMGradientDirection {
    /// Converts to the `DankThemeEngine` gradient direction (identical raw values).
    var dteDirection: DTEOmniWMGradientDirection { DTEOmniWMGradientDirection(rawValue: rawValue) ?? .topLeftToBottomRight }

    /// Creates a direction from a `DankThemeEngine` gradient direction.
    init(dte: DTEOmniWMGradientDirection) {
        self = OmniWMGradientDirection(rawValue: dte.rawValue) ?? .topLeftToBottomRight
    }
}

/// Pure updater for OmniWM `settings.toml`. The TOML parser/writer and gradient
/// resolution are delegated to the Rust-backed `DankThemeEngine.updateOmniWMToml(...)`.
public struct OmniWMThemeUpdater: Sendable {

    /// Derives the start and end colors for the gradient given the current palette and mode.
    /// Field selection only — exact parity with the engine's `resolve_colors`.
    public static func resolveColors(
        palette: ThemePalette,
        secondarySeed: M3Color? = nil,
        mode: OmniWMGradientMode
    ) -> (start: M3Color, end: M3Color, solid: M3Color, isGradient: Bool) {
        switch mode {
        case .expressive:
            return (start: palette.primary, end: palette.tertiary, solid: palette.primary, isGradient: true)
        case .analogous:
            return (start: palette.primary, end: palette.secondary, solid: palette.primary, isGradient: true)
        case .luminance:
            return (start: palette.primaryContainer, end: palette.primary, solid: palette.primary, isGradient: true)
        case .dualWallpaper:
            let endColor = secondarySeed ?? palette.tertiary
            return (start: palette.primary, end: endColor, solid: palette.primary, isGradient: true)
        case .solid:
            return (start: palette.primary, end: palette.primary, solid: palette.primary, isGradient: false)
        }
    }

    /// Surgically updates the theme-bearing sections in `settings.toml` without mutating any hotkeys, routing, or comments.
    /// Delegates to `DankThemeEngine.updateOmniWMToml(...)`; on engine failure the input is returned unchanged.
    public static func applyTheme(
        to tomlContent: String,
        palette: ThemePalette,
        secondarySeed: M3Color? = nil,
        mode: OmniWMGradientMode = .expressive,
        direction: OmniWMGradientDirection = .topLeftToBottomRight,
        syncOverview: Bool = true,
        syncWorkspaceBar: Bool = true
    ) -> String {
        let config = DTEOmniWMConfig(
            mode: mode.dteMode,
            direction: direction.dteDirection,
            syncOverview: syncOverview,
            syncWorkspaceBar: syncWorkspaceBar,
            secondarySeed: secondarySeed?.hex
        )
        if let updated = try? DankThemeEngine.updateOmniWMToml(
            tomlContent,
            palette: palette.dtePalette,
            config: config
        ) {
            return updated
        }
        return tomlContent
    }
}
