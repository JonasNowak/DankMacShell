import Testing
import Foundation
@testable import DMSCore
import DankThemeEngine

@Suite("Terminal Theme Format Tests (v0.7)")
struct TerminalThemeTests {

    private var palette: ThemePalette { StockThemes.purpleDark }
    private var dank16: Dank16Palette { Dank16Generator.generate(from: palette) }

    private func rendered(_ emulator: TerminalEmulator) -> String {
        TerminalThemeRenderer.render(emulator: emulator, palette: palette, dank16: dank16, themeName: palette.name)
    }

    // MARK: - Renderer content: all 16 ANSI colors + bg/fg/cursor in every format

    @Test("All emulators render all 16 ANSI colors plus background, foreground, cursor")
    func testAllEmulatorsContainFullPalette() {
        for emulator in TerminalEmulator.allCases {
            let output = rendered(emulator).lowercased()
            if emulator == .iterm2 {
                // iTerm2 Dynamic Profiles encode colors as RGB components, not hex.
                for i in 0..<16 {
                    #expect(output.contains("\"ansi \(i) color\""), "iterm2 missing Ansi \(i) Color")
                }
                #expect(output.contains("\"background color\""))
                #expect(output.contains("\"foreground color\""))
                #expect(output.contains("\"cursor color\""))
                continue
            }
            for color in dank16.colors {
                #expect(output.contains(color.hex.lowercased()), "\(emulator) missing ANSI color \(color.hex)")
            }
            #expect(output.contains(dank16.background.hex.lowercased()), "\(emulator) missing background")
            #expect(output.contains(dank16.foreground.hex.lowercased()), "\(emulator) missing foreground")
            #expect(output.contains(dank16.cursor.hex.lowercased()), "\(emulator) missing cursor")
        }
    }

    @Test("Dank16 palette has exactly 16 colors")
    func testDank16Has16Colors() {
        #expect(dank16.colors.count == 16)
    }

    // MARK: - Format syntax

    @Test("Ghostty format uses palette/background/foreground/cursor-color keys")
    func testGhosttySyntax() {
        let output = rendered(.ghostty)
        #expect(output.contains("palette = 0="))
        #expect(output.contains("palette = 15="))
        #expect(output.contains("background = "))
        #expect(output.contains("foreground = "))
        #expect(output.contains("cursor-color = "))
        #expect(output.contains("selection-background = "))
    }

    @Test("Kitty format uses colorN / foreground / background / cursor keys")
    func testKittySyntax() {
        let output = rendered(.kitty)
        #expect(output.contains("color0 "))
        #expect(output.contains("color15 "))
        #expect(output.contains("foreground "))
        #expect(output.contains("background "))
        #expect(output.contains("cursor "))
        #expect(output.contains("selection_background "))
    }

    @Test("Alacritty format is TOML with primary/cursor/selection/normal/bright sections")
    func testAlacrittySyntax() {
        let output = rendered(.alacritty)
        #expect(output.contains("[colors.primary]"))
        #expect(output.contains("[colors.cursor]"))
        #expect(output.contains("[colors.selection]"))
        #expect(output.contains("[colors.normal]"))
        #expect(output.contains("[colors.bright]"))
        #expect(output.contains("black = '"))
        #expect(output.contains("white = '"))
        #expect(output.contains("background = '"))
        #expect(output.contains("cursor = '"))
    }

    @Test("iTerm2 format is a JSON Dynamic Profile with Ansi 0..15 color entries")
    func testITerm2Syntax() {
        let output = rendered(.iterm2)
        guard let data = output.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let profile = parsed.first else {
            Issue.record("iTerm2 output is not a JSON array of profiles")
            return
        }
        for i in 0..<16 {
            guard let ansi = profile["Ansi \(i) Color"] as? [String: Any] else {
                Issue.record("missing Ansi \(i) Color")
                continue
            }
            #expect(ansi["Red Component"] != nil)
            #expect(ansi["Green Component"] != nil)
            #expect(ansi["Blue Component"] != nil)
        }
        #expect(profile["Background Color"] != nil)
        #expect(profile["Foreground Color"] != nil)
        #expect(profile["Cursor Color"] != nil)
        #expect(profile["Name"] as? String != nil)
    }

    @Test("iTerm2 ANSI components match the dank16 hex values")
    func testITerm2ColorComponents() {
        let output = rendered(.iterm2)
        guard let data = output.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let profile = parsed.first else {
            Issue.record("iTerm2 output is not a JSON array of profiles")
            return
        }
        for (i, color) in dank16.colors.enumerated() {
            guard let ansi = profile["Ansi \(i) Color"] as? [String: Any],
                  let r = ansi["Red Component"] as? Double,
                  let g = ansi["Green Component"] as? Double,
                  let b = ansi["Blue Component"] as? Double else {
                Issue.record("missing Ansi \(i) Color")
                continue
            }
            #expect(abs(r - color.red) < 0.01)
            #expect(abs(g - color.green) < 0.01)
            #expect(abs(b - color.blue) < 0.01)
        }
    }

    // MARK: - XDG_CONFIG_HOME resolution

    @Test("configHome honors XDG_CONFIG_HOME when set")
    func testConfigHomeXDG() {
        let env = ["XDG_CONFIG_HOME": "/tmp/dms-xdg-test"]
        #expect(TerminalThemePaths.configHome(environment: env).path == "/tmp/dms-xdg-test")
    }

    @Test("configHome falls back to ~/.config when XDG_CONFIG_HOME is unset or empty")
    func testConfigHomeFallback() {
        let expected = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true).path
        #expect(TerminalThemePaths.configHome(environment: [:]).path == expected)
        #expect(TerminalThemePaths.configHome(environment: ["XDG_CONFIG_HOME": "  "]).path == expected)
    }

    @Test("configHome default parameter reads the process environment (setenv/unsetenv)")
    func testConfigHomeProcessEnvironment() {
        let original = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
        setenv("XDG_CONFIG_HOME", "/tmp/dms-xdg-env-test", 1)
        #expect(TerminalThemePaths.configHome().path == "/tmp/dms-xdg-env-test")
        unsetenv("XDG_CONFIG_HOME")
        let expected = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true).path
        #expect(TerminalThemePaths.configHome().path == expected)
        if let original { setenv("XDG_CONFIG_HOME", original, 1) } else { unsetenv("XDG_CONFIG_HOME") }
    }

    @Test("targetPath resolves per-emulator locations under the config home")
    func testTargetPaths() {
        let env = ["XDG_CONFIG_HOME": "/tmp/dms-xdg-paths"]
        #expect(TerminalThemePaths.targetPath(for: .ghostty, environment: env).path == "/tmp/dms-xdg-paths/ghostty/themes/dms")
        #expect(TerminalThemePaths.targetPath(for: .kitty, environment: env).path == "/tmp/dms-xdg-paths/kitty/dms-theme.conf")
        #expect(TerminalThemePaths.targetPath(for: .alacritty, environment: env).path == "/tmp/dms-xdg-paths/alacritty/dms-theme.toml")
        let iterm = TerminalThemePaths.targetPath(for: .iterm2, environment: env).path
        #expect(iterm.hasSuffix("Library/Application Support/iTerm2/DynamicProfiles/dms.json"))
        #expect(!iterm.contains("/tmp/dms-xdg-paths"), "iTerm2 DynamicProfiles must not live under XDG config home")
    }

    @Test("appSupportThemeJSON is the stable canonical DMS theme.json path")
    func testAppSupportThemeJSON() {
        let path = TerminalThemePaths.appSupportThemeJSON().path
        #expect(path.hasSuffix("Library/Application Support/DMS/theme.json"))
    }

    // MARK: - nix-store managed symlink detection

    @Test("isManagedSymlink detects symlinks resolving into the store prefix")
    func testIsManagedSymlink() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dms_nix_\(UUID().uuidString)")
        let store = tmp.appendingPathComponent("store", isDirectory: true)
        let storeFile = store.appendingPathComponent("abc-theme.conf")
        let configDir = tmp.appendingPathComponent("config/kitty", isDirectory: true)
        try FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try "theme".write(to: storeFile, atomically: true, encoding: .utf8)
        // Pass the unresolved store path — isManagedSymlink canonicalizes the prefix itself
        // (realpath resolves /var -> /private/var style links).
        let storeReal = store.path

        // 1. Symlink pointing into the store -> managed.
        let managed = configDir.appendingPathComponent("dms-theme.conf")
        try FileManager.default.createSymbolicLink(at: managed, withDestinationURL: storeFile)
        #expect(TerminalThemeSecurity.isManagedSymlink(path: managed.path, storePrefix: storeReal))

        // 2. Regular file -> not managed.
        let regular = configDir.appendingPathComponent("regular.conf")
        try "x".write(to: regular, atomically: true, encoding: .utf8)
        #expect(!TerminalThemeSecurity.isManagedSymlink(path: regular.path, storePrefix: storeReal))

        // 3. Symlink to a normal (non-store) file -> not managed.
        let normalTarget = configDir.appendingPathComponent("normal.conf")
        try "y".write(to: normalTarget, atomically: true, encoding: .utf8)
        let normalLink = configDir.appendingPathComponent("normal-link.conf")
        try FileManager.default.createSymbolicLink(at: normalLink, withDestinationURL: normalTarget)
        #expect(!TerminalThemeSecurity.isManagedSymlink(path: normalLink.path, storePrefix: storeReal))

        // 4. Direct path inside the store -> managed.
        #expect(TerminalThemeSecurity.isManagedSymlink(path: storeFile.path, storePrefix: storeReal))

        // 5. Dangling symlink into the store (home-manager gc'd target) -> managed via manual walk.
        let dangling = configDir.appendingPathComponent("dangling.conf")
        try FileManager.default.createSymbolicLink(
            at: dangling,
            withDestinationURL: store.appendingPathComponent("does-not-exist.conf")
        )
        #expect(TerminalThemeSecurity.isManagedSymlink(path: dangling.path, storePrefix: storeReal))

        // 6. Symlink chain (link -> link -> store file) -> managed.
        let midLink = configDir.appendingPathComponent("mid.conf")
        try FileManager.default.createSymbolicLink(at: midLink, withDestinationURL: managed)
        #expect(TerminalThemeSecurity.isManagedSymlink(path: midLink.path, storePrefix: storeReal))

        // 7. Nonexistent path outside the store -> not managed, no crash.
        #expect(!TerminalThemeSecurity.isManagedSymlink(
            path: configDir.appendingPathComponent("missing.conf").path,
            storePrefix: storeReal
        ))

        try? FileManager.default.removeItem(at: tmp)
    }

    // MARK: - Canonical theme document

    @Test("TerminalThemeDocument JSON roundtrip preserves all fields")
    func testThemeDocumentRoundtrip() throws {
        let doc = TerminalThemeDocument(
            themeName: palette.name,
            isDark: palette.isDark,
            palette: palette,
            dank16: dank16,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try doc.encodeJSON()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970 // matches encodeJSON
        let decoded = try decoder.decode(TerminalThemeDocument.self, from: data)
        #expect(decoded == doc)
        // Pretty-printed, sorted, machine-readable.
        let text = String(data: data, encoding: .utf8) ?? ""
        #expect(text.contains("\n"))
        #expect(text.contains("\"dank16\""))
        #expect(text.contains("\"themeName\""))
    }

    // MARK: - dmenu staging

    @Test("DMenuStaging request IDs are unique uppercase hex")
    func testDMenuRequestIDs() {
        let a = DMenuStaging.newRequestID()
        let b = DMenuStaging.newRequestID()
        #expect(a != b)
        #expect(a.count == 32)
        #expect(a == a.uppercased())
        #expect(a.allSatisfy { $0.isHexDigit })
    }

    @Test("DMenuStaging stage/read/result/cleanup in a temp directory")
    func testDMenuStagingLifecycle() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dms_dmenu_\(UUID().uuidString)")
        let requestID = DMenuStaging.newRequestID()
        let candidates = ["alpha", "beta", "gamma"]

        let staged = try DMenuStaging.stage(candidates: candidates, requestID: requestID, in: dir)
        #expect(staged == DMenuStaging.candidatesPath(for: requestID, in: dir))
        #expect(FileManager.default.fileExists(atPath: staged.path))
        #expect(DMenuStaging.readCandidates(at: staged) == candidates)

        // Result file absent before the daemon answers.
        #expect(DMenuStaging.readResult(for: requestID, in: dir) == nil)
        try "beta".write(to: DMenuStaging.resultPath(for: requestID, in: dir), atomically: true, encoding: .utf8)
        #expect(DMenuStaging.readResult(for: requestID, in: dir) == "beta")

        DMenuStaging.cleanup(requestID: requestID, in: dir)
        #expect(!FileManager.default.fileExists(atPath: staged.path))
        #expect(!FileManager.default.fileExists(atPath: DMenuStaging.resultPath(for: requestID, in: dir).path))
        #expect(DMenuStaging.readCandidates(at: staged).isEmpty)

        try? FileManager.default.removeItem(at: dir)
    }

    @Test("DMenuStaging default directory is <appSupport>/DMS/dmenu")
    func testDMenuDefaultDirectory() {
        let path = DMenuStaging.defaultDirectory().path
        #expect(path.hasSuffix("Library/Application Support/DMS/dmenu"))
    }

    // MARK: - Emulator live-reload helpers

    @Test("kittyGUIPids keeps only kitty GUI boss processes from ps output")
    func testKittyGUIPids() {
        let ps = """
          45968 /nix/store/abc-kitty/Applications/kitty.app/Contents/MacOS/kitty
          46657 /nix/store/abc-kitty/Applications/kitty.app/Contents/MacOS/kitty --config /tmp/kt/kitty.conf --listen-on unix:/tmp/kt/sock
          46700 /nix/store/abc-kitty/Applications/kitty.app/Contents/MacOS/kitty @ get-colors
          46701 /nix/store/abc-kitty/Applications/kitty.app/Contents/MacOS/kitty +runpy "print(1)"
          46702 /nix/store/abc-kitty/Applications/kitty.app/Contents/MacOS/kitten __watch_conf__ 45968 100 /etc/xdg/kitty/kitty.conf
          46703 /nix/store/abc-kitty/Applications/kitty.app/Contents/MacOS/kitty +open /tmp/x
          1234 /bin/zsh -l
        """
        let pids = EmulatorReload.kittyGUIPids(fromPSOutput: ps)
        #expect(pids == [45968, 46657, 46703])
    }

    @Test("kittyConfigReferencesTheme detects include directives only")
    func testKittyConfigReferencesTheme() {
        #expect(EmulatorReload.kittyConfigReferencesTheme("include dms-theme.conf\nfont_size 14\n"))
        #expect(EmulatorReload.kittyConfigReferencesTheme("include /nix/store/xyz/themes/rose-pine.conf\ninclude dms-theme.conf\n"))
        #expect(EmulatorReload.kittyConfigReferencesTheme("globinclude themes/*.conf\n", themeFileName: "dms-theme.conf") == false)
        #expect(!EmulatorReload.kittyConfigReferencesTheme("# include dms-theme.conf\nfont_size 14\n"))
        #expect(!EmulatorReload.kittyConfigReferencesTheme("include /nix/store/xyz/themes/rose-pine-moon.conf\n"))
        #expect(!EmulatorReload.kittyConfigReferencesTheme(""))
    }

    // MARK: - DankThemeEngine parity

    @Test("DankThemeEngine parity: target registry, render output, managed symlink")
    func testDankThemeEngineParity() throws {
        // Every DMSCore emulator maps to a registered engine target id.
        let targetIds = try DankThemeEngine.listTargets().map(\.id)
        for emulator in TerminalEmulator.allCases {
            #expect(targetIds.contains(emulator.rawValue))
            #expect(emulator.dteTargetId == emulator.rawValue)
        }

        // Rendering through the engine matches the DMSCore renderer byte-for-byte.
        let doc = TerminalThemeDocument(
            themeName: palette.name,
            isDark: palette.isDark,
            palette: palette,
            dank16: dank16
        )
        for emulator in TerminalEmulator.allCases {
            let dte = try DankThemeEngine.renderTerminal(targetId: emulator.rawValue, doc: doc.dteDocument)
            #expect(dte.targetId == emulator.rawValue)
            #expect(dte.content == rendered(emulator))
        }

        // Managed-symlink detection for the default /nix/store prefix delegates to the engine,
        // so both entry points agree on every path (existing store files, symlink chains,
        // dangling links, and plain non-store paths).
        let storePath = "/nix/store/abc-dms-theme/x.conf"
        #expect(DankThemeEngine.isManagedSymlink(storePath) == TerminalThemeSecurity.isManagedSymlink(path: storePath))
        let outside = "/tmp/dms-not-managed-\(UUID().uuidString).conf"
        #expect(!DankThemeEngine.isManagedSymlink(outside))
        #expect(!TerminalThemeSecurity.isManagedSymlink(path: outside))
        #expect(DankThemeEngine.isManagedSymlink(outside) == TerminalThemeSecurity.isManagedSymlink(path: outside))
    }

    // MARK: - Config toggles

    @Test("Terminal theme sync defaults: master on, ghostty/kitty/alacritty on, iTerm2 off")
    func testTerminalThemeDefaults() {
        let config = DMSConfig()
        #expect(config.terminalThemeSync)
        #expect(config.terminalThemeGhostty)
        #expect(config.terminalThemeKitty)
        #expect(config.terminalThemeAlacritty)
        #expect(!config.terminalThemeITerm2)
        #expect(config.isTerminalThemeEnabled(.ghostty))
        #expect(config.isTerminalThemeEnabled(.kitty))
        #expect(config.isTerminalThemeEnabled(.alacritty))
        #expect(!config.isTerminalThemeEnabled(.iterm2))
    }

    @Test("Master switch disables every emulator")
    func testTerminalThemeMasterSwitch() {
        var config = DMSConfig()
        config.terminalThemeSync = false
        for emulator in TerminalEmulator.allCases {
            #expect(!config.isTerminalThemeEnabled(emulator))
        }
    }

    @Test("Terminal theme toggles survive a Codable roundtrip and legacy decode defaults")
    func testTerminalThemeCodableRoundtrip() throws {
        var config = DMSConfig()
        config.terminalThemeSync = true
        config.terminalThemeITerm2 = true
        config.terminalThemeKitty = false
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DMSConfig.self, from: data)
        #expect(decoded.terminalThemeSync)
        #expect(decoded.terminalThemeITerm2)
        #expect(!decoded.terminalThemeKitty)
        #expect(decoded.terminalThemeGhostty)
        #expect(decoded.terminalThemeAlacritty)

        // Legacy config JSON without the new keys decodes with documented defaults.
        let legacy = "{}".data(using: .utf8)!
        let legacyConfig = try JSONDecoder().decode(DMSConfig.self, from: legacy)
        #expect(legacyConfig.terminalThemeSync)
        #expect(legacyConfig.terminalThemeGhostty)
        #expect(legacyConfig.terminalThemeKitty)
        #expect(legacyConfig.terminalThemeAlacritty)
        #expect(!legacyConfig.terminalThemeITerm2)
    }
}
