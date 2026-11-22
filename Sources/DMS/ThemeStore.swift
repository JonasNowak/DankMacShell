import SwiftUI
import AppKit
import CoreText
import DMSCore
import DankThemeEngine

@MainActor
public final class ThemeStore: ObservableObject {
    public static let shared = ThemeStore()

    @Published public private(set) var palette: ThemePalette {
        didSet {
            guard oldValue != palette else { return }
            rebuildCachedColors()
            // v0.7 THEME: live terminal emulator theme sync + events.theme broadcast
            TerminalThemeExporter.shared.exportIfEnabled(
                palette: palette,
                themeName: themeName,
                isDark: palette.isDark
            )
            EventSubscriptionBroker.shared.broadcast(event: "events.theme", payload: [
                "theme": themeName,
                "isDark": palette.isDark,
                "isLightMode": isLightMode,
                "primary": palette.primary.hex,
                "surface": palette.surface.hex,
                "onSurface": palette.onSurface.hex
            ])
        }
    }

    @Published public var themeName: String = "purple" {
        didSet {
            guard !isBatchUpdating, oldValue != themeName else { return }
            refreshTheme()
        }
    }

    @Published public var isLightMode: Bool = false {
        didSet {
            guard !isBatchUpdating, oldValue != isLightMode else { return }
            refreshTheme()
        }
    }

    @Published public var themeMode: String = "dark" {
        didSet {
            guard !isBatchUpdating, oldValue != themeMode else { return }
            applyThemeMode()
        }
    }

    @Published public var customSeedHex: String = "#D0BCFF" {
        didSet {
            guard !isBatchUpdating, oldValue != customSeedHex else { return }
            refreshTheme()
        }
    }

    @Published public var matugenScheme: MatugenScheme = .tonalSpot {
        didSet {
            guard !isBatchUpdating, oldValue != matugenScheme else { return }
            refreshTheme()
        }
    }

    @Published public var matugenContrast: Double = 0.0 {
        didSet {
            guard !isBatchUpdating, oldValue != matugenContrast else { return }
            refreshTheme()
        }
    }

    // MARK: - M3 Design System Token Sets
    @Published public var shapeTokens: M3ShapeTokens = M3ShapeTokens()
    @Published public var motionTokens: M3MotionTokens = M3MotionTokens()
    @Published public var typographyTokens: M3TypographyTokens = M3TypographyTokens()
    @Published public var surfaceTokens: M3SurfaceTokens = M3SurfaceTokens()
    @Published public var shadowTokens: M3ShadowTokens = M3ShadowTokens()
    @Published public private(set) var dank16Palette: [M3Color] = []
    @Published public private(set) var primaryTonalPalette: M3TonalPalette = M3TonalPalette(hue: 275, chroma: 48)

    // MARK: - Font Catalog & Single-Font Mode
    @Published public var useSingleFontEverywhere: Bool = false
    @Published public var fontFamilyNerd: String = "Auto"
    @Published public var customFontPaths: [String] = []
    @Published public private(set) var installedFontFamilies: [String] = []
    @Published public private(set) var detectedNerdFonts: [String] = []

    private var isBatchUpdating = false
    private var dynamicSeedColor: M3Color?
    private var dynamicSecondarySeedColor: M3Color?
    private var lastWallpaperURL: URL?
    private var extractionTask: Task<Void, Never>?

    // MARK: - Cached SwiftUI Colors (Eliminates per-render hex string parsing)
    public private(set) var primary: Color = .clear
    public private(set) var onPrimary: Color = .clear
    public private(set) var primaryContainer: Color = .clear
    public private(set) var onPrimaryContainer: Color = .clear

    public private(set) var secondary: Color = .clear
    public private(set) var onSecondary: Color = .clear
    public private(set) var secondaryContainer: Color = .clear
    public private(set) var onSecondaryContainer: Color = .clear

    public private(set) var tertiary: Color = .clear
    public private(set) var onTertiary: Color = .clear
    public private(set) var tertiaryContainer: Color = .clear
    public private(set) var onTertiaryContainer: Color = .clear

    public private(set) var surface: Color = .clear
    public private(set) var onSurface: Color = .clear
    public private(set) var surfaceVariant: Color = .clear
    public private(set) var onSurfaceVariant: Color = .clear

    public private(set) var surfaceContainerLowest: Color = .clear
    public private(set) var surfaceContainerLow: Color = .clear
    public private(set) var surfaceContainer: Color = .clear
    public private(set) var surfaceContainerHigh: Color = .clear
    public private(set) var surfaceContainerHighest: Color = .clear

    public private(set) var background: Color = .clear
    public private(set) var onBackground: Color = .clear
    public private(set) var outline: Color = .clear
    public private(set) var outlineVariant: Color = .clear
    public private(set) var scrim: Color = .clear
    public private(set) var shadow: Color = .clear

    public private(set) var error: Color = .clear
    public private(set) var onError: Color = .clear
    public private(set) var errorContainer: Color = .clear
    public private(set) var onErrorContainer: Color = .clear

    public private(set) var warning: Color = .clear
    public private(set) var onWarning: Color = .clear
    public private(set) var warningContainer: Color = .clear
    public private(set) var onWarningContainer: Color = .clear

    public private(set) var info: Color = .clear
    public private(set) var onInfo: Color = .clear
    public private(set) var infoContainer: Color = .clear
    public private(set) var onInfoContainer: Color = .clear

    public private(set) var success: Color = .clear
    public private(set) var onSuccess: Color = .clear
    public private(set) var successContainer: Color = .clear
    public private(set) var onSuccessContainer: Color = .clear

    // MARK: - M3 Expressive Extended Surface & Fixed Accent Colors
    public private(set) var surfaceDim: Color = .clear
    public private(set) var surfaceBright: Color = .clear
    public private(set) var inverseSurface: Color = .clear
    public private(set) var inverseOnSurface: Color = .clear

    public private(set) var primaryFixed: Color = .clear
    public private(set) var primaryFixedDim: Color = .clear
    public private(set) var onPrimaryFixed: Color = .clear
    public private(set) var onPrimaryFixedVariant: Color = .clear

    public private(set) var secondaryFixed: Color = .clear
    public private(set) var secondaryFixedDim: Color = .clear
    public private(set) var onSecondaryFixed: Color = .clear
    public private(set) var onSecondaryFixedVariant: Color = .clear

    public private(set) var tertiaryFixed: Color = .clear
    public private(set) var tertiaryFixedDim: Color = .clear
    public private(set) var onTertiaryFixed: Color = .clear
    public private(set) var onTertiaryFixedVariant: Color = .clear

    private init() {
        let initialPalette = StockThemes.theme(named: "purple", isDark: true)
        self.palette = initialPalette
        rebuildCachedColors()
        setupWallpaperObserver()
        setupSystemAppearanceObserver()
        extractWallpaperSeed()
        // Populate system/Nerd fonts without touching ConfigStore.shared (which calls
        // ThemeStore.shared.sync(with:) during its own dispatch_once init).
        refreshFontCatalog(customPaths: [])
    }

    private func rebuildCachedColors() {
        primary = Color(hex: palette.primary.hex)
        onPrimary = Color(hex: palette.onPrimary.hex)
        primaryContainer = Color(hex: palette.primaryContainer.hex)
        onPrimaryContainer = Color(hex: palette.onPrimaryContainer.hex)

        secondary = Color(hex: palette.secondary.hex)
        onSecondary = Color(hex: palette.onSecondary.hex)
        secondaryContainer = Color(hex: palette.secondaryContainer.hex)
        onSecondaryContainer = Color(hex: palette.onSecondaryContainer.hex)

        tertiary = Color(hex: palette.tertiary.hex)
        onTertiary = Color(hex: palette.onTertiary.hex)
        tertiaryContainer = Color(hex: palette.tertiaryContainer.hex)
        onTertiaryContainer = Color(hex: palette.onTertiaryContainer.hex)

        surface = Color(hex: palette.surface.hex)
        onSurface = Color(hex: palette.onSurface.hex)
        surfaceVariant = Color(hex: palette.surfaceVariant.hex)
        onSurfaceVariant = Color(hex: palette.onSurfaceVariant.hex)

        surfaceContainerLowest = Color(hex: palette.surfaceContainerLowest.hex)
        surfaceContainerLow = Color(hex: palette.surfaceContainerLow.hex)
        surfaceContainer = Color(hex: palette.surfaceContainer.hex)
        surfaceContainerHigh = Color(hex: palette.surfaceContainerHigh.hex)
        surfaceContainerHighest = Color(hex: palette.surfaceContainerHighest.hex)

        background = Color(hex: palette.background.hex)
        onBackground = Color(hex: palette.onBackground.hex)
        outline = Color(hex: palette.outline.hex)
        outlineVariant = Color(hex: palette.outlineVariant.hex)
        scrim = Color(hex: palette.scrim.hex)
        shadow = Color(hex: palette.shadow.hex)

        error = Color(hex: palette.error.hex)
        onError = Color(hex: palette.onError.hex)
        errorContainer = Color(hex: palette.errorContainer.hex)
        onErrorContainer = Color(hex: palette.onErrorContainer.hex)

        warning = Color(hex: palette.warning.hex)
        onWarning = Color(hex: palette.onWarning.hex)
        warningContainer = Color(hex: palette.warningContainer.hex)
        onWarningContainer = Color(hex: palette.onWarningContainer.hex)

        info = Color(hex: palette.info.hex)
        onInfo = Color(hex: palette.onInfo.hex)
        infoContainer = Color(hex: palette.infoContainer.hex)
        onInfoContainer = Color(hex: palette.onInfoContainer.hex)

        success = Color(hex: palette.success.hex)
        onSuccess = Color(hex: palette.onSuccess.hex)
        successContainer = Color(hex: palette.successContainer.hex)
        onSuccessContainer = Color(hex: palette.onSuccessContainer.hex)

        surfaceDim = Color(hex: palette.surfaceDim.hex)
        surfaceBright = Color(hex: palette.surfaceBright.hex)
        inverseSurface = Color(hex: palette.inverseSurface.hex)
        inverseOnSurface = Color(hex: palette.inverseOnSurface.hex)

        primaryFixed = Color(hex: palette.primaryFixed.hex)
        primaryFixedDim = Color(hex: palette.primaryFixedDim.hex)
        onPrimaryFixed = Color(hex: palette.onPrimaryFixed.hex)
        onPrimaryFixedVariant = Color(hex: palette.onPrimaryFixedVariant.hex)

        secondaryFixed = Color(hex: palette.secondaryFixed.hex)
        secondaryFixedDim = Color(hex: palette.secondaryFixedDim.hex)
        onSecondaryFixed = Color(hex: palette.onSecondaryFixed.hex)
        onSecondaryFixedVariant = Color(hex: palette.onSecondaryFixedVariant.hex)

        tertiaryFixed = Color(hex: palette.tertiaryFixed.hex)
        tertiaryFixedDim = Color(hex: palette.tertiaryFixedDim.hex)
        onTertiaryFixed = Color(hex: palette.onTertiaryFixed.hex)
        onTertiaryFixedVariant = Color(hex: palette.onTertiaryFixedVariant.hex)

        dank16Palette = Dank16Generator.generate(from: palette).colors
        let hct = HCT.from(color: palette.primary)
        primaryTonalPalette = M3TonalPalette(hue: hct.hue, chroma: max(36.0, hct.chroma))
    }

    /// Synchronizes all global theme, shape, motion, typography, surface, and shadow tokens from `DMSConfig` in a single batch.
    public func sync(with config: DMSConfig) {
        isBatchUpdating = true
        self.themeName = config.theme
        self.themeMode = config.themeMode
        if config.themeMode == "system" {
            self.isLightMode = Self.detectSystemLightMode()
        } else {
            self.isLightMode = config.isLightMode
        }
        self.customSeedHex = config.themeSeedColor
        self.matugenScheme = config.matugenScheme
        self.matugenContrast = config.matugenContrast
        self.shapeTokens = config.shapeTokens
        self.motionTokens = config.motionTokens
        self.typographyTokens = config.typographyTokens
        self.surfaceTokens = config.surfaceTokens
        self.shadowTokens = config.shadowTokens
        self.useSingleFontEverywhere = config.useSingleFontEverywhere
        self.fontFamilyNerd = config.fontFamilyNerd
        if customFontPaths != config.customFontPaths || installedFontFamilies.isEmpty {
            refreshFontCatalog(customPaths: config.customFontPaths)
        }
        self.customFontPaths = config.customFontPaths
        isBatchUpdating = false
        refreshTheme()
    }

    public func apply(theme: String, lightMode: Bool) {
        isBatchUpdating = true
        self.themeName = theme
        self.isLightMode = lightMode
        isBatchUpdating = false
        refreshTheme()
    }

    public func apply(theme: String) {
        self.themeName = theme
    }

    public func setDynamicWallpaper() {
        self.themeName = "dynamic"
        ConfigStore.shared.update { $0.theme = "dynamic" }
        extractWallpaperSeed(force: true)
    }

    /// Automatically sets theme to dynamic and extracts dominant colors from the specified wallpaper image URL.
    public func applyDynamicWallpaper(url: URL) {
        self.themeName = "dynamic"
        ConfigStore.shared.update { $0.theme = "dynamic" }
        self.lastWallpaperURL = url

        extractionTask?.cancel()
        let task = Task { @MainActor [weak self] in
            let (seedColor, secondarySeed) = await Task.detached(priority: .userInitiated) { () -> (M3Color?, M3Color?) in
                let seeds = Self.extractPaletteSeedsOffMainThread(from: url)
                let primarySeed = seeds?.primary ?? Self.extractDominantColorOffMainThread(from: url)
                return (primarySeed, seeds?.secondary)
            }.value
            // A newer wallpaper change may have started its own extraction — never apply
            // stale results out of order.
            guard let self = self, !Task.isCancelled, let seedColor = seedColor else { return }
            self.dynamicSeedColor = seedColor
            self.dynamicSecondarySeedColor = secondarySeed
            self.refreshTheme()
        }
        extractionTask = task
    }

    public func toggleLightMode() {
        self.isLightMode.toggle()
    }

    public func setLightMode(_ light: Bool) {
        self.isLightMode = light
    }

    private func applyThemeMode() {
        switch themeMode.lowercased() {
        case "light":
            isLightMode = true
        case "dark":
            isLightMode = false
        case "system":
            isLightMode = Self.detectSystemLightMode()
        default:
            break
        }
    }

    public static func detectSystemLightMode() -> Bool {
        if let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
            return style.lowercased() != "dark"
        }
        return true
    }

    public func refreshTheme() {
        let lower = themeName.lowercased()
        let contrast: ContrastLevel = matugenContrast >= 0.5 ? .high : (matugenContrast >= 0.2 ? .medium : .standard)

        if lower == "dynamic" {
            if let seed = dynamicSeedColor {
                let (dark, light) = DynamicThemeGenerator.generate(
                    from: seed,
                    name: "Dynamic",
                    contrast: contrast,
                    scheme: matugenScheme
                )
                self.palette = isLightMode ? light : dark
            } else {
                extractWallpaperSeed(force: true)
                self.palette = StockThemes.theme(named: "purple", isDark: !isLightMode)
            }
        } else if lower == "custom" || lower.hasPrefix("#") {
            let hex = lower.hasPrefix("#") ? themeName : customSeedHex
            let seed = M3Color(hex)
            let (dark, light) = DynamicThemeGenerator.generate(
                from: seed,
                name: "Custom",
                contrast: contrast,
                scheme: matugenScheme
            )
            self.palette = isLightMode ? light : dark
        } else {
            self.palette = StockThemes.theme(named: themeName, isDark: !isLightMode)
        }

        let targetAppearanceName: NSAppearance.Name = isLightMode ? .aqua : .darkAqua
        if let app = NSApp, app.appearance?.name != targetAppearanceName {
            app.appearance = NSAppearance(named: targetAppearanceName)
        }

        // Auto-theme OmniWM window borders and UI if enabled
        OmniWMThemeSyncService.shared.syncThemeIfEnabled(palette: self.palette, secondarySeed: dynamicSecondarySeedColor)
    }

    // MARK: - Adaptive Surface, Glass & Light Mode Helpers

    /// Adaptive background for bar widget capsules that respects glass/transparent bar modes and Light Mode contrast.
    public var barWidgetBackground: Color {
        let cfg = ConfigStore.shared.config
        let bar = cfg.barConfigs.first ?? .default
        let style = bar.backgroundStyle.lowercased()
        let isGlassOrTranslucent = style == "glass"
            || style == "island"
            || style == "transparent"
            || cfg.barTransparent
            || bar.transparency < 0.99
            || surfaceTokens.surfaceOpacity < 0.99

        if isGlassOrTranslucent {
            if isLightMode {
                return surfaceContainerLowest.opacity(0.72)
            } else {
                return surfaceContainerHigh.opacity(0.58)
            }
        } else {
            // In solid Light Mode, elevated white capsules on the soft tinted bar look crisp rather than muddy gray.
            return isLightMode ? surfaceContainerLowest : surfaceContainerHigh
        }
    }

    /// Adaptive background for cards, tiles, and rows inside panels/popouts.
    public var cardBackground: Color {
        let cfg = ConfigStore.shared.config
        let isGlass = cfg.barTransparent
            || cfg.popupTransparency < 0.99
            || surfaceTokens.surfaceOpacity < 0.99
        if isGlass {
            return isLightMode ? surfaceContainerLowest.opacity(0.75) : surfaceContainerHigh.opacity(0.68)
        }
        return isLightMode ? surfaceContainerLowest : surfaceContainerHigh
    }

    /// Adaptive background for headers and footers inside panels/popouts.
    public var panelHeaderBackground: Color {
        let cfg = ConfigStore.shared.config
        let isGlass = cfg.barTransparent
            || cfg.popupTransparency < 0.99
            || surfaceTokens.surfaceOpacity < 0.99
        if isGlass {
            return isLightMode ? surfaceContainerLow.opacity(0.55) : surfaceContainerHigh.opacity(0.55)
        }
        return isLightMode ? surfaceContainerLow : surfaceContainerHigh
    }

    /// Subtle progress/gauge track color visible in both Light and Dark mode.
    public var subtleTrackColor: Color {
        isLightMode ? outlineVariant.opacity(0.55) : Color.white.opacity(0.14)
    }

    /// Crisp perimeter border stroke color for floating glass and surface panels.
    public var panelBorderColor: Color {
        if isLightMode {
            return outlineVariant.opacity(0.65)
        }
        return outlineVariant.opacity(0.38)
    }

    /// Elevation shadow color scaled appropriately for Light Mode vs Dark Mode.
    public func adaptiveShadowColor(baseOpacity: Double = 0.35) -> Color {
        Color.black.opacity(isLightMode ? baseOpacity * 0.45 : baseOpacity)
    }

    // MARK: - Typography, Motion & Shape Helpers

    public var fastSpatialAnimation: Animation { motionTokens.fastSpatialAnimation }
    public var defaultSpatialAnimation: Animation { motionTokens.defaultSpatialAnimation }
    public var slowSpatialAnimation: Animation { motionTokens.slowSpatialAnimation }
    public var fastEffectsAnimation: Animation { motionTokens.fastEffectsAnimation }
    public var defaultEffectsAnimation: Animation { motionTokens.defaultEffectsAnimation }
    public var slowEffectsAnimation: Animation { motionTokens.slowEffectsAnimation }

    public func scaledRadius(_ base: CGFloat) -> CGFloat {
        CGFloat(shapeTokens.scaled(Double(base)))
    }

    public func morphedRadius(_ base: CGFloat, progress: CGFloat, targetScale: Double? = nil) -> CGFloat {
        CGFloat(shapeTokens.morphedRadius(base: Double(base), progress: Double(progress), targetScale: targetScale))
    }

    // MARK: - Font Catalog

    /// Registers user-imported font files with the process and rebuilds the installed /
    /// detected Nerd Font family catalogs.
    public func refreshFontCatalog(customPaths: [String] = []) {
        for path in customPaths where FileManager.default.fileExists(atPath: path) {
            CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: path) as CFURL, .process, nil)
        }
        installedFontFamilies = NSFontManager.shared.availableFontFamilies.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        detectedNerdFonts = installedFontFamilies.filter {
            let l = $0.lowercased()
            return l.contains("nerd") || l.hasSuffix(" nf") || l.hasSuffix(" nfm")
                || l.contains("nerd font") || l.contains("powerline")
        }
    }

    /// The font family actually used for Nerd Font icons and glyphs.
    public var resolvedNerdFontFamily: String {
        if useSingleFontEverywhere,
           typographyTokens.fontFamilyUI.lowercased() != "system",
           !typographyTokens.fontFamilyUI.isEmpty {
            return typographyTokens.fontFamilyUI
        }
        if fontFamilyNerd != "Auto" && !fontFamilyNerd.isEmpty {
            return fontFamilyNerd
        }
        if let firstNerd = detectedNerdFonts.first {
            return firstNerd
        }
        return typographyTokens.fontFamilyMono
    }

    /// Font for Nerd Font icons/glyphs, scaled by the global font scale.
    public func nerdFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let scaledSize = size * CGFloat(typographyTokens.fontScale)
        let family = resolvedNerdFontFamily
        let lower = family.lowercased()
        if lower == "system" || lower == "sf pro" || lower == "sf mono" || lower.isEmpty {
            return .system(size: scaledSize, weight: weight, design: .monospaced)
        }
        return .custom(family, size: scaledSize).weight(weight)
    }

    public func font(for role: M3TypeScaleRole, emphasized: Bool = false) -> Font {
        let style = typographyTokens.style(for: role, emphasized: emphasized)
        let isDisplay = role == .displayLarge || role == .displayMedium || role == .displaySmall
        return font(
            size: CGFloat(style.size / max(0.01, typographyTokens.fontScale)),
            weight: style.swiftUIWeight,
            mono: false,
            display: isDisplay && !emphasized
        )
    }

    public func font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default, mono: Bool = false, display: Bool = false) -> Font {
        let scaledSize = size * CGFloat(typographyTokens.fontScale)
        let isMono = mono || (design == .monospaced && !useSingleFontEverywhere)
        let family = useSingleFontEverywhere ? typographyTokens.fontFamilyUI : (isMono ? typographyTokens.fontFamilyMono : (display ? typographyTokens.fontFamilyDisplay : typographyTokens.fontFamilyUI))
        let lower = family.lowercased()
        if lower == "system" || lower == "sf pro" || lower.isEmpty {
            return .system(size: scaledSize, weight: weight, design: isMono ? .monospaced : design)
        } else if lower == "sf mono" && isMono {
            return .system(size: scaledSize, weight: weight, design: .monospaced)
        } else if lower == "new york" || lower == "serif" {
            return .system(size: scaledSize, weight: weight, design: .serif)
        } else if lower == "sf pro rounded" || lower == "rounded" {
            return .system(size: scaledSize, weight: weight, design: .rounded)
        }
        return .custom(family, size: scaledSize).weight(weight)
    }

    // MARK: - Observers & Off-Main-Thread Wallpaper Extraction

    private func setupWallpaperObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.extractWallpaperSeed(force: false)
            }
        }
    }

    private func setupSystemAppearanceObserver() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.themeMode.lowercased() == "system" else { return }
                self.isLightMode = Self.detectSystemLightMode()
            }
        }
    }

    public func extractWallpaperSeed(from customURL: URL? = nil, force: Bool = false) {
        let url: URL
        if let customURL = customURL {
            url = customURL
        } else {
            guard let screen = NSScreen.main ?? NSScreen.screens.first,
                  let desktopURL = NSWorkspace.shared.desktopImageURL(for: screen) else {
                return
            }
            url = desktopURL
        }
        if !force, url == lastWallpaperURL, dynamicSeedColor != nil {
            return
        }
        lastWallpaperURL = url

        extractionTask?.cancel()
        let task = Task { @MainActor [weak self] in
            let seedColor = await Task.detached(priority: .utility) { () -> M3Color? in
                Self.extractDominantColorOffMainThread(from: url)
            }.value
            guard let self = self, !Task.isCancelled, let seedColor = seedColor else { return }
            self.dynamicSeedColor = seedColor
            if self.themeName.lowercased() == "dynamic" {
                self.refreshTheme()
            }
        }
        extractionTask = task
    }

    nonisolated private static func extractDominantColorOffMainThread(from url: URL) -> M3Color? {
        // Wallpaper quantization lives in the Rust-backed DankThemeEngine.
        // Missing/unreadable files throw there and surface as nil; images with no
        // usable pixels fall back to the M3 default seed inside the engine.
        guard let color = try? DankThemeEngine.extractWallpaperSeed(from: url.path) else {
            return nil
        }
        return M3Color(color)
    }

    /// Extracts both primary dominant color and contrasting secondary chromatic cluster from wallpaper pixels.
    nonisolated public static func extractPaletteSeedsOffMainThread(from url: URL) -> (primary: M3Color, secondary: M3Color)? {
        guard let seeds = try? DankThemeEngine.extractPaletteSeeds(from: url.path, count: 2),
              seeds.count >= 2 else {
            return nil
        }
        return (primary: M3Color(seeds[0]), secondary: M3Color(seeds[1]))
    }
}
