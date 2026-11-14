import Foundation
@_exported import MaterialTokens
import DankThemeEngine
#if canImport(SwiftUI)
import SwiftUI
#endif

/// DMS color token. Now an alias of `MaterialTokens.MaterialColor`, which also
/// provides `Color.init(hex:)` to every target that imports `DMSCore`.
public typealias M3Color = MaterialColor

public extension M3Color {
    #if canImport(SwiftUI)
    /// SwiftUI color for this token.
    var color: Color { swiftUIColor }
    #endif

    /// Creates a DMS color from a `DankThemeEngine` color.
    init(_ dte: DTEColor) {
        self.init(dte.hex, alpha: dte.alpha)
    }

    /// Converts this DMS color to a `DankThemeEngine` color.
    var dteColor: DTEColor {
        DTEColor(red: red, green: green, blue: blue, alpha: alpha, hex: hex)
    }
}

/// Material Design 3 full color token set. Alias of `MaterialTokens.MaterialPalette`
/// (extracted directly from the former DMS `ThemePalette`).
public typealias ThemePalette = MaterialPalette
public typealias DMSPalette = ThemePalette

public extension ThemePalette {
    /// Default dark palette (DMS "Purple" dark stock theme).
    static let `default`: ThemePalette = .defaultDark

    /// Creates a palette from a `DankThemeEngine` palette.
    init(dte: DTEPalette) {
        self.init(
            name: dte.name,
            isDark: dte.isDark,
            primary: M3Color(dte.primary),
            onPrimary: M3Color(dte.onPrimary),
            primaryContainer: M3Color(dte.primaryContainer),
            onPrimaryContainer: M3Color(dte.onPrimaryContainer),
            inversePrimary: M3Color(dte.inversePrimary),
            secondary: M3Color(dte.secondary),
            onSecondary: M3Color(dte.onSecondary),
            secondaryContainer: M3Color(dte.secondaryContainer),
            onSecondaryContainer: M3Color(dte.onSecondaryContainer),
            tertiary: M3Color(dte.tertiary),
            onTertiary: M3Color(dte.onTertiary),
            tertiaryContainer: M3Color(dte.tertiaryContainer),
            onTertiaryContainer: M3Color(dte.onTertiaryContainer),
            surface: M3Color(dte.surface),
            onSurface: M3Color(dte.onSurface),
            surfaceVariant: M3Color(dte.surfaceVariant),
            onSurfaceVariant: M3Color(dte.onSurfaceVariant),
            surfaceTint: M3Color(dte.surfaceTint),
            surfaceContainerLowest: M3Color(dte.surfaceContainerLowest),
            surfaceContainerLow: M3Color(dte.surfaceContainerLow),
            surfaceContainer: M3Color(dte.surfaceContainer),
            surfaceContainerHigh: M3Color(dte.surfaceContainerHigh),
            surfaceContainerHighest: M3Color(dte.surfaceContainerHighest),
            background: M3Color(dte.background),
            onBackground: M3Color(dte.onBackground),
            outline: M3Color(dte.outline),
            outlineVariant: M3Color(dte.outlineVariant),
            error: M3Color(dte.error),
            onError: M3Color(dte.onError),
            errorContainer: M3Color(dte.errorContainer),
            onErrorContainer: M3Color(dte.onErrorContainer),
            warning: M3Color(dte.warning),
            onWarning: M3Color(dte.onWarning),
            warningContainer: M3Color(dte.warningContainer),
            onWarningContainer: M3Color(dte.onWarningContainer),
            info: M3Color(dte.info),
            onInfo: M3Color(dte.onInfo),
            infoContainer: M3Color(dte.infoContainer),
            onInfoContainer: M3Color(dte.onInfoContainer),
            success: M3Color(dte.success),
            onSuccess: M3Color(dte.onSuccess),
            successContainer: M3Color(dte.successContainer),
            onSuccessContainer: M3Color(dte.onSuccessContainer),
            scrim: M3Color(dte.scrim),
            shadow: M3Color(dte.shadow)
        )
    }

    /// Converts this palette to a `DankThemeEngine` palette.
    var dtePalette: DTEPalette {
        DTEPalette(
            name: name,
            isDark: isDark,
            primary: primary.dteColor,
            onPrimary: onPrimary.dteColor,
            primaryContainer: primaryContainer.dteColor,
            onPrimaryContainer: onPrimaryContainer.dteColor,
            inversePrimary: inversePrimary.dteColor,
            secondary: secondary.dteColor,
            onSecondary: onSecondary.dteColor,
            secondaryContainer: secondaryContainer.dteColor,
            onSecondaryContainer: onSecondaryContainer.dteColor,
            tertiary: tertiary.dteColor,
            onTertiary: onTertiary.dteColor,
            tertiaryContainer: tertiaryContainer.dteColor,
            onTertiaryContainer: onTertiaryContainer.dteColor,
            surface: surface.dteColor,
            onSurface: onSurface.dteColor,
            surfaceVariant: surfaceVariant.dteColor,
            onSurfaceVariant: onSurfaceVariant.dteColor,
            surfaceTint: surfaceTint.dteColor,
            surfaceContainerLowest: surfaceContainerLowest.dteColor,
            surfaceContainerLow: surfaceContainerLow.dteColor,
            surfaceContainer: surfaceContainer.dteColor,
            surfaceContainerHigh: surfaceContainerHigh.dteColor,
            surfaceContainerHighest: surfaceContainerHighest.dteColor,
            background: background.dteColor,
            onBackground: onBackground.dteColor,
            outline: outline.dteColor,
            outlineVariant: outlineVariant.dteColor,
            error: error.dteColor,
            onError: onError.dteColor,
            errorContainer: errorContainer.dteColor,
            onErrorContainer: onErrorContainer.dteColor,
            warning: warning.dteColor,
            onWarning: onWarning.dteColor,
            warningContainer: warningContainer.dteColor,
            onWarningContainer: onWarningContainer.dteColor,
            info: info.dteColor,
            onInfo: onInfo.dteColor,
            infoContainer: infoContainer.dteColor,
            onInfoContainer: onInfoContainer.dteColor,
            success: success.dteColor,
            onSuccess: onSuccess.dteColor,
            successContainer: successContainer.dteColor,
            onSuccessContainer: onSuccessContainer.dteColor,
            scrim: scrim.dteColor,
            shadow: shadow.dteColor
        )
    }

    /// All 45 color roles as a camelCase role-name → hex map.
    var hexMap: [String: String] {
        [
            "primary": primary.hex,
            "onPrimary": onPrimary.hex,
            "primaryContainer": primaryContainer.hex,
            "onPrimaryContainer": onPrimaryContainer.hex,
            "inversePrimary": inversePrimary.hex,
            "secondary": secondary.hex,
            "onSecondary": onSecondary.hex,
            "secondaryContainer": secondaryContainer.hex,
            "onSecondaryContainer": onSecondaryContainer.hex,
            "tertiary": tertiary.hex,
            "onTertiary": onTertiary.hex,
            "tertiaryContainer": tertiaryContainer.hex,
            "onTertiaryContainer": onTertiaryContainer.hex,
            "surface": surface.hex,
            "onSurface": onSurface.hex,
            "surfaceVariant": surfaceVariant.hex,
            "onSurfaceVariant": onSurfaceVariant.hex,
            "surfaceTint": surfaceTint.hex,
            "surfaceContainerLowest": surfaceContainerLowest.hex,
            "surfaceContainerLow": surfaceContainerLow.hex,
            "surfaceContainer": surfaceContainer.hex,
            "surfaceContainerHigh": surfaceContainerHigh.hex,
            "surfaceContainerHighest": surfaceContainerHighest.hex,
            "background": background.hex,
            "onBackground": onBackground.hex,
            "outline": outline.hex,
            "outlineVariant": outlineVariant.hex,
            "error": error.hex,
            "onError": onError.hex,
            "errorContainer": errorContainer.hex,
            "onErrorContainer": onErrorContainer.hex,
            "warning": warning.hex,
            "onWarning": onWarning.hex,
            "warningContainer": warningContainer.hex,
            "onWarningContainer": onWarningContainer.hex,
            "info": info.hex,
            "onInfo": onInfo.hex,
            "infoContainer": infoContainer.hex,
            "onInfoContainer": onInfoContainer.hex,
            "success": success.hex,
            "onSuccess": onSuccess.hex,
            "successContainer": successContainer.hex,
            "onSuccessContainer": onSuccessContainer.hex,
            "scrim": scrim.hex,
            "shadow": shadow.hex
        ]
    }

    /// Builds a palette from a camelCase role-name → hex map; missing roles fall
    /// back to the default dark palette, `name`/`isDark` to the map or defaults.
    static func from(hexMap map: [String: String]) -> ThemePalette {
        let base = ThemePalette.defaultDark
        func c(_ key: String, _ fallback: M3Color) -> M3Color {
            map[key].map { M3Color($0) } ?? fallback
        }
        return ThemePalette(
            name: map["name"] ?? base.name,
            isDark: map["isDark"].flatMap(Bool.init) ?? base.isDark,
            primary: c("primary", base.primary),
            onPrimary: c("onPrimary", base.onPrimary),
            primaryContainer: c("primaryContainer", base.primaryContainer),
            onPrimaryContainer: c("onPrimaryContainer", base.onPrimaryContainer),
            inversePrimary: c("inversePrimary", base.inversePrimary),
            secondary: c("secondary", base.secondary),
            onSecondary: c("onSecondary", base.onSecondary),
            secondaryContainer: c("secondaryContainer", base.secondaryContainer),
            onSecondaryContainer: c("onSecondaryContainer", base.onSecondaryContainer),
            tertiary: c("tertiary", base.tertiary),
            onTertiary: c("onTertiary", base.onTertiary),
            tertiaryContainer: c("tertiaryContainer", base.tertiaryContainer),
            onTertiaryContainer: c("onTertiaryContainer", base.onTertiaryContainer),
            surface: c("surface", base.surface),
            onSurface: c("onSurface", base.onSurface),
            surfaceVariant: c("surfaceVariant", base.surfaceVariant),
            onSurfaceVariant: c("onSurfaceVariant", base.onSurfaceVariant),
            surfaceTint: c("surfaceTint", base.surfaceTint),
            surfaceContainerLowest: c("surfaceContainerLowest", base.surfaceContainerLowest),
            surfaceContainerLow: c("surfaceContainerLow", base.surfaceContainerLow),
            surfaceContainer: c("surfaceContainer", base.surfaceContainer),
            surfaceContainerHigh: c("surfaceContainerHigh", base.surfaceContainerHigh),
            surfaceContainerHighest: c("surfaceContainerHighest", base.surfaceContainerHighest),
            background: c("background", base.background),
            onBackground: c("onBackground", base.onBackground),
            outline: c("outline", base.outline),
            outlineVariant: c("outlineVariant", base.outlineVariant),
            error: c("error", base.error),
            onError: c("onError", base.onError),
            errorContainer: c("errorContainer", base.errorContainer),
            onErrorContainer: c("onErrorContainer", base.onErrorContainer),
            warning: c("warning", base.warning),
            onWarning: c("onWarning", base.onWarning),
            warningContainer: c("warningContainer", base.warningContainer),
            onWarningContainer: c("onWarningContainer", base.onWarningContainer),
            info: c("info", base.info),
            onInfo: c("onInfo", base.onInfo),
            infoContainer: c("infoContainer", base.infoContainer),
            onInfoContainer: c("onInfoContainer", base.onInfoContainer),
            success: c("success", base.success),
            onSuccess: c("onSuccess", base.onSuccess),
            successContainer: c("successContainer", base.successContainer),
            onSuccessContainer: c("onSuccessContainer", base.onSuccessContainer),
            scrim: c("scrim", base.scrim),
            shadow: c("shadow", base.shadow)
        )
    }

    /// Returns the palette color for a camelCase role name, or nil for unknown roles.
    func color(for role: String) -> M3Color? {
        hexMap[role].map { M3Color($0) }
    }
}

/// Pre-configured stock and community themes, resolved through the Rust-backed
/// `DankThemeEngine` (`stockThemes()` / `resolveTheme(.preset(...))`) instead of
/// duplicated hardcoded hex tables. Name lookup, aliases, and the Purple fallback
/// match the engine exactly.
public enum StockThemes {
    /// Looks up a preset theme by name (case-insensitive, whitespace-trimmed).
    /// Unknown names fall back to Purple.
    public static func theme(named name: String, isDark: Bool = true) -> ThemePalette {
        if let palette = try? DankThemeEngine.resolveTheme(.preset(name, isDark: isDark)) {
            return ThemePalette(dte: palette)
        }
        return isDark ? .defaultDark : .defaultLight
    }

    /// Core stock theme names, as reported by `DankThemeEngine.stockThemes()`.
    public static let allThemeNames: [String] = {
        if let themes = try? DankThemeEngine.stockThemes() {
            let names = themes.filter { !$0.community }.map(\.name)
            if !names.isEmpty { return names }
        }
        return ["purple", "blue", "green", "orange", "red", "yellow", "neutral"]
    }()

    /// Community theme names, as reported by `DankThemeEngine.stockThemes()`.
    public static let communityThemeNames: [String] = {
        if let themes = try? DankThemeEngine.stockThemes() {
            let names = themes.filter(\.community).map(\.name)
            if !names.isEmpty { return names }
        }
        return ["catppuccin-mocha", "catppuccin-latte", "nord", "gruvbox", "tokyo-night", "everforest"]
    }()

    public static let allAvailableThemes = allThemeNames + communityThemeNames

    // MARK: - Purple (Default DMS theme)
    public static let purpleDark = theme(named: "purple", isDark: true)
    public static let purpleLight = theme(named: "purple", isDark: false)

    // MARK: - Blue
    public static let blueDark = theme(named: "blue", isDark: true)
    public static let blueLight = theme(named: "blue", isDark: false)

    // MARK: - Green
    public static let greenDark = theme(named: "green", isDark: true)
    public static let greenLight = theme(named: "green", isDark: false)

    // MARK: - Orange
    public static let orangeDark = theme(named: "orange", isDark: true)
    public static let orangeLight = theme(named: "orange", isDark: false)

    // MARK: - Red
    public static let redDark = theme(named: "red", isDark: true)
    public static let redLight = theme(named: "red", isDark: false)

    // MARK: - Yellow
    public static let yellowDark = theme(named: "yellow", isDark: true)
    public static let yellowLight = theme(named: "yellow", isDark: false)

    // MARK: - Neutral
    public static let neutralDark = theme(named: "neutral", isDark: true)
    public static let neutralLight = theme(named: "neutral", isDark: false)

    // MARK: - Catppuccin (Mocha / Latte)
    public static let catppuccinMocha = theme(named: "catppuccin-mocha", isDark: true)
    public static let catppuccinLatte = theme(named: "catppuccin-latte", isDark: false)

    // MARK: - Nord
    public static let nordDark = theme(named: "nord", isDark: true)
    public static let nordLight = theme(named: "nord", isDark: false)

    // MARK: - Gruvbox
    public static let gruvboxDark = theme(named: "gruvbox", isDark: true)
    public static let gruvboxLight = theme(named: "gruvbox", isDark: false)

    // MARK: - Tokyo Night
    public static let tokyoNightDark = theme(named: "tokyo-night", isDark: true)
    public static let tokyoNightLight = theme(named: "tokyo-night", isDark: false)

    // MARK: - Everforest
    public static let everforestDark = theme(named: "everforest", isDark: true)
    public static let everforestLight = theme(named: "everforest", isDark: false)
}
