import SwiftUI
import AppKit
import DMSCore

/// Theme provider for the Nokia Belle USB Sync companion application.
/// Mirrors the DMS shell theme: reads the shared DMS config (`settings.json`,
/// falling back to legacy `config.json`) and resolves the palette exactly like
/// `ThemeStore.refreshTheme()` — stock themes, custom seed hex, and the dynamic
/// wallpaper-derived theme — including light/dark mode, matugen scheme, and
/// contrast. Re-reads the config when it changes on disk.
@MainActor
public final class SymbianThemeStore: ObservableObject {
    public static let shared = SymbianThemeStore()

    @Published public private(set) var palette: DMSPalette
    @Published public private(set) var isLightMode: Bool = false

    private let configDirectory: URL
    private var watcherSource: (any DispatchSourceFileSystemObject)?
    private var watcherFD: Int32 = -1

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.configDirectory = appSupport.appendingPathComponent("DMS", isDirectory: true)
        self.isLightMode = false
        self.palette = StockThemes.theme(named: "purple", isDark: true)
        refresh()
        startWatching()
    }

    // MARK: - Config loading

    private var configFile: URL {
        let modern = configDirectory.appendingPathComponent("settings.json")
        if FileManager.default.fileExists(atPath: modern.path) { return modern }
        return configDirectory.appendingPathComponent("config.json")
    }

    private func loadConfig() -> DMSConfig? {
        guard let data = try? Data(contentsOf: configFile) else { return nil }
        return DMSConfig.load(from: data, baseDirectory: configDirectory)
    }

    // MARK: - Theme resolution (mirrors ThemeStore.refreshTheme)

    public func refresh() {
        let config = loadConfig() ?? .default
        let lower = config.theme.lowercased()

        // Light/dark: explicit themeMode wins, then system appearance
        let light: Bool
        switch config.themeMode.lowercased() {
        case "light": light = true
        case "dark": light = false
        case "system": light = Self.detectSystemLightMode()
        default: light = config.isLightMode
        }
        self.isLightMode = light

        let contrast: ContrastLevel = config.matugenContrast >= 0.5 ? .high : (config.matugenContrast >= 0.2 ? .medium : .standard)
        let scheme = config.matugenScheme

        if lower == "dynamic" {
            let seed = dynamicSeed(from: config) ?? M3Color(config.themeSeedColor)
            let (dark, lightPalette) = DynamicThemeGenerator.generate(from: seed, name: "Dynamic", contrast: contrast, scheme: scheme)
            self.palette = light ? lightPalette : dark
        } else if lower == "custom" || lower.hasPrefix("#") {
            let hex = lower.hasPrefix("#") ? config.theme : config.themeSeedColor
            let seed = M3Color(hex)
            let (dark, lightPalette) = DynamicThemeGenerator.generate(from: seed, name: "Custom", contrast: contrast, scheme: scheme)
            self.palette = light ? lightPalette : dark
        } else {
            self.palette = StockThemes.theme(named: config.theme, isDark: !light)
        }

        let targetAppearance: NSAppearance.Name = light ? .aqua : .darkAqua
        if let app = NSApp, app.appearance?.name != targetAppearance {
            app.appearance = NSAppearance(named: targetAppearance)
        }
    }

    /// Seed color for the dynamic theme: dominant color of the configured wallpaper.
    private func dynamicSeed(from config: DMSConfig) -> M3Color? {
        let path = config.wallpaperPath
        guard !path.isEmpty else { return nil }
        return WallpaperSeedColor.dominantColor(from: URL(fileURLWithPath: path))
    }

    private static func detectSystemLightMode() -> Bool {
        if let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
            return style.lowercased() != "dark"
        }
        return true
    }

    // MARK: - Config file watcher (re-theme when DMS saves settings)

    private func startWatching() {
        let path = configFile.path
        watcherFD = open(path, O_EVTONLY)
        guard watcherFD >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: watcherFD,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            // The file may be replaced (atomic rename); reopen the descriptor.
            self?.reopenWatcher()
            self?.refresh()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.watcherFD, fd >= 0 { close(fd) }
            self?.watcherFD = -1
        }
        source.resume()
        watcherSource = source
    }

    private func reopenWatcher() {
        if watcherFD >= 0 { close(watcherFD) }
        watcherFD = open(configFile.path, O_EVTONLY)
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
