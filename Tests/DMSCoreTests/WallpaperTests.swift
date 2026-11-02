import Testing
import Foundation
@testable import DMSCore

@Suite("Wallpaper Models, Filtering, and IPC Tests")
struct WallpaperTests {

    @Test("Supported Wallpaper File Extensions")
    func testSupportedExtensions() {
        #expect(WallpaperItem.supportedExtensions.contains("jpg"))
        #expect(WallpaperItem.supportedExtensions.contains("jpeg"))
        #expect(WallpaperItem.supportedExtensions.contains("png"))
        #expect(WallpaperItem.supportedExtensions.contains("heic"))
        #expect(WallpaperItem.supportedExtensions.contains("webp"))
        #expect(WallpaperItem.supportedExtensions.contains("tiff"))
        #expect(!WallpaperItem.supportedExtensions.contains("txt"))
        #expect(!WallpaperItem.supportedExtensions.contains("mov"))
    }

    @Test("Wallpaper Category and Search Filtering")
    func testWallpaperFiltering() {
        let items: [WallpaperItem] = [
            WallpaperItem(id: "1", name: "Mountain Lake", path: "/Pictures/lake.heic", source: .pictures),
            WallpaperItem(id: "2", name: "Sonoma Horizon", path: "/System/Library/Desktop Pictures/sonoma.heic", source: .system),
            WallpaperItem(id: "3", name: "Custom Anime", path: "/Wallpapers/anime.png", source: .custom),
            WallpaperItem(id: "4", name: "Purple Horizon", source: .presets, associatedTheme: "purple")
        ]

        // Filter by source All
        let all = WallpaperItem.filterWallpapers(items: items, source: .all)
        #expect(all.count == 4)

        // Filter by source System
        let systemOnly = WallpaperItem.filterWallpapers(items: items, source: .system)
        #expect(systemOnly.count == 1)
        #expect(systemOnly.first?.name == "Sonoma Horizon")

        // Filter by source Presets
        let presetsOnly = WallpaperItem.filterWallpapers(items: items, source: .presets)
        #expect(presetsOnly.count == 1)
        #expect(presetsOnly.first?.name == "Purple Horizon")

        // Search query filtering
        let searchMountain = WallpaperItem.filterWallpapers(items: items, source: .all, query: "mountain")
        #expect(searchMountain.count == 1)
        #expect(searchMountain.first?.id == "1")

        let searchPurple = WallpaperItem.filterWallpapers(items: items, source: .all, query: "purple")
        #expect(searchPurple.count == 1)
        #expect(searchPurple.first?.name == "Purple Horizon")
    }

    @Test("Wallpaper IPC Command Parsing")
    func testWallpaperIPCParsing() {
        // dms wallpaper get
        let cmdGet = IPCCommand.parseCLI(args: ["wallpaper", "get"])
        #expect(cmdGet == .wallpaper(action: "get", path: nil))

        // dms wallpaper set /path/to/img.heic
        let cmdSet = IPCCommand.parseCLI(args: ["wallpaper", "set", "/Library/Desktop Pictures/Wave.heic"])
        #expect(cmdSet == .wallpaper(action: "set", path: "/Library/Desktop Pictures/Wave.heic"))

        // dms wallpaper list
        let cmdList = IPCCommand.parseCLI(args: ["wallpaper", "list"])
        #expect(cmdList == .wallpaper(action: "list", path: nil))

        // URL scheme parsing: dms://wallpaper/set?path=/Users/me/pic.png
        let url = URL(string: "dms://wallpaper/set?path=/Users/me/pic.png")!
        let cmdURL = IPCCommand.parse(url: url)
        #expect(cmdURL == .wallpaper(action: "set", path: "/Users/me/pic.png"))
    }

    @Test("Auto-Generate Wallpaper Colors Configuration Setting")
    func testAutoGenerateColorsConfig() throws {
        // Default value must be true
        let defaultConfig = DMSConfig()
        #expect(defaultConfig.autoGenerateWallpaperColors == true)

        // Codable round-trip with autoGenerateWallpaperColors = false
        var custom = DMSConfig()
        custom.autoGenerateWallpaperColors = false
        custom.wallpaperPath = "/Library/Desktop Pictures/Ventura.heic"
        custom.wallpaperFolders = ["/Users/test/Wallpapers"]

        let data = try JSONEncoder().encode(custom)
        let decoded = try JSONDecoder().decode(DMSConfig.self, from: data)

        #expect(decoded.autoGenerateWallpaperColors == false)
        #expect(decoded.wallpaperPath == "/Library/Desktop Pictures/Ventura.heic")
        #expect(decoded.wallpaperFolders == ["/Users/test/Wallpapers"])
    }
}
