import Foundation

/// Contrast mode adjustment levels complying with WCAG AAA accessibility.
public enum ContrastLevel: Double, Sendable, Codable, CaseIterable {
    case standard = 0.0
    case medium = 0.3
    case high = 0.6
}

/// Mathematical generator for Material 3 dynamic color schemes from wallpaper or seed colors.
/// Strictly implements Google's Material Design 3 HCT / CAM16 color space specifications.
public struct DynamicThemeGenerator: Sendable {

    public struct HSL: Sendable, Equatable {
        public var h: Double // 0 .. 360
        public var s: Double // 0 .. 1
        public var l: Double // 0 .. 1

        public init(h: Double, s: Double, l: Double) {
            self.h = h.truncatingRemainder(dividingBy: 360)
            if self.h < 0 { self.h += 360 }
            self.s = min(1.0, max(0.0, s))
            self.l = min(1.0, max(0.0, l))
        }

        public func toRGB() -> (r: Double, g: Double, b: Double) {
            if s == 0 {
                return (l, l, l)
            }
            let q = l < 0.5 ? l * (1.0 + s) : l + s - (l * s)
            let p = 2.0 * l - q
            let hk = h / 360.0

            let tr = hk + (1.0 / 3.0)
            let tg = hk
            let tb = hk - (1.0 / 3.0)

            return (
                colorComponent(p: p, q: q, t: tr),
                colorComponent(p: p, q: q, t: tg),
                colorComponent(p: p, q: q, t: tb)
            )
        }

        private func colorComponent(p: Double, q: Double, t: Double) -> Double {
            var tc = t
            if tc < 0 { tc += 1.0 }
            if tc > 1 { tc -= 1.0 }
            if tc < (1.0 / 6.0) { return p + ((q - p) * 6.0 * tc) }
            if tc < 0.5 { return q }
            if tc < (2.0 / 3.0) { return p + ((q - p) * ((2.0 / 3.0) - tc) * 6.0) }
            return p
        }
    }

    public static func rgbToHSL(r: Double, g: Double, b: Double) -> HSL {
        let maxV = max(r, max(g, b))
        let minV = min(r, min(g, b))
        let delta = maxV - minV
        let l = (maxV + minV) / 2.0

        if delta == 0 {
            return HSL(h: 0, s: 0, l: l)
        }

        let s = l > 0.5 ? delta / (2.0 - maxV - minV) : delta / (maxV + minV)
        var h: Double = 0
        if maxV == r {
            h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxV == g {
            h = ((b - r) / delta) + 2.0
        } else {
            h = ((r - g) / delta) + 4.0
        }
        h *= 60.0
        if h < 0 { h += 360.0 }
        return HSL(h: h, s: s, l: l)
    }

    /// Generates a tone in HCT space for a given base hue and chroma.
    public static func toneColor(h: Double, c: Double, tone: Double) -> M3Color {
        return HCT.solve(hue: h, chroma: c, tone: tone)
    }

    /// Adjusts tone according to WCAG contrast mode.
    private static func adjustTone(base: Double, contrast: ContrastLevel, isDark: Bool, isForeground: Bool) -> Double {
        let delta = contrast.rawValue * 15.0
        if isDark {
            if isForeground {
                return min(100.0, base + delta)
            } else {
                return max(0.0, base - delta * 0.5)
            }
        } else {
            if isForeground {
                return max(0.0, base - delta)
            } else {
                return min(100.0, base + delta * 0.5)
            }
        }
    }

    /// Returns the 5 M3 13-tone palettes (Primary, Secondary, Tertiary, Neutral, NeutralVariant) for a seed color and Matugen scheme.
    public static func tonalPalettes(
        from seed: M3Color,
        scheme: MatugenScheme = .tonalSpot
    ) -> (
        primary: M3TonalPalette,
        secondary: M3TonalPalette,
        tertiary: M3TonalPalette,
        neutral: M3TonalPalette,
        neutralVariant: M3TonalPalette
    ) {
        let params = resolveSchemeParameters(from: seed, scheme: scheme)
        return (
            primary: M3TonalPalette(hue: params.primaryHue, chroma: params.primaryChroma),
            secondary: M3TonalPalette(hue: params.secondaryHue, chroma: params.secondaryChroma),
            tertiary: M3TonalPalette(hue: params.tertiaryHue, chroma: params.tertiaryChroma),
            neutral: M3TonalPalette(hue: params.primaryHue, chroma: params.neutralChroma),
            neutralVariant: M3TonalPalette(hue: params.primaryHue, chroma: params.neutralVariantChroma)
        )
    }

    private struct SchemeParams {
        let primaryHue: Double
        let secondaryHue: Double
        let tertiaryHue: Double
        let primaryChroma: Double
        let secondaryChroma: Double
        let tertiaryChroma: Double
        let neutralChroma: Double
        let neutralVariantChroma: Double
    }

    private static func resolveSchemeParameters(from seed: M3Color, scheme: MatugenScheme) -> SchemeParams {
        let seedHct = HCT.from(color: seed)
        let hue = seedHct.hue
        let sourceChroma = seedHct.chroma

        switch scheme {
        case .monochrome:
            return SchemeParams(
                primaryHue: hue,
                secondaryHue: hue,
                tertiaryHue: hue,
                primaryChroma: 0.0,
                secondaryChroma: 0.0,
                tertiaryChroma: 0.0,
                neutralChroma: 0.0,
                neutralVariantChroma: 0.0
            )
        case .neutral:
            return SchemeParams(
                primaryHue: hue,
                secondaryHue: hue,
                tertiaryHue: hue,
                primaryChroma: 12.0,
                secondaryChroma: 8.0,
                tertiaryChroma: 16.0,
                neutralChroma: 2.0,
                neutralVariantChroma: 2.0
            )
        case .vibrant:
            return SchemeParams(
                primaryHue: hue,
                secondaryHue: HCTMath.sanitizeDegrees(hue + 18.0),
                tertiaryHue: HCTMath.sanitizeDegrees(hue + 35.0),
                primaryChroma: max(76.0, sourceChroma * 1.25),
                secondaryChroma: 28.0,
                tertiaryChroma: 36.0,
                neutralChroma: 10.0,
                neutralVariantChroma: 14.0
            )
        case .expressive:
            return SchemeParams(
                primaryHue: HCTMath.sanitizeDegrees(hue + 240.0),
                secondaryHue: HCTMath.sanitizeDegrees(hue + 45.0),
                tertiaryHue: HCTMath.sanitizeDegrees(hue + 120.0),
                primaryChroma: 40.0,
                secondaryChroma: 24.0,
                tertiaryChroma: 32.0,
                neutralChroma: 8.0,
                neutralVariantChroma: 12.0
            )
        case .fidelity:
            return SchemeParams(
                primaryHue: hue,
                secondaryHue: hue,
                tertiaryHue: HCTMath.sanitizeDegrees(hue + 60.0),
                primaryChroma: max(32.0, sourceChroma),
                secondaryChroma: max(12.0, sourceChroma * 0.35),
                tertiaryChroma: max(20.0, sourceChroma * 0.55),
                neutralChroma: min(8.0, max(2.0, sourceChroma * 0.08)),
                neutralVariantChroma: min(14.0, max(4.0, sourceChroma * 0.16))
            )
        case .tonalSpot:
            let pChroma = max(48.0, sourceChroma)
            return SchemeParams(
                primaryHue: hue,
                secondaryHue: hue,
                tertiaryHue: HCTMath.sanitizeDegrees(hue + 60.0),
                primaryChroma: pChroma,
                secondaryChroma: max(16.0, pChroma * 0.35),
                tertiaryChroma: max(24.0, pChroma * 0.6),
                neutralChroma: min(6.0, max(2.0, sourceChroma * 0.08)),
                neutralVariantChroma: min(12.0, max(4.0, sourceChroma * 0.16))
            )
        }
    }

    /// Generates full dark and light ThemePalettes from a seed color using CAM16/HCT math, Matugen scheme, and contrast modes.
    public static func generate(
        from seed: M3Color,
        name: String = "Dynamic",
        contrast: ContrastLevel = .standard,
        scheme: MatugenScheme = .tonalSpot
    ) -> (dark: ThemePalette, light: ThemePalette) {
        let params = resolveSchemeParameters(from: seed, scheme: scheme)
        let hue = params.primaryHue
        let secHue = params.secondaryHue
        let tertiaryHue = params.tertiaryHue
        let primaryChroma = params.primaryChroma
        let secondaryChroma = params.secondaryChroma
        let tertiaryChroma = params.tertiaryChroma
        let neutralChroma = params.neutralChroma
        let neutralVariantChroma = params.neutralVariantChroma

        let errorHue = 25.0
        let errorChroma = 84.0

        // Tone helper for Dark mode
        func darkTone(h: Double, c: Double, t: Double, fg: Bool = true) -> M3Color {
            let adjusted = adjustTone(base: t, contrast: contrast, isDark: true, isForeground: fg)
            return HCT.solve(hue: h, chroma: c, tone: adjusted)
        }

        // Tone helper for Light mode
        func lightTone(h: Double, c: Double, t: Double, fg: Bool = true) -> M3Color {
            let adjusted = adjustTone(base: t, contrast: contrast, isDark: false, isForeground: fg)
            return HCT.solve(hue: h, chroma: c, tone: adjusted)
        }

        // Dark Palette
        let darkSurface = darkTone(h: hue, c: neutralChroma, t: 6, fg: false)
        let darkPrimary = darkTone(h: hue, c: primaryChroma, t: 80, fg: true)
        let dark = ThemePalette(
            name: name,
            isDark: true,
            primary: darkPrimary,
            onPrimary: darkTone(h: hue, c: primaryChroma, t: 20, fg: true),
            primaryContainer: darkTone(h: hue, c: primaryChroma, t: 30, fg: false),
            onPrimaryContainer: darkTone(h: hue, c: primaryChroma, t: 90, fg: true),
            inversePrimary: darkTone(h: hue, c: primaryChroma, t: 40, fg: true),
            secondary: darkTone(h: secHue, c: secondaryChroma, t: 80, fg: true),
            onSecondary: darkTone(h: secHue, c: secondaryChroma, t: 20, fg: true),
            secondaryContainer: darkTone(h: secHue, c: secondaryChroma, t: 30, fg: false),
            onSecondaryContainer: darkTone(h: secHue, c: secondaryChroma, t: 90, fg: true),
            tertiary: darkTone(h: tertiaryHue, c: tertiaryChroma, t: 80, fg: true),
            onTertiary: darkTone(h: tertiaryHue, c: tertiaryChroma, t: 20, fg: true),
            tertiaryContainer: darkTone(h: tertiaryHue, c: tertiaryChroma, t: 30, fg: false),
            onTertiaryContainer: darkTone(h: tertiaryHue, c: tertiaryChroma, t: 90, fg: true),
            surface: darkSurface,
            onSurface: darkTone(h: hue, c: neutralChroma, t: 90, fg: true),
            surfaceVariant: darkTone(h: hue, c: neutralVariantChroma, t: 30, fg: false),
            onSurfaceVariant: darkTone(h: hue, c: neutralVariantChroma, t: 80, fg: true),
            surfaceTint: darkPrimary,
            surfaceContainerLowest: darkTone(h: hue, c: neutralChroma, t: 4, fg: false),
            surfaceContainerLow: darkTone(h: hue, c: neutralChroma, t: 10, fg: false),
            surfaceContainer: darkTone(h: hue, c: neutralChroma, t: 12, fg: false),
            surfaceContainerHigh: darkTone(h: hue, c: neutralChroma, t: 17, fg: false),
            surfaceContainerHighest: darkTone(h: hue, c: neutralChroma, t: 22, fg: false),
            background: darkSurface,
            onBackground: darkTone(h: hue, c: neutralChroma, t: 90, fg: true),
            outline: darkTone(h: hue, c: neutralVariantChroma, t: 60, fg: true),
            outlineVariant: darkTone(h: hue, c: neutralVariantChroma, t: 30, fg: false),
            error: darkTone(h: errorHue, c: errorChroma, t: 80, fg: true),
            onError: darkTone(h: errorHue, c: errorChroma, t: 20, fg: true),
            errorContainer: darkTone(h: errorHue, c: errorChroma, t: 30, fg: false),
            onErrorContainer: darkTone(h: errorHue, c: errorChroma, t: 90, fg: true),
            warning: darkTone(h: 70.0, c: 45.0, t: 80, fg: true),
            onWarning: darkTone(h: 70.0, c: 45.0, t: 20, fg: true),
            warningContainer: darkTone(h: 70.0, c: 45.0, t: 30, fg: false),
            onWarningContainer: darkTone(h: 70.0, c: 45.0, t: 90, fg: true),
            info: darkTone(h: 240.0, c: 45.0, t: 80, fg: true),
            onInfo: darkTone(h: 240.0, c: 45.0, t: 20, fg: true),
            infoContainer: darkTone(h: 240.0, c: 45.0, t: 30, fg: false),
            onInfoContainer: darkTone(h: 240.0, c: 45.0, t: 90, fg: true),
            success: darkTone(h: 140.0, c: 45.0, t: 80, fg: true),
            onSuccess: darkTone(h: 140.0, c: 45.0, t: 20, fg: true),
            successContainer: darkTone(h: 140.0, c: 45.0, t: 30, fg: false),
            onSuccessContainer: darkTone(h: 140.0, c: 45.0, t: 90, fg: true)
        )

        // Light Palette
        let lightSurface = lightTone(h: hue, c: neutralChroma, t: 98, fg: false)
        let lightPrimary = lightTone(h: hue, c: primaryChroma, t: 40, fg: true)
        let light = ThemePalette(
            name: name,
            isDark: false,
            primary: lightPrimary,
            onPrimary: lightTone(h: hue, c: primaryChroma, t: 100, fg: true),
            primaryContainer: lightTone(h: hue, c: primaryChroma, t: 90, fg: false),
            onPrimaryContainer: lightTone(h: hue, c: primaryChroma, t: 10, fg: true),
            inversePrimary: lightTone(h: hue, c: primaryChroma, t: 80, fg: true),
            secondary: lightTone(h: secHue, c: secondaryChroma, t: 40, fg: true),
            onSecondary: lightTone(h: secHue, c: secondaryChroma, t: 100, fg: true),
            secondaryContainer: lightTone(h: secHue, c: secondaryChroma, t: 90, fg: false),
            onSecondaryContainer: lightTone(h: secHue, c: secondaryChroma, t: 10, fg: true),
            tertiary: lightTone(h: tertiaryHue, c: tertiaryChroma, t: 40, fg: true),
            onTertiary: lightTone(h: tertiaryHue, c: tertiaryChroma, t: 100, fg: true),
            tertiaryContainer: lightTone(h: tertiaryHue, c: tertiaryChroma, t: 90, fg: false),
            onTertiaryContainer: lightTone(h: tertiaryHue, c: tertiaryChroma, t: 10, fg: true),
            surface: lightSurface,
            onSurface: lightTone(h: hue, c: neutralChroma, t: 10, fg: true),
            surfaceVariant: lightTone(h: hue, c: neutralVariantChroma, t: 90, fg: false),
            onSurfaceVariant: lightTone(h: hue, c: neutralVariantChroma, t: 30, fg: true),
            surfaceTint: lightPrimary,
            surfaceContainerLowest: lightTone(h: hue, c: neutralChroma, t: 100, fg: false),
            surfaceContainerLow: lightTone(h: hue, c: neutralChroma, t: 96, fg: false),
            surfaceContainer: lightTone(h: hue, c: neutralChroma, t: 94, fg: false),
            surfaceContainerHigh: lightTone(h: hue, c: neutralChroma, t: 92, fg: false),
            surfaceContainerHighest: lightTone(h: hue, c: neutralChroma, t: 90, fg: false),
            background: lightSurface,
            onBackground: lightTone(h: hue, c: neutralChroma, t: 10, fg: true),
            outline: lightTone(h: hue, c: neutralVariantChroma, t: 50, fg: true),
            outlineVariant: lightTone(h: hue, c: neutralVariantChroma, t: 80, fg: false),
            error: lightTone(h: errorHue, c: errorChroma, t: 40, fg: true),
            onError: lightTone(h: errorHue, c: errorChroma, t: 100, fg: true),
            errorContainer: lightTone(h: errorHue, c: errorChroma, t: 90, fg: false),
            onErrorContainer: lightTone(h: errorHue, c: errorChroma, t: 10, fg: true),
            warning: lightTone(h: 70.0, c: 45.0, t: 40, fg: true),
            onWarning: lightTone(h: 70.0, c: 45.0, t: 100, fg: true),
            warningContainer: lightTone(h: 70.0, c: 45.0, t: 90, fg: false),
            onWarningContainer: lightTone(h: 70.0, c: 45.0, t: 10, fg: true),
            info: lightTone(h: 240.0, c: 45.0, t: 40, fg: true),
            onInfo: lightTone(h: 240.0, c: 45.0, t: 100, fg: true),
            infoContainer: lightTone(h: 240.0, c: 45.0, t: 90, fg: false),
            onInfoContainer: lightTone(h: 240.0, c: 45.0, t: 10, fg: true),
            success: lightTone(h: 140.0, c: 45.0, t: 40, fg: true),
            onSuccess: lightTone(h: 140.0, c: 45.0, t: 100, fg: true),
            successContainer: lightTone(h: 140.0, c: 45.0, t: 90, fg: false),
            onSuccessContainer: lightTone(h: 140.0, c: 45.0, t: 10, fg: true)
        )

        return (dark, light)
    }

    /// Derives soft container color using upstream Tonal.js algorithm.
    public static func softContainer(accent: M3Color, card: M3Color, tint: Double = 0.5) -> M3Color {
        return HCTMath.softContainer(accent: accent, card: card, tint: tint)
    }
}
