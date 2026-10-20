import Foundation

/// Material Design 3 corner radius tokens and strength scaling (`Shape.js` — `THEME-001`, `THEME-002`).
public struct M3ShapeTokens: Sendable, Codable, Equatable {
    public var strength: Int // 0 to 100, default 50 = 1.0x
    public var fixedRadius: Double // < 0 means use scaled tokens

    public init(strength: Int = 50, fixedRadius: Double = -1.0) {
        self.strength = min(100, max(0, strength))
        self.fixedRadius = fixedRadius
    }

    /// Scale multiplier derived from `strength` (`scale = normalizeStrength(strength) / 50.0`).
    public var scale: Double {
        Double(min(100, max(0, strength))) / 50.0
    }

    public func scaled(_ base: Double) -> Double {
        if fixedRadius >= 0 {
            return fixedRadius
        }
        return round(base * scale * 100.0) / 100.0
    }

    public var xxs: Double { scaled(2.0) }
    public var xs: Double { scaled(4.0) }
    public var s: Double { scaled(8.0) }
    public var m: Double { scaled(12.0) }
    public var l: Double { scaled(16.0) }
    public var lIncreased: Double { scaled(20.0) }
    public var xl: Double { scaled(28.0) }
    public var xlIncreased: Double { scaled(32.0) }
    public var xxl: Double { scaled(48.0) }
    public var full: Double { fixedRadius >= 0 ? fixedRadius : 9999.0 }
}

/// Material Design 3 cubic Bezier spline control points (`Anims.qml` — `THEME-004`).
public struct M3BezierCurve: Sendable, Codable, Equatable {
    public let name: String
    public let controlPoints: [Double]

    public var c1x: Double { controlPoints.count >= 4 ? controlPoints[0] : 0.2 }
    public var c1y: Double { controlPoints.count >= 4 ? controlPoints[1] : 0.0 }
    public var c2x: Double { controlPoints.count >= 4 ? controlPoints[2] : 0.0 }
    public var c2y: Double { controlPoints.count >= 4 ? controlPoints[3] : 1.0 }

    public init(name: String, controlPoints: [Double]) {
        self.name = name
        self.controlPoints = controlPoints
    }

    public static let emphasized = M3BezierCurve(
        name: "emphasized",
        controlPoints: [0.05, 0.0, 0.133333, 0.06, 0.166667, 0.4, 0.208333, 0.82, 0.25, 1.0, 1.0, 1.0]
    )
    public static let emphasizedDecel = M3BezierCurve(
        name: "emphasizedDecel",
        controlPoints: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    )
    public static let emphasizedAccel = M3BezierCurve(
        name: "emphasizedAccel",
        controlPoints: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    )
    public static let standard = M3BezierCurve(
        name: "standard",
        controlPoints: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    )
    public static let standardDecel = M3BezierCurve(
        name: "standardDecel",
        controlPoints: [0.0, 0.0, 0.0, 1.0, 1.0, 1.0]
    )
    public static let standardAccel = M3BezierCurve(
        name: "standardAccel",
        controlPoints: [0.3, 0.0, 1.0, 1.0, 1.0, 1.0]
    )
}

/// Material Design 3 motion durations and spring constants (`Anims.qml` — `THEME-003`, `THEME-004`).
public struct M3MotionTokens: Sendable, Codable, Equatable {
    public var animationSpeed: Double // 0.1 to 3.0, default 1.0
    public var reducedMotion: Bool

    public init(animationSpeed: Double = 1.0, reducedMotion: Bool = false) {
        self.animationSpeed = max(0.0, min(3.0, animationSpeed))
        self.reducedMotion = reducedMotion
    }

    private func scaleDuration(_ baseSeconds: Double) -> Double {
        if reducedMotion || animationSpeed <= 0.01 {
            return 0.0
        }
        return baseSeconds / animationSpeed
    }

    /// 200ms base duration
    public var durShort: Double { scaleDuration(0.200) }
    /// 450ms base duration
    public var durMed: Double { scaleDuration(0.450) }
    /// 600ms base duration
    public var durLong: Double { scaleDuration(0.600) }
    /// 180ms settings navigation duration
    public var settingsNavigationStateDuration: Double { scaleDuration(0.180) }
    /// 200ms settings ripple duration
    public var settingsNavigationRippleDuration: Double { scaleDuration(0.200) }
    /// 80px slide translation distance
    public var slidePx: Double { reducedMotion ? 0.0 : 80.0 }
}

/// Material Design 3 typography hierarchy and scaling (`Fonts.qml` — `THEME-007`).
public struct M3TypographyTokens: Sendable, Codable, Equatable {
    public var fontFamilyUI: String
    public var fontFamilyMono: String
    public var fontFamilyDisplay: String
    public var fontFamilyHand: String
    public var fontFamilyStylistic: String
    public var fontFamilySymbols: String
    public var fontScale: Double

    public init(
        fontFamilyUI: String = "Google Sans Flex",
        fontFamilyMono: String = "Fira Code",
        fontFamilyDisplay: String = "DM Serif Display",
        fontFamilyHand: String = "Gochi Hand",
        fontFamilyStylistic: String = "Notable",
        fontFamilySymbols: String = "Material Symbols Rounded",
        fontScale: Double = 1.0
    ) {
        self.fontFamilyUI = fontFamilyUI
        self.fontFamilyMono = fontFamilyMono
        self.fontFamilyDisplay = fontFamilyDisplay
        self.fontFamilyHand = fontFamilyHand
        self.fontFamilyStylistic = fontFamilyStylistic
        self.fontFamilySymbols = fontFamilySymbols
        self.fontScale = max(0.75, min(1.5, fontScale))
    }

    public func scaledSize(_ basePt: Double) -> Double {
        round(basePt * fontScale * 10.0) / 10.0
    }
}

/// Surface glassmorphism, opacity, blur, and border customization (`ThemeSurfacesTab.qml`).
public struct M3SurfaceTokens: Sendable, Codable, Equatable {
    public var surfaceOpacity: Double // 0.0 .. 1.0 (default 0.85)
    public var popupTransparency: Double // 0.0 .. 1.0 (default 0.92)
    public var floatingWindowTransparency: Double // 0.0 .. 1.0 (default 0.90)
    public var blurRadius: Int // 0 .. 64 (default 24)
    public var borderWidth: Double // 0.0 .. 4.0 (default 1.0)
    public var outlineOpacity: Double // 0.0 .. 1.0 (default 0.12)

    public init(
        surfaceOpacity: Double = 0.85,
        popupTransparency: Double = 0.92,
        floatingWindowTransparency: Double = 0.90,
        blurRadius: Int = 24,
        borderWidth: Double = 1.0,
        outlineOpacity: Double = 0.12
    ) {
        self.surfaceOpacity = max(0.1, min(1.0, surfaceOpacity))
        self.popupTransparency = max(0.1, min(1.0, popupTransparency))
        self.floatingWindowTransparency = max(0.1, min(1.0, floatingWindowTransparency))
        self.blurRadius = max(0, min(64, blurRadius))
        self.borderWidth = max(0.0, min(4.0, borderWidth))
        self.outlineOpacity = max(0.0, min(1.0, outlineOpacity))
    }
}

/// Elevation shadow customization (`ShadowsTab.qml`).
public struct M3ShadowTokens: Sendable, Codable, Equatable {
    public var enabled: Bool
    public var blurRadius: Double // default 24.0
    public var offsetY: Double // default 8.0
    public var opacity: Double // default 0.35
    public var colorHex: String // default "#000000"

    public init(
        enabled: Bool = true,
        blurRadius: Double = 24.0,
        offsetY: Double = 8.0,
        opacity: Double = 0.35,
        colorHex: String = "#000000"
    ) {
        self.enabled = enabled
        self.blurRadius = max(0.0, min(80.0, blurRadius))
        self.offsetY = max(-24.0, min(32.0, offsetY))
        self.opacity = max(0.0, min(1.0, opacity))
        self.colorHex = colorHex
    }
}

/// 13-tone Material Design 3 Tonal Palette (`0, 10, 20, 25, 30, 40, 50, 60, 70, 80, 90, 95, 98, 100`).
public struct M3TonalPalette: Sendable, Codable, Equatable {
    public static let standardTones: [Int] = [0, 10, 20, 25, 30, 40, 50, 60, 70, 80, 90, 95, 98, 100]

    public let hue: Double
    public let chroma: Double
    public let swatches: [Int: M3Color]

    public init(hue: Double, chroma: Double) {
        self.hue = hue
        self.chroma = chroma
        var map: [Int: M3Color] = [:]
        for t in Self.standardTones {
            map[t] = HCT.solve(hue: hue, chroma: chroma, tone: Double(t))
        }
        self.swatches = map
    }

    public func tone(_ t: Int) -> M3Color {
        if let existing = swatches[t] {
            return existing
        }
        return HCT.solve(hue: hue, chroma: chroma, tone: Double(max(0, min(100, t))))
    }
}

/// Matugen scheme algorithm variants (`01-theme.md §4`).
public enum MatugenScheme: String, Sendable, Codable, CaseIterable {
    case tonalSpot = "scheme-tonal-spot"
    case vibrant = "scheme-vibrant"
    case expressive = "scheme-expressive"
    case fidelity = "scheme-fidelity"
    case monochrome = "scheme-monochrome"
    case neutral = "scheme-neutral"

    public var displayName: String {
        switch self {
        case .tonalSpot: return "Tonal Spot (Default)"
        case .vibrant: return "Vibrant"
        case .expressive: return "Expressive"
        case .fidelity: return "Fidelity"
        case .monochrome: return "Monochrome"
        case .neutral: return "Neutral"
        }
    }
}

/// Dynamic 16-color ANSI terminal palette (`core/internal/dank16/` — `01-theme.md §1.5`).
public struct Dank16Palette: Sendable, Codable, Equatable {
    public let colors: [M3Color] // 16 ANSI colors (0..15)
    public let background: M3Color
    public let foreground: M3Color
    public let cursor: M3Color

    public init(colors: [M3Color], background: M3Color, foreground: M3Color, cursor: M3Color) {
        self.colors = colors
        self.background = background
        self.foreground = foreground
        self.cursor = cursor
    }
}

public enum Dank16Generator: Sendable {
    /// Generates a 16-color ANSI palette derived from a `ThemePalette`.
    public static func generate(from palette: ThemePalette) -> Dank16Palette {
        let isDark = palette.isDark
        let normalTone = isDark ? 72.0 : 38.0
        let brightTone = isDark ? 85.0 : 28.0
        let seedHct = HCT.from(color: palette.primary)
        let baseChroma = max(42.0, min(72.0, seedHct.chroma))

        // Standard ANSI hue angles: Red(25), Green(140), Yellow(85), Blue(250), Magenta(315), Cyan(195)
        let ansiHues: [Double] = [25.0, 140.0, 85.0, 250.0, 315.0, 195.0]

        var colors: [M3Color] = []
        // 0: Black
        colors.append(isDark ? palette.surfaceContainerLowest : palette.onSurface)
        // 1..6: Red, Green, Yellow, Blue, Magenta, Cyan
        for h in ansiHues {
            colors.append(HCT.solve(hue: h, chroma: baseChroma, tone: normalTone))
        }
        // 7: White
        colors.append(isDark ? palette.onSurface : palette.surfaceContainerLowest)
        // 8: Bright Black (Gray)
        colors.append(palette.outline)
        // 9..14: Bright Red..Bright Cyan
        for h in ansiHues {
            colors.append(HCT.solve(hue: h, chroma: min(84.0, baseChroma * 1.15), tone: brightTone))
        }
        // 15: Bright White
        colors.append(isDark ? M3Color("#FFFFFF") : M3Color("#000000"))

        return Dank16Palette(
            colors: colors,
            background: palette.surface,
            foreground: palette.onSurface,
            cursor: palette.primary
        )
    }
}
