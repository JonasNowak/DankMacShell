import Testing
import Foundation
@testable import DMSCore

@Suite("Config and Include Resolution Tests")
struct ConfigAndIncludeTests {

    @Test("V1 to V2 Schema Migration")
    func testV1Migration() throws {
        let v1JSON = """
        {
            "version": 1,
            "theme": "blue",
            "barPosition": "top",
            "barAutoHide": true,
            "barTransparent": true,
            "showDock": true,
            "showWorkspaceApps": true
        }
        """

        let config = DMSConfig.load(from: Data(v1JSON.utf8))

        // Version upgraded
        #expect(config.version == 2)

        // Bar configs created from legacy fields
        #expect(config.barConfigs.count == 1)
        #expect(config.barConfigs[0].position == "top")
        #expect(config.barConfigs[0].autoHide == true)
        #expect(config.barConfigs[0].transparency < 1.0)
        #expect(config.barPosition == "top")
        #expect(config.barAutoHide == true)
        #expect(config.barTransparent == true)

        // Dock configs created from legacy showDock
        #expect(config.dockConfigs.count == 1)
        #expect(config.dockConfigs[0].enabled == true)
        #expect(config.showDock == true)

        // RunningApps injected into barConfigs since showWorkspaceApps is true
        let leftWidgets = config.barConfigs[0].layout.left
        #expect(leftWidgets.contains(where: { $0.widgetId == "runningApps" }))
    }

    @Test("Legacy Accessor Get and Set with Empty Layouts")
    func testLegacyAccessors() {
        var config = DMSConfig()
        config.barConfigs = []
        config.dockConfigs = []

        // Set on empty barConfigs creates a default BarConfig
        config.barPosition = "left"
        #expect(config.barConfigs.count == 1)
        #expect(config.barConfigs[0].position == "left")

        config.barAutoHide = true
        #expect(config.barConfigs[0].autoHide == true)

        config.barTransparent = true
        #expect(config.barConfigs[0].transparency == 0.7)

        // Set on empty dockConfigs creates a default DockConfig
        config.showDock = true
        #expect(config.dockConfigs.count == 1)
        #expect(config.dockConfigs[0].enabled == true)
    }

    @Test("$include Fragment Resolution and Deep Merging")
    func testIncludeResolution() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dms_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Fragment 1: defines theme and partial bar config
        let frag1 = """
        {
            "theme": "orange",
            "barMarginX": 16.0,
            "apps": {
                "terminal": "Kitty"
            }
        }
        """
        try frag1.write(to: tmpDir.appendingPathComponent("frag1.json"), atomically: true, encoding: .utf8)

        // Fragment 2: includes another key and overrides editor
        let frag2 = """
        {
            "weatherUnits": "fahrenheit",
            "apps": {
                "editor": "VSCode"
            }
        }
        """
        try frag2.write(to: tmpDir.appendingPathComponent("frag2.json"), atomically: true, encoding: .utf8)

        // Main config includes both
        let main = """
        {
            "$include": ["frag1.json", "frag2.json"],
            "theme": "red",
            "showTelemetry": false
        }
        """
        let mainData = Data(main.utf8)
        let config = DMSConfig.load(from: mainData, baseDirectory: tmpDir)

        // Main config overrides fragment 1's theme ("red" instead of "orange")
        #expect(config.theme == "red")
        #expect(config.showTelemetry == false)

        // Values from fragment 1 merged
        #expect(config.barMarginX == 16.0)
        #expect(config.apps.terminal == "Kitty")

        // Values from fragment 2 merged
        #expect(config.weatherUnits == "fahrenheit")
        #expect(config.apps.editor == "VSCode")
    }

    @Test("Circular Include Handling")
    func testCircularIncludes() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dms_circular_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // A includes B, B includes A
        let fileA = """
        {
            "$include": "b.json",
            "theme": "yellow"
        }
        """
        let fileB = """
        {
            "$include": "a.json",
            "barMarginX": 24.0
        }
        """

        try fileA.write(to: tmpDir.appendingPathComponent("a.json"), atomically: true, encoding: .utf8)
        try fileB.write(to: tmpDir.appendingPathComponent("b.json"), atomically: true, encoding: .utf8)

        // Must terminate safely without stack overflow
        let config = DMSConfig.load(from: Data(fileA.utf8), baseDirectory: tmpDir)
        #expect(config.theme == "yellow")
        #expect(config.barMarginX == 24.0)
    }

    @Test("getSetting and setSetting for Built-in Keys")
    func testGetAndSetSettings() {
        var config = DMSConfig()

        // Test every built-in setter
        config.setSetting("theme", value: AnyCodable("green"))
        #expect(config.theme == "green")
        #expect(config.getSetting("theme")?.stringValue == "green")

        config.setSetting("isLightMode", value: AnyCodable(true))
        #expect(config.isLightMode == true)
        #expect(config.getSetting("isLightMode")?.boolValue == true)

        config.setSetting("barMarginX", value: AnyCodable(14.5))
        #expect(config.barMarginX == 14.5)
        #expect(config.getSetting("barMarginX")?.doubleValue == 14.5)

        config.setSetting("weatherLocation", value: AnyCodable("Berlin"))
        #expect(config.weatherLocation == "Berlin")
        #expect(config.getSetting("weatherLocation")?.stringValue == "Berlin")

        config.setSetting("weatherUnits", value: AnyCodable("fahrenheit"))
        #expect(config.weatherUnits == "fahrenheit")
        #expect(config.getSetting("weatherUnits")?.stringValue == "fahrenheit")

        config.setSetting("webSearchProvider", value: AnyCodable("kagi"))
        #expect(config.webSearchProvider == "kagi")
        #expect(config.getSetting("webSearchProvider")?.stringValue == "kagi")

        config.setSetting("controlCenterColumns", value: AnyCodable(12))
        #expect(config.controlCenterColumns == 12)
        #expect(config.getSetting("controlCenterColumns")?.intValue == 12)

        config.setSetting("pinnedApps", value: AnyCodable([AnyCodable("com.apple.Music")]))
        #expect(config.pinnedApps == ["com.apple.Music"])

        config.setSetting("enabledPlugins", value: AnyCodable([AnyCodable("pomodoro-timer")]))
        #expect(config.enabledPlugins == ["pomodoro-timer"])

        // Applets & Hotkeys toggles
        config.setSetting("showNotepadApplet", value: AnyCodable(true))
        #expect(config.showNotepadApplet == true)

        config.setSetting("showClipboardApplet", value: AnyCodable(true))
        #expect(config.showClipboardApplet == true)

        config.setSetting("showColorPickerApplet", value: AnyCodable(true))
        #expect(config.showColorPickerApplet == true)

        config.setSetting("launcherHotkey", value: AnyCodable(false))
        #expect(config.launcherHotkey == false)
    }

    @Test("AppOverrides Model and Defaults")
    func testAppOverrides() throws {
        let def = DMSConfig.AppOverrides()
        #expect(def.terminal == "Terminal")
        #expect(def.browser == "Safari")
        #expect(def.fileManager == "Finder")
        #expect(def.editor == "TextEdit")
        #expect(def.activityMonitor == "Activity Monitor")

        let custom = DMSConfig.AppOverrides(
            terminal: "Alacritty",
            browser: "Firefox",
            fileManager: "ForkLift",
            editor: "Neovim",
            activityMonitor: "btop"
        )
        let data = try JSONEncoder().encode(custom)
        let decoded = try JSONDecoder().decode(DMSConfig.AppOverrides.self, from: data)
        #expect(decoded == custom)
    }
}
