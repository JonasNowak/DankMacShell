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

        // dms wallpaper picker / slanted
        let cmdPicker = IPCCommand.parseCLI(args: ["wallpaper", "picker"])
        #expect(cmdPicker == .wallpaper(action: "picker", path: nil))

        let cmdSlanted = IPCCommand.parseCLI(args: ["wallpaper", "slanted", "show"])
        #expect(cmdSlanted == .wallpaper(action: "picker", path: "show"))

        // dms wallpaper next / prev / random
        let cmdNext = IPCCommand.parseCLI(args: ["wallpaper", "next"])
        #expect(cmdNext == .wallpaper(action: "next", path: nil))

        let cmdPrev = IPCCommand.parseCLI(args: ["wallpaper", "prev"])
        #expect(cmdPrev == .wallpaper(action: "prev", path: nil))

        let cmdRandom = IPCCommand.parseCLI(args: ["wallpaper", "random"])
        #expect(cmdRandom == .wallpaper(action: "random", path: nil))

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

    @Test("Slanted Wallpaper Picker & Hotkey Configuration Settings")
    func testSlantedWallpaperPickerConfig() throws {
        var cfg = DMSConfig()
        // Defaults
        #expect(cfg.wallpaperPickerHotkey == true)
        #expect(cfg.wallpaperPickerHotkeyKey == "w")
        #expect(cfg.wallpaperPickerHotkeyModifiers == "hyper")
        #expect(cfg.wallpaperPickerFolder == "")
        #expect(cfg.wallpaperPickerOnlyFolder == false)
        #expect(cfg.wallpaperPickerSkew == 32.0)

        // Custom config round-trip
        cfg.wallpaperPickerHotkey = false
        cfg.wallpaperPickerHotkeyKey = "p"
        cfg.wallpaperPickerHotkeyModifiers = "cmd+opt"
        cfg.wallpaperPickerFolder = "/Users/test/Wallpapers/Anime"
        cfg.wallpaperPickerOnlyFolder = true
        cfg.wallpaperPickerSkew = 24.0

        let data = try JSONEncoder().encode(cfg)
        let decoded = try JSONDecoder().decode(DMSConfig.self, from: data)

        #expect(decoded.wallpaperPickerHotkey == false)
        #expect(decoded.wallpaperPickerHotkeyKey == "p")
        #expect(decoded.wallpaperPickerHotkeyModifiers == "cmd+opt")
        #expect(decoded.wallpaperPickerFolder == "/Users/test/Wallpapers/Anime")
        #expect(decoded.wallpaperPickerOnlyFolder == true)
        #expect(decoded.wallpaperPickerSkew == 24.0)

        // Dynamic getSetting / setSetting
        var dynamicCfg = DMSConfig()
        dynamicCfg.setSetting("wallpaperPickerFolder", value: AnyCodable("/Custom/Path"))
        #expect(dynamicCfg.wallpaperPickerFolder == "/Custom/Path")
        #expect(dynamicCfg.getSetting("wallpaperPickerFolder")?.stringValue == "/Custom/Path")

        dynamicCfg.setSetting("wallpaperPickerOnlyFolder", value: AnyCodable(true))
        #expect(dynamicCfg.wallpaperPickerOnlyFolder == true)

        dynamicCfg.setSetting("wallpaperPickerHotkeyModifiers", value: AnyCodable("hyper"))
        #expect(dynamicCfg.wallpaperPickerHotkeyModifiers == "hyper")

        dynamicCfg.setSetting("wallpaperPickerSkew", value: AnyCodable(28.5))
        #expect(dynamicCfg.wallpaperPickerSkew == 28.5)
    }

    @Test("HotkeyHelper Hyper Key and Modifier Parsing")
    func testHotkeyHelper() {
        // Hyper key is ⌃⌥⇧⌘ (Control + Option + Shift + Command) = 6912
        let hyperMask = HotkeyHelper.parseModifiers("hyper")
        #expect(hyperMask == 6912)
        #expect(hyperMask == (HotkeyHelper.controlModifier | HotkeyHelper.optionModifier | HotkeyHelper.shiftModifier | HotkeyHelper.cmdModifier))

        // Preset match
        #expect(HotkeyModifierPreset.hyper.carbonModifiers == 6912)
        #expect(HotkeyModifierPreset.meh.carbonModifiers == (HotkeyHelper.controlModifier | HotkeyHelper.optionModifier | HotkeyHelper.shiftModifier))
        #expect(HotkeyModifierPreset.option.carbonModifiers == HotkeyHelper.optionModifier)

        // Composite string parsing
        let cmdOpt = HotkeyHelper.parseModifiers("cmd+opt")
        #expect(cmdOpt == (HotkeyHelper.cmdModifier | HotkeyHelper.optionModifier))

        let ctrlShift = HotkeyHelper.parseModifiers("ctrl+shift")
        #expect(ctrlShift == (HotkeyHelper.controlModifier | HotkeyHelper.shiftModifier))

        // Key code parsing
        #expect(HotkeyHelper.parseKeyCode("w") == 13)
        #expect(HotkeyHelper.parseKeyCode("p") == 35)
        #expect(HotkeyHelper.parseKeyCode("space") == 49)
        #expect(HotkeyHelper.parseKeyCode("return") == 36)
        #expect(HotkeyHelper.parseKeyCode("d") == 2)
        #expect(HotkeyHelper.parseKeyCode("n") == 45)
        #expect(HotkeyHelper.parseKeyCode("v") == 9)

        // Display string formatting
        let hyperDisplay = HotkeyHelper.displayString(key: "w", modifiers: "hyper")
        #expect(hyperDisplay.contains("Hyper"))
        #expect(hyperDisplay.contains("W"))
        #expect(hyperDisplay.contains("⌃⌥⇧⌘"))

        let optDisplay = HotkeyHelper.displayString(key: "w", modifiers: "option")
        #expect(optDisplay == "⌥ W")
    }

    @Test("Wallpaper Folder Path Filtering")
    func testWallpaperFolderFiltering() {
        let items: [WallpaperItem] = [
            WallpaperItem(id: "1", name: "Anime 1", path: "/Users/test/Wallpapers/Anime/1.png", source: .custom),
            WallpaperItem(id: "2", name: "Anime 2", path: "/Users/test/Wallpapers/Anime/2.jpg", source: .custom),
            WallpaperItem(id: "3", name: "Nature 1", path: "/Users/test/Wallpapers/Nature/1.heic", source: .custom),
            WallpaperItem(id: "4", name: "System Sonoma", path: "/System/Library/Desktop Pictures/sonoma.heic", source: .system)
        ]

        let folderTarget = "/Users/test/Wallpapers/Anime"
        let filtered = items.filter { item in
            guard let p = item.path else { return false }
            return p.hasPrefix(folderTarget)
        }

        #expect(filtered.count == 2)
        #expect(filtered.map(\.name) == ["Anime 1", "Anime 2"])
    }
}
