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
    public var onWarning: M3Color
    public var warningContainer: M3Color
    public var onWarningContainer: M3Color

    public var info: M3Color
    public var onInfo: M3Color
    public var infoContainer: M3Color
    public var onInfoContainer: M3Color

    public var success: M3Color
    public var onSuccess: M3Color
    public var successContainer: M3Color
    public var onSuccessContainer: M3Color

    public var scrim: M3Color
    public var shadow: M3Color

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
        onWarning: M3Color? = nil,
        warningContainer: M3Color? = nil,
        onWarningContainer: M3Color? = nil,
        info: M3Color = M3Color("#4FC3F7"),
        onInfo: M3Color? = nil,
        infoContainer: M3Color? = nil,
        onInfoContainer: M3Color? = nil,
        success: M3Color = M3Color("#81C784"),
        onSuccess: M3Color? = nil,
        successContainer: M3Color? = nil,
        onSuccessContainer: M3Color? = nil,
        scrim: M3Color = M3Color("#000000"),
        shadow: M3Color = M3Color("#000000")
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
        self.onWarning = onWarning ?? (isDark ? M3Color("#462B00") : M3Color("#FFFFFF"))
        self.warningContainer = warningContainer ?? (isDark ? M3Color("#643F00") : M3Color("#FFDEAD"))
        self.onWarningContainer = onWarningContainer ?? (isDark ? M3Color("#FFDEAD") : M3Color("#281800"))
        self.info = info
        self.onInfo = onInfo ?? (isDark ? M3Color("#003548") : M3Color("#FFFFFF"))
        self.infoContainer = infoContainer ?? (isDark ? M3Color("#004D67") : M3Color("#BFE9FF"))
        self.onInfoContainer = onInfoContainer ?? (isDark ? M3Color("#BFE9FF") : M3Color("#001F2B"))
        self.success = success
        self.onSuccess = onSuccess ?? (isDark ? M3Color("#0A3912") : M3Color("#FFFFFF"))
        self.successContainer = successContainer ?? (isDark ? M3Color("#215126") : M3Color("#B8F397"))
        self.onSuccessContainer = onSuccessContainer ?? (isDark ? M3Color("#B8F397") : M3Color("#022106"))
        self.scrim = scrim
        self.shadow = shadow
    }
}

/// Pre-configured stock and community themes from DMS upstream.
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
        case "catppuccin", "catppuccin-mocha", "catppuccin mocha":
            return isDark ? catppuccinMocha : catppuccinLatte
        case "catppuccin-latte", "catppuccin latte":
            return isDark ? catppuccinMocha : catppuccinLatte
        case "nord":
            return isDark ? nordDark : nordLight
        case "gruvbox":
            return isDark ? gruvboxDark : gruvboxLight
        case "tokyo-night", "tokyonight", "tokyo night":
            return isDark ? tokyoNightDark : tokyoNightLight
        case "everforest":
            return isDark ? everforestDark : everforestLight
        case "purple", "default":
            fallthrough
        default:
            return isDark ? purpleDark : purpleLight
        }
    }

    public static let allThemeNames = ["purple", "blue", "green", "orange", "red", "yellow", "neutral"]
    public static let communityThemeNames = ["catppuccin-mocha", "catppuccin-latte", "nord", "gruvbox", "tokyo-night", "everforest"]
    public static let allAvailableThemes = allThemeNames + communityThemeNames

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

    // MARK: - Catppuccin (Mocha / Latte)
    public static let catppuccinMocha = ThemePalette(
        name: "Catppuccin-Mocha",
        isDark: true,
        primary: M3Color("#CBA6F7"),
        onPrimary: M3Color("#1E1E2E"),
        primaryContainer: M3Color("#45475A"),
        onPrimaryContainer: M3Color("#F5E0DC"),
        inversePrimary: M3Color("#8839EF"),
        secondary: M3Color("#89B4FA"),
        onSecondary: M3Color("#1E1E2E"),
        secondaryContainer: M3Color("#313244"),
        onSecondaryContainer: M3Color("#CDD6F4"),
        tertiary: M3Color("#F5C2E7"),
        onTertiary: M3Color("#1E1E2E"),
        tertiaryContainer: M3Color("#45475A"),
        onTertiaryContainer: M3Color("#F5E0DC"),
        surface: M3Color("#1E1E2E"),
        onSurface: M3Color("#CDD6F4"),
        surfaceVariant: M3Color("#313244"),
        onSurfaceVariant: M3Color("#BAC2DE"),
        surfaceTint: M3Color("#CBA6F7"),
        surfaceContainerLowest: M3Color("#11111B"),
        surfaceContainerLow: M3Color("#181825"),
        surfaceContainer: M3Color("#1E1E2E"),
        surfaceContainerHigh: M3Color("#313244"),
        surfaceContainerHighest: M3Color("#45475A"),
        background: M3Color("#1E1E2E"),
        onBackground: M3Color("#CDD6F4"),
        outline: M3Color("#6C7086"),
        outlineVariant: M3Color("#45475A"),
        error: M3Color("#F38BA8"),
        onError: M3Color("#1E1E2E"),
        errorContainer: M3Color("#45475A"),
        onErrorContainer: M3Color("#F38BA8"),
        warning: M3Color("#FAB387"),
        info: M3Color("#89DCEB"),
        success: M3Color("#A6E3A1")
    )

    public static let catppuccinLatte = ThemePalette(
        name: "Catppuccin-Latte",
        isDark: false,
        primary: M3Color("#8839EF"),
        onPrimary: M3Color("#EFF1F5"),
        primaryContainer: M3Color("#CCD0DA"),
        onPrimaryContainer: M3Color("#4C4F69"),
        inversePrimary: M3Color("#CBA6F7"),
        secondary: M3Color("#1E66F5"),
        onSecondary: M3Color("#EFF1F5"),
        secondaryContainer: M3Color("#DCE0E8"),
        onSecondaryContainer: M3Color("#4C4F69"),
        tertiary: M3Color("#EA76CB"),
        onTertiary: M3Color("#EFF1F5"),
        tertiaryContainer: M3Color("#CCD0DA"),
        onTertiaryContainer: M3Color("#4C4F69"),
        surface: M3Color("#EFF1F5"),
        onSurface: M3Color("#4C4F69"),
        surfaceVariant: M3Color("#CCD0DA"),
        onSurfaceVariant: M3Color("#5C5F77"),
        surfaceTint: M3Color("#8839EF"),
        surfaceContainerLowest: M3Color("#FFFFFF"),
        surfaceContainerLow: M3Color("#E6E9EF"),
        surfaceContainer: M3Color("#DCE0E8"),
        surfaceContainerHigh: M3Color("#CCD0DA"),
        surfaceContainerHighest: M3Color("#BCC0CC"),
        background: M3Color("#EFF1F5"),
        onBackground: M3Color("#4C4F69"),
        outline: M3Color("#8C8FA1"),
        outlineVariant: M3Color("#CCD0DA"),
        error: M3Color("#D20F39"),
        onError: M3Color("#EFF1F5"),
        errorContainer: M3Color("#CCD0DA"),
        onErrorContainer: M3Color("#D20F39"),
        warning: M3Color("#FE640B"),
        info: M3Color("#04A5E5"),
        success: M3Color("#40A02B")
    )

    // MARK: - Nord
    public static let nordDark = ThemePalette(
        name: "Nord",
        isDark: true,
        primary: M3Color("#88C0D0"),
        onPrimary: M3Color("#2E3440"),
        primaryContainer: M3Color("#3B4252"),
        onPrimaryContainer: M3Color("#ECEFF4"),
        inversePrimary: M3Color("#5E81AC"),
        secondary: M3Color("#81A1C1"),
        onSecondary: M3Color("#2E3440"),
        secondaryContainer: M3Color("#434C5E"),
        onSecondaryContainer: M3Color("#E5E9F0"),
        tertiary: M3Color("#B48EAD"),
        onTertiary: M3Color("#2E3440"),
        tertiaryContainer: M3Color("#4C566A"),
        onTertiaryContainer: M3Color("#ECEFF4"),
        surface: M3Color("#2E3440"),
        onSurface: M3Color("#ECEFF4"),
        surfaceVariant: M3Color("#3B4252"),
        onSurfaceVariant: M3Color("#D8DEE9"),
        surfaceTint: M3Color("#88C0D0"),
        surfaceContainerLowest: M3Color("#242933"),
        surfaceContainerLow: M3Color("#2E3440"),
        surfaceContainer: M3Color("#3B4252"),
        surfaceContainerHigh: M3Color("#434C5E"),
        surfaceContainerHighest: M3Color("#4C566A"),
        background: M3Color("#2E3440"),
        onBackground: M3Color("#ECEFF4"),
        outline: M3Color("#7B88A1"),
        outlineVariant: M3Color("#4C566A"),
        error: M3Color("#BF616A"),
        warning: M3Color("#EBCB8B"),
        info: M3Color("#81A1C1"),
        success: M3Color("#A3BE8C")
    )

    public static let nordLight = ThemePalette(
        name: "Nord",
        isDark: false,
        primary: M3Color("#5E81AC"),
        onPrimary: M3Color("#ECEFF4"),
        primaryContainer: M3Color("#D8DEE9"),
        onPrimaryContainer: M3Color("#2E3440"),
        inversePrimary: M3Color("#88C0D0"),
        secondary: M3Color("#81A1C1"),
        onSecondary: M3Color("#ECEFF4"),
        secondaryContainer: M3Color("#E5E9F0"),
        onSecondaryContainer: M3Color("#2E3440"),
        tertiary: M3Color("#B48EAD"),
        onTertiary: M3Color("#ECEFF4"),
        tertiaryContainer: M3Color("#E5E9F0"),
        onTertiaryContainer: M3Color("#2E3440"),
        surface: M3Color("#ECEFF4"),
        onSurface: M3Color("#2E3440"),
        surfaceVariant: M3Color("#D8DEE9"),
        onSurfaceVariant: M3Color("#4C566A"),
        surfaceTint: M3Color("#5E81AC"),
        surfaceContainerLowest: M3Color("#FFFFFF"),
        surfaceContainerLow: M3Color("#ECEFF4"),
        surfaceContainer: M3Color("#E5E9F0"),
        surfaceContainerHigh: M3Color("#D8DEE9"),
        surfaceContainerHighest: M3Color("#C8D0E0"),
        background: M3Color("#ECEFF4"),
        onBackground: M3Color("#2E3440"),
        outline: M3Color("#7B88A1"),
        outlineVariant: M3Color("#D8DEE9"),
        error: M3Color("#BF616A"),
        warning: M3Color("#D08770"),
        info: M3Color("#5E81AC"),
        success: M3Color("#A3BE8C")
    )

    // MARK: - Gruvbox
    public static let gruvboxDark = ThemePalette(
        name: "Gruvbox",
        isDark: true,
        primary: M3Color("#FABD2F"),
        onPrimary: M3Color("#282828"),
        primaryContainer: M3Color("#504945"),
        onPrimaryContainer: M3Color("#EBDBB2"),
        inversePrimary: M3Color("#D79921"),
        secondary: M3Color("#83A598"),
        onSecondary: M3Color("#282828"),
        secondaryContainer: M3Color("#3C3836"),
        onSecondaryContainer: M3Color("#EBDBB2"),
        tertiary: M3Color("#D3869B"),
        onTertiary: M3Color("#282828"),
        tertiaryContainer: M3Color("#504945"),
        onTertiaryContainer: M3Color("#FBF1C7"),
        surface: M3Color("#282828"),
        onSurface: M3Color("#EBDBB2"),
        surfaceVariant: M3Color("#3C3836"),
        onSurfaceVariant: M3Color("#D5C4A1"),
        surfaceTint: M3Color("#FABD2F"),
        surfaceContainerLowest: M3Color("#1D2021"),
        surfaceContainerLow: M3Color("#282828"),
        surfaceContainer: M3Color("#32302F"),
        surfaceContainerHigh: M3Color("#3C3836"),
        surfaceContainerHighest: M3Color("#504945"),
        background: M3Color("#282828"),
        onBackground: M3Color("#EBDBB2"),
        outline: M3Color("#928374"),
        outlineVariant: M3Color("#504945"),
        error: M3Color("#FB4934"),
        warning: M3Color("#FE8019"),
        info: M3Color("#83A598"),
        success: M3Color("#B8BB26")
    )

    public static let gruvboxLight = ThemePalette(
        name: "Gruvbox",
        isDark: false,
        primary: M3Color("#B57614"),
        onPrimary: M3Color("#FBF1C7"),
        primaryContainer: M3Color("#EBDBB2"),
        onPrimaryContainer: M3Color("#3C3836"),
        inversePrimary: M3Color("#FABD2F"),
        secondary: M3Color("#076678"),
        onSecondary: M3Color("#FBF1C7"),
        secondaryContainer: M3Color("#D5C4A1"),
        onSecondaryContainer: M3Color("#3C3836"),
        tertiary: M3Color("#8F3F71"),
        onTertiary: M3Color("#FBF1C7"),
        tertiaryContainer: M3Color("#EBDBB2"),
        onTertiaryContainer: M3Color("#3C3836"),
        surface: M3Color("#FBF1C7"),
        onSurface: M3Color("#3C3836"),
        surfaceVariant: M3Color("#EBDBB2"),
        onSurfaceVariant: M3Color("#504945"),
        surfaceTint: M3Color("#B57614"),
        surfaceContainerLowest: M3Color("#FFFFFF"),
        surfaceContainerLow: M3Color("#F9F5D7"),
        surfaceContainer: M3Color("#F2E5BC"),
        surfaceContainerHigh: M3Color("#EBDBB2"),
        surfaceContainerHighest: M3Color("#D5C4A1"),
        background: M3Color("#FBF1C7"),
        onBackground: M3Color("#3C3836"),
        outline: M3Color("#7C6F64"),
        outlineVariant: M3Color("#D5C4A1"),
        error: M3Color("#9D0006"),
        warning: M3Color("#AF3A03"),
        info: M3Color("#076678"),
        success: M3Color("#79740E")
    )

    // MARK: - Tokyo Night
    public static let tokyoNightDark = ThemePalette(
        name: "Tokyo-Night",
        isDark: true,
        primary: M3Color("#7AA2F7"),
        onPrimary: M3Color("#1A1B26"),
        primaryContainer: M3Color("#292E42"),
        onPrimaryContainer: M3Color("#C0CAF5"),
        inversePrimary: M3Color("#3D59A1"),
        secondary: M3Color("#BB9AF7"),
        onSecondary: M3Color("#1A1B26"),
        secondaryContainer: M3Color("#24283B"),
        onSecondaryContainer: M3Color("#C0CAF5"),
        tertiary: M3Color("#7DCFFF"),
        onTertiary: M3Color("#1A1B26"),
        tertiaryContainer: M3Color("#292E42"),
        onTertiaryContainer: M3Color("#C0CAF5"),
        surface: M3Color("#1A1B26"),
        onSurface: M3Color("#C0CAF5"),
        surfaceVariant: M3Color("#24283B"),
        onSurfaceVariant: M3Color("#A9B1D6"),
        surfaceTint: M3Color("#7AA2F7"),
        surfaceContainerLowest: M3Color("#16161E"),
        surfaceContainerLow: M3Color("#1A1B26"),
        surfaceContainer: M3Color("#24283B"),
        surfaceContainerHigh: M3Color("#292E42"),
        surfaceContainerHighest: M3Color("#414868"),
        background: M3Color("#1A1B26"),
        onBackground: M3Color("#C0CAF5"),
        outline: M3Color("#565F89"),
        outlineVariant: M3Color("#414868"),
        error: M3Color("#F7768E"),
        warning: M3Color("#E0AF68"),
        info: M3Color("#7DCFFF"),
        success: M3Color("#9ECE6A")
    )

    public static let tokyoNightLight = ThemePalette(
        name: "Tokyo-Night",
        isDark: false,
        primary: M3Color("#2E7DE9"),
        onPrimary: M3Color("#E1E2E7"),
        primaryContainer: M3Color("#C4C8DA"),
        onPrimaryContainer: M3Color("#3760BF"),
        inversePrimary: M3Color("#7AA2F7"),
        secondary: M3Color("#9854F1"),
        onSecondary: M3Color("#E1E2E7"),
        secondaryContainer: M3Color("#D0D5E3"),
        onSecondaryContainer: M3Color("#3760BF"),
        tertiary: M3Color("#007197"),
        onTertiary: M3Color("#E1E2E7"),
        tertiaryContainer: M3Color("#C4C8DA"),
        onTertiaryContainer: M3Color("#3760BF"),
        surface: M3Color("#E1E2E7"),
        onSurface: M3Color("#3760BF"),
        surfaceVariant: M3Color("#D0D5E3"),
        onSurfaceVariant: M3Color("#6172B0"),
        surfaceTint: M3Color("#2E7DE9"),
        surfaceContainerLowest: M3Color("#FFFFFF"),
        surfaceContainerLow: M3Color("#E9E9ED"),
        surfaceContainer: M3Color("#E1E2E7"),
        surfaceContainerHigh: M3Color("#D0D5E3"),
        surfaceContainerHighest: M3Color("#C4C8DA"),
        background: M3Color("#E1E2E7"),
        onBackground: M3Color("#3760BF"),
        outline: M3Color("#848CB5"),
        outlineVariant: M3Color("#C4C8DA"),
        error: M3Color("#F52A65"),
        warning: M3Color("#8C6C3E"),
        info: M3Color("#007197"),
        success: M3Color("#587539")
    )

    // MARK: - Everforest
    public static let everforestDark = ThemePalette(
        name: "Everforest",
        isDark: true,
        primary: M3Color("#A7C080"),
        onPrimary: M3Color("#272E33"),
        primaryContainer: M3Color("#374145"),
        onPrimaryContainer: M3Color("#D3C6AA"),
        inversePrimary: M3Color("#8DA101"),
        secondary: M3Color("#7FBBB3"),
        onSecondary: M3Color("#272E33"),
        secondaryContainer: M3Color("#2E383C"),
        onSecondaryContainer: M3Color("#D3C6AA"),
        tertiary: M3Color("#D699B6"),
        onTertiary: M3Color("#272E33"),
        tertiaryContainer: M3Color("#374145"),
        onTertiaryContainer: M3Color("#D3C6AA"),
        surface: M3Color("#272E33"),
        onSurface: M3Color("#D3C6AA"),
        surfaceVariant: M3Color("#374145"),
        onSurfaceVariant: M3Color("#9DA9A0"),
        surfaceTint: M3Color("#A7C080"),
        surfaceContainerLowest: M3Color("#1E2326"),
        surfaceContainerLow: M3Color("#272E33"),
        surfaceContainer: M3Color("#2E383C"),
        surfaceContainerHigh: M3Color("#374145"),
        surfaceContainerHighest: M3Color("#414B50"),
        background: M3Color("#272E33"),
        onBackground: M3Color("#D3C6AA"),
        outline: M3Color("#859289"),
        outlineVariant: M3Color("#414B50"),
        error: M3Color("#E67E80"),
        warning: M3Color("#DBBC7F"),
        info: M3Color("#7FBBB3"),
        success: M3Color("#A7C080")
    )

    public static let everforestLight = ThemePalette(
        name: "Everforest",
        isDark: false,
        primary: M3Color("#8DA101"),
        onPrimary: M3Color("#FDF6E3"),
        primaryContainer: M3Color("#EFEBD4"),
        onPrimaryContainer: M3Color("#5C6A72"),
        inversePrimary: M3Color("#A7C080"),
        secondary: M3Color("#35A77C"),
        onSecondary: M3Color("#FDF6E3"),
        secondaryContainer: M3Color("#F4F0D9"),
        onSecondaryContainer: M3Color("#5C6A72"),
        tertiary: M3Color("#DF69BA"),
        onTertiary: M3Color("#FDF6E3"),
        tertiaryContainer: M3Color("#EFEBD4"),
        onTertiaryContainer: M3Color("#5C6A72"),
        surface: M3Color("#FDF6E3"),
        onSurface: M3Color("#5C6A72"),
        surfaceVariant: M3Color("#EFEBD4"),
        onSurfaceVariant: M3Color("#829181"),
        surfaceTint: M3Color("#8DA101"),
        surfaceContainerLowest: M3Color("#FFFFFF"),
        surfaceContainerLow: M3Color("#FDF6E3"),
        surfaceContainer: M3Color("#F4F0D9"),
        surfaceContainerHigh: M3Color("#EFEBD4"),
        surfaceContainerHighest: M3Color("#E6E2CC"),
        background: M3Color("#FDF6E3"),
        onBackground: M3Color("#5C6A72"),
        outline: M3Color("#939F91"),
        outlineVariant: M3Color("#E6E2CC"),
        error: M3Color("#F85552"),
        warning: M3Color("#DFA000"),
        info: M3Color("#3A94C5"),
        success: M3Color("#8DA101")
    )
}
