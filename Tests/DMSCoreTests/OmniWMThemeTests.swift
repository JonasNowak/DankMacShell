import Testing
import Foundation
@testable import DMSCore
import DankThemeEngine

@Suite("OmniWM Theme and Border Gradient Tests")
struct OmniWMThemeTests {

    @Test("Gradient Colors Resolution for All Modes")
    func testResolveColors() {
        let palette = StockThemes.purpleDark

        // 1. Expressive Mode (Option 1 - Default): Primary -> Tertiary
        let expressive = OmniWMThemeUpdater.resolveColors(palette: palette, mode: .expressive)
        #expect(expressive.start.hex == palette.primary.hex)
        #expect(expressive.end.hex == palette.tertiary.hex)
        #expect(expressive.solid.hex == palette.primary.hex)
        #expect(expressive.isGradient == true)

        // 2. Analogous Mode: Primary -> Secondary
        let analogous = OmniWMThemeUpdater.resolveColors(palette: palette, mode: .analogous)
        #expect(analogous.start.hex == palette.primary.hex)
        #expect(analogous.end.hex == palette.secondary.hex)
        #expect(analogous.isGradient == true)

        // 3. Luminance Mode: PrimaryContainer -> Primary
        let luminance = OmniWMThemeUpdater.resolveColors(palette: palette, mode: .luminance)
        #expect(luminance.start.hex == palette.primaryContainer.hex)
        #expect(luminance.end.hex == palette.primary.hex)
        #expect(luminance.isGradient == true)

        // 4. Dual Wallpaper Mode: Primary -> Custom Secondary Seed
        let customSecondary = M3Color("#FFB74D")
        let dual = OmniWMThemeUpdater.resolveColors(palette: palette, secondarySeed: customSecondary, mode: .dualWallpaper)
        #expect(dual.start.hex == palette.primary.hex)
        #expect(dual.end.hex == customSecondary.hex)
        #expect(dual.isGradient == true)

        // 5. Solid Mode: No gradient, single border color
        let solid = OmniWMThemeUpdater.resolveColors(palette: palette, mode: .solid)
        #expect(solid.solid.hex == palette.primary.hex)
        #expect(solid.isGradient == false)
    }

    @Test("Surgical In-Place Update Preserves Comments, Hotkeys and Other Tables")
    func testApplyThemePreservesUnrelatedSections() {
        let sampleTOML = """
        # Custom OmniWM Header Comment
        schemaVersion = 4

        [borders]
        enabled = true
        width = 1.5

        [borders.color]
        alpha = 1.0
        blue = 0.500000
        green = 0.500000
        red = 0.500000

        [borders.gradient]
        direction = "topRightToBottomLeft"
        enabled = false

        [borders.gradient.end]
        alpha = 1.0
        blue = 0.100000
        green = 0.100000
        red = 0.100000

        [borders.gradient.start]
        alpha = 1.0
        blue = 0.200000
        green = 0.200000
        red = 0.200000

        [gaps]
        size = 12.0

        [[hotkeys]]
        binding = "Option+Return"
        id = "openTerminal"
        """

        let palette = StockThemes.purpleDark
        let updated = OmniWMThemeUpdater.applyTheme(
            to: sampleTOML,
            palette: palette,
            mode: .expressive,
            direction: .topLeftToBottomRight,
            syncOverview: true,
            syncWorkspaceBar: true
        )

        // Verifications
        #expect(updated.contains("# Custom OmniWM Header Comment"))
        #expect(updated.contains("schemaVersion = 4"))
        #expect(updated.contains("[gaps]\nsize = 12.0") || updated.contains("size = 12.0"))
        #expect(updated.contains("binding = \"Option+Return\""))
        #expect(updated.contains("id = \"openTerminal\""))

        // Borders gradient updated to Expressive
        #expect(updated.contains("direction = \"topLeftToBottomRight\""))
        #expect(updated.contains("enabled = true"))

        // Primary color: #D0BCFF -> R: 0.815686, G: 0.737255, B: 1.0
        let primR = String(format: "%.6f", palette.primary.red)
        let primG = String(format: "%.6f", palette.primary.green)
        let primB = String(format: "%.6f", palette.primary.blue)
        #expect(updated.contains("red = \(primR)"))
        #expect(updated.contains("green = \(primG)"))
        #expect(updated.contains("blue = \(primB)"))

        // Tertiary color: #EFB8C8 -> R: 0.937255, G: 0.721569, B: 0.784314
        let tertR = String(format: "%.6f", palette.tertiary.red)
        let tertG = String(format: "%.6f", palette.tertiary.green)
        let tertB = String(format: "%.6f", palette.tertiary.blue)
        #expect(updated.contains("red = \(tertR)"))
        #expect(updated.contains("green = \(tertG)"))
        #expect(updated.contains("blue = \(tertB)"))
    }

    @Test("Idempotent Updates (Repeated Runs Produce Byte-Identical Output)")
    func testApplyThemeIdempotency() {
        let initialTOML = """
        [borders.color]
        alpha = 1.0
        blue = 0.000000
        green = 0.000000
        red = 0.000000

        [borders.gradient]
        direction = "topLeftToBottomRight"
        enabled = true

        [borders.gradient.start]
        alpha = 1.0
        blue = 0.000000
        green = 0.000000
        red = 0.000000

        [borders.gradient.end]
        alpha = 1.0
        blue = 0.000000
        green = 0.000000
        red = 0.000000
        """

        let palette = StockThemes.blueDark
        let firstRun = OmniWMThemeUpdater.applyTheme(to: initialTOML, palette: palette, mode: .expressive)
        let secondRun = OmniWMThemeUpdater.applyTheme(to: firstRun, palette: palette, mode: .expressive)

        #expect(firstRun == secondRun)
    }

    @Test("DankThemeEngine parity: updateOmniWMToml matches applyTheme byte-for-byte")
    func testDankThemeEngineOmniWMParity() throws {
        let sampleTOML = """
        # OmniWM settings
        schemaVersion = 4

        [borders]
        enabled = true
        width = 1.5

        [borders.color]
        alpha = 1.0
        blue = 0.500000
        green = 0.500000
        red = 0.500000

        [borders.gradient]
        direction = "topRightToBottomLeft"
        enabled = false

        [borders.gradient.end]
        alpha = 1.0
        blue = 0.100000
        green = 0.100000
        red = 0.100000

        [borders.gradient.start]
        alpha = 1.0
        blue = 0.200000
        green = 0.200000
        red = 0.200000

        [gaps]
        size = 12.0
        """

        for mode in OmniWMGradientMode.allCases {
            for direction in OmniWMGradientDirection.allCases {
                let palette = StockThemes.purpleDark
                let secondary = M3Color("#FFB74D")
                let viaDMS = OmniWMThemeUpdater.applyTheme(
                    to: sampleTOML,
                    palette: palette,
                    secondarySeed: secondary,
                    mode: mode,
                    direction: direction,
                    syncOverview: true,
                    syncWorkspaceBar: false
                )
                let viaDTE = try DankThemeEngine.updateOmniWMToml(
                    sampleTOML,
                    palette: palette.dtePalette,
                    config: DTEOmniWMConfig(
                        mode: mode.dteMode,
                        direction: direction.dteDirection,
                        syncOverview: true,
                        syncWorkspaceBar: false,
                        secondarySeed: secondary.hex
                    )
                )
                #expect(viaDMS == viaDTE, "mode \(mode.rawValue) direction \(direction.rawValue)")
            }
        }
    }

    @Test("OmniWM Configuration Codable Round-Trip")
    func testOmniWMConfigCodable() throws {
        var config = DMSConfig()
        config.autoThemeOmniWM = true
        config.omniwmGradientMode = .analogous
        config.omniwmGradientDirection = .topRightToBottomLeft
        config.omniwmSyncOverview = false
        config.omniwmSyncWorkspaceBar = true

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DMSConfig.self, from: data)

        #expect(decoded.autoThemeOmniWM == true)
        #expect(decoded.omniwmGradientMode == .analogous)
        #expect(decoded.omniwmGradientDirection == .topRightToBottomLeft)
        #expect(decoded.omniwmSyncOverview == false)
        #expect(decoded.omniwmSyncWorkspaceBar == true)
    }

    @Test("IPC Command Parsing for OmniWM Theming")
    func testIPCCommandParsing() {
        // CLI line parsing
        let syncCmd = IPCCommand.parseCLI(args: ["omniwm", "sync"])
        if case .omniwmTheme(let action, let arg) = syncCmd {
            #expect(action == "sync")
            #expect(arg == nil)
        } else {
            Issue.record("Expected .omniwmTheme(sync, nil)")
        }

        let modeCmd = IPCCommand.parseCLI(args: ["omniwm", "mode", "expressive"])
        if case .omniwmTheme(let action, let arg) = modeCmd {
            #expect(action == "mode")
            #expect(arg == "expressive")
        } else {
            Issue.record("Expected .omniwmTheme(mode, expressive)")
        }

        let getCmd = IPCCommand.parseCLI(args: ["omniwm", "get"])
        if case .omniwmTheme(let action, _) = getCmd {
            #expect(action == "get")
        } else {
            Issue.record("Expected .omniwmTheme(get)")
        }

        // URL parsing
        let url = URL(string: "dms://omniwm?action=direction&arg=topRightToBottomLeft")!
        let urlCmd = IPCCommand.parse(url: url)
        if case .omniwmTheme(let action, let arg) = urlCmd {
            #expect(action == "direction")
            #expect(arg == "topRightToBottomLeft")
        } else {
            Issue.record("Expected .omniwmTheme(direction, topRightToBottomLeft)")
        }
    }
}
