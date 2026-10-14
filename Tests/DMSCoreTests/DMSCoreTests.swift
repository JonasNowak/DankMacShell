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

    @Test("IPC URL and CLI Command Parsing")
    func testIPCCommands() {
        // URLs
        let url1 = URL(string: "dms://toggleLauncher")!
        #expect(IPCCommand.parse(url: url1) == .toggleLauncher)

        let url2 = URL(string: "dms://setTheme?name=green")!
        #expect(IPCCommand.parse(url: url2) == .setTheme(name: "green"))

        let url3 = URL(string: "dms://powerMenu")!
        #expect(IPCCommand.parse(url: url3) == .powerMenu)

        let urlDash = URL(string: "dms://dash")!
        #expect(IPCCommand.parse(url: urlDash) == .toggleDash)

        let urlInvalid = URL(string: "https://google.com")!
        #expect(IPCCommand.parse(url: urlInvalid) == nil)

        // CLI
        let cli1 = IPCCommand.parseCLI(args: ["ipc", "call", "audio", "setvolume", "75"])
        #expect(cli1 == .audio(action: "setvolume", value: "75"))

        let cli2 = IPCCommand.parseCLI(args: ["notepad", "get"])
        #expect(cli2 == .getNotepad)

        let cli3 = IPCCommand.parseCLI(args: ["inhibit", "toggle"])
        #expect(cli3 == .inhibit(action: "toggle"))
    }

    @Test("Clipboard Store Operations")
    func testClipboardStore() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_clip_\(UUID().uuidString).json")
        let store = ClipboardStore(storageURL: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        #expect(store.getItems().isEmpty)

        let item = store.add(text: "Hello DankMaterialShell")
        #expect(item != nil)
        #expect(store.getItems().count == 1)
        #expect(store.getItems().first?.preview == "Hello DankMaterialShell")

        // Search
        let results = store.search(query: "Dank")
        #expect(results.count == 1)

        store.clear()
        #expect(store.getItems().isEmpty)
    }

    @Test("Notepad Store Operations")
    func testNotepadStore() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_notes_\(UUID().uuidString).json")
        let store = NotepadStore(storageURL: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let initial = store.getActiveNote()
        #expect(!initial.title.isEmpty)

        store.updateActiveNote(title: "My Note", content: "Line one\nLine two")
        let updated = store.getActiveNote()
        #expect(updated.title == "My Note")
        #expect(updated.wordCount == 4)
        #expect(updated.charCount == 17)
    }

    @Test("Weather Model and Symbols")
    func testWeatherModel() {
        let clearDay = WeatherData(temperatureC: 22.5, weatherCode: 0, isDay: true)
        #expect(clearDay.conditionDescription == "Clear Sky")
        #expect(clearDay.sfSymbol == "sun.max.fill")
        #expect(abs(clearDay.temperatureF - 72.5) < 0.1)

        let rain = WeatherData(temperatureC: 14.0, weatherCode: 61, isDay: false)
        #expect(rain.conditionDescription == "Rain")
        #expect(rain.sfSymbol == "cloud.drizzle.fill")
    }

    @Test("Now Playing Model Progress")
    func testNowPlayingModel() {
        let track = NowPlayingTrack(
            title: "Song",
            artist: "Artist",
            isPlaying: true,
            durationSeconds: 200,
            elapsedSeconds: 50
        )
        #expect(track.formattedDuration == "3:20")
        #expect(track.formattedElapsed == "0:50")
        #expect(track.progress == 0.25)
    }

    @Test("Emoji and Web Search")
    func testEmojisAndWebSearch() {
        let rocket = AppSearch.searchEmojis(query: "rocket")
        #expect(!rocket.isEmpty)
        #expect(rocket.first?.emoji == "🚀")

        let googleURL = AppSearch.webSearchURL(query: "DankMaterialShell", provider: "google")
        #expect(googleURL?.absoluteString.contains("google.com/search") == true)
    }

    @Test("Plugin Models and Lockfile")
    func testPluginModels() throws {
        let lock = DMSPluginLockfile(version: 1, plugins: [
            "github-notifications": DMSPluginLockfile.DMSPluginLockEntry(version: "1.2.0", enabled: true)
        ])
        let data = try JSONEncoder().encode(lock)
        let decoded = try JSONDecoder().decode(DMSPluginLockfile.self, from: data)
        #expect(decoded.plugins["github-notifications"]?.version == "1.2.0")
        #expect(decoded.plugins["github-notifications"]?.enabled == true)

        let plugin = DMSPluginRegistry.standardPlugins.first { $0.id == "github-notifications" }
        #expect(plugin != nil)
        #expect(plugin?.type == .barWidget)

        let cliPlugins = IPCCommand.parseCLI(args: ["plugins", "search", "github"])
        #expect(cliPlugins == .searchPlugins(query: "github"))

        let cliApplets = IPCCommand.parseCLI(args: ["applets", "toggle", "weather"])
        #expect(cliApplets == .toggleApplet(id: "weather"))
    }
}
