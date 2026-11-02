import Foundation

/// Sources for wallpapers in DankMacShell.
public enum WallpaperSource: String, CaseIterable, Codable, Sendable, Identifiable {
    case all = "All"
    case pictures = "Pictures"
    case system = "System"
    case custom = "Custom"
    case presets = "Presets"

    public var id: String { rawValue }
}

/// Metadata model for a wallpaper (local disk image or built-in gradient preset).
public struct WallpaperItem: Identifiable, Sendable, Codable, Equatable {
    public var id: String
    public var name: String
    public var path: String?
    public var source: WallpaperSource
    public var gradientColorsHex: [String]?
    public var associatedTheme: String?
    public var isCurrentDesktop: Bool

    public init(
        id: String,
        name: String,
        path: String? = nil,
        source: WallpaperSource = .pictures,
        gradientColorsHex: [String]? = nil,
        associatedTheme: String? = nil,
        isCurrentDesktop: Bool = false
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.source = source
        self.gradientColorsHex = gradientColorsHex
        self.associatedTheme = associatedTheme
        self.isCurrentDesktop = isCurrentDesktop
    }

    /// Supported image extensions for local wallpaper indexing.
    public static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "webp", "tiff", "tif"
    ]

    /// Built-in Material 3 gradient wallpaper presets.
    public static let defaultPresets: [WallpaperItem] = [
        WallpaperItem(
            id: "preset-purple-horizon",
            name: "Purple Horizon",
            path: nil,
            source: .presets,
            gradientColorsHex: ["#2c1654", "#7b3fa8", "#d699ff"],
            associatedTheme: "purple"
        ),
        WallpaperItem(
            id: "preset-midnight-aurora",
            name: "Midnight Aurora",
            path: nil,
            source: .presets,
            gradientColorsHex: ["#051c24", "#0c505b", "#34d399"],
            associatedTheme: "green"
        ),
        WallpaperItem(
            id: "preset-deep-ocean",
            name: "Deep Ocean",
            path: nil,
            source: .presets,
            gradientColorsHex: ["#0f172a", "#1e3a8a", "#60a5fa"],
            associatedTheme: "blue"
        ),
        WallpaperItem(
            id: "preset-solar-flare",
            name: "Solar Flare",
            path: nil,
            source: .presets,
            gradientColorsHex: ["#3b0764", "#9a3412", "#f97316"],
            associatedTheme: "orange"
        ),
        WallpaperItem(
            id: "preset-crimson-dusk",
            name: "Crimson Dusk",
            path: nil,
            source: .presets,
            gradientColorsHex: ["#450a0a", "#991b1b", "#f87171"],
            associatedTheme: "red"
        ),
        WallpaperItem(
            id: "preset-golden-hour",
            name: "Golden Hour",
            path: nil,
            source: .presets,
            gradientColorsHex: ["#422006", "#a16207", "#facc15"],
            associatedTheme: "yellow"
        )
    ]

    /// Filters wallpaper items by category source and optional search query.
    public static func filterWallpapers(
        items: [WallpaperItem],
        source: WallpaperSource,
        query: String = ""
    ) -> [WallpaperItem] {
        let categoryFiltered: [WallpaperItem]
        if source == .all {
            categoryFiltered = items
        } else {
            categoryFiltered = items.filter { $0.source == source }
        }

        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanQuery.isEmpty else {
            return categoryFiltered
        }

        return categoryFiltered.filter {
            $0.name.lowercased().contains(cleanQuery)
                || ($0.path?.lowercased().contains(cleanQuery) ?? false)
                || ($0.associatedTheme?.lowercased().contains(cleanQuery) ?? false)
        }
    }
}
