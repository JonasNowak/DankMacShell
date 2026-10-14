import SwiftUI
import AppKit
import DMSCore

@MainActor
public final class ThemeStore: ObservableObject {
    public static let shared = ThemeStore()

    @Published public private(set) var palette: ThemePalette
    @Published public var themeName: String = "purple" {
        didSet {
            refreshTheme()
        }
    }
    @Published public var isLightMode: Bool = false {
        didSet {
            refreshTheme()
        }
    }

    private var dynamicPalettes: (dark: ThemePalette, light: ThemePalette)?

    private init() {
        self.palette = StockThemes.theme(named: "purple", isDark: true)
        setupWallpaperObserver()
        extractWallpaperSeed()
    }

    public func apply(theme: String, lightMode: Bool) {
        self.themeName = theme
        self.isLightMode = lightMode
        refreshTheme()
    }

    public func toggleLightMode() {
        self.isLightMode.toggle()
        refreshTheme()
    }

    public func refreshTheme() {
        if themeName.lowercased() == "dynamic" {
            if dynamicPalettes == nil {
                extractWallpaperSeed()
            }
            if let dp = dynamicPalettes {
                self.palette = isLightMode ? dp.light : dp.dark
            } else {
                self.palette = StockThemes.theme(named: "purple", isDark: !isLightMode)
            }
        } else {
            self.palette = StockThemes.theme(named: themeName, isDark: !isLightMode)
        }
    }

    private func setupWallpaperObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.extractWallpaperSeed()
            }
        }
    }

    public func extractWallpaperSeed() {
        guard let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let img = NSImage(contentsOf: url) else {
            return
        }

        guard let seedColor = extractDominantColor(from: img) else { return }
        let (dark, light) = DynamicThemeGenerator.generate(from: seedColor, name: "Dynamic")
        self.dynamicPalettes = (dark, light)

        if themeName.lowercased() == "dynamic" {
            self.palette = isLightMode ? light : dark
        }
    }

    private func extractDominantColor(from image: NSImage) -> M3Color? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
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
                // Ignore extreme darks and extreme whites for seed extraction
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

    // MARK: - Convenient Color Accessors
    public var primary: Color { Color(hex: palette.primary.hex) }
    public var onPrimary: Color { Color(hex: palette.onPrimary.hex) }
    public var primaryContainer: Color { Color(hex: palette.primaryContainer.hex) }
    public var onPrimaryContainer: Color { Color(hex: palette.onPrimaryContainer.hex) }

    public var secondary: Color { Color(hex: palette.secondary.hex) }
    public var onSecondary: Color { Color(hex: palette.onSecondary.hex) }
    public var secondaryContainer: Color { Color(hex: palette.secondaryContainer.hex) }
    public var onSecondaryContainer: Color { Color(hex: palette.onSecondaryContainer.hex) }

    public var tertiary: Color { Color(hex: palette.tertiary.hex) }
    public var onTertiary: Color { Color(hex: palette.onTertiary.hex) }
    public var tertiaryContainer: Color { Color(hex: palette.tertiaryContainer.hex) }
    public var onTertiaryContainer: Color { Color(hex: palette.onTertiaryContainer.hex) }

    public var surface: Color { Color(hex: palette.surface.hex) }
    public var onSurface: Color { Color(hex: palette.onSurface.hex) }
    public var surfaceVariant: Color { Color(hex: palette.surfaceVariant.hex) }
    public var onSurfaceVariant: Color { Color(hex: palette.onSurfaceVariant.hex) }

    public var surfaceContainerLowest: Color { Color(hex: palette.surfaceContainerLowest.hex) }
    public var surfaceContainerLow: Color { Color(hex: palette.surfaceContainerLow.hex) }
    public var surfaceContainer: Color { Color(hex: palette.surfaceContainer.hex) }
    public var surfaceContainerHigh: Color { Color(hex: palette.surfaceContainerHigh.hex) }
    public var surfaceContainerHighest: Color { Color(hex: palette.surfaceContainerHighest.hex) }

    public var background: Color { Color(hex: palette.background.hex) }
    public var onBackground: Color { Color(hex: palette.onBackground.hex) }
    public var outline: Color { Color(hex: palette.outline.hex) }
    public var outlineVariant: Color { Color(hex: palette.outlineVariant.hex) }

    public var warning: Color { Color(hex: palette.warning.hex) }
    public var info: Color { Color(hex: palette.info.hex) }
    public var success: Color { Color(hex: palette.success.hex) }
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
