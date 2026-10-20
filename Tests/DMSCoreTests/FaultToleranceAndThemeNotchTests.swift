import Testing
import Foundation
@testable import DMSCore

@Suite("DankSearch Fault Tolerance Tests")
struct DankSearchFaultToleranceTests {

    @Test("SafeMathParser Incomplete and Malformed Input (NSException Immunity)")
    func testSafeMathParserRobustness() {
        // Expressions that previously caused uncatchable NSException in NSExpression(format:)
        let incompleteInputs = ["2+", "10 *", "(", "((5 + 2)", "sin(", "sqrt(", "2 ^", "%", "++", "+-/*"]
        for input in incompleteInputs {
            let res = AppSearch.evaluateMath(query: input)
            #expect(res == nil, "Incomplete input '\(input)' should safely return nil instead of crashing")
        }

        // Valid math operations
        let resAdd = AppSearch.evaluateMath(query: "15 + 27")
        #expect(resAdd?.result == "42")

        let resPrecedence = AppSearch.evaluateMath(query: "2 + 3 * 4")
        #expect(resPrecedence?.result == "14")

        let resParens = AppSearch.evaluateMath(query: "(2 + 3) * 4")
        #expect(resParens?.result == "20")

        let resPower = AppSearch.evaluateMath(query: "2 ^ 10")
        #expect(resPower?.result == "1024")

        let resHex = AppSearch.evaluateMath(query: "0x10 + 0x20")
        #expect(resHex?.result == "48")

        let resFunc = AppSearch.evaluateMath(query: "sqrt(144) + abs(-8)")
        #expect(resFunc?.result == "20")

        let resPercentage = AppSearch.evaluateMath(query: "25% of 200")
        #expect(resPercentage?.result == "50")

        // Paths and shell commands should be ignored by calculator
        #expect(AppSearch.evaluateMath(query: "/usr/bin/python3") == nil)
        #expect(AppSearch.evaluateMath(query: "~/Documents") == nil)
    }

    @Test("DankSearch Output Parser Handles JSON, NDJSON, and Malformed Output")
    func testDankSearchOutputParser() {
        // Valid JSON array
        let validJson = """
        [
            {"name": "readme.md", "path": "/Users/test/readme.md", "isDirectory": false},
            {"name": "Projects", "path": "/Users/test/Projects", "isDirectory": true}
        ]
        """.data(using: .utf8)!

        let parseRes = DankSearchClient.parseOutput(validJson, maxResults: 10)
        switch parseRes {
        case .success(let items):
            #expect(items.count == 2)
            #expect(items[0].name == "readme.md")
            #expect(items[0].path == "/Users/test/readme.md")
            #expect(!items[0].isDirectory)
            #expect(items[1].name == "Projects")
            #expect(items[1].isDirectory)
        case .failure(let err):
            Issue.record("Failed to parse valid JSON: \(err)")
        }

        // Valid NDJSON
        let validNDJson = """
        {"name": "file1.txt", "path": "/Users/test/file1.txt"}
        {"name": "file2.txt", "path": "/Users/test/file2.txt"}
        """.data(using: .utf8)!

        let ndjsonRes = DankSearchClient.parseOutput(validNDJson, maxResults: 10)
        switch ndjsonRes {
        case .success(let items):
            #expect(items.count == 2)
            #expect(items[0].path == "/Users/test/file1.txt")
        case .failure(let err):
            Issue.record("Failed to parse valid NDJSON: \(err)")
        }

        // Newline-delimited file paths
        let plainPaths = """
        /Users/test/fileA.swift
        /Users/test/fileB.swift
        ~/test/fileC.swift
        """.data(using: .utf8)!

        let pathsRes = DankSearchClient.parseOutput(plainPaths, maxResults: 10)
        switch pathsRes {
        case .success(let items):
            #expect(items.count == 3)
            #expect(items[0].name == "fileA.swift")
        case .failure(let err):
            Issue.record("Failed to parse valid plain paths: \(err)")
        }

        // Malformed non-JSON non-path output
        let garbage = "SOMETHING BROKE IN BACKEND INTERNAL FATAL\nCORRUPT DATA\n???".data(using: .utf8)!
        let garbageRes = DankSearchClient.parseOutput(garbage, maxResults: 10)
        switch garbageRes {
        case .success:
            Issue.record("Garbage output should have resulted in .malformedOutput")
        case .failure(let err):
            if case .malformedOutput = err {
                // Expected
            } else {
                Issue.record("Expected malformedOutput error, got \(err)")
            }
        }
    }

    @Test("DankSearch Client Crash Isolation and Recovery")
    func testDankSearchClientCrashIsolationAndRecovery() {
        let client = DankSearchClient(timeout: 0.1)

        // 1. Simulate process crash
        client.configure(customExecutor: { _, _, _ in
            return .failure(.crashedWithSignal(11, stderr: "Segmentation fault: 11"))
        })

        let response1 = client.searchFiles(query: "report", maxResults: 5)
        #expect(response1.usedFallback == true, "Crashed backend should seamlessly fall back")
        #expect(client.healthState.isDegraded == true)
        #expect(client.diagnostics.count >= 1)

        // 2. Next search attempt with healthy backend automatically recovers health state
        client.configure(customExecutor: { _, _, _ in
            let sample = """
            [{"name": "recovered_report.pdf", "path": "/Users/test/recovered_report.pdf"}]
            """.data(using: .utf8)!
            return .success(sample)
        })

        let response2 = client.searchFiles(query: "report", maxResults: 5)
        #expect(response2.usedFallback == false)
        #expect(response2.files.count == 1)
        #expect(response2.files[0].name == "recovered_report.pdf")
        #expect(client.healthState == .healthy, "Client should auto-recover on successful subsequent query")

        // 3. Manual reset
        client.resetAndRecover()
        #expect(client.healthState == .healthy)
        #expect(client.consecutiveFailures == 0)
    }

    @Test("DankSearch Client Watchdog Timeout Isolation")
    func testDankSearchTimeoutWatchdog() {
        let client = DankSearchClient(timeout: 0.05)

        // Simulate hang/timeout
        client.configure(customExecutor: { _, _, _ in
            return .failure(.timedOut(0.05))
        })

        let response = client.searchFiles(query: "slow_query", maxResults: 5)
        #expect(response.usedFallback == true)
        #expect(client.healthState.isDegraded == true)
        #expect(client.diagnostics.contains { $0.error == .timedOut(0.05) })
    }
}

@Suite("Theme System and Token Customization Tests")
struct ThemeTokensAndCustomizationTests {

    @Test("M3 Shape Tokens and Strength Scaling")
    func testShapeTokens() {
        // Default strength 50 = 1.0x scale
        let defaultShape = M3ShapeTokens(strength: 50)
        #expect(defaultShape.scale == 1.0)
        #expect(defaultShape.s == 8.0)
        #expect(defaultShape.m == 12.0)
        #expect(defaultShape.l == 16.0)
        #expect(defaultShape.xl == 28.0)

        // Strength 100 = 2.0x scale
        let doubledShape = M3ShapeTokens(strength: 100)
        #expect(doubledShape.scale == 2.0)
        #expect(doubledShape.s == 16.0)
        #expect(doubledShape.m == 24.0)

        // Fixed radius overrides scaling
        let fixedShape = M3ShapeTokens(strength: 50, fixedRadius: 10.0)
        #expect(fixedShape.s == 10.0)
        #expect(fixedShape.m == 10.0)
        #expect(fixedShape.full == 10.0)
    }

    @Test("M3 Motion Tokens and Reduced Motion")
    func testMotionTokens() {
        let normalMotion = M3MotionTokens(animationSpeed: 1.0, reducedMotion: false)
        #expect(normalMotion.durShort == 0.200)
        #expect(normalMotion.durMed == 0.450)
        #expect(normalMotion.slidePx == 80.0)

        // 2x speed cuts durations in half
        let fastMotion = M3MotionTokens(animationSpeed: 2.0, reducedMotion: false)
        #expect(abs(fastMotion.durShort - 0.100) < 0.001)

        // Reduced motion zeroes durations and slide translations
        let reduced = M3MotionTokens(animationSpeed: 1.0, reducedMotion: true)
        #expect(reduced.durShort == 0.0)
        #expect(reduced.durMed == 0.0)
        #expect(reduced.slidePx == 0.0)
    }

    @Test("M3 Typography and Surface Customization")
    func testTypographyAndSurfaceTokens() {
        let typography = M3TypographyTokens(
            fontFamilyUI: "Inter",
            fontFamilyMono: "JetBrains Mono",
            fontFamilyDisplay: "Playfair Display",
            fontScale: 1.2
        )
        #expect(typography.fontFamilyUI == "Inter")
        #expect(typography.scaledSize(10.0) == 12.0)

        let surface = M3SurfaceTokens(
            surfaceOpacity: 0.90,
            popupTransparency: 0.95,
            floatingWindowTransparency: 0.85,
            blurRadius: 32,
            borderWidth: 1.5,
            outlineOpacity: 0.20
        )
        #expect(surface.surfaceOpacity == 0.90)
        #expect(surface.blurRadius == 32)
        #expect(surface.borderWidth == 1.5)

        let shadow = M3ShadowTokens(enabled: true, blurRadius: 20.0, offsetY: 10.0, opacity: 0.4)
        #expect(shadow.enabled == true)
        #expect(shadow.blurRadius == 20.0)
    }

    @Test("Community Themes and Matugen Schemes")
    func testCommunityThemesAndMatugenSchemes() {
        // Stock themes check
        #expect(StockThemes.allThemeNames.contains("purple"))
        #expect(StockThemes.allThemeNames.contains("blue"))

        // Community themes in allAvailableThemes
        let community = ["catppuccin-mocha", "catppuccin-latte", "nord", "gruvbox", "tokyo-night", "everforest"]
        for theme in community {
            #expect(StockThemes.allAvailableThemes.contains(theme), "Expected StockThemes.allAvailableThemes to contain \(theme)")
            let darkTheme = StockThemes.theme(named: theme, isDark: true)
            #expect(!darkTheme.name.isEmpty)
        }

        // Matugen Schemes
        for scheme in MatugenScheme.allCases {
            #expect(!scheme.displayName.isEmpty)
        }

        // Dynamic theme generation with specific Matugen scheme
        let (darkVibrant, _) = DynamicThemeGenerator.generate(from: M3Color("#007ACC"), name: "VSCode", scheme: .vibrant)
        #expect(darkVibrant.name == "VSCode")
    }

    @Test("DMSConfig Round-Trip with Theme, Bar, and Island Customizations")
    func testConfigCustomizationRoundTrip() throws {
        var cfg = DMSConfig()
        cfg.theme = "catppuccin-mocha"
        cfg.isLightMode = false
        cfg.cornerRadiusStrength = 75.0
        cfg.surfaceOpacity = 0.88
        cfg.blurRadius = 28.0
        cfg.borderWidth = 1.2
        cfg.fontFamily = "Google Sans"
        cfg.fontScale = 1.1

        var bar = BarConfig.default
        bar.thickness = 44
        bar.horizontalPadding = 16
        bar.verticalPadding = 6
        bar.adaptToNotch = true
        bar.cornerRadius = 14
        bar.widgetStyles["clock"] = BarWidgetStyleOptions(alias: "Main Clock", fontSize: 13, bold: true)
        cfg.barConfigs = [bar]

        var island = IslandSettings.default
        island.compactWidth = 190.0
        island.expandedWidth = 460.0
        island.springStiffness = 620.0
        island.gothCorners = true
        cfg.islandSettings = island

        let json = try cfg.encodeJSON()
        let decoded = DMSConfig.load(from: json)

        #expect(decoded.theme == "catppuccin-mocha")
        #expect(decoded.cornerRadiusStrength == 75.0)
        #expect(decoded.surfaceOpacity == 0.88)
        #expect(decoded.fontFamily == "Google Sans")
        #expect(decoded.barConfigs.first?.thickness == 44)
        #expect(decoded.barConfigs.first?.adaptToNotch == true)
        #expect(decoded.barConfigs.first?.widgetStyles["clock"]?.alias == "Main Clock")
        #expect(decoded.islandSettings.compactWidth == 190.0)
        #expect(decoded.islandSettings.springStiffness == 620.0)
        #expect(decoded.islandSettings.gothCorners == true)
    }
}

@Suite("Mac Display Notch and Bar Layout Solver Tests")
struct NotchLayoutSolverTests {

    @Test("ScreenNotchGeometry Detection and Safe Areas")
    func testScreenNotchGeometry() {
        // Standard external monitor (e.g. 4K 3840x2160)
        let external = ScreenNotchGeometry.standardMonitor(screenID: "ext-1", width: 3840, height: 2160)
        #expect(!external.hasNotch)
        #expect(external.notchWidth == 0.0)
        #expect(external.leftSafeAreaWidth == 3840.0)
        #expect(external.rightSafeAreaWidth == 3840.0)

        // MacBook with hardware notch
        let macNotch = ScreenNotchGeometry.fromScreenMeasurements(
            screenID: "built-in",
            screenWidth: 1512,
            screenHeight: 982,
            safeAreaTop: 34.0,
            auxiliaryLeftWidth: 650.0,
            auxiliaryRightMinX: 862.0,
            auxiliaryRightWidth: 650.0
        )
        #expect(macNotch.hasNotch)
        #expect(macNotch.notchHeight == 34.0)
        #expect(macNotch.notchMinX == 650.0)
        #expect(macNotch.notchMaxX == 862.0)
        #expect(macNotch.notchWidth == 212.0)
        #expect(macNotch.leftSafeAreaWidth == 650.0)
        #expect(macNotch.rightSafeAreaWidth == 650.0)

        // Simulated notch for development/testing
        let simulated = ScreenNotchGeometry.fromScreenMeasurements(
            screenID: "sim-1",
            screenWidth: 1440,
            screenHeight: 900,
            safeAreaTop: 0,
            auxiliaryLeftWidth: nil,
            auxiliaryRightMinX: nil,
            auxiliaryRightWidth: nil,
            simulateNotch: true,
            simulatedNotchWidth: 200.0,
            simulatedNotchHeight: 32.0
        )
        #expect(simulated.hasNotch)
        #expect(simulated.notchWidth == 200.0)
        #expect(simulated.notchHeight == 32.0)
    }

    @Test("NotchAwareBarLayoutSolver Splits and Reflows Widgets Around Notch")
    func testNotchAwareBarLayoutSolver() {
        let notch = ScreenNotchGeometry.fromScreenMeasurements(
            screenID: "mbp",
            screenWidth: 1512,
            screenHeight: 982,
            safeAreaTop: 34.0,
            auxiliaryLeftWidth: 650.0,
            auxiliaryRightMinX: 862.0,
            auxiliaryRightWidth: 650.0
        )

        var config = BarConfig.default
        config.adaptToNotch = true
        config.layout = BarLayout(
            left: [BarWidgetEntry(id: "workspaces"), BarWidgetEntry(id: "runningApps")],
            center: [BarWidgetEntry(id: "clock"), BarWidgetEntry(id: "weather")],
            right: [BarWidgetEntry(id: "systemTray"), BarWidgetEntry(id: "battery"), BarWidgetEntry(id: "controlCenter")]
        )

        let layout = NotchAwareBarLayoutSolver.solve(
            barLength: 1496.0,
            barPosition: "top",
            barMargin: 8.0,
            screenNotch: notch,
            islandReservedWidth: 220.0,
            leftSizes: [160.0, 180.0],
            centerSizes: [120.0, 90.0],
            rightSizes: [80.0, 60.0, 44.0]
        )

        // Verify notch split is active and exclusion bounds are computed
        #expect(layout.isNotchSplitActive == true)
        #expect(layout.exclusionMinX != nil)
        #expect(layout.exclusionMaxX != nil)

        if let exMin = layout.exclusionMinX, let exMax = layout.exclusionMaxX {
            #expect(exMax > exMin)
            #expect(exMax - exMin >= 212.0)

            // Verify no placed widget collides with or overlaps the notch/island exclusion zone
            for placed in layout.allVisiblePlacements {
                let overlaps = (placed.x < exMax) && (placed.maxX > exMin)
                #expect(!overlaps, "Widget at [\(placed.x), \(placed.maxX)] must not overlap exclusion zone [\(exMin), \(exMax)]")
            }
        }
    }
}

@Suite("Dynamic Island Physics and State Machine Tests")
struct IslandEngineTests {

    @Test("8-DOF VectorSpringEngine RK4 Physics Simulation")
    func testVectorSpringPhysicsConvergence() {
        let initial = IslandGeometryVector(width: 176.0, height: 32.0, offsetX: 0.0, offsetY: 0.0)
        let target = IslandGeometryVector(width: 420.0, height: 180.0, offsetX: 0.0, offsetY: 8.0)

        var engine = VectorSpringEngine(initial: initial, stiffness: 560.0, damping: 37.0)
        engine.target = target

        #expect(!engine.isAtRest)

        // Simulate 120 frames at 60fps (2.0s)
        for _ in 0..<120 {
            _ = engine.step(dt: 1.0 / 60.0)
            if engine.isAtRest { break }
        }

        #expect(engine.isAtRest, "8-DOF Spring should converge to target within 2 seconds")
        #expect(abs(engine.current.width - 420.0) < 0.5)
        #expect(abs(engine.current.height - 180.0) < 0.5)
    }

    @Test("Island State Machine Priority Arbitration (OSD > Notification > Media > Idle)")
    func testIslandStateMachinePriority() {
        var sm = IslandStateMachine()
        let now = Date()

        // 1. Idle state initially
        #expect(sm.resolveState(at: now) == .idle)

        // 2. Media playing elevates to compactMedia
        sm.isMediaPlaying = true
        #expect(sm.resolveState(at: now) == .compactMedia)

        // 3. Notification alert overrides Media
        sm.triggerNotification(at: now, duration: 5.0)
        #expect(sm.resolveState(at: now) == .compactNotification)

        // 4. OSD event overrides Notification
        sm.triggerOSD(at: now, duration: 3.0)
        #expect(sm.resolveState(at: now) == .compactOSD)

        // 5. After 3.5s, OSD expires; Notification (5s duration) resumes
        let at3_5s = now.addingTimeInterval(3.5)
        #expect(sm.resolveState(at: at3_5s) == .compactNotification)

        // 6. After 5.5s, Notification expires; Media resumes
        let at5_5s = now.addingTimeInterval(5.5)
        #expect(sm.resolveState(at: at5_5s) == .compactMedia)

        // 7. Explicit expansion overrides compact states
        sm.expand(to: .media, at: at5_5s)
        #expect(sm.resolveState(at: at5_5s) == .expandedMedia)
    }

    @Test("Expanded Island Geometry Has Uniform Height and Width Across Tabs")
    func testExpandedIslandGeometryUniformHeight() {
        var settings = IslandSettings.default
        settings.expandedWidth = 420.0
        settings.expandedHeight = 180.0

        let expandedStates: [IslandPresentationState] = [
            .expandedHome,
            .expandedMedia,
            .expandedNotification,
            .expandedOSD,
            .expandedControlCenter,
            .expandedLauncher,
            .expandedClipboard,
            .expandedPowerMenu,
            .expandedWeather
        ]

        for state in expandedStates {
            let geom = IslandStateMachine.targetGeometry(for: state, settings: settings)
            #expect(geom.width == 420.0, "State \(state) width should be uniform")
            #expect(geom.height == 180.0, "State \(state) height should be uniform (equal vertical size)")
        }

        // Custom height setting should also scale uniformly
        settings.expandedHeight = 220.0
        for state in expandedStates {
            let geom = IslandStateMachine.targetGeometry(for: state, settings: settings)
            #expect(geom.height == 220.0, "State \(state) height should adapt to custom expandedHeight")
        }
    }
}

