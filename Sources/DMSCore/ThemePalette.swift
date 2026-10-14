import Foundation

/// Represents an RGB color hex code and utility helpers for Material 3.
public struct M3Color: Sendable, Codable, Equatable, Hashable {
    public let hex: String

    public init(_ hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.hasPrefix("#") {
            clean = "#" + clean
        }
        self.hex = clean
    }

    public var red: Double {
        parseComponents().0
    }

    public var green: Double {
        parseComponents().1
    }

    public var blue: Double {
        parseComponents().2
    }

    private func parseComponents() -> (Double, Double, Double) {
        var c = hex
        if c.hasPrefix("#") {
            c.removeFirst()
        }
        if c.count == 3 {
            let r = c[c.startIndex]
            let g = c[c.index(c.startIndex, offsetBy: 1)]
            let b = c[c.index(c.startIndex, offsetBy: 2)]
            c = "\(r)\(r)\(g)\(g)\(b)\(b)"
        }
        guard c.count >= 6, let hexNum = UInt64(c.prefix(6), radix: 16) else {
            return (0, 0, 0)
        }
        let r = Double((hexNum >> 16) & 0xFF) / 255.0
        let g = Double((hexNum >> 8) & 0xFF) / 255.0
        let b = Double(hexNum & 0xFF) / 255.0
        return (r, g, b)
    }

    public static func from(r: Double, g: Double, b: Double) -> M3Color {
        let ri = min(255, max(0, Int(round(r * 255.0))))
        let gi = min(255, max(0, Int(round(g * 255.0))))
        let bi = min(255, max(0, Int(round(b * 255.0))))
        let hex = String(format: "#%02X%02X%02X", ri, gi, bi)
        return M3Color(hex)
    }
}

/// Material Design 3 full color token set.
public typealias DMSPalette = ThemePalette
public struct ThemePalette: Sendable, Codable, Equatable {
    public var name: String
    public var isDark: Bool

    // Primary
    public var primary: M3Color
    public var onPrimary: M3Color
    public var primaryContainer: M3Color
    public var onPrimaryContainer: M3Color
    public var inversePrimary: M3Color

    // Secondary
    public var secondary: M3Color
    public var onSecondary: M3Color
    public var secondaryContainer: M3Color
    public var onSecondaryContainer: M3Color

    // Tertiary
    public var tertiary: M3Color
    public var onTertiary: M3Color
    public var tertiaryContainer: M3Color
    public var onTertiaryContainer: M3Color

    // Surface & Background
    public var surface: M3Color
    public var onSurface: M3Color
    public var surfaceVariant: M3Color
    public var onSurfaceVariant: M3Color
    public var surfaceTint: M3Color

    public var surfaceContainerLowest: M3Color
    public var surfaceContainerLow: M3Color
    public var surfaceContainer: M3Color
    public var surfaceContainerHigh: M3Color
    public var surfaceContainerHighest: M3Color

    public var background: M3Color
    public var onBackground: M3Color

    // Outline
    public var outline: M3Color
    public var outlineVariant: M3Color

    // Error & Status
    public var error: M3Color
    public var onError: M3Color
    public var errorContainer: M3Color
    public var onErrorContainer: M3Color

    public var warning: M3Color
    public var info: M3Color
    public var success: M3Color

    public init(
        name: String,
        isDark: Bool,
        primary: M3Color,
        onPrimary: M3Color,
        primaryContainer: M3Color,
        onPrimaryContainer: M3Color,
        inversePrimary: M3Color,
        secondary: M3Color,
        onSecondary: M3Color,
        secondaryContainer: M3Color,
        onSecondaryContainer: M3Color,
        tertiary: M3Color,
        onTertiary: M3Color,
        tertiaryContainer: M3Color,
        onTertiaryContainer: M3Color,
        surface: M3Color,
        onSurface: M3Color,
        surfaceVariant: M3Color,
        onSurfaceVariant: M3Color,
        surfaceTint: M3Color,
        surfaceContainerLowest: M3Color,
        surfaceContainerLow: M3Color,
        surfaceContainer: M3Color,
        surfaceContainerHigh: M3Color,
        surfaceContainerHighest: M3Color,
        background: M3Color,
        onBackground: M3Color,
        outline: M3Color,
        outlineVariant: M3Color,
        error: M3Color = M3Color("#F2B8B5"),
        onError: M3Color = M3Color("#601410"),
        errorContainer: M3Color = M3Color("#8C1D18"),
        onErrorContainer: M3Color = M3Color("#F9DEDC"),
        warning: M3Color = M3Color("#FFB74D"),
        info: M3Color = M3Color("#4FC3F7"),
        success: M3Color = M3Color("#81C784")
    ) {
        self.name = name
        self.isDark = isDark
        self.primary = primary
        self.onPrimary = onPrimary
        self.primaryContainer = primaryContainer
        self.onPrimaryContainer = onPrimaryContainer
        self.inversePrimary = inversePrimary
        self.secondary = secondary
        self.onSecondary = onSecondary
        self.secondaryContainer = secondaryContainer
        self.onSecondaryContainer = onSecondaryContainer
        self.tertiary = tertiary
        self.onTertiary = onTertiary
        self.tertiaryContainer = tertiaryContainer
        self.onTertiaryContainer = onTertiaryContainer
        self.surface = surface
        self.onSurface = onSurface
        self.surfaceVariant = surfaceVariant
        self.onSurfaceVariant = onSurfaceVariant
        self.surfaceTint = surfaceTint
        self.surfaceContainerLowest = surfaceContainerLowest
        self.surfaceContainerLow = surfaceContainerLow
        self.surfaceContainer = surfaceContainer
        self.surfaceContainerHigh = surfaceContainerHigh
        self.surfaceContainerHighest = surfaceContainerHighest
        self.background = background
        self.onBackground = onBackground
        self.outline = outline
        self.outlineVariant = outlineVariant
        self.error = error
        self.onError = onError
        self.errorContainer = errorContainer
        self.onErrorContainer = onErrorContainer
        self.warning = warning
        self.info = info
        self.success = success
    }
}

/// Pre-configured stock themes from DMS upstream.
public enum StockThemes {
    public static func theme(named name: String, isDark: Bool = true) -> ThemePalette {
        let key = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch key {
        case "blue":
            return isDark ? blueDark : blueLight
        case "green":
            return isDark ? greenDark : greenLight
        case "orange":
            return isDark ? orangeDark : orangeLight
        case "red":
            return isDark ? redDark : redLight
        case "yellow":
            return isDark ? yellowDark : yellowLight
        case "neutral":
            return isDark ? neutralDark : neutralLight
        case "purple", "default":
            fallthrough
        default:
            return isDark ? purpleDark : purpleLight
        }
    }

    public static let allThemeNames = ["purple", "blue", "green", "orange", "red", "yellow", "neutral"]

    // MARK: - Purple (Default DMS theme)
    public static let purpleDark = ThemePalette(
        name: "Purple",
        isDark: true,
        primary: M3Color("#D0BCFF"),
        onPrimary: M3Color("#381E72"),
        primaryContainer: M3Color("#4F378B"),
        onPrimaryContainer: M3Color("#EADDFF"),
        inversePrimary: M3Color("#6750A4"),
        secondary: M3Color("#CCC2DC"),
        onSecondary: M3Color("#332D41"),
        secondaryContainer: M3Color("#4A4458"),
        onSecondaryContainer: M3Color("#E8DEF8"),
        tertiary: M3Color("#EFB8C8"),
        onTertiary: M3Color("#492532"),
        tertiaryContainer: M3Color("#633B48"),
        onTertiaryContainer: M3Color("#FFD8E4"),
        surface: M3Color("#141218"),
        onSurface: M3Color("#E6E0E9"),
        surfaceVariant: M3Color("#49454E"),
        onSurfaceVariant: M3Color("#CAC4CF"),
        surfaceTint: M3Color("#D0BCFF"),
        surfaceContainerLowest: M3Color("#100E14"),
        surfaceContainerLow: M3Color("#1D1B20"),
        surfaceContainer: M3Color("#211F24"),
        surfaceContainerHigh: M3Color("#2B292F"),
        surfaceContainerHighest: M3Color("#36343A"),
        background: M3Color("#141218"),
        onBackground: M3Color("#E6E0E9"),
        outline: M3Color("#948F99"),
        outlineVariant: M3Color("#49454E")
    )

    public static let purpleLight = ThemePalette(
        name: "Purple",
        isDark: false,
        primary: M3Color("#6750A4"),
        onPrimary: M3Color("#FFFFFF"),
        primaryContainer: M3Color("#EADDFF"),
        onPrimaryContainer: M3Color("#21005D"),
        inversePrimary: M3Color("#D0BCFF"),
        secondary: M3Color("#625B71"),
        onSecondary: M3Color("#FFFFFF"),
        secondaryContainer: M3Color("#E8DEF8"),
        onSecondaryContainer: M3Color("#1D192B"),
        tertiary: M3Color("#7D5260"),
        onTertiary: M3Color("#FFFFFF"),
        tertiaryContainer: M3Color("#FFD8E4"),
        onTertiaryContainer: M3Color("#31111D"),
        surface: M3Color("#FEF7FF"),
        onSurface: M3Color("#1D1B20"),
        surfaceVariant: M3Color("#E7E0EC"),
        onSurfaceVariant: M3Color("#49454E"),
        surfaceTint: M3Color("#6750A4"),
        surfaceContainerLowest: M3Color("#FFFFFF"),
        surfaceContainerLow: M3Color("#F7F2FA"),
        surfaceContainer: M3Color("#F3EDF7"),
        surfaceContainerHigh: M3Color("#ECE6F0"),
        surfaceContainerHighest: M3Color("#E6E0E9"),
        background: M3Color("#FEF7FF"),
        onBackground: M3Color("#1D1B20"),
        outline: M3Color("#79747E"),
        outlineVariant: M3Color("#CAC4D0")
    )

    // MARK: - Blue
    public static let blueDark = ThemePalette(
        name: "Blue",
        isDark: true,
        primary: M3Color("#A8C7FA"),
        onPrimary: M3Color("#062E6F"),
        primaryContainer: M3Color("#0842A0"),
        onPrimaryContainer: M3Color("#D3E3FD"),
        inversePrimary: M3Color("#0B57D0"),
        secondary: M3Color("#C2E7FF"),
        onSecondary: M3Color("#003355"),
        secondaryContainer: M3Color("#004A77"),
        onSecondaryContainer: M3Color("#C2E7FF"),
        tertiary: M3Color("#7FCFFF"),
        onTertiary: M3Color("#003550"),
        tertiaryContainer: M3Color("#004C72"),
        onTertiaryContainer: M3Color("#C6E7FF"),
        surface: M3Color("#111318"),
        onSurface: M3Color("#E2E2E9"),
        surfaceVariant: M3Color("#44474F"),
        onSurfaceVariant: M3Color("#C4C7D0"),
        surfaceTint: M3Color("#A8C7FA"),
        surfaceContainerLowest: M3Color("#0C0E13"),
        surfaceContainerLow: M3Color("#191C20"),
        surfaceContainer: M3Color("#1D2024"),
        surfaceContainerHigh: M3Color("#282A2F"),
        surfaceContainerHighest: M3Color("#33353A"),
        background: M3Color("#111318"),
        onBackground: M3Color("#E2E2E9"),
        outline: M3Color("#8E919A"),
        outlineVariant: M3Color("#44474F")
    )

    public static let blueLight = ThemePalette(
        name: "Blue",
        isDark: false,
        primary: M3Color("#0B57D0"),
        onPrimary: M3Color("#FFFFFF"),
        primaryContainer: M3Color("#D3E3FD"),
        onPrimaryContainer: M3Color("#041E49"),
        inversePrimary: M3Color("#A8C7FA"),
        secondary: M3Color("#00639B"),
        onSecondary: M3Color("#FFFFFF"),
        secondaryContainer: M3Color("#C2E7FF"),
        onSecondaryContainer: M3Color("#001D32"),
        tertiary: M3Color("#00669A"),
        onTertiary: M3Color("#FFFFFF"),
        tertiaryContainer: M3Color("#C6E7FF"),
        onTertiaryContainer: M3Color("#001E31"),
        surface: M3Color("#F8F9FF"),
        onSurface: M3Color("#191C20"),
        surfaceVariant: M3Color("#E1E2EC"),
        onSurfaceVariant: M3Color("#44474F"),
        surfaceTint: M3Color("#0B57D0"),
        surfaceContainerLowest: M3Color("#FFFFFF"),
        surfaceContainerLow: M3Color("#F2F3FA"),
        surfaceContainer: M3Color("#EDEEF4"),
        surfaceContainerHigh: M3Color("#E7E8EE"),
        surfaceContainerHighest: M3Color("#E1E2E8"),
        background: M3Color("#F8F9FF"),
        onBackground: M3Color("#191C20"),
        outline: M3Color("#74777F"),
        outlineVariant: M3Color("#C4C7D0")
    )

    // MARK: - Green
    public static let greenDark = ThemePalette(
        name: "Green",
        isDark: true,
        primary: M3Color("#81C995"),
        onPrimary: M3Color("#07381A"),
        primaryContainer: M3Color("#0E5227"),
        onPrimaryContainer: M3Color("#A8E5BA"),
        inversePrimary: M3Color("#1B6D38"),
        secondary: M3Color("#B4CCB9"),
        onSecondary: M3Color("#203527"),
        secondaryContainer: M3Color("#364B3D"),
        onSecondaryContainer: M3Color("#D0E8D4"),
        tertiary: M3Color("#A1CED6"),
        onTertiary: M3Color("#01363D"),
        tertiaryContainer: M3Color("#1F4D54"),
        onTertiaryContainer: M3Color("#BDEAF2"),
        surface: M3Color("#101411"),
        onSurface: M3Color("#E1E4DF"),
        surfaceVariant: M3Color("#414942"),
        onSurfaceVariant: M3Color("#C1C9BF"),
        surfaceTint: M3Color("#81C995"),
        surfaceContainerLowest: M3Color("#0B0F0C"),
        surfaceContainerLow: M3Color("#191D19"),
        surfaceContainer: M3Color("#1D211D"),
        surfaceContainerHigh: M3Color("#272B27"),
        surfaceContainerHighest: M3Color("#323631"),
        background: M3Color("#101411"),
        onBackground: M3Color("#E1E4DF"),
        outline: M3Color("#8B938A"),
        outlineVariant: M3Color("#414942")
    )

    public static let greenLight = ThemePalette(
        name: "Green",
        isDark: false,
        primary: M3Color("#1B6D38"),
        onPrimary: M3Color("#FFFFFF"),
        primaryContainer: M3Color("#A8E5BA"),
        onPrimaryContainer: M3Color("#00210C"),
        inversePrimary: M3Color("#81C995"),
        secondary: M3Color("#4E6354"),
        onSecondary: M3Color("#FFFFFF"),
        secondaryContainer: M3Color("#D0E8D4"),
        onSecondaryContainer: M3Color("#0B1F13"),
        tertiary: M3Color("#39656D"),
        onTertiary: M3Color("#FFFFFF"),
        tertiaryContainer: M3Color("#BDEAF2"),
        onTertiaryContainer: M3Color("#001F24"),
        surface: M3Color("#F6FAF3"),
        onSurface: M3Color("#181D19"),
        surfaceVariant: M3Color("#DDE5DC"),
        onSurfaceVariant: M3Color("#414942"),
        surfaceTint: M3Color("#1B6D38"),
        surfaceContainerLowest: M3Color("#FFFFFF"),
        surfaceContainerLow: M3Color("#F0F5EE"),
        surfaceContainer: M3Color("#EAEFE8"),
        surfaceContainerHigh: M3Color("#E4EAE2"),
        surfaceContainerHighest: M3Color("#DFE4DD"),
        background: M3Color("#F6FAF3"),
        onBackground: M3Color("#181D19"),
        outline: M3Color("#717971"),
        outlineVariant: M3Color("#C1C9BF")
    )

    // MARK: - Orange
    public static let orangeDark = ThemePalette(
        name: "Orange",
        isDark: true,
        primary: M3Color("#FFB77C"),
        onPrimary: M3Color("#4D2600"),
        primaryContainer: M3Color("#6D3900"),
        onPrimaryContainer: M3Color("#FFDCC2"),
        inversePrimary: M3Color("#8F4E00"),
        secondary: M3Color("#E5C0A7"),
        onSecondary: M3Color("#422C1B"),
        secondaryContainer: M3Color("#5B4230"),
        onSecondaryContainer: M3Color("#FFDCC2"),
        tertiary: M3Color("#C8CD9E"),
        onTertiary: M3Color("#303314"),
        tertiaryContainer: M3Color("#474A28"),
        onTertiaryContainer: M3Color("#E4E9B8"),
        surface: M3Color("#18120C"),
        onSurface: M3Color("#EFE0D7"),
        surfaceVariant: M3Color("#51453A"),
        onSurfaceVariant: M3Color("#D6C4B4"),
        surfaceTint: M3Color("#FFB77C"),
        surfaceContainerLowest: M3Color("#120D08"),
        surfaceContainerLow: M3Color("#211A14"),
        surfaceContainer: M3Color("#251E18"),
        surfaceContainerHigh: M3Color("#302922"),
        surfaceContainerHighest: M3Color("#3C332C"),
        background: M3Color("#18120C"),
        onBackground: M3Color("#EFE0D7"),
        outline: M3Color("#9E8E81"),
        outlineVariant: M3Color("#51453A")
    )

    public static let orangeLight = ThemePalette(
        name: "Orange",
        isDark: false,
        primary: M3Color("#8F4E00"),
        onPrimary: M3Color("#FFFFFF"),
        primaryContainer: M3Color("#FFDCC2"),
        onPrimaryContainer: M3Color("#2E1500"),
        inversePrimary: M3Color("#FFB77C"),
        secondary: M3Color("#745946"),
        onSecondary: M3Color("#FFFFFF"),
        secondaryContainer: M3Color("#FFDCC2"),
        onSecondaryContainer: M3Color("#2B1708"),
        tertiary: M3Color("#5E623E"),
        onTertiary: M3Color("#FFFFFF"),
        tertiaryContainer: M3Color("#E4E9B8"),
        onTertiaryContainer: M3Color("#1B1E03"),
        surface: M3Color("#FFF8F5"),
        onSurface: M3Color("#211A14"),
        surfaceVariant: M3Color("#F3DFD1"),
        onSurfaceVariant: M3Color("#51453A"),
        surfaceTint: M3Color("#8F4E00"),
        surfaceContainerLowest: M3Color("#FFFFFF"),
        surfaceContainerLow: M3Color("#FAF2EC"),
        surfaceContainer: M3Color("#F4ECE6"),
        surfaceContainerHigh: M3Color("#EEE6E0"),
        surfaceContainerHighest: M3Color("#E8E0DA"),
        background: M3Color("#FFF8F5"),
        onBackground: M3Color("#211A14"),
        outline: M3Color("#847568"),
        outlineVariant: M3Color("#D6C4B4")
    )

    // MARK: - Red
    public static let redDark = ThemePalette(
        name: "Red",
        isDark: true,
        primary: M3Color("#FFB3AC"),
        onPrimary: M3Color("#561E1A"),
        primaryContainer: M3Color("#73332E"),
        onPrimaryContainer: M3Color("#FFDAD6"),
        inversePrimary: M3Color("#904A44"),
        secondary: M3Color("#E7BDB8"),
        onSecondary: M3Color("#442926"),
        secondaryContainer: M3Color("#5D3F3C"),
        onSecondaryContainer: M3Color("#FFDAD6"),
        tertiary: M3Color("#DFBF90"),
        onTertiary: M3Color("#3E2D08"),
        tertiaryContainer: M3Color("#57431C"),
        onTertiaryContainer: M3Color("#FCDDAE"),
        surface: M3Color("#181211"),
        onSurface: M3Color("#F0DFDD"),
        surfaceVariant: M3Color("#534342"),
        onSurfaceVariant: M3Color("#D8C2BF"),
        surfaceTint: M3Color("#FFB3AC"),
        surfaceContainerLowest: M3Color("#120D0C"),
        surfaceContainerLow: M3Color("#211A19"),
        surfaceContainer: M3Color("#251E1D"),
        surfaceContainerHigh: M3Color("#302827"),
        surfaceContainerHighest: M3Color("#3B3332"),
        background: M3Color("#181211"),
        onBackground: M3Color("#F0DFDD"),
        outline: M3Color("#A08C8A"),
        outlineVariant: M3Color("#534342")
    )

    public static let redLight = ThemePalette(
        name: "Red",
        isDark: false,
        primary: M3Color("#904A44"),
        onPrimary: M3Color("#FFFFFF"),
        primaryContainer: M3Color("#FFDAD6"),
        onPrimaryContainer: M3Color("#3B0907"),
        inversePrimary: M3Color("#FFB3AC"),
        secondary: M3Color("#775653"),
        onSecondary: M3Color("#FFFFFF"),
        secondaryContainer: M3Color("#FFDAD6"),
        onSecondaryContainer: M3Color("#2C1513"),
        tertiary: M3Color("#715B32"),
        onTertiary: M3Color("#FFFFFF"),
        tertiaryContainer: M3Color("#FCDDAE"),
        onTertiaryContainer: M3Color("#261900"),
        surface: M3Color("#FFF8F7"),
        onSurface: M3Color("#221919"),
        surfaceVariant: M3Color("#F5DDDA"),
        onSurfaceVariant: M3Color("#534342"),
        surfaceTint: M3Color("#904A44"),
        surfaceContainerLowest: M3Color("#FFFFFF"),
        surfaceContainerLow: M3Color("#FDF1EF"),
        surfaceContainer: M3Color("#F7EBE9"),
        surfaceContainerHigh: M3Color("#F2E5E3"),
        surfaceContainerHighest: M3Color("#ECE0DE"),
        background: M3Color("#FFF8F7"),
        onBackground: M3Color("#221919"),
        outline: M3Color("#857371"),
        outlineVariant: M3Color("#D8C2BF")
    )

    // MARK: - Yellow
    public static let yellowDark = ThemePalette(
        name: "Yellow",
        isDark: true,
        primary: M3Color("#E2C553"),
        onPrimary: M3Color("#3C2F00"),
        primaryContainer: M3Color("#574500"),
        onPrimaryContainer: M3Color("#FFE278"),
        inversePrimary: M3Color("#725C00"),
        secondary: M3Color("#D2C6A3"),
        onSecondary: M3Color("#383017"),
        secondaryContainer: M3Color("#4F472B"),
        onSecondaryContainer: M3Color("#EFE2BD"),
        tertiary: M3Color("#ABCFA7"),
        onTertiary: M3Color("#17371A"),
        tertiaryContainer: M3Color("#2E4E2F"),
        onTertiaryContainer: M3Color("#C7EBC2"),
        surface: M3Color("#16130C"),
        onSurface: M3Color("#E9E2D4"),
        surfaceVariant: M3Color("#4B4638"),
        onSurfaceVariant: M3Color("#CDC6B3"),
        surfaceTint: M3Color("#E2C553"),
        surfaceContainerLowest: M3Color("#100E07"),
        surfaceContainerLow: M3Color("#1E1B13"),
        surfaceContainer: M3Color("#221F17"),
        surfaceContainerHigh: M3Color("#2D2A21"),
        surfaceContainerHighest: M3Color("#38342B"),
        background: M3Color("#16130C"),
        onBackground: M3Color("#E9E2D4"),
        outline: M3Color("#969080"),
        outlineVariant: M3Color("#4B4638")
    )

    public static let yellowLight = ThemePalette(
        name: "Yellow",
        isDark: false,
        primary: M3Color("#725C00"),
        onPrimary: M3Color("#FFFFFF"),
        primaryContainer: M3Color("#FFE278"),
        onPrimaryContainer: M3Color("#231B00"),
        inversePrimary: M3Color("#E2C553"),
        secondary: M3Color("#675E40"),
        onSecondary: M3Color("#FFFFFF"),
        secondaryContainer: M3Color("#EFE2BD"),
        onSecondaryContainer: M3Color("#221B04"),
        tertiary: M3Color("#456645"),
        onTertiary: M3Color("#FFFFFF"),
        tertiaryContainer: M3Color("#C7EBC2"),
        onTertiaryContainer: M3Color("#022108"),
        surface: M3Color("#FFF9EE"),
        onSurface: M3Color("#1E1B13"),
        surfaceVariant: M3Color("#EAE2CF"),
        onSurfaceVariant: M3Color("#4B4638"),
        surfaceTint: M3Color("#725C00"),
        surfaceContainerLowest: M3Color("#FFFFFF"),
        surfaceContainerLow: M3Color("#F8F3E5"),
        surfaceContainer: M3Color("#F2EDE0"),
        surfaceContainerHigh: M3Color("#ECE7DA"),
        surfaceContainerHighest: M3Color("#E6E1D5"),
        background: M3Color("#FFF9EE"),
        onBackground: M3Color("#1E1B13"),
        outline: M3Color("#7D7767"),
        outlineVariant: M3Color("#CDC6B3")
    )

    // MARK: - Neutral
    public static let neutralDark = ThemePalette(
        name: "Neutral",
        isDark: true,
        primary: M3Color("#C7C6CA"),
        onPrimary: M3Color("#303034"),
        primaryContainer: M3Color("#47464B"),
        onPrimaryContainer: M3Color("#E3E2E6"),
        inversePrimary: M3Color("#5F5E62"),
        secondary: M3Color("#C7C6CA"),
        onSecondary: M3Color("#303034"),
        secondaryContainer: M3Color("#47464B"),
        onSecondaryContainer: M3Color("#E3E2E6"),
        tertiary: M3Color("#CBC4CF"),
        onTertiary: M3Color("#332D37"),
        tertiaryContainer: M3Color("#49444D"),
        onTertiaryContainer: M3Color("#E8E0EB"),
        surface: M3Color("#141316"),
        onSurface: M3Color("#E5E1E6"),
        surfaceVariant: M3Color("#47464F"),
        onSurfaceVariant: M3Color("#C8C5D0"),
        surfaceTint: M3Color("#C7C6CA"),
        surfaceContainerLowest: M3Color("#0F0E11"),
        surfaceContainerLow: M3Color("#1C1B1E"),
        surfaceContainer: M3Color("#201F22"),
        surfaceContainerHigh: M3Color("#2B292D"),
        surfaceContainerHighest: M3Color("#363438"),
        background: M3Color("#141316"),
        onBackground: M3Color("#E5E1E6"),
        outline: M3Color("#928F99"),
        outlineVariant: M3Color("#47464F")
    )

    public static let neutralLight = ThemePalette(
        name: "Neutral",
        isDark: false,
        primary: M3Color("#5F5E62"),
        onPrimary: M3Color("#FFFFFF"),
        primaryContainer: M3Color("#E3E2E6"),
        onPrimaryContainer: M3Color("#1B1B1E"),
        inversePrimary: M3Color("#C7C6CA"),
        secondary: M3Color("#5F5E62"),
        onSecondary: M3Color("#FFFFFF"),
        secondaryContainer: M3Color("#E3E2E6"),
        onSecondaryContainer: M3Color("#1B1B1E"),
        tertiary: M3Color("#615B65"),
        onTertiary: M3Color("#FFFFFF"),
        tertiaryContainer: M3Color("#E8E0EB"),
        onTertiaryContainer: M3Color("#1E1921"),
        surface: M3Color("#FAF8FD"),
        onSurface: M3Color("#1C1B1E"),
        surfaceVariant: M3Color("#E4E1EC"),
        onSurfaceVariant: M3Color("#47464F"),
        surfaceTint: M3Color("#5F5E62"),
        surfaceContainerLowest: M3Color("#FFFFFF"),
        surfaceContainerLow: M3Color("#F4F2F7"),
        surfaceContainer: M3Color("#EFEDF1"),
        surfaceContainerHigh: M3Color("#E9E7EC"),
        surfaceContainerHighest: M3Color("#E3E1E6"),
        background: M3Color("#FAF8FD"),
        onBackground: M3Color("#1C1B1E"),
        outline: M3Color("#787680"),
        outlineVariant: M3Color("#C8C5D0")
    )
}
