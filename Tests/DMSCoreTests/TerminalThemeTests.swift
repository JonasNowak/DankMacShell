import Testing
import Foundation
@testable import DMSCore
import DankThemeEngine

// .serialized: testConfigHomeProcessEnvironment mutates the process-wide XDG_CONFIG_HOME
// via setenv/unsetenv, which races with parallel tests reading the environment.
@Suite("Terminal Theme Format Tests (v0.7)", .serialized)
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

    @Test("Kitty format uses full kitty color keys (foreground, cursor, tabs, borders, color0..15)")
    func testKittySyntax() {
        let output = rendered(.kitty)
        for needle in [
            "foreground ",
            "background ",
            "selection_foreground ",
            "selection_background ",
            "cursor ",
            "cursor_text_color ",
            "url_color ",
            "active_border_color ",
            "inactive_border_color ",
            "bell_border_color ",
            "active_tab_foreground ",
            "active_tab_background ",
            "inactive_tab_foreground ",
            "inactive_tab_background ",
            "tab_bar_background none",
            "tab_bar_margin_color none",
            "mark1_foreground ",
            "color0 ",
            "color15 ",
        ] {
            #expect(output.contains(needle), "kitty missing \(needle)")
        }
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
        #expect(TerminalThemePaths.targetPath(for: .ghostty as TerminalEmulator, environment: env).path == "/tmp/dms-xdg-paths/ghostty/themes/dms")
        #expect(TerminalThemePaths.targetPath(for: .kitty as TerminalEmulator, environment: env).path == "/tmp/dms-xdg-paths/kitty/dms-theme.conf")
        #expect(TerminalThemePaths.targetPath(for: .alacritty as TerminalEmulator, environment: env).path == "/tmp/dms-xdg-paths/alacritty/dms-theme.toml")
        let iterm = TerminalThemePaths.targetPath(for: .iterm2 as TerminalEmulator, environment: env).path
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

        let hmPS = """
          76985 /Users/testuser/Applications/Home Manager Apps/kitty.app/Contents/MacOS/kitty
          76986 /Applications/Home Manager Apps/kitty.app/Contents/MacOS/kitty --listen-on unix:/tmp/k.sock
          76987 /Users/testuser/Applications/Home Manager Apps/kitty.app/Contents/MacOS/kitty +open /tmp/dir
          76988 /Users/testuser/Applications/Home Manager Apps/kitty.app/Contents/MacOS/kitty @ get-colors
          76989 /Users/testuser/Applications/Home Manager Apps/kitty.app/Contents/MacOS/kitty +runpy "print(1)"
          76990 /nix/store/abc-kitty/Applications/kitty.app/Contents/MacOS/kitten __watch_conf__ 76985 /Users/foo/kitty
          76991 /bin/zsh -c /Users/testuser/Applications/Home Manager Apps/kitty.app/Contents/MacOS/kitty
          76992 zsh subdir/kitty
        """
        #expect(EmulatorReload.kittyGUIPids(fromPSOutput: hmPS) == [76985, 76986, 76987])
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

// MARK: - v0.9.2 full dank-theme-engine target expansion

@Suite("Theme Sync Targets (v0.9.2)", .serialized)
struct ThemeSyncTargetTests {

    private var palette: ThemePalette { StockThemes.purpleDark }
    private var dank16: Dank16Palette { Dank16Generator.generate(from: palette) }

    private func rendered(_ target: ThemeSyncTarget) -> String {
        TerminalThemeRenderer.render(target: target, palette: palette, dank16: dank16, themeName: palette.name)
    }

    // MARK: - Catalog shape

    @Test("ThemeSyncTarget covers exactly 32 targets across 4 categories")
    func testTargetCatalogShape() {
        #expect(ThemeSyncTarget.allCases.count == 32)
        #expect(ThemeSyncCategory.allCases.count == 4)
        #expect(ThemeSyncTarget.targets(in: .terminals).count == 7)
        #expect(ThemeSyncTarget.targets(in: .editors).count == 6)
        #expect(ThemeSyncTarget.targets(in: .tuis).count == 13)
        #expect(ThemeSyncTarget.targets(in: .appsAndWMs).count == 6)
        // Every target's category round-trips through targets(in:).
        for target in ThemeSyncTarget.allCases {
            #expect(ThemeSyncTarget.targets(in: target.category).contains(target))
            #expect(target.id == target.rawValue)
            #expect(target.dteTargetId == target.rawValue)
            #expect(!target.displayName.isEmpty)
            #expect(!target.relativePathSummary.isEmpty)
        }
    }

    @Test("ThemeSyncCategory display names and icons")
    func testCategoryMetadata() {
        #expect(ThemeSyncCategory.terminals.displayName == "Terminals")
        #expect(ThemeSyncCategory.terminals.icon == "terminal.fill")
        #expect(ThemeSyncCategory.editors.displayName == "Editors & IDEs")
        #expect(ThemeSyncCategory.editors.icon == "chevron.left.forwardslash.chevron.right")
        #expect(ThemeSyncCategory.tuis.displayName == "Multiplexers, Shells & TUIs")
        #expect(ThemeSyncCategory.tuis.icon == "rectangle.split.3x1.fill")
        #expect(ThemeSyncCategory.appsAndWMs.displayName == "Window Managers & Apps")
        #expect(ThemeSyncCategory.appsAndWMs.icon == "macwindow.on.rectangle")
    }

    @Test("Display names match the spec")
    func testDisplayNames() {
        let expected: [ThemeSyncTarget: String] = [
            .ghostty: "Ghostty", .kitty: "Kitty", .alacritty: "Alacritty", .iterm2: "iTerm2",
            .wezterm: "WezTerm", .warp: "Warp", .rio: "Rio",
            .neovim: "Neovim (nvim)", .zed: "Zed", .vscode: "VS Code", .cursor: "Cursor",
            .helix: "Helix", .emacs: "Emacs",
            .tmux: "tmux", .starship: "Starship", .fish: "fish", .zsh: "zsh", .btop: "btop",
            .lazygit: "lazygit", .yazi: "yazi", .bat: "bat", .delta: "delta", .fzf: "fzf",
            .fastfetch: "fastfetch", .eza: "eza", .cava: "cava",
            .sketchybar: "SketchyBar", .aerospace: "AeroSpace", .jankyborders: "JankyBorders",
            .yabai: "yabai", .obsidian: "Obsidian", .vesktop: "Vesktop",
        ]
        #expect(expected.count == 32)
        for (target, name) in expected {
            #expect(target.displayName == name, "\(target.rawValue) displayName")
        }
    }

    @Test("defaultEnabled is true only for ghostty, kitty, alacritty, neovim, tmux")
    func testDefaultEnabled() {
        for target in ThemeSyncTarget.allCases {
            switch target {
            case .ghostty, .kitty, .alacritty, .neovim, .tmux:
                #expect(target.defaultEnabled, "\(target.rawValue) should default to enabled")
            default:
                #expect(!target.defaultEnabled, "\(target.rawValue) should default to disabled")
            }
        }
    }

    @Test("Setup snippets for the spec-named targets")
    func testSetupSnippets() {
        #expect(ThemeSyncTarget.neovim.setupSnippet == "vim.cmd.colorscheme(\"dms\")")
        #expect(ThemeSyncTarget.tmux.setupSnippet == "source-file ~/.config/tmux/dms.conf")
        #expect(ThemeSyncTarget.kitty.setupSnippet == "include dms-theme.conf")
        #expect(ThemeSyncTarget.ghostty.setupSnippet == "theme = dms")
        #expect(ThemeSyncTarget.alacritty.setupSnippet == "general.import = [\"~/.config/alacritty/dms-theme.toml\"]")
        #expect(ThemeSyncTarget.wezterm.setupSnippet == "config.color_scheme = \"dms\"")
        #expect(ThemeSyncTarget.helix.setupSnippet == "theme = \"dms\"")
        #expect(ThemeSyncTarget.fish.setupSnippet == "# Auto-loaded from ~/.config/fish/conf.d/dms.fish")
        #expect(ThemeSyncTarget.zsh.setupSnippet == "source ~/.config/zsh/dms.zsh")
        #expect(ThemeSyncTarget.bat.setupSnippet == "--theme=dms")
        #expect(ThemeSyncTarget.delta.setupSnippet == "[include] path = ~/.config/git/dms-delta.ini")
        #expect(ThemeSyncTarget.fzf.setupSnippet == "source ~/.config/fzf/dms.sh")
        #expect(ThemeSyncTarget.sketchybar.setupSnippet == "source \"$HOME/.config/sketchybar/dms-colors.sh\"")
        #expect(ThemeSyncTarget.jankyborders.setupSnippet == "source \"$HOME/.config/borders/dms-bordersrc\"")
        // Every target offers a snippet.
        for target in ThemeSyncTarget.allCases {
            #expect(target.setupSnippet != nil, "\(target.rawValue) missing setup snippet")
        }
    }

    // MARK: - Rendering: all 32 targets render non-empty content

    @Test("All 32 targets render non-empty content via TerminalThemeRenderer.render(target:)")
    func testAllTargetsRenderNonEmpty() throws {
        // Every target id is registered in the dank-theme-engine registry.
        let registered = Set(try DankThemeEngine.listTargets().map(\.id))
        for target in ThemeSyncTarget.allCases {
            #expect(registered.contains(target.dteTargetId), "\(target.rawValue) not registered in engine")
            let output = rendered(target)
            #expect(!output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(target.rawValue) rendered empty")
        }
    }

    @Test("neovim renders valid Lua with vim.g.colors_name = 'dms'")
    func testNeovimRender() {
        let output = rendered(.neovim)
        #expect(output.contains("vim.g.colors_name = 'dms'"))
        #expect(output.contains("vim.api.nvim_set_hl"))
        #expect(output.contains("vim.cmd('hi clear')"))
        // All 16 terminal colors are exposed.
        for i in 0..<16 {
            #expect(output.contains("vim.g.terminal_color_\(i)"), "missing terminal_color_\(i)")
        }
    }

    @Test("tmux renders a valid tmux config with status and pane colors")
    func testTmuxRender() {
        let output = rendered(.tmux)
        #expect(output.contains("set -g status-style"))
        #expect(output.contains("set -g status-left-style"))
        #expect(output.contains("set -g status-right-style"))
        #expect(output.contains("set -g pane-border-style"))
        #expect(output.contains("set -g pane-active-border-style"))
        #expect(output.contains("set -g message-style"))
        for i in 0..<16 {
            #expect(output.contains("set -g @dte-color-\(i)"), "missing @dte-color-\(i)")
        }
        // Dank16 ANSI colors appear in the config (case-insensitive hex).
        let lowered = output.lowercased()
        for color in dank16.colors {
            #expect(lowered.contains(color.hex.lowercased()), "tmux missing ANSI color \(color.hex)")
        }
    }

    // MARK: - Path resolution

    @Test("targetPath(for: target) resolves every target under XDG_CONFIG_HOME")
    func testTargetPathsRespectXDG() {
        let env = ["XDG_CONFIG_HOME": "/tmp/dms-xdg-targets"]
        let expected: [ThemeSyncTarget: String] = [
            .ghostty: "/tmp/dms-xdg-targets/ghostty/themes/dms",
            .kitty: "/tmp/dms-xdg-targets/kitty/dms-theme.conf",
            .alacritty: "/tmp/dms-xdg-targets/alacritty/dms-theme.toml",
            .wezterm: "/tmp/dms-xdg-targets/wezterm/colors/dms.lua",
            .warp: "/tmp/dms-xdg-targets/warp/themes/dms.yaml",
            .rio: "/tmp/dms-xdg-targets/rio/themes/dms.toml",
            .neovim: "/tmp/dms-xdg-targets/nvim/colors/dms.lua",
            .zed: "/tmp/dms-xdg-targets/zed/themes/dms.json",
            .vscode: "/tmp/dms-xdg-targets/Code/User/dms-theme.json",
            .cursor: "/tmp/dms-xdg-targets/Cursor/User/dms-theme.json",
            .helix: "/tmp/dms-xdg-targets/helix/themes/dms.toml",
            .emacs: "/tmp/dms-xdg-targets/emacs/dms-theme.el",
            .tmux: "/tmp/dms-xdg-targets/tmux/dms.conf",
            .starship: "/tmp/dms-xdg-targets/starship.dms.toml",
            .fish: "/tmp/dms-xdg-targets/fish/conf.d/dms.fish",
            .zsh: "/tmp/dms-xdg-targets/zsh/dms.zsh",
            .btop: "/tmp/dms-xdg-targets/btop/themes/dms.theme",
            .lazygit: "/tmp/dms-xdg-targets/lazygit/dms-theme.yml",
            .yazi: "/tmp/dms-xdg-targets/yazi/theme.toml",
            .bat: "/tmp/dms-xdg-targets/bat/themes/dms.tmTheme",
            .delta: "/tmp/dms-xdg-targets/git/dms-delta.ini",
            .fzf: "/tmp/dms-xdg-targets/fzf/dms.sh",
            .fastfetch: "/tmp/dms-xdg-targets/fastfetch/dms.jsonc",
            .eza: "/tmp/dms-xdg-targets/eza/theme.yml",
            .cava: "/tmp/dms-xdg-targets/cava/dms.ini",
            .sketchybar: "/tmp/dms-xdg-targets/sketchybar/dms-colors.sh",
            .aerospace: "/tmp/dms-xdg-targets/aerospace/dms.toml",
            .jankyborders: "/tmp/dms-xdg-targets/borders/dms-bordersrc",
            .yabai: "/tmp/dms-xdg-targets/yabai/dms.sh",
            .vesktop: "/tmp/dms-xdg-targets/vesktop/themes/dms.css",
        ]
        #expect(expected.count == 30)
        for (target, path) in expected {
            #expect(TerminalThemePaths.targetPath(for: target, environment: env).path == path, "\(target.rawValue) path")
        }
        // iTerm2 + Obsidian live under Application Support, not the XDG config home.
        let iterm = TerminalThemePaths.targetPath(for: .iterm2 as ThemeSyncTarget, environment: env).path
        #expect(iterm.hasSuffix("Library/Application Support/iTerm2/DynamicProfiles/dms.json"))
        #expect(!iterm.contains("/tmp/dms-xdg-targets"))
        let obsidian = TerminalThemePaths.targetPath(for: .obsidian, environment: env).path
        #expect(obsidian.hasSuffix("Library/Application Support/obsidian/snippets/dms.css"))
        #expect(!obsidian.contains("/tmp/dms-xdg-targets"))
    }

    @Test("targetPath(for: target) falls back to ~/.config without XDG_CONFIG_HOME")
    func testTargetPathsFallback() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(TerminalThemePaths.targetPath(for: .neovim, environment: [:]).path == "\(home)/.config/nvim/colors/dms.lua")
        #expect(TerminalThemePaths.targetPath(for: .tmux, environment: ["XDG_CONFIG_HOME": "  "]).path == "\(home)/.config/tmux/dms.conf")
    }

    @Test("targetPath(for: target) matches the legacy emulator paths")
    func testTargetPathsMatchEmulatorPaths() {
        let env = ["XDG_CONFIG_HOME": "/tmp/dms-xdg-parity"]
        for emulator in TerminalEmulator.allCases {
            let target = ThemeSyncTarget(rawValue: emulator.rawValue)!
            #expect(TerminalThemePaths.targetPath(for: target, environment: env) == TerminalThemePaths.targetPath(for: emulator, environment: env))
        }
    }

    // MARK: - Config toggles

    @Test("isThemeTargetEnabled defaults: ghostty/kitty/alacritty/neovim/tmux on, rest off")
    func testThemeTargetDefaults() {
        let config = DMSConfig()
        #expect(config.isThemeTargetEnabled(.ghostty))
        #expect(config.isThemeTargetEnabled(.kitty))
        #expect(config.isThemeTargetEnabled(.alacritty))
        #expect(config.isThemeTargetEnabled(.neovim))
        #expect(config.isThemeTargetEnabled(.tmux))
        #expect(!config.isThemeTargetEnabled(.iterm2))
        #expect(!config.isThemeTargetEnabled(.zed))
        #expect(!config.isThemeTargetEnabled(.sketchybar))
        #expect(!config.isThemeTargetEnabled(.obsidian))
        // Legacy emulator API agrees with the target API.
        for emulator in TerminalEmulator.allCases {
            let target = ThemeSyncTarget(rawValue: emulator.rawValue)!
            #expect(config.isTerminalThemeEnabled(emulator) == config.isThemeTargetEnabled(target))
        }
    }

    @Test("Master terminalThemeSync switch disables every target but keeps stored toggles")
    func testThemeTargetMasterSwitch() {
        var config = DMSConfig()
        config.terminalThemeSync = false
        for target in ThemeSyncTarget.allCases {
            #expect(!config.isThemeTargetEnabled(target), "\(target.rawValue) should be off with master switch off")
            // ...but the stored toggle is still readable for UI bindings.
            #expect(config.isThemeTargetConfiguredOn(target) == target.defaultEnabled || target == .ghostty || target == .kitty || target == .alacritty)
        }
        #expect(config.isThemeTargetConfiguredOn(.neovim))
        #expect(config.isThemeTargetConfiguredOn(.ghostty))
        #expect(!config.isThemeTargetConfiguredOn(.iterm2))
    }

    @Test("setThemeTargetEnabled persists custom targets in rawSettings and legacy keys for emulators")
    func testSetThemeTargetEnabled() {
        var config = DMSConfig()
        config.setThemeTargetEnabled(.zed, true)
        #expect(config.isThemeTargetEnabled(.zed))
        #expect(config.rawSettings["themeTarget_zed"]?.boolValue == true)
        #expect(config.isThemeTargetConfiguredOn(.zed))

        config.setThemeTargetEnabled(.tmux, false)
        #expect(!config.isThemeTargetEnabled(.tmux))
        #expect(!config.isThemeTargetConfiguredOn(.tmux))

        // Legacy emulators write their dedicated keys AND always record the rawSettings override.
        config.setThemeTargetEnabled(.kitty, false)
        #expect(!config.terminalThemeKitty)
        #expect(!config.isThemeTargetEnabled(.kitty))
        #expect(config.rawSettings["themeTarget_kitty"]?.boolValue == false)
        #expect(config.isThemeTargetExplicitlyConfigured(.kitty))
        config.setThemeTargetEnabled(.iterm2, true)
        #expect(config.terminalThemeITerm2)
        #expect(config.isThemeTargetEnabled(.iterm2))
    }

    @Test("Theme target toggles survive a Codable roundtrip")
    func testThemeTargetCodableRoundtrip() throws {
        var config = DMSConfig()
        config.setThemeTargetEnabled(.zed, true)
        config.setThemeTargetEnabled(.vesktop, true)
        config.setThemeTargetEnabled(.tmux, false)
        config.setThemeTargetEnabled(.alacritty, false)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DMSConfig.self, from: data)
        #expect(decoded.isThemeTargetEnabled(.zed))
        #expect(decoded.isThemeTargetEnabled(.vesktop))
        #expect(!decoded.isThemeTargetEnabled(.tmux))
        #expect(!decoded.isThemeTargetEnabled(.alacritty))
        #expect(decoded.isThemeTargetEnabled(.neovim))
        #expect(decoded.isThemeTargetEnabled(.ghostty))
        #expect(!decoded.isThemeTargetEnabled(.iterm2))

        // Legacy JSON without themeTarget_* keys decodes with documented defaults.
        let legacy = try JSONDecoder().decode(DMSConfig.self, from: "{}".data(using: .utf8)!)
        #expect(legacy.isThemeTargetEnabled(.neovim))
        #expect(legacy.isThemeTargetEnabled(.tmux))
        #expect(!legacy.isThemeTargetEnabled(.zed))
    }

    // MARK: - EmulatorReload: tmux + neovim helpers

    @Test("tmuxConfigReferencesTheme detects uncommented source/source-file lines only")
    func testTmuxConfigReferencesTheme() {
        #expect(EmulatorReload.tmuxConfigReferencesTheme("source-file ~/.config/tmux/dms.conf\n"))
        #expect(EmulatorReload.tmuxConfigReferencesTheme("source ~/.config/tmux/dms.conf\nset -g status on\n"))
        #expect(EmulatorReload.tmuxConfigReferencesTheme("source-file /nix/store/xyz/dms.conf\nsource-file ~/.config/tmux/dms.conf\n"))
        #expect(!EmulatorReload.tmuxConfigReferencesTheme("# source-file ~/.config/tmux/dms.conf\n"))
        #expect(!EmulatorReload.tmuxConfigReferencesTheme("#source ~/.config/tmux/dms.conf\n"))
        #expect(!EmulatorReload.tmuxConfigReferencesTheme("source-file ~/.config/tmux/other.conf\n"))
        #expect(!EmulatorReload.tmuxConfigReferencesTheme("set -g @plugin 'tmux/dms.conf'\n"))
        #expect(!EmulatorReload.tmuxConfigReferencesTheme(""))
        #expect(EmulatorReload.tmuxConfigReferencesTheme("source-file ~/my-dms.conf\n", themeFileName: "my-dms.conf"))
    }

    @Test("tmuxConfigReferencesTheme(atPath:) reads the file from disk")
    func testTmuxConfigReferencesThemeAtPath() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dms_tmux_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let conf = dir.appendingPathComponent("tmux.conf")
        try "set -g status on\nsource-file ~/.config/tmux/dms.conf\n".write(to: conf, atomically: true, encoding: .utf8)
        #expect(EmulatorReload.tmuxConfigReferencesTheme(atPath: conf.path))
        let other = dir.appendingPathComponent("other.conf")
        try "# source-file ~/.config/tmux/dms.conf\n".write(to: other, atomically: true, encoding: .utf8)
        #expect(!EmulatorReload.tmuxConfigReferencesTheme(atPath: other.path))
        #expect(!EmulatorReload.tmuxConfigReferencesTheme(atPath: dir.appendingPathComponent("missing.conf").path))
        try? FileManager.default.removeItem(at: dir)
    }

    @Test("neovimPids keeps only interactive nvim processes from ps output")
    func testNeovimPids() {
        let ps = """
          51001 /usr/local/bin/nvim
          51002 nvim
          51003 /opt/homebrew/bin/nvim --listen /tmp/nvim.sock
          51004 /usr/local/bin/nvim --headless "+q"
          51005 nvim --embed
          51006 /bin/zsh -l
          51007 /usr/bin/sudo nvim
          51008 vim
          51009 /Applications/Neovim.app/Contents/MacOS/nvim -u NONE
        """
        #expect(EmulatorReload.neovimPids(fromPSOutput: ps) == [51001, 51002, 51003, 51009])
        #expect(EmulatorReload.neovimPids(fromPSOutput: "").isEmpty)
        #expect(EmulatorReload.neovimPids(fromPSOutput: "not a pid line\n").isEmpty)
    }
}

// MARK: - v0.9.2 local installation detection (never trust DMS's own output files)

@Suite("Terminal Theme Detector (v0.9.2)", .serialized)
struct TerminalThemeDetectorTests {

    private func makeTempHome() throws -> URL {
        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dms_detect_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    /// Hermetic environment: XDG config home inside the temp home, empty PATH.
    private func env(for home: URL) -> [String: String] {
        [
            "XDG_CONFIG_HOME": home.appendingPathComponent(".config", isDirectory: true).path,
            "PATH": "",
            "USER": "dms-test",
        ]
    }

    private func writeFile(_ path: URL, _ content: String = "x", permissions: Int? = nil) throws {
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: path, atomically: true, encoding: .utf8)
        if let permissions {
            try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: path.path)
        }
    }

    @Test("empty hermetic home detects nothing")
    func testEmptyHomeDetectsNothing() throws {
        let home = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let e = env(for: home)
        let detected = TerminalThemeDetector.detectedTargets(
            environment: e, additionalBinDirs: [], additionalAppDirs: [], homeDirectory: home)
        #expect(detected.isEmpty)
        for target in ThemeSyncTarget.allCases {
            #expect(!TerminalThemeDetector.isTargetInstalled(
                target, environment: e, additionalBinDirs: [], additionalAppDirs: [], homeDirectory: home),
                "\(target.rawValue) falsely detected in empty home")
        }
    }

    @Test("DMS's own generated theme files never cause detection")
    func testDMSOutputFilesDoNotDetect() throws {
        let home = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let xdg = home.appendingPathComponent(".config", isDirectory: true)
        // Only DMS-generated outputs exist — no binaries, no app bundles, no user configs.
        try writeFile(xdg.appendingPathComponent("nvim/colors/dms.lua"), "vim.g.colors_name = 'dms'")
        try writeFile(xdg.appendingPathComponent("alacritty/dms-theme.toml"), "[colors.primary]")
        try writeFile(xdg.appendingPathComponent("kitty/dms-theme.conf"), "foreground #fff")
        try writeFile(xdg.appendingPathComponent("tmux/dms.conf"), "set -g status-style")
        try writeFile(xdg.appendingPathComponent("ghostty/themes/dms"), "palette = 0=#000")
        try writeFile(xdg.appendingPathComponent("zed/themes/dms.json"), "{}")
        try writeFile(xdg.appendingPathComponent("sketchybar/dms-colors.sh"), "accent_color=#fff")
        let e = env(for: home)
        let detected = TerminalThemeDetector.detectedTargets(
            environment: e, additionalBinDirs: [], additionalAppDirs: [], homeDirectory: home)
        #expect(detected.isEmpty, "DMS output files must not mark targets as installed: \(detected)")
        for target in [ThemeSyncTarget.neovim, .alacritty, .kitty, .tmux, .ghostty, .zed, .sketchybar] {
            #expect(!TerminalThemeDetector.isTargetInstalled(
                target, environment: e, additionalBinDirs: [], additionalAppDirs: [], homeDirectory: home))
        }
    }

    @Test("executable CLI binary in a provided bin dir detects the target; non-executable does not")
    func testBinaryDetection() throws {
        let home = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let bin = home.appendingPathComponent("bin", isDirectory: true)
        try writeFile(bin.appendingPathComponent("nvim"), "#!/bin/sh\n", permissions: 0o755)
        try writeFile(bin.appendingPathComponent("tmux"), "not executable", permissions: 0o644)
        let e = env(for: home)
        #expect(TerminalThemeDetector.isTargetInstalled(
            .neovim, environment: e, additionalBinDirs: [bin], additionalAppDirs: [], homeDirectory: home))
        #expect(!TerminalThemeDetector.isTargetInstalled(
            .tmux, environment: e, additionalBinDirs: [bin], additionalAppDirs: [], homeDirectory: home),
            "non-executable file must not count")
        let detected = TerminalThemeDetector.detectedTargets(
            environment: e, additionalBinDirs: [bin], additionalAppDirs: [], homeDirectory: home)
        #expect(detected == [.neovim])
    }

    @Test(".app bundle in a provided app dir detects the target")
    func testAppBundleDetection() throws {
        let home = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let apps = home.appendingPathComponent("Applications", isDirectory: true)
        try FileManager.default.createDirectory(
            at: apps.appendingPathComponent("Ghostty.app", isDirectory: true), withIntermediateDirectories: true)
        let e = env(for: home)
        #expect(TerminalThemeDetector.isTargetInstalled(
            .ghostty, environment: e, additionalBinDirs: [], additionalAppDirs: [apps], homeDirectory: home))
        #expect(!TerminalThemeDetector.isTargetInstalled(
            .kitty, environment: e, additionalBinDirs: [], additionalAppDirs: [apps], homeDirectory: home))
        let detected = TerminalThemeDetector.detectedTargets(
            environment: e, additionalBinDirs: [], additionalAppDirs: [apps], homeDirectory: home)
        #expect(detected == [.ghostty])
    }

    @Test("user config markers (XDG and home dotfiles) detect the target")
    func testConfigMarkerDetection() throws {
        let home = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let xdg = home.appendingPathComponent(".config", isDirectory: true)
        try writeFile(xdg.appendingPathComponent("nvim/init.lua"))
        try writeFile(xdg.appendingPathComponent("starship.toml"))
        try writeFile(home.appendingPathComponent(".tmux.conf"))
        try writeFile(home.appendingPathComponent(".zshrc"))
        let e = env(for: home)
        for target: ThemeSyncTarget in [.neovim, .starship, .tmux, .zsh] {
            #expect(TerminalThemeDetector.isTargetInstalled(
                target, environment: e, additionalBinDirs: [], additionalAppDirs: [], homeDirectory: home),
                "\(target.rawValue) should be detected via user config marker")
        }
        #expect(!TerminalThemeDetector.isTargetInstalled(
            .zed, environment: e, additionalBinDirs: [], additionalAppDirs: [], homeDirectory: home))
        let detected = TerminalThemeDetector.detectedTargets(
            environment: e, additionalBinDirs: [], additionalAppDirs: [], homeDirectory: home)
        #expect(detected == [.neovim, .starship, .tmux, .zsh])
    }

    @Test("explicit overrides restrict checks to the provided dirs (hermetic: no system /bin, /Applications)")
    func testHermeticOverridesIgnoreSystemDirs() throws {
        let home = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let e = env(for: home)
        // zsh ships in /bin on macOS, but with additionalBinDirs: [] and an empty temp home
        // it must NOT be detected.
        #expect(!TerminalThemeDetector.isTargetInstalled(
            .zsh, environment: e, additionalBinDirs: [], additionalAppDirs: [], homeDirectory: home))
        #expect(!TerminalThemeDetector.isTargetInstalled(
            .ghostty, environment: e, additionalBinDirs: [], additionalAppDirs: [], homeDirectory: home))
    }

    @Test("isThemeTargetEnabled(target, detected:) skips uninstalled default targets unless explicitly enabled")
    func testDetectedGating() {
        var config = DMSConfig()
        let none: Set<ThemeSyncTarget> = []
        // Default-enabled targets are OFF when not detected — DMS must not create orphan files.
        for target in [ThemeSyncTarget.ghostty, .kitty, .alacritty, .neovim, .tmux] {
            #expect(!config.isThemeTargetEnabled(target, detected: none), "\(target.rawValue) should be off when undetected")
        }
        // Non-default targets stay off even when detected.
        #expect(!config.isThemeTargetEnabled(.zed, detected: [.zed]))
        // Detected default targets turn on.
        let detected: Set<ThemeSyncTarget> = [.ghostty, .tmux, .zed]
        #expect(config.isThemeTargetEnabled(.ghostty, detected: detected))
        #expect(config.isThemeTargetEnabled(.tmux, detected: detected))
        #expect(!config.isThemeTargetEnabled(.kitty, detected: detected))
        #expect(!config.isThemeTargetEnabled(.zed, detected: detected))
        // Explicit override wins over detection, in both directions.
        config.setThemeTargetEnabled(.zed, true)
        #expect(config.isThemeTargetEnabled(.zed, detected: none))
        #expect(config.isThemeTargetExplicitlyConfigured(.zed))
        config.setThemeTargetEnabled(.ghostty, false)
        #expect(!config.isThemeTargetEnabled(.ghostty, detected: detected))
        // Master switch still gates everything.
        config.terminalThemeSync = false
        #expect(!config.isThemeTargetEnabled(.tmux, detected: detected))
        #expect(!config.isThemeTargetEnabled(.zed, detected: none))
        // ...but configuredOn ignores the master switch (UI binding semantics).
        #expect(config.isThemeTargetConfiguredOn(.tmux, detected: detected))
        // Legacy emulator key set to false disables even when detected.
        var c2 = DMSConfig()
        c2.terminalThemeKitty = false
        #expect(!c2.isThemeTargetConfiguredOn(.kitty, detected: [.kitty]))
        #expect(!c2.isThemeTargetEnabled(.kitty, detected: [.kitty]))
    }

    @Test("setThemeTargetEnabled always records rawSettings, including the 4 legacy emulators")
    func testSetterAlwaysWritesRawSettings() {
        var config = DMSConfig()
        for target in ThemeSyncTarget.allCases {
            config.setThemeTargetEnabled(target, true)
            #expect(config.rawSettings["themeTarget_\(target.rawValue)"]?.boolValue == true)
            #expect(config.isThemeTargetExplicitlyConfigured(target))
        }
        config.setThemeTargetEnabled(.iterm2, true)
        #expect(config.terminalThemeITerm2)
        #expect(config.rawSettings["themeTarget_iterm2"]?.boolValue == true)
        config.setThemeTargetEnabled(.alacritty, false)
        #expect(!config.terminalThemeAlacritty)
        #expect(config.rawSettings["themeTarget_alacritty"]?.boolValue == false)
    }

    @Test("detected-gated toggles survive a Codable roundtrip")
    func testDetectedGatingRoundtrip() throws {
        var config = DMSConfig()
        config.setThemeTargetEnabled(.zed, true)
        config.setThemeTargetEnabled(.tmux, false)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DMSConfig.self, from: data)
        #expect(decoded.isThemeTargetEnabled(.zed, detected: []))
        #expect(!decoded.isThemeTargetEnabled(.tmux, detected: [.tmux]))
        #expect(decoded.isThemeTargetEnabled(.ghostty, detected: [.ghostty]))
        #expect(!decoded.isThemeTargetEnabled(.ghostty, detected: []))
        #expect(decoded.isThemeTargetExplicitlyConfigured(.zed))
        #expect(!decoded.isThemeTargetExplicitlyConfigured(.ghostty))
    }
}

// MARK: - v0.9.2 multi-vault Obsidian theme sync

@Suite("Obsidian Multi-Vault Sync (v0.9.2)", .serialized)
struct ObsidianVaultTests {

    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dms_obsidian_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeFile(_ path: URL, _ content: String) throws {
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: path, atomically: true, encoding: .utf8)
    }

    private func makeVault(_ root: URL, _ name: String) throws -> URL {
        let vault = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        return vault
    }

    @Test("obsidianRegistryURL points at <appSupport>/obsidian/obsidian.json")
    func testRegistryURL() {
        let appSupport = URL(fileURLWithPath: "/tmp/fake-app-support", isDirectory: true)
        #expect(TerminalThemePaths.obsidianRegistryURL(applicationSupportDir: appSupport).path
                == "/tmp/fake-app-support/obsidian/obsidian.json")
    }

    @Test("parseObsidianVaultPaths parses vaults, dedupes and sorts by path")
    func testParseVaultPaths() throws {
        let json = Data(#"{"vaults": {"b": {"path": "/tmp/zzz-vault"}, "a": {"path": "/tmp/aaa-vault"}, "c": {"path": "/tmp/aaa-vault"}, "d": {"name": "no path"}}}"#.utf8)
        let urls = TerminalThemePaths.parseObsidianVaultPaths(fromRegistryData: json)
        #expect(urls == [
            URL(fileURLWithPath: "/tmp/aaa-vault", isDirectory: true).standardizedFileURL,
            URL(fileURLWithPath: "/tmp/zzz-vault", isDirectory: true).standardizedFileURL,
        ])
    }

    @Test("parseObsidianVaultPaths rejects invalid JSON, expands tilde paths")
    func testParseVaultPathsInvalid() throws {
        #expect(TerminalThemePaths.parseObsidianVaultPaths(fromRegistryData: Data("not json".utf8)).isEmpty)
        #expect(TerminalThemePaths.parseObsidianVaultPaths(fromRegistryData: Data("{}".utf8)).isEmpty)
        #expect(TerminalThemePaths.parseObsidianVaultPaths(fromRegistryData: Data(#"{"vaults": []}"#.utf8)).isEmpty)
        let urls = TerminalThemePaths.parseObsidianVaultPaths(
            fromRegistryData: Data(#"{"vaults": {"x": {"path": "~/my-vault"}}}"#.utf8))
        #expect(urls.count == 1)
        #expect(!urls[0].path.hasPrefix("~"))
        #expect(urls[0].path.hasSuffix("/my-vault"))
    }

    @Test("resolveObsidianSnippetURLs: existing registry vaults + custom paths, deduped, missing filtered")
    func testResolveMultiVault() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let appSupport = root.appendingPathComponent("AppSupport", isDirectory: true)
        let vaultA = try makeVault(root, "vault-a")
        let vaultB = try makeVault(root, "vault-b")
        let missing = root.appendingPathComponent("missing-vault", isDirectory: true)
        let registry: [String: Any] = [
            "vaults": [
                "1": ["path": vaultB.path],
                "2": ["path": vaultA.path],
                "3": ["path": missing.path],
            ],
        ]
        let registryURL = appSupport.appendingPathComponent("obsidian/obsidian.json", isDirectory: false)
        try writeFile(registryURL, String(data: try JSONSerialization.data(withJSONObject: registry), encoding: .utf8)!)

        let vaultC = try makeVault(root, "vault-c")
        let urls = TerminalThemePaths.resolveObsidianSnippetURLs(
            customVaultPaths: [vaultC.path, missing.path, vaultA.path],
            registryURL: registryURL,
            fallbackAppSupportDir: appSupport
        )
        let expected = [vaultA, vaultB, vaultC].map {
            $0.standardizedFileURL.appendingPathComponent(".obsidian/snippets/dms.css", isDirectory: false)
        }
        #expect(urls == expected)
    }

    @Test("resolveObsidianSnippetURLs falls back to the app-support snippet when no vault exists")
    func testResolveFallback() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let appSupport = root.appendingPathComponent("AppSupport", isDirectory: true)
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let fallback = appSupport.appendingPathComponent("obsidian/snippets/dms.css", isDirectory: false)

        // No registry file, no custom paths.
        #expect(TerminalThemePaths.resolveObsidianSnippetURLs(fallbackAppSupportDir: appSupport) == [fallback])

        // Registry exists but every vault dir is missing; custom path missing too.
        let registryURL = appSupport.appendingPathComponent("obsidian/obsidian.json", isDirectory: false)
        try writeFile(registryURL, #"{"vaults": {"1": {"path": "/nonexistent/vault"}}}"#)
        #expect(TerminalThemePaths.resolveObsidianSnippetURLs(
            customVaultPaths: ["/nonexistent/custom"],
            registryURL: registryURL,
            fallbackAppSupportDir: appSupport) == [fallback])

        // A single existing custom vault wins over the fallback.
        let vault = try makeVault(root, "solo")
        let urls = TerminalThemePaths.resolveObsidianSnippetURLs(
            customVaultPaths: [vault.path], registryURL: registryURL, fallbackAppSupportDir: appSupport)
        #expect(urls == [vault.standardizedFileURL.appendingPathComponent(".obsidian/snippets/dms.css", isDirectory: false)])
    }

    @Test("obsidian is detected via the registry file even without app bundle or binary")
    func testObsidianRegistryDetection() throws {
        let home = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: home) }
        let appSupport = home.appendingPathComponent("Library/Application Support", isDirectory: true)
        let env: [String: String] = [
            "XDG_CONFIG_HOME": home.appendingPathComponent(".config", isDirectory: true).path,
            "PATH": "",
            "USER": "dms-test",
        ]
        #expect(!TerminalThemeDetector.isTargetInstalled(
            .obsidian, environment: env, additionalBinDirs: [], additionalAppDirs: [],
            homeDirectory: home, applicationSupportDir: appSupport))
        try writeFile(TerminalThemePaths.obsidianRegistryURL(applicationSupportDir: appSupport), #"{"vaults": {}}"#)
        #expect(TerminalThemeDetector.isTargetInstalled(
            .obsidian, environment: env, additionalBinDirs: [], additionalAppDirs: [],
            homeDirectory: home, applicationSupportDir: appSupport))
        let detected = TerminalThemeDetector.detectedTargets(
            environment: env, additionalBinDirs: [], additionalAppDirs: [],
            homeDirectory: home, applicationSupportDir: appSupport)
        #expect(detected == [.obsidian])
    }

    @Test("obsidianVaultPaths defaults empty, persists via rawSettings and Codable")
    func testObsidianVaultPathsConfig() throws {
        var config = DMSConfig()
        #expect(config.obsidianVaultPaths.isEmpty)
        config.obsidianVaultPaths = ["/vaults/one", "~/vaults/two"]
        #expect(config.obsidianVaultPaths == ["/vaults/one", "~/vaults/two"])
        #expect(config.rawSettings["obsidianVaultPaths"]?.arrayValue?.compactMap(\.stringValue)
                == ["/vaults/one", "~/vaults/two"])
        let data = try JSONEncoder().encode(config)
        var decoded = try JSONDecoder().decode(DMSConfig.self, from: data)
        #expect(decoded.obsidianVaultPaths == ["/vaults/one", "~/vaults/two"])
        decoded.obsidianVaultPaths = []
        #expect(decoded.obsidianVaultPaths.isEmpty)
        #expect(decoded.rawSettings["obsidianVaultPaths"]?.arrayValue?.isEmpty == true)
    }
}
