import Foundation
@_exported import MaterialTokens
import DankThemeEngine

// MARK: - Token type aliases (implementations live in MaterialTokens)

public typealias M3ShapeTokens = MaterialShapeTokens
public typealias M3BezierCurve = MaterialBezierCurve
public typealias M3MotionTokens = MaterialMotionTokens
public typealias M3TypographyTokens = MaterialTypographyTokens
public typealias M3SurfaceTokens = MaterialSurfaceTokens
public typealias M3ShadowTokens = MaterialShadowTokens

/// Matugen scheme algorithm variants (raw values match `DTEScheme`).
public typealias MatugenScheme = MaterialMatugenScheme

public extension MatugenScheme {
    /// Converts to the `DankThemeEngine` scheme enum (identical raw values).
    var dteScheme: DTEScheme { DTEScheme(rawValue: rawValue) ?? .tonalSpot }

    /// Creates a scheme from a `DankThemeEngine` scheme enum.
    init(dte: DTEScheme) {
        self = MatugenScheme(rawValue: dte.rawValue) ?? .tonalSpot
    }
}

/// Dynamic 16-color ANSI terminal palette.
public typealias Dank16Palette = MaterialDank16Palette

public extension Dank16Palette {
    /// Creates a Dank16 palette from a `DankThemeEngine` palette.
    init(_ dte: DTEDank16Palette) {
        self.init(
            colors: dte.colors.map(M3Color.init),
            background: M3Color(dte.background),
            foreground: M3Color(dte.foreground),
            cursor: M3Color(dte.cursor)
        )
    }

    /// Converts this Dank16 palette to a `DankThemeEngine` palette.
    var dteDank16: DTEDank16Palette {
        DTEDank16Palette(
            colors: colors.map(\.dteColor),
            background: background.dteColor,
            foreground: foreground.dteColor,
            cursor: cursor.dteColor
        )
    }
}

/// 14-tone Material Design 3 tonal palette. Swatches are resolved by the
/// Rust-backed `DankThemeEngine.HCTMath.tonalPalette(hue:chroma:)`; arbitrary
/// tones fall back to `DankThemeEngine.HCTMath.solve`.
public struct M3TonalPalette: Sendable, Codable, Equatable {
    public static let standardTones: [Int] = DTETonalPalette.standardTones

    public let hue: Double
    public let chroma: Double
    public let swatches: [Int: M3Color]

    public init(hue: Double, chroma: Double) {
        self.hue = hue
        self.chroma = chroma
        if let tonal = try? HCTMath.tonalPalette(hue: hue, chroma: chroma) {
            self.swatches = Dictionary(uniqueKeysWithValues: tonal.swatches.map { ($0.key, M3Color($0.value)) })
        } else {
            self.swatches = [:]
        }
    }

    /// Returns the precomputed swatch or solves an arbitrary tone via the engine.
    public func tone(_ t: Int) -> M3Color {
        if let existing = swatches[t] {
            return existing
        }
        return HCT.solve(hue: hue, chroma: chroma, tone: Double(max(0, min(100, t))))
    }
}

/// Generates the Dank16 ANSI palette via the Rust-backed `DankThemeEngine.dank16(for:)`.
public enum Dank16Generator: Sendable {
    /// Generates a 16-color ANSI palette derived from a `ThemePalette`.
    public static func generate(from palette: ThemePalette) -> Dank16Palette {
        if let dank16 = try? DankThemeEngine.dank16(for: palette.dtePalette) {
            return Dank16Palette(dank16)
        }
        return .default
    }
}
