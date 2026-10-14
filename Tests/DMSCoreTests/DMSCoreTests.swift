import Testing
import Foundation
@testable import DMSCore

@Suite("DMSCore Tests")
struct DMSCoreTests {

    @Test("Stock Themes and Colors")
    func testStockThemes() {
        let purpleDark = StockThemes.theme(named: "purple", isDark: true)
        #expect(purpleDark.name == "Purple")
        #expect(purpleDark.isDark == true)
        #expect(purpleDark.primary.hex.hasPrefix("#"))

        let blueLight = StockThemes.theme(named: "blue", isDark: false)
        #expect(blueLight.name == "Blue")
        #expect(blueLight.isDark == false)

        let color = M3Color("#FF00AA")
        #expect(abs(color.red - 1.0) < 0.01)
        #expect(abs(color.green - 0.0) < 0.01)
        #expect(abs(color.blue - 0.666) < 0.05)
    }

    @Test("Dynamic Theme Generator")
    func testDynamicThemeGeneration() {
        let seed = M3Color("#3F51B5") // Indigo seed
        let (dark, light) = DynamicThemeGenerator.generate(from: seed, name: "IndigoDynamic")

        #expect(dark.isDark == true)
        #expect(light.isDark == false)
        #expect(dark.name == "IndigoDynamic")
        #expect(light.name == "IndigoDynamic")
        #expect(dark.primary.hex != light.primary.hex)
    }

    @Test("Config Encoding and Decoding")
    func testConfig() throws {
        let original = DMSConfig(
            theme: "blue",
            isLightMode: true,
            barPosition: "top",
            barAutoHide: true,
            barTransparent: true,
            showDock: false,
            showTelemetry: true,
            launcherHotkey: true,
            pinnedApps: ["com.apple.Safari"]
        )

        let data = try original.encodeJSON()
        let decoded = DMSConfig.load(from: data)

        #expect(decoded.theme == "blue")
        #expect(decoded.isLightMode == true)
        #expect(decoded.barPosition == "top")
        #expect(decoded.barAutoHide == true)
        #expect(decoded.pinnedApps == ["com.apple.Safari"])
    }

    @Test("App Search Fuzzy Matching")
    func testAppSearch() {
        let safari = AppItem(name: "Safari", bundleID: "com.apple.Safari", path: "/Applications/Safari.app")
        let activityMonitor = AppItem(name: "Activity Monitor", bundleID: "com.apple.ActivityMonitor", path: "/System/Applications/Utilities/Activity Monitor.app")

        // Exact match
        let exactScore = AppSearch.score(app: safari, query: "safari")
        #expect(exactScore != nil)
        #expect(exactScore! >= 800)

        // Prefix match
        let prefixScore = AppSearch.score(app: safari, query: "saf")
        #expect(prefixScore != nil)

        // Word boundary acronym match: "am" for "Activity Monitor"
        let acronymScore = AppSearch.score(app: activityMonitor, query: "am")
        #expect(acronymScore != nil)
        #expect(acronymScore! >= 500)

        // Non-match
        let noMatch = AppSearch.score(app: safari, query: "calculator")
        #expect(noMatch == nil)
    }

    @Test("Search Calculator Evaluation")
    func testCalculator() {
        let res1 = AppSearch.evaluateMath(query: "2 + 2")
        #expect(res1?.result == "4")

        let res2 = AppSearch.evaluateMath(query: "10 * 5 - 2")
        #expect(res2?.result == "48")

        let res3 = AppSearch.evaluateMath(query: "20% of 150")
        #expect(res3?.result == "30")

        let resNone = AppSearch.evaluateMath(query: "Safari")
        #expect(resNone == nil)
    }

    @Test("IPC URL Command Parsing")
    func testIPCCommands() {
        let url1 = URL(string: "dms://toggleLauncher")!
        #expect(IPCCommand.parse(url: url1) == .toggleLauncher)

        let url2 = URL(string: "dms://setTheme?name=green")!
        #expect(IPCCommand.parse(url: url2) == .setTheme(name: "green"))

        let url3 = URL(string: "dms://powerMenu")!
        #expect(IPCCommand.parse(url: url3) == .powerMenu)

        let urlInvalid = URL(string: "https://google.com")!
        #expect(IPCCommand.parse(url: urlInvalid) == nil)
    }
}
