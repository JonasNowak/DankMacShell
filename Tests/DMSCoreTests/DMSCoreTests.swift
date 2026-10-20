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

    @Test("Workspace Models and App Items")
    func testWorkspaceModels() {
        let app1 = WorkspaceAppItem(
            pid: 1234,
            name: "Kitty",
            bundleID: "net.kovidgoyal.kitty",
            path: "/Applications/kitty.app",
            isActive: true,
            omniWMWindowID: "ow_abc123"
        )
        #expect(app1.id == "ow_abc123")
        #expect(app1.isActive == true)
        #expect(app1.bundleID == "net.kovidgoyal.kitty")

        let app2 = WorkspaceAppItem(
            pid: 5678,
            name: "Obsidian",
            bundleID: "md.obsidian",
            path: "/Applications/Obsidian.app",
            isActive: false
        )
        #expect(app2.id == "5678_md.obsidian")
        #expect(app2.isActive == false)

        let ws = WorkspaceInfo(
            id: "ws-1",
            number: 1,
            name: "1",
            isCurrent: true,
            apps: [app1, app2]
        )
        #expect(ws.number == 1)
        #expect(ws.isCurrent == true)
        #expect(ws.apps.count == 2)
        #expect(ws.apps.first?.name == "Kitty")
    }

    @Test("Dock Magnification Physics and Spans")
    func testDockMagnificationEngine() {
        let baseSize = 42.0

        // 1. Radius calculations
        let rParabolic = DockMagnificationEngine.magnificationRadius(baseSize: baseSize, profile: "parabolic")
        let rGaussian = DockMagnificationEngine.magnificationRadius(baseSize: baseSize, profile: "gaussian")
        let rCosine = DockMagnificationEngine.magnificationRadius(baseSize: baseSize, profile: "cosine")

        #expect(abs(rParabolic - (baseSize * 1.8)) < 0.001)
        #expect(abs(rGaussian - (baseSize * 2.2)) < 0.001)
        #expect(abs(rCosine - (baseSize * 2.5)) < 0.001)

        // 2. Magnification factor at center (dist = 0) must be 1.0
        #expect(abs(DockMagnificationEngine.magnificationFactor(dist: 0, radius: rParabolic, profile: "parabolic") - 1.0) < 0.001)
        #expect(abs(DockMagnificationEngine.magnificationFactor(dist: 0, radius: rGaussian, profile: "gaussian") - 1.0) < 0.001)
        #expect(abs(DockMagnificationEngine.magnificationFactor(dist: 0, radius: rCosine, profile: "cosine") - 1.0) < 0.001)

        // 3. Magnification factor beyond radius must be 0.0
        #expect(DockMagnificationEngine.magnificationFactor(dist: rParabolic + 10, radius: rParabolic, profile: "parabolic") == 0.0)
        #expect(DockMagnificationEngine.magnificationFactor(dist: rGaussian + 10, radius: rGaussian, profile: "gaussian") == 0.0)
        #expect(DockMagnificationEngine.magnificationFactor(dist: rCosine + 10, radius: rCosine, profile: "cosine") == 0.0)

        // 4. Magnification scale with 130% zoom
        let centerScale = DockMagnificationEngine.magnificationScale(
            dist: 0,
            baseSize: baseSize,
            maxScalePercent: 130.0,
            profile: "parabolic"
        )
        #expect(abs(centerScale - 1.30) < 0.001)

        let farScale = DockMagnificationEngine.magnificationScale(
            dist: rParabolic + 50,
            baseSize: baseSize,
            maxScalePercent: 130.0,
            profile: "parabolic"
        )
        #expect(abs(farScale - 1.0) < 0.001)

        // 5. Unit target midpoint hysteresis swapping
        let spans: [(id: String, start: Double, end: Double)] = [
            (id: "app_1", start: 0, end: 50),
            (id: "app_2", start: 50, end: 100),
            (id: "app_3", start: 100, end: 150)
        ]
        // app_1 dragging past midpoint of app_2 (75)
        let swapForward = DockMagnificationEngine.unitTarget(spans: spans, id: "app_1", offset: 30) // end 50 + 30 = 80 > 75
        #expect(swapForward == "app_2")

        let stayPut = DockMagnificationEngine.unitTarget(spans: spans, id: "app_1", offset: 10) // end 50 + 10 = 60 < 75
        #expect(stayPut == "app_1")

        // 6. Geometry derivations
        #expect(DockMagnificationEngine.effectiveThickness(iconSize: 42, spacing: 8) == 58)
        #expect(DockMagnificationEngine.indicatorLane(iconSize: 42) >= 8)
    }

    @Test("Grid Packing 2D Solver with Gravity")
    func testGridPackingSolver() {
        let cards = [
            GridPackingSolver.CardItem(id: "user", w: 5, h: 1),
            GridPackingSolver.CardItem(id: "wifi", w: 4, h: 1),
            GridPackingSolver.CardItem(id: "bluetooth", w: 4, h: 1),
            GridPackingSolver.CardItem(id: "slider", w: 8, h: 1)
        ]

        let layout = GridPackingSolver.packCards(
            cards: cards,
            columns: 8,
            width: 600,
            gap: 8,
            rowUnit: 64,
            step: 0.5,
            gravity: true
        )

        #expect(layout.columns == 8)
        #expect(layout.slots.count == 4)
        #expect(layout.rows > 0)
        #expect(layout.totalHeight > 0)

        // Test reverse coordinate resolution
        let firstSlot = layout.slots[0]
        let cell = GridPackingSolver.cellAt(layout: layout, x: firstSlot.x, y: firstSlot.y, cols: firstSlot.cols, rows: firstSlot.rows)
        #expect(cell.col == firstSlot.col)
        #expect(cell.row == firstSlot.row)
    }

    @Test("Bar Center Layout Solver")
    func testBarCenterLayoutSolver() {
        // Ideal start centering: bar width 1000, 1 center widget with size 300
        let result = BarCenterLayoutSolver.resolve(
            sizes: [300.0],
            length: 1000.0,
            spacing: 0.0,
            mode: "geometric"
        )

        #expect(result.positions.count == 1)
        #expect(result.totalSize == 300.0)
        // Center element should be placed at 1000/2 - 300/2 = 350
        if let centerPos = result.positions[0] {
            #expect(abs(centerPos - 350.0) < 0.001)
        } else {
            Issue.record("Expected center position to be resolved")
        }

        // Test boundary confinement: left bounds encroaches up to 400
        let confined = BarCenterLayoutSolver.resolve(
            sizes: [300.0],
            length: 1000.0,
            spacing: 0.0,
            mode: "geometric",
            bounds: BarCenterLayoutSolver.Bounds(min: 400.0, max: nil)
        )
        if let confinedPos = confined.positions[0] {
            #expect(confinedPos >= 400.0)
        }
    }

    @Test("Bar Segment Role Solver")
    func testBarSegmentRoleSolver() {
        // Run of 1 element -> solo
        let e1 = [BarWidgetEntry(id: "clock", widgetId: "clock")]
        let solo = BarSegmentRoleSolver.resolve(entries: e1, participating: [true])
        #expect(solo == [SegmentRole.solo])

        // Run of 3 elements -> first, middle, last
        let e3 = [
            BarWidgetEntry(id: "w1", widgetId: "clock"),
            BarWidgetEntry(id: "w2", widgetId: "weather"),
            BarWidgetEntry(id: "w3", widgetId: "battery")
        ]
        let triple = BarSegmentRoleSolver.resolve(entries: e3, participating: [true, true, true])
        #expect(triple == [SegmentRole.first, SegmentRole.middle, SegmentRole.last])

        // Breaking run on index 1 separator
        let e4 = [
            BarWidgetEntry(id: "w1", widgetId: "clock"),
            BarWidgetEntry(id: "sep", widgetId: "separator"),
            BarWidgetEntry(id: "w2", widgetId: "weather"),
            BarWidgetEntry(id: "w3", widgetId: "battery")
        ]
        let broken = BarSegmentRoleSolver.resolve(entries: e4, participating: [true, true, true, true])
        #expect(broken[0] == SegmentRole.solo)
        #expect(broken[1] == SegmentRole.solo) // separator
        #expect(broken[2] == SegmentRole.first)
        #expect(broken[3] == SegmentRole.last)
    }

    @Test("HCT Dynamic Color Math and Contrast Ratios")
    func testHCTAndContrastMath() {
        let blue = M3Color("#1976D2")
        let hct = HCT.from(color: blue)
        #expect(hct.hue >= 0.0 && hct.hue <= 360.0)
        #expect(hct.chroma >= 0.0)
        #expect(hct.tone >= 0.0 && hct.tone <= 100.0)

        // Test contrast ratio between black and white
        let black = M3Color("#000000")
        let white = M3Color("#FFFFFF")
        let ratio = HCTMath.contrastRatio(black, white)
        #expect(ratio >= 20.0) // ~21:1

        // Test readableOn contrast enforcement
        let onDark = HCTMath.readableOn(background: M3Color("#121212"), candidates: [black, white])
        #expect(onDark.hex.uppercased() == "#FFFFFF")

        let onLight = HCTMath.readableOn(background: white, candidates: [white, black])
        #expect(onLight.hex.uppercased() == "#000000")

        // Test softContainer
        let container = HCTMath.softContainer(accent: blue, card: M3Color("#1E1E1E"), tint: 0.5)
        #expect(container.hex.hasPrefix("#"))
    }

    @Test("Arbitrary Root Key Decoding, Roundtrip, and getSetting/setSetting")
    func testArbitraryKeyConfigRoundtrip() throws {
        let json = """
        {
            "theme": "espresso",
            "isLightMode": false,
            "dockDeadZone": 18,
            "customFloatOption": 42.5,
            "customArrayOption": ["foo", "bar"],
            "controlCenterColumns": 10
        }
        """

        let config = DMSConfig.load(from: Data(json.utf8))
        #expect(config.theme == "espresso")
        #expect(config.isLightMode == false)
        #expect(config.controlCenterColumns == 10)

        // Verify arbitrary keys decoded into rawSettings
        #expect(config.getSetting("dockDeadZone")?.intValue == 18)
        #expect(config.getSetting("customFloatOption")?.doubleValue == 42.5)
        #expect(config.getSetting("customArrayOption")?.arrayValue?.compactMap(\.stringValue) == ["foo", "bar"])

        // Mutate both strongly-typed and arbitrary keys
        var mutableConfig = config
        mutableConfig.setSetting("theme", value: AnyCodable("nord"))
        mutableConfig.setSetting("dockDeadZone", value: AnyCodable(24))
        mutableConfig.setSetting("newDynamicKey", value: AnyCodable("dynamicValue"))

        #expect(mutableConfig.theme == "nord")
        #expect(mutableConfig.getSetting("theme")?.stringValue == "nord")
        #expect(mutableConfig.getSetting("dockDeadZone")?.intValue == 24)
        #expect(mutableConfig.getSetting("newDynamicKey")?.stringValue == "dynamicValue")

        // Re-encode and verify roundtrip preserves dynamic keys
        let encodedData = try mutableConfig.encodeJSON()
        let reloadedConfig = DMSConfig.load(from: encodedData)

        #expect(reloadedConfig.theme == "nord")
        #expect(reloadedConfig.getSetting("dockDeadZone")?.intValue == 24)
        #expect(reloadedConfig.getSetting("newDynamicKey")?.stringValue == "dynamicValue")
        #expect(reloadedConfig.getSetting("customFloatOption")?.doubleValue == 42.5)
    }

    @Test("Grid Packing Oversized Cards and Gravity Stress")
    func testGridPackingSolverOversizedAndStress() {
        // Card with w=12 in 6-column grid (oversized card)
        let oversized = [
            GridPackingSolver.CardItem(id: "giant", w: 12, h: 2),
            GridPackingSolver.CardItem(id: "small1", w: 2, h: 1),
            GridPackingSolver.CardItem(id: "tall", w: 2, h: 8)
        ]

        let layout = GridPackingSolver.packCards(
            cards: oversized,
            columns: 6,
            width: 480,
            gap: 8,
            rowUnit: 64,
            step: 0.5,
            gravity: true
        )

        #expect(layout.columns == 6)
        #expect(layout.slots.count == 3)
        // Ensure giant was placed without crash and fits within columns
        let giantSlot = layout.slots.first(where: { $0.id == "giant" })
        #expect(giantSlot != nil)
        #expect(giantSlot!.cols <= 6.0)

        // Multiple cards gravity settle stress
        var manyCards: [GridPackingSolver.CardItem] = []
        for i in 0..<16 {
            manyCards.append(GridPackingSolver.CardItem(
                id: "card_\(i)",
                w: Double((i % 4) + 1),
                h: Double((i % 3) + 1)
            ))
        }

        let stressLayout = GridPackingSolver.packCards(
            cards: manyCards,
            columns: 8,
            width: 600,
            gap: 8,
            rowUnit: 64,
            gravity: true
        )
        #expect(stressLayout.slots.count == 16)
        #expect(stressLayout.totalHeight > 0)
    }

    @Test("Dock Magnification Unit Target Edge Cases")
    func testDockMagnificationEngineBoundaryAndEmpty() {
        // 1. Empty spans - defaults back to original ID
        let emptyResult = DockMagnificationEngine.unitTarget(spans: [], id: "test", offset: 20)
        #expect(emptyResult == "test")

        // 2. Single span - stays put on self
        let singleSpan = [(id: "app_1", start: 0.0, end: 50.0)]
        let singleResult = DockMagnificationEngine.unitTarget(spans: singleSpan, id: "app_1", offset: 100)
        #expect(singleResult == "app_1")

        // 3. Target not found in spans - defaults back to original ID
        let notFound = DockMagnificationEngine.unitTarget(spans: singleSpan, id: "nonexistent", offset: 10)
        #expect(notFound == "nonexistent")

        // 4. Zero-width span boundary
        let zeroSpans = [
            (id: "app_1", start: 0.0, end: 50.0),
            (id: "zero", start: 50.0, end: 50.0),
            (id: "app_2", start: 50.0, end: 100.0)
        ]
        let zeroResult = DockMagnificationEngine.unitTarget(spans: zeroSpans, id: "app_1", offset: 30)
        #expect(zeroResult == "app_2")
    }
}

