import Foundation

/// Mathematical generator for Material 3 dynamic color schemes from wallpaper or seed colors.
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

    /// Generates a tone in HSL space for a given base hue and saturation scale.
    public static func toneColor(h: Double, s: Double, tone: Double) -> M3Color {
        // tone is 0..100 (Material 3 tone). Maps roughly to luminance.
        let l = tone / 100.0
        let hsl = HSL(h: h, s: s, l: l)
        let rgb = hsl.toRGB()
        return M3Color.from(r: rgb.r, g: rgb.g, b: rgb.b)
    }

    /// Generates full dark and light ThemePalettes from a seed color.
    public static func generate(from seed: M3Color, name: String = "Dynamic") -> (dark: ThemePalette, light: ThemePalette) {
        let baseHSL = rgbToHSL(r: seed.red, g: seed.green, b: seed.blue)
        let hue = baseHSL.h
        let primarySat = max(0.45, min(0.85, baseHSL.s))
        let secondarySat = max(0.18, primarySat * 0.35)
        let tertiarySat = max(0.35, primarySat * 0.6)
        let neutralSat = max(0.04, min(0.08, baseHSL.s * 0.15))
        let neutralVariantSat = max(0.08, min(0.16, baseHSL.s * 0.25))

        let tertiaryHue = (hue + 60.0).truncatingRemainder(dividingBy: 360.0)

        // Dark Palette
        let dark = ThemePalette(
            name: name,
            isDark: true,
            primary: toneColor(h: hue, s: primarySat, tone: 80),
            onPrimary: toneColor(h: hue, s: primarySat, tone: 20),
            primaryContainer: toneColor(h: hue, s: primarySat, tone: 30),
            onPrimaryContainer: toneColor(h: hue, s: primarySat, tone: 90),
            inversePrimary: toneColor(h: hue, s: primarySat, tone: 40),
            secondary: toneColor(h: hue, s: secondarySat, tone: 80),
            onSecondary: toneColor(h: hue, s: secondarySat, tone: 20),
            secondaryContainer: toneColor(h: hue, s: secondarySat, tone: 30),
            onSecondaryContainer: toneColor(h: hue, s: secondarySat, tone: 90),
            tertiary: toneColor(h: tertiaryHue, s: tertiarySat, tone: 80),
            onTertiary: toneColor(h: tertiaryHue, s: tertiarySat, tone: 20),
            tertiaryContainer: toneColor(h: tertiaryHue, s: tertiarySat, tone: 30),
            onTertiaryContainer: toneColor(h: tertiaryHue, s: tertiarySat, tone: 90),
            surface: toneColor(h: hue, s: neutralSat, tone: 6),
            onSurface: toneColor(h: hue, s: neutralSat, tone: 90),
            surfaceVariant: toneColor(h: hue, s: neutralVariantSat, tone: 30),
            onSurfaceVariant: toneColor(h: hue, s: neutralVariantSat, tone: 80),
            surfaceTint: toneColor(h: hue, s: primarySat, tone: 80),
            surfaceContainerLowest: toneColor(h: hue, s: neutralSat, tone: 4),
            surfaceContainerLow: toneColor(h: hue, s: neutralSat, tone: 10),
            surfaceContainer: toneColor(h: hue, s: neutralSat, tone: 12),
            surfaceContainerHigh: toneColor(h: hue, s: neutralSat, tone: 17),
            surfaceContainerHighest: toneColor(h: hue, s: neutralSat, tone: 22),
            background: toneColor(h: hue, s: neutralSat, tone: 6),
            onBackground: toneColor(h: hue, s: neutralSat, tone: 90),
            outline: toneColor(h: hue, s: neutralVariantSat, tone: 60),
            outlineVariant: toneColor(h: hue, s: neutralVariantSat, tone: 30)
        )

        // Light Palette
        let light = ThemePalette(
            name: name,
            isDark: false,
            primary: toneColor(h: hue, s: primarySat, tone: 40),
            onPrimary: toneColor(h: hue, s: primarySat, tone: 100),
            primaryContainer: toneColor(h: hue, s: primarySat, tone: 90),
            onPrimaryContainer: toneColor(h: hue, s: primarySat, tone: 10),
            inversePrimary: toneColor(h: hue, s: primarySat, tone: 80),
            secondary: toneColor(h: hue, s: secondarySat, tone: 40),
            onSecondary: toneColor(h: hue, s: secondarySat, tone: 100),
            secondaryContainer: toneColor(h: hue, s: secondarySat, tone: 90),
            onSecondaryContainer: toneColor(h: hue, s: secondarySat, tone: 10),
            tertiary: toneColor(h: tertiaryHue, s: tertiarySat, tone: 40),
            onTertiary: toneColor(h: tertiaryHue, s: tertiarySat, tone: 100),
            tertiaryContainer: toneColor(h: tertiaryHue, s: tertiarySat, tone: 90),
            onTertiaryContainer: toneColor(h: tertiaryHue, s: tertiarySat, tone: 10),
            surface: toneColor(h: hue, s: neutralSat, tone: 98),
            onSurface: toneColor(h: hue, s: neutralSat, tone: 10),
            surfaceVariant: toneColor(h: hue, s: neutralVariantSat, tone: 90),
            onSurfaceVariant: toneColor(h: hue, s: neutralVariantSat, tone: 30),
            surfaceTint: toneColor(h: hue, s: primarySat, tone: 40),
            surfaceContainerLowest: toneColor(h: hue, s: neutralSat, tone: 100),
            surfaceContainerLow: toneColor(h: hue, s: neutralSat, tone: 96),
            surfaceContainer: toneColor(h: hue, s: neutralSat, tone: 94),
            surfaceContainerHigh: toneColor(h: hue, s: neutralSat, tone: 92),
            surfaceContainerHighest: toneColor(h: hue, s: neutralSat, tone: 90),
            background: toneColor(h: hue, s: neutralSat, tone: 98),
            onBackground: toneColor(h: hue, s: neutralSat, tone: 10),
            outline: toneColor(h: hue, s: neutralVariantSat, tone: 50),
            outlineVariant: toneColor(h: hue, s: neutralVariantSat, tone: 80)
        )

        return (dark, light)
    }
}
