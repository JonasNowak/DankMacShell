import Foundation
import DankThemeEngine

/// Contrast mode adjustment levels complying with WCAG AAA accessibility.
public enum ContrastLevel: Double, Sendable, Codable, CaseIterable {
    case standard = 0.0
    case medium = 0.3
    case high = 0.6
}

public extension ContrastLevel {
    /// Converts to the `DankThemeEngine` contrast enum.
    var dteContrast: DTEContrast {
        switch self {
        case .standard: return .standard
        case .medium: return .medium
        case .high: return .high
        }
    }

    /// Creates a contrast level from a `DankThemeEngine` contrast enum.
    init(dte: DTEContrast) {
        switch dte {
        case .standard: self = .standard
        case .medium: self = .medium
        case .high: self = .high
        }
    }
}

/// Mathematical generator for Material 3 dynamic color schemes from wallpaper or seed colors.
/// Palette assembly, Matugen scheme parameters, and tone mapping are delegated to the
/// Rust-backed `DankThemeEngine.generateDynamicTheme(...)`; only the lightweight HSL
/// helpers (used by `ColorPickerService`) remain local.
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

    /// HSL components to RGB components (0..1).
    public static func hslToRGB(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
        HSL(h: h, s: s, l: l).toRGB()
    }

    /// Generates a tone in HCT space for a given base hue and chroma.
    public static func toneColor(h: Double, c: Double, tone: Double) -> M3Color {
        return HCT.solve(hue: h, chroma: c, tone: tone)
    }

    /// Generates full dark and light ThemePalettes from a seed color via the
    /// Rust-backed `DankThemeEngine.generateDynamicTheme(...)`.
    public static func generate(
        from seed: M3Color,
        name: String = "Dynamic",
        contrast: ContrastLevel = .standard,
        scheme: MatugenScheme = .tonalSpot
    ) -> (dark: ThemePalette, light: ThemePalette) {
        if let pair = try? DankThemeEngine.generateDynamicTheme(
            seedHex: seed.hex,
            name: name,
            contrast: contrast.dteContrast,
            scheme: scheme.dteScheme
        ) {
            return (ThemePalette(dte: pair.dark), ThemePalette(dte: pair.light))
        }
        return (
            StockThemes.theme(named: "purple", isDark: true),
            StockThemes.theme(named: "purple", isDark: false)
        )
    }

    /// Derives soft container color using the engine's upstream Tonal.js algorithm.
    public static func softContainer(accent: M3Color, card: M3Color, tint: Double = 0.5) -> M3Color {
        HCTMath.softContainer(accent: accent, card: card, tint: tint)
    }
}
