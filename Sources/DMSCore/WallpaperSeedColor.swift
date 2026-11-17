import Foundation
import DankThemeEngine

/// Extracts seed colors from a wallpaper image. The downsampling, histogram, and
/// scoring math live in the Rust-backed `DankThemeEngine`
/// (`extractWallpaperSeed(from:)` / `extractPaletteSeeds(from:count:)`); this enum
/// only adapts the FFI results to DMS types. Shared by the DMS shell (via
/// ThemeStore) and the dms-symbian companion so both resolve the same "dynamic"
/// theme palette.
public enum WallpaperSeedColor {
    /// Dominant average color of the image at `url`, as an M3 seed color.
    /// Returns nil when the image cannot be decoded; falls back to the M3 default
    /// seed (`#6750A4`) when the image has no usable pixels (engine behavior).
    public static func dominantColor(from url: URL) -> M3Color? {
        guard let color = try? DankThemeEngine.extractWallpaperSeed(from: url.path) else {
            return nil
        }
        return M3Color(color)
    }

    /// Up to `count` palette seed colors from the image at `url` (dominant color
    /// first, then farthest-point samples). Returns nil for missing/unreadable files.
    public static func paletteSeeds(from url: URL, count: Int = 2) -> [M3Color]? {
        guard let seeds = try? DankThemeEngine.extractPaletteSeeds(from: url.path, count: UInt32(max(1, count))) else {
            return nil
        }
        return seeds.map(M3Color.init)
    }
}
