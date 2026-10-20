import SwiftUI
import AppKit
import DMSCore

@MainActor
public final class ThemeStore: ObservableObject {
    public static let shared = ThemeStore()

    @Published public private(set) var palette: ThemePalette {
        didSet {
            rebuildCachedColors()
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

    private var isBatchUpdating = false
    private var dynamicSeedColor: M3Color?
    private var lastWallpaperURL: URL?

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

    private init() {
        let initialPalette = StockThemes.theme(named: "purple", isDark: true)
        self.palette = initialPalette
        rebuildCachedColors()
        setupWallpaperObserver()
        setupSystemAppearanceObserver()
        extractWallpaperSeed()
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
        extractWallpaperSeed(force: true)
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
        let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
        let match = appearance.bestMatch(from: [.aqua, .darkAqua])
        return match == .aqua
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
    }

    // MARK: - Typography & Shape Helpers

    public func scaledRadius(_ base: CGFloat) -> CGFloat {
        CGFloat(shapeTokens.scaled(Double(base)))
    }

    public func font(size: CGFloat, weight: Font.Weight = .regular, mono: Bool = false, display: Bool = false) -> Font {
        let scaledSize = size * CGFloat(typographyTokens.fontScale)
        let family = mono ? typographyTokens.fontFamilyMono : (display ? typographyTokens.fontFamilyDisplay : typographyTokens.fontFamilyUI)
        let lower = family.lowercased()
        if lower == "system" || lower == "sf pro" || lower.isEmpty {
            return .system(size: scaledSize, weight: weight, design: mono ? .monospaced : .default)
        } else if lower == "sf mono" && mono {
            return .system(size: scaledSize, weight: weight, design: .monospaced)
        } else if lower == "New York".lowercased() || lower == "serif" {
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

    public func extractWallpaperSeed(force: Bool = false) {
        guard let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            return
        }
        if !force, url == lastWallpaperURL, dynamicSeedColor != nil {
            return
        }
        lastWallpaperURL = url

        Task.detached(priority: .utility) { [weak self] in
            guard let seedColor = Self.extractDominantColorOffMainThread(from: url) else { return }
            await MainActor.run {
                guard let self = self else { return }
                self.dynamicSeedColor = seedColor
                if self.themeName.lowercased() == "dynamic" {
                    self.refreshTheme()
                }
            }
        }
    }

    nonisolated private static func extractDominantColorOffMainThread(from url: URL) -> M3Color? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        let width = 32
        let height = 32
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalR: Double = 0
        var totalG: Double = 0
        var totalB: Double = 0
        var count: Double = 0

        for i in stride(from: 0, to: rawData.count, by: 4) {
            let r = Double(rawData[i]) / 255.0
            let g = Double(rawData[i + 1]) / 255.0
            let b = Double(rawData[i + 2]) / 255.0
            let a = Double(rawData[i + 3]) / 255.0

            if a > 0.5 {
                let l = (r + g + b) / 3.0
                if l > 0.1 && l < 0.9 {
                    totalR += r
                    totalG += g
                    totalB += b
                    count += 1
                }
            }
        }

        guard count > 0 else {
            return M3Color("#6750A4")
        }

        return M3Color.from(r: totalR / count, g: totalG / count, b: totalB / count)
    }
}

public extension Color {
    init(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") {
            clean.removeFirst()
        }
        if clean.count == 3 {
            let r = clean[clean.startIndex]
            let g = clean[clean.index(clean.startIndex, offsetBy: 1)]
            let b = clean[clean.index(clean.startIndex, offsetBy: 2)]
            clean = "\(r)\(r)\(g)\(g)\(b)\(b)"
        }
        guard clean.count >= 6, let hexNum = UInt64(clean.prefix(6), radix: 16) else {
            self = .clear
            return
        }
        let r = Double((hexNum >> 16) & 0xFF) / 255.0
        let g = Double((hexNum >> 8) & 0xFF) / 255.0
        let b = Double(hexNum & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
