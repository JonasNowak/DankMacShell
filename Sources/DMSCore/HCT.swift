import Foundation
@_exported import DankThemeEngine

/// Material Design 3 HCT (Hue, Chroma, Tone) color coordinates.
/// All CAM16 math is delegated to the Rust-backed `DankThemeEngine` `HCTMath`.
public struct HCT: Sendable, Equatable, Hashable {
    public var hue: Double      // 0 .. 360
    public var chroma: Double   // 0 .. ~130
    public var tone: Double     // 0 .. 100

    public init(hue: Double, chroma: Double, tone: Double) {
        self.hue = HCTMath.sanitizeDegrees(hue)
        self.chroma = max(0.0, chroma)
        self.tone = min(100.0, max(0.0, tone))
    }

    /// Converts an RGB M3Color to HCT coordinates.
    public static func from(color: M3Color) -> HCT {
        if let hct = try? HCTMath.fromHex(color.hex) {
            return HCT(hue: hct.hue, chroma: hct.chroma, tone: hct.tone)
        }
        return HCT(hue: 0, chroma: 0, tone: 0)
    }

    /// Converts HCT coordinates to an RGB M3Color using the engine's CAM16 solver.
    public func toColor() -> M3Color {
        HCT.solve(hue: hue, chroma: chroma, tone: tone)
    }

    /// Direct CAM16 solver helper.
    public static func solve(hue: Double, chroma: Double, tone: Double) -> M3Color {
        if let color = try? HCTMath.solve(hue: hue, chroma: chroma, tone: tone) {
            return M3Color(color)
        }
        return M3Color("#000000")
    }
}

/// Scalar HCT / WCAG `M3Color` overloads extending `DankThemeEngine`'s `HCTMath`
/// (Rust CAM16 over the FFI). The local CAM16 matrices, critical planes, and
/// Lab math were removed in the DankThemeEngine migration.
public extension HCTMath {

    /// Converts RGB components (0..1) to an HCT tuple (hue, chroma, tone).
    static func toHct(r: Double, g: Double, b: Double) -> (hue: Double, chroma: Double, tone: Double) {
        let hex = M3Color.from(r: r, g: g, b: b).hex
        if let hct = try? HCTMath.fromHex(hex) {
            return (hue: hct.hue, chroma: hct.chroma, tone: hct.tone)
        }
        return (hue: 0, chroma: 0, tone: 0)
    }

    /// Converts HCT (Hue, Chroma, Tone) to an RGB M3Color.
    static func fromHct(hue: Double, chroma: Double, tone: Double) -> M3Color {
        HCT.solve(hue: hue, chroma: chroma, tone: tone)
    }

    /// Mixing formula matching upstream Tonal.js softContainer().
    static func softContainer(accent: M3Color, card: M3Color, tint: Double) -> M3Color {
        if let color = try? HCTMath.softContainer(
            accent: accent.hex,
            card: card.hex,
            tint: tint
        ) {
            return M3Color(color)
        }
        return accent
    }

    /// Linear relative luminance per WCAG 2.1.
    static func relativeLuminance(_ c: M3Color) -> Double {
        HCTMath.relativeLuminance(c.hex)
    }

    /// WCAG contrast ratio between two colors (1.0 to 21.0).
    static func contrastRatio(_ a: M3Color, _ b: M3Color) -> Double {
        HCTMath.contrastRatio(a.hex, b.hex)
    }

    /// Linear interpolation between two RGB colors.
    static func mix(_ c1: M3Color, _ c2: M3Color, amount: Double) -> M3Color {
        if let color = try? HCTMath.mix(c1.hex, c2.hex, amount: amount) {
            return M3Color(color)
        }
        return c1
    }

    /// Picks the first candidate meeting `target` contrast against `background`,
    /// else the highest-contrast candidate.
    static func readableOn(background: M3Color, candidates: [M3Color], target: Double = 4.5) -> M3Color {
        guard let first = candidates.first else { return background }
        var best = first
        for candidate in candidates {
            let current = contrastRatio(candidate, background)
            if current >= target { return candidate }
            if current > contrastRatio(best, background) {
                best = candidate
            }
        }
        return best
    }
}
