import Foundation
import AppKit
import ImageIO
import DMSCore

/// Service managing wallpaper directory indexing, thumbnail generation/caching, and desktop wallpaper switching.
@MainActor
public final class WallpaperService: ObservableObject {
    public static let shared = WallpaperService()

    @Published public private(set) var wallpapers: [WallpaperItem] = WallpaperItem.defaultPresets
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var currentDesktopPath: String = ""

    private let thumbsDir: URL
    private let memoryThumbCache = NSCache<NSString, NSImage>()
    private var scanTask: Task<Void, Never>?

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.thumbsDir = appSupport.appendingPathComponent("DMS/wallpaper_thumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: thumbsDir, withIntermediateDirectories: true)

        var initialSaved = ConfigStore.shared.config.wallpaperPath
        if initialSaved.isEmpty,
           let screen = NSScreen.main ?? NSScreen.screens.first,
           let desktopURL = NSWorkspace.shared.desktopImageURL(for: screen) {
            initialSaved = desktopURL.path
        }
        self.currentDesktopPath = initialSaved
        scan()
    }

    /// Triggers an asynchronous re-scan of wallpaper directories and user folders.
    public func scan() {
        scanTask?.cancel()
        isScanning = true

        var userFolders = ConfigStore.shared.config.wallpaperFolders
        let pickerFolder = ConfigStore.shared.config.wallpaperPickerFolder
        if !pickerFolder.isEmpty && !userFolders.contains(pickerFolder) {
            userFolders.append(pickerFolder)
        }
        var savedDesktop = ConfigStore.shared.config.wallpaperPath
        if savedDesktop.isEmpty,
           let screen = NSScreen.main ?? NSScreen.screens.first,
           let desktopURL = NSWorkspace.shared.desktopImageURL(for: screen) {
            savedDesktop = desktopURL.path
        }

        let currentDesktopPath = savedDesktop
        scanTask = Task { @MainActor [weak self] in
            let allItems = await Task.detached(priority: .userInitiated) { () -> [WallpaperItem] in
                var discovered: [WallpaperItem] = []
                let fileManager = FileManager.default

                // 1. Scan ~/Pictures
                let picturesURL = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first!
                Self.scanDirectory(url: picturesURL, source: .pictures, results: &discovered)

                // 2. Scan /System/Library/Desktop Pictures
                let systemWallpapers = URL(fileURLWithPath: "/System/Library/Desktop Pictures")
                if fileManager.fileExists(atPath: systemWallpapers.path) {
                    Self.scanDirectory(url: systemWallpapers, source: .system, results: &discovered)
                }

                // 3. Scan user-configured custom folders
                for folderPath in userFolders {
                    let expanded = (folderPath as NSString).expandingTildeInPath
                    let folderURL = URL(fileURLWithPath: expanded)
                    if fileManager.fileExists(atPath: folderURL.path) {
                        Self.scanDirectory(url: folderURL, source: .custom, results: &discovered)
                    }
                }

                // Mark current desktop
                for i in 0..<discovered.count {
                    if let p = discovered[i].path, !currentDesktopPath.isEmpty, p == currentDesktopPath {
                        discovered[i].isCurrentDesktop = true
                    }
                }

                // 4. Combine discovered with built-in presets
                var combined = discovered
                combined.append(contentsOf: WallpaperItem.defaultPresets)
                return combined
            }.value

            guard let self = self, !Task.isCancelled else { return }
            self.wallpapers = allItems
            self.isScanning = false
        }
    }

    private nonisolated static func scanDirectory(
        url: URL,
        source: WallpaperSource,
        results: inout [WallpaperItem]
    ) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard WallpaperItem.supportedExtensions.contains(ext) else { continue }

            let name = fileURL.deletingPathExtension().lastPathComponent
            let item = WallpaperItem(
                id: fileURL.path,
                name: name,
                path: fileURL.path,
                source: source
            )
            results.append(item)
        }
    }

    /// Adds a folder path to the configured wallpaper folders and initiates a scan.
    public func addFolder(path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var folders = ConfigStore.shared.config.wallpaperFolders
        if !folders.contains(trimmed) {
            folders.append(trimmed)
            ConfigStore.shared.update { $0.wallpaperFolders = folders }
            scan()
            ToastCenter.shared.show(icon: "folder.badge.plus", message: "Added wallpaper folder: \(trimmed)")
        }
    }

    /// Removes a folder path from configured wallpaper folders and triggers a re-scan.
    public func removeFolder(path: String) {
        var folders = ConfigStore.shared.config.wallpaperFolders
        folders.removeAll(where: { $0 == path })
        ConfigStore.shared.update { $0.wallpaperFolders = folders }
        scan()
        ToastCenter.shared.show(icon: "trash", message: "Removed wallpaper folder")
    }

    /// Fast synchronous lookup in the memory cache for instantaneous first-frame slice rendering.
    public func cachedThumbnail(for item: WallpaperItem) -> NSImage? {
        guard let path = item.path else { return nil }
        return memoryThumbCache.object(forKey: path as NSString)
    }

    /// Asynchronously retrieves or generates a downsampled thumbnail for the wallpaper image.
    public func thumbnail(for item: WallpaperItem) async -> NSImage? {
        guard let path = item.path else { return nil }

        // 1. Check memory cache
        if let cached = memoryThumbCache.object(forKey: path as NSString) {
            return cached
        }

        // 2. Check disk cache
        let safeName = Data(path.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-") + ".jpg"
        let thumbURL = thumbsDir.appendingPathComponent(safeName)

        if FileManager.default.fileExists(atPath: thumbURL.path),
           let diskImg = NSImage(contentsOf: thumbURL) {
            memoryThumbCache.setObject(diskImg, forKey: path as NSString)
            return diskImg
        }

        // 3. Generate thumbnail off main thread via ImageIO
        let targetURL = thumbURL
        let cgThumb = await Task.detached(priority: .utility) { () -> CGImage? in
            Self.generateThumbnail(at: path, targetURL: targetURL)
        }.value

        guard let cgThumb else { return nil }
        let generated = NSImage(cgImage: cgThumb, size: NSSize(width: 160, height: 100))
        memoryThumbCache.setObject(generated, forKey: path as NSString)
        return generated
    }

    private nonisolated static func generateThumbnail(at path: String, targetURL: URL) -> CGImage? {
        let srcURL = URL(fileURLWithPath: path)
        guard let src = CGImageSourceCreateWithURL(srcURL as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 320
        ]

        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
            return nil
        }

        // Save to disk cache
        let rep = NSBitmapImageRep(cgImage: cgThumb)
        if let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            try? jpegData.write(to: targetURL)
        }

        return cgThumb
    }

    /// Applies the wallpaper to the user's desktop across connected screens and syncs dynamic M3 theme.
    public func applyWallpaper(_ item: WallpaperItem, autoGenerateColors: Bool = true) {
        if let path = item.path {
            let fileURL = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                ToastCenter.shared.show(icon: "exclamationmark.triangle", message: "Wallpaper file not found: \(item.name)")
                return
            }

            let workspace = NSWorkspace.shared
            for screen in NSScreen.screens {
                do {
                    try workspace.setDesktopImageURL(fileURL, for: screen, options: [:])
                } catch {
                    // Try fallback
                    _ = try? workspace.setDesktopImageURL(fileURL, for: screen, options: [:])
                }
            }

            currentDesktopPath = path
            ConfigStore.shared.update { $0.wallpaperPath = path }

            // Update item states
            for i in 0..<wallpapers.count {
                wallpapers[i].isCurrentDesktop = (wallpapers[i].path == path)
            }

            // Automatically generate colors from wallpaper
            let shouldAutoGenerate = autoGenerateColors && ConfigStore.shared.config.autoGenerateWallpaperColors
            if shouldAutoGenerate {
                ThemeStore.shared.applyDynamicWallpaper(url: fileURL)
                ToastCenter.shared.show(icon: "sparkles", message: "Applied Wallpaper & Generated Colors")
            } else if ConfigStore.shared.config.theme == "dynamic" {
                ThemeStore.shared.extractWallpaperSeed(from: fileURL, force: true)
                ToastCenter.shared.show(icon: "checkmark.circle.fill", message: "Applied desktop wallpaper: \(item.name)")
            } else {
                ToastCenter.shared.show(icon: "checkmark.circle.fill", message: "Applied desktop wallpaper: \(item.name)")
            }
        } else if let themeName = item.associatedTheme {
            // Gradient preset: Apply corresponding theme
            ThemeStore.shared.apply(theme: themeName)
            ConfigStore.shared.update { $0.theme = themeName }
            ToastCenter.shared.show(icon: "paintpalette.fill", message: "Applied theme: \(themeName.capitalized)")
        }
    }

    /// Fast live-preview of a wallpaper across connected screens without persisting to config,
    /// generating Matugen themes, or emitting Toast alerts.
    public func previewWallpaper(_ item: WallpaperItem) {
        if let path = item.path {
            let fileURL = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return }
            let workspace = NSWorkspace.shared
            for screen in NSScreen.screens {
                _ = try? workspace.setDesktopImageURL(fileURL, for: screen, options: [:])
            }
            currentDesktopPath = path
        } else if let themeName = item.associatedTheme {
            ThemeStore.shared.apply(theme: themeName)
        }
    }

    /// Reverts desktop wallpaper back to the specified original path from before a live testing session started.
    public func revertWallpaper(to originalPath: String) {
        guard !originalPath.isEmpty, FileManager.default.fileExists(atPath: originalPath) else { return }
        let fileURL = URL(fileURLWithPath: originalPath)
        let workspace = NSWorkspace.shared
        for screen in NSScreen.screens {
            _ = try? workspace.setDesktopImageURL(fileURL, for: screen, options: [:])
        }
        currentDesktopPath = originalPath
        if ConfigStore.shared.config.theme == "dynamic" {
            ThemeStore.shared.extractWallpaperSeed(from: fileURL, force: true)
        }
    }

    /// Retrieves wallpapers constrained by the slanted wallpaper picker settings.
    /// When `wallpaperPickerOnlyFolder` is enabled and a folder is configured, returns only wallpapers
    /// located within that folder (or subdirectories).
    public func pickerWallpapers() -> [WallpaperItem] {
        let config = ConfigStore.shared.config
        if config.wallpaperPickerOnlyFolder && !config.wallpaperPickerFolder.isEmpty {
            let target = (config.wallpaperPickerFolder as NSString).expandingTildeInPath
            let matched = wallpapers.filter { item in
                guard let p = item.path else { return false }
                return p.hasPrefix(target)
            }
            if !matched.isEmpty {
                return matched
            }
        }
        return wallpapers
    }

    /// Cycles desktop wallpaper to the next available wallpaper according to active folder constraints.
    public func nextWallpaper() {
        let items = pickerWallpapers().filter { $0.path != nil }
        guard !items.isEmpty else { return }
        let current = currentDesktopPath
        let currentIndex = items.firstIndex(where: { $0.path == current }) ?? -1
        let nextIndex = (currentIndex + 1) % items.count
        applyWallpaper(items[nextIndex])
    }

    /// Cycles desktop wallpaper to the previous available wallpaper according to active folder constraints.
    public func previousWallpaper() {
        let items = pickerWallpapers().filter { $0.path != nil }
        guard !items.isEmpty else { return }
        let current = currentDesktopPath
        let currentIndex = items.firstIndex(where: { $0.path == current }) ?? 0
        let prevIndex = (currentIndex - 1 + items.count) % items.count
        applyWallpaper(items[prevIndex])
    }

    /// Randomizes desktop wallpaper from items matching the active folder constraints.
    public func randomWallpaper() {
        let items = pickerWallpapers().filter { $0.path != nil }
        guard !items.isEmpty else { return }
        let others = items.filter { $0.path != currentDesktopPath }
        if let pick = (others.isEmpty ? items : others).randomElement() {
            applyWallpaper(pick)
        }
    }
}
