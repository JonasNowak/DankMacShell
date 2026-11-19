import SwiftUI
import AppKit
import Darwin
import DMSCore
import MaterialMacLibrary

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
    private var appearanceObserver: Any?
    private var currentThemeMode: String = "dark"
    private var refreshGeneration: Int = 0

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.configDirectory = appSupport.appendingPathComponent("DMS", isDirectory: true)
        self.isLightMode = false
        self.palette = StockThemes.theme(named: "purple", isDark: true)
        refresh()
        startWatching()
        startAppearanceObserver()
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
        currentThemeMode = config.themeMode
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
        applyAppearance(light: light)

        let contrast: ContrastLevel = config.matugenContrast >= 0.5 ? .high : (config.matugenContrast >= 0.2 ? .medium : .standard)
        let scheme = config.matugenScheme

        if lower == "dynamic" {
            applyDynamicTheme(config: config, light: light, contrast: contrast, scheme: scheme)
        } else if lower == "custom" || lower.hasPrefix("#") {
            let hex = lower.hasPrefix("#") ? config.theme : config.themeSeedColor
            let seed = M3Color(hex)
            let (dark, lightPalette) = DynamicThemeGenerator.generate(from: seed, name: "Custom", contrast: contrast, scheme: scheme)
            self.palette = light ? lightPalette : dark
        } else {
            self.palette = StockThemes.theme(named: config.theme, isDark: !light)
        }
    }

    private func applyAppearance(light: Bool) {
        let targetAppearance: NSAppearance.Name = light ? .aqua : .darkAqua
        if let app = NSApp, app.appearance?.name != targetAppearance {
            app.appearance = NSAppearance(named: targetAppearance)
        }
    }

    /// Dynamic theme: the wallpaper seed extraction (`WallpaperSeedColor.dominantColor`,
    /// a potentially slow image decode) runs on a detached task — never on the main actor.
    private func applyDynamicTheme(config: DMSConfig, light: Bool, contrast: ContrastLevel, scheme: MatugenScheme) {
        let generation = refreshGeneration + 1
        refreshGeneration = generation
        let seedHex = config.themeSeedColor
        let wallpaperPath = config.wallpaperPath

        // Provisional palette from the configured seed hex so the UI updates immediately.
        let provisional = M3Color(seedHex)
        let (provDark, provLight) = DynamicThemeGenerator.generate(from: provisional, name: "Dynamic", contrast: contrast, scheme: scheme)
        self.palette = light ? provLight : provDark

        Task.detached(priority: .userInitiated) { [weak self] in
            let seed = wallpaperPath.isEmpty ? nil : WallpaperSeedColor.dominantColor(from: URL(fileURLWithPath: wallpaperPath))
            let resolved = seed ?? M3Color(seedHex)
            let (dark, lightPalette) = DynamicThemeGenerator.generate(from: resolved, name: "Dynamic", contrast: contrast, scheme: scheme)
            await MainActor.run { [weak self] in
                guard let self, self.refreshGeneration == generation else { return }
                self.palette = light ? lightPalette : dark
            }
        }
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
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        watcherFD = fd
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            // settings.json may have been atomically replaced (rename/delete): the old
            // descriptor is now stale, so cancel the old source and watch the new file.
            self?.restartWatcher()
            self?.refresh()
        }
        source.setCancelHandler { [weak self] in
            // Capture the local fd: never close a descriptor that has been reused.
            close(fd)
            if self?.watcherFD == fd { self?.watcherFD = -1 }
        }
        source.resume()
        watcherSource = source
    }

    private func restartWatcher() {
        watcherSource?.cancel()
        watcherSource = nil
        watcherFD = -1
        startWatching()
    }

    // MARK: - System appearance observer (themeMode == "system")

    private func startAppearanceObserver() {
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.currentThemeMode.lowercased() == "system" else { return }
                self.refresh()
            }
        }
    }
}

extension SymbianThemeStore {
    /// Bridges the Symbian companion theme into a `MaterialTheme` so `MaterialComponents`
    /// views can be injected with `.materialTheme(store.materialTheme)`.
    /// `Color.init(hex:)` is provided by `MaterialTokens` (via `MaterialMacLibrary` / DMSCore).
    var materialTheme: MaterialTheme {
        MaterialTheme(
            palette: palette,
            isLightMode: isLightMode,
            activeThemeName: "symbian"
        )
    }
}
