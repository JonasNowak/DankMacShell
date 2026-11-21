import Foundation
import DankThemeEngine

/// Terminal emulators supported by the DMS live theme exporter (v0.7 THEME).
public enum TerminalEmulator: String, Sendable, Codable, CaseIterable {
    case ghostty
    case kitty
    case alacritty
    case iterm2

    public var displayName: String {
        switch self {
        case .ghostty: return "Ghostty"
        case .kitty: return "Kitty"
        case .alacritty: return "Alacritty"
        case .iterm2: return "iTerm2"
        }
    }

    /// Target id used by `DankThemeEngine.renderTerminal(targetId:doc:)`.
    public var dteTargetId: String { rawValue }
}

/// Broad grouping for the full dank-theme-engine target catalog (v0.9.2).
public enum ThemeSyncCategory: String, Sendable, Codable, CaseIterable {
    case terminals
    case editors
    case tuis
    case appsAndWMs

    public var displayName: String {
        switch self {
        case .terminals: return "Terminals"
        case .editors: return "Editors & IDEs"
        case .tuis: return "Multiplexers, Shells & TUIs"
        case .appsAndWMs: return "Window Managers & Apps"
        }
    }

    public var icon: String {
        switch self {
        case .terminals: return "terminal.fill"
        case .editors: return "chevron.left.forwardslash.chevron.right"
        case .tuis: return "rectangle.split.3x1.fill"
        case .appsAndWMs: return "macwindow.on.rectangle"
        }
    }
}

/// All 32 macOS-relevant dank-theme-engine target IDs (v0.9.2 full target expansion).
/// The raw value is the engine target id used by `DankThemeEngine.renderTerminal(targetId:doc:)`
/// and `DankThemeEngine.detectTargets()`.
public enum ThemeSyncTarget: String, Sendable, Codable, CaseIterable, Identifiable {
    // Terminals
    case ghostty
    case kitty
    case alacritty
    case iterm2
    case wezterm
    case warp
    case rio
    // Editors & IDEs
    case neovim
    case zed
    case vscode
    case cursor
    case helix
    case emacs
    // Multiplexers, shells & TUIs
    case tmux
    case starship
    case fish
    case zsh
    case btop
    case lazygit
    case yazi
    case bat
    case delta
    case fzf
    case fastfetch
    case eza
    case cava
    // Window managers & apps
    case sketchybar
    case aerospace
    case jankyborders
    case yabai
    case obsidian
    case vesktop

    public var id: String { rawValue }

    /// Target id used by `DankThemeEngine.renderTerminal(targetId:doc:)` / `detectTargets()`.
    public var dteTargetId: String { rawValue }

    public var category: ThemeSyncCategory {
        switch self {
        case .ghostty, .kitty, .alacritty, .iterm2, .wezterm, .warp, .rio:
            return .terminals
        case .neovim, .zed, .vscode, .cursor, .helix, .emacs:
            return .editors
        case .tmux, .starship, .fish, .zsh, .btop, .lazygit, .yazi, .bat, .delta, .fzf, .fastfetch, .eza, .cava:
            return .tuis
        case .sketchybar, .aerospace, .jankyborders, .yabai, .obsidian, .vesktop:
            return .appsAndWMs
        }
    }

    public var displayName: String {
        switch self {
        case .ghostty: return "Ghostty"
        case .kitty: return "Kitty"
        case .alacritty: return "Alacritty"
        case .iterm2: return "iTerm2"
        case .wezterm: return "WezTerm"
        case .warp: return "Warp"
        case .rio: return "Rio"
        case .neovim: return "Neovim (nvim)"
        case .zed: return "Zed"
        case .vscode: return "VS Code"
        case .cursor: return "Cursor"
        case .helix: return "Helix"
        case .emacs: return "Emacs"
        case .tmux: return "tmux"
        case .starship: return "Starship"
        case .fish: return "fish"
        case .zsh: return "zsh"
        case .btop: return "btop"
        case .lazygit: return "lazygit"
        case .yazi: return "yazi"
        case .bat: return "bat"
        case .delta: return "delta"
        case .fzf: return "fzf"
        case .fastfetch: return "fastfetch"
        case .eza: return "eza"
        case .cava: return "cava"
        case .sketchybar: return "SketchyBar"
        case .aerospace: return "AeroSpace"
        case .jankyborders: return "JankyBorders"
        case .yabai: return "yabai"
        case .obsidian: return "Obsidian"
        case .vesktop: return "Vesktop"
        }
    }

    /// Human-readable summary of the file DMS writes for this target (under `~/.config`,
    /// or Application Support for iTerm2 / Obsidian).
    public var relativePathSummary: String {
        switch self {
        case .ghostty: return "~/.config/ghostty/themes/dms"
        case .kitty: return "~/.config/kitty/dms-theme.conf"
        case .alacritty: return "~/.config/alacritty/dms-theme.toml"
        case .iterm2: return "~/Library/Application Support/iTerm2/DynamicProfiles/dms.json"
        case .wezterm: return "~/.config/wezterm/colors/dms.lua"
        case .warp: return "~/.config/warp/themes/dms.yaml"
        case .rio: return "~/.config/rio/themes/dms.toml"
        case .neovim: return "~/.config/nvim/colors/dms.lua"
        case .zed: return "~/.config/zed/themes/dms.json"
        case .vscode: return "~/.config/Code/User/dms-theme.json"
        case .cursor: return "~/.config/Cursor/User/dms-theme.json"
        case .helix: return "~/.config/helix/themes/dms.toml"
        case .emacs: return "~/.config/emacs/dms-theme.el"
        case .tmux: return "~/.config/tmux/dms.conf"
        case .starship: return "~/.config/starship.dms.toml"
        case .fish: return "~/.config/fish/conf.d/dms.fish"
        case .zsh: return "~/.config/zsh/dms.zsh"
        case .btop: return "~/.config/btop/themes/dms.theme"
        case .lazygit: return "~/.config/lazygit/dms-theme.yml"
        case .yazi: return "~/.config/yazi/theme.toml"
        case .bat: return "~/.config/bat/themes/dms.tmTheme"
        case .delta: return "~/.config/git/dms-delta.ini"
        case .fzf: return "~/.config/fzf/dms.sh"
        case .fastfetch: return "~/.config/fastfetch/dms.jsonc"
        case .eza: return "~/.config/eza/theme.yml"
        case .cava: return "~/.config/cava/dms.ini"
        case .sketchybar: return "~/.config/sketchybar/dms-colors.sh"
        case .aerospace: return "~/.config/aerospace/dms.toml"
        case .jankyborders: return "~/.config/borders/dms-bordersrc"
        case .yabai: return "~/.config/yabai/dms.sh"
        case .obsidian: return "~/Library/Application Support/obsidian/snippets/dms.css"
        case .vesktop: return "~/.config/vesktop/themes/dms.css"
        }
    }

    /// Config snippet the user copies into the app's own config to activate the DMS theme.
    public var setupSnippet: String? {
        switch self {
        case .ghostty: return "theme = dms"
        case .kitty: return "include dms-theme.conf"
        case .alacritty: return "general.import = [\"~/.config/alacritty/dms-theme.toml\"]"
        case .iterm2: return "# Auto-loaded from ~/Library/Application Support/iTerm2/DynamicProfiles/dms.json"
        case .wezterm: return "config.color_scheme = \"dms\""
        case .warp: return "# Select \"dms\" in Warp's theme picker (~/.config/warp/themes/dms.yaml)"
        case .rio: return "theme = \"dms\""
        case .neovim: return "vim.cmd.colorscheme(\"dms\")"
        case .zed: return "# Select \"dms\" in Zed's theme picker (~/.config/zed/themes/dms.json)"
        case .vscode: return "# Merge ~/.config/Code/User/dms-theme.json colorCustomizations into settings.json"
        case .cursor: return "# Merge ~/.config/Cursor/User/dms-theme.json colorCustomizations into settings.json"
        case .helix: return "theme = \"dms\""
        case .emacs: return "(load-theme 'dms t)"
        case .tmux: return "source-file ~/.config/tmux/dms.conf"
        case .starship: return "# Merge into ~/.config/starship.toml (or STARSHIP_CONFIG=~/.config/starship.dms.toml)"
        case .fish: return "# Auto-loaded from ~/.config/fish/conf.d/dms.fish"
        case .zsh: return "source ~/.config/zsh/dms.zsh"
        case .btop: return "# Select dms in btop settings (~/.config/btop/themes/dms.theme)"
        case .lazygit: return "# Run lazygit with LG_CONFIG_FILE=\"$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/dms-theme.yml\""
        case .yazi: return "# yazi picks up ~/.config/yazi/theme.toml automatically"
        case .bat: return "--theme=dms"
        case .delta: return "[include] path = ~/.config/git/dms-delta.ini"
        case .fzf: return "source ~/.config/fzf/dms.sh"
        case .fastfetch: return "--config ~/.config/fastfetch/dms.jsonc"
        case .eza: return "--theme ~/.config/eza/theme.yml"
        case .cava: return "cava --config ~/.config/cava/dms.ini"
        case .sketchybar: return "source \"$HOME/.config/sketchybar/dms-colors.sh\""
        case .aerospace: return "# Merge ~/.config/aerospace/dms.toml into aerospace.toml"
        case .jankyborders: return "source \"$HOME/.config/borders/dms-bordersrc\""
        case .yabai: return "source \"$HOME/.config/yabai/dms.sh\""
        case .obsidian: return "# Enable the \"dms\" CSS snippet in Obsidian's Appearance settings"
        case .vesktop: return "# Enable the dms theme in Vesktop's settings (~/.config/vesktop/themes/dms.css)"
        }
    }

    /// Whether this target is exported by default when theme sync is on.
    public var defaultEnabled: Bool {
        switch self {
        case .ghostty, .kitty, .alacritty, .neovim, .tmux: return true
        default: return false
        }
    }

    /// macOS `.app` bundle names that count as "installed" (checked in the app dirs).
    public var appBundleNames: [String] {
        switch self {
        case .ghostty: return ["Ghostty.app"]
        case .kitty: return ["kitty.app"]
        case .alacritty: return ["Alacritty.app"]
        case .iterm2: return ["iTerm2.app"]
        case .wezterm: return ["WezTerm.app"]
        case .warp: return ["Warp.app"]
        case .rio: return ["Rio.app"]
        case .zed: return ["Zed.app"]
        case .vscode: return ["Visual Studio Code.app"]
        case .cursor: return ["Cursor.app"]
        case .jankyborders: return ["Borders.app"]
        case .obsidian: return ["Obsidian.app"]
        case .vesktop: return ["Vesktop.app"]
        default: return []
        }
    }

    /// CLI executable names that count as "installed" (checked in the bin dirs).
    public var cliExecutableNames: [String] {
        switch self {
        case .ghostty: return ["ghostty"]
        case .kitty: return ["kitty"]
        case .alacritty: return ["alacritty"]
        case .wezterm: return ["wezterm"]
        case .warp: return ["warp"]
        case .rio: return ["rio"]
        case .neovim: return ["nvim"]
        case .zed: return ["zed"]
        case .vscode: return ["code"]
        case .cursor: return ["cursor"]
        case .helix: return ["hx"]
        case .emacs: return ["emacs"]
        case .tmux: return ["tmux"]
        case .starship: return ["starship"]
        case .fish: return ["fish"]
        case .zsh: return ["zsh"]
        case .btop: return ["btop"]
        case .lazygit: return ["lazygit"]
        case .yazi: return ["yazi"]
        case .bat: return ["bat"]
        case .delta: return ["delta"]
        case .fzf: return ["fzf"]
        case .fastfetch: return ["fastfetch"]
        case .eza: return ["eza"]
        case .cava: return ["cava"]
        case .sketchybar: return ["sketchybar"]
        case .aerospace: return ["aerospace"]
        case .jankyborders: return ["borders"]
        case .yabai: return ["yabai"]
        default: return []
        }
    }

    /// Primary *user* config marker files, relative to the XDG config home.
    /// Never DMS-generated output files (e.g. `nvim/colors/dms.lua`), so DMS's own
    /// exports can never cause a false-positive "installed" detection.
    public var configMarkers: [String] {
        switch self {
        case .ghostty: return ["ghostty/config"]
        case .kitty: return ["kitty/kitty.conf"]
        case .alacritty: return ["alacritty/alacritty.toml", "alacritty/alacritty.yml"]
        case .wezterm: return ["wezterm/wezterm.lua"]
        case .neovim: return ["nvim/init.lua", "nvim/init.vim"]
        case .zed: return ["zed/settings.json"]
        case .vscode: return ["Code/User/settings.json"]
        case .cursor: return ["Cursor/User/settings.json"]
        case .helix: return ["helix/config.toml"]
        case .emacs: return ["emacs/init.el"]
        case .tmux: return ["tmux/tmux.conf"]
        case .starship: return ["starship.toml"]
        case .fish: return ["fish/config.fish"]
        case .zsh: return ["zsh/.zshrc"]
        case .btop: return ["btop/btop.conf"]
        case .lazygit: return ["lazygit/config.yml"]
        case .yazi: return ["yazi/yazi.toml"]
        case .bat: return ["bat/config"]
        case .cava: return ["cava/config"]
        case .sketchybar: return ["sketchybar/sketchybarrc"]
        case .aerospace: return ["aerospace/aerospace.toml"]
        case .jankyborders: return ["borders/bordersrc"]
        case .yabai: return ["yabai/yabairc"]
        default: return []
        }
    }

    /// User config marker files relative to the home directory (dotfiles).
    public var homeConfigMarkers: [String] {
        switch self {
        case .wezterm: return [".wezterm.lua"]
        case .emacs: return [".emacs.d/init.el", ".emacs"]
        case .tmux: return [".tmux.conf"]
        case .zsh: return [".zshrc"]
        case .aerospace: return [".aerospace.toml"]
        case .yabai: return [".yabairc"]
        default: return []
        }
    }

    /// All targets in a category, in declaration order.
    public static func targets(in category: ThemeSyncCategory) -> [ThemeSyncTarget] {
        allCases.filter { $0.category == category }
    }
}

/// Local installation detection for theme-sync targets (v0.9.2).
///
/// A target counts as installed when any of these hold:
/// a) one of its macOS `.app` bundles exists in an app dir,
/// b) one of its CLI executables exists and is executable in a bin dir,
/// c) one of its primary *user* config marker files exists.
///
/// DMS's own generated theme files (e.g. `nvim/colors/dms.lua`, `kitty/dms-theme.conf`)
/// are never consulted, so exporting a theme can never make an uninstalled app look installed.
///
/// Passing `additionalBinDirs` / `additionalAppDirs` / `homeDirectory` explicitly restricts
/// the checks to those directories (plus `XDG_CONFIG_HOME` from `environment`), which keeps
/// unit tests fully hermetic.
public enum TerminalThemeDetector {

    /// Default app bundle search dirs: system + user Applications, including nix/home-manager locations.
    public static func defaultAppDirs(home: URL) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Nix Apps", isDirectory: true),
            home.appendingPathComponent("Applications/Home Manager Apps", isDirectory: true),
        ]
    }

    /// Default bin search dirs: every `PATH` entry plus the usual nix/homebrew/cargo locations.
    public static func defaultBinDirs(environment: [String: String], home: URL) -> [URL] {
        var dirs: [URL] = []
        if let path = environment["PATH"] {
            for entry in path.split(separator: ":") where !entry.isEmpty {
                dirs.append(URL(fileURLWithPath: String(entry), isDirectory: true))
            }
        }
        let user = environment["USER"] ?? NSUserName()
        dirs.append(contentsOf: [
            URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/bin", isDirectory: true),
            home.appendingPathComponent(".nix-profile/bin", isDirectory: true),
            URL(fileURLWithPath: "/etc/profiles/per-user/\(user)/bin", isDirectory: true),
            URL(fileURLWithPath: "/run/current-system/sw/bin", isDirectory: true),
            home.appendingPathComponent(".local/bin", isDirectory: true),
            home.appendingPathComponent(".cargo/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/bin", isDirectory: true),
            URL(fileURLWithPath: "/bin", isDirectory: true),
        ])
        return dirs
    }

    /// Resolves the config home for detection: `XDG_CONFIG_HOME` from `environment` when set,
    /// else `<home>/.config` (using the injected `homeDirectory` when provided).
    private static func detectionConfigHome(environment: [String: String], home: URL) -> URL {
        if let xdg = environment["XDG_CONFIG_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !xdg.isEmpty {
            return URL(fileURLWithPath: (xdg as NSString).expandingTildeInPath, isDirectory: true)
        }
        return home.appendingPathComponent(".config", isDirectory: true)
    }

    private static func isExecutableRegularFile(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
            return false
        }
        return FileManager.default.isExecutableFile(atPath: path)
    }

    /// Whether `target` is genuinely installed on this machine.
    public static func isTargetInstalled(
        _ target: ThemeSyncTarget,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        additionalBinDirs: [URL]? = nil,
        additionalAppDirs: [URL]? = nil,
        homeDirectory: URL? = nil
    ) -> Bool {
        isTargetInstalled(
            target,
            environment: environment,
            additionalBinDirs: additionalBinDirs,
            additionalAppDirs: additionalAppDirs,
            homeDirectory: homeDirectory,
            // Hermetic mode: when a home override is given, Application Support is derived from
            // it too, so tests never see the real machine's Obsidian registry.
            applicationSupportDir: homeDirectory.map {
                $0.appendingPathComponent("Library/Application Support", isDirectory: true)
            }
        )
    }

    /// Full detection with an injectable Application Support dir (used by hermetic tests).
    static func isTargetInstalled(
        _ target: ThemeSyncTarget,
        environment: [String: String],
        additionalBinDirs: [URL]?,
        additionalAppDirs: [URL]?,
        homeDirectory: URL?,
        applicationSupportDir: URL?
    ) -> Bool {
        let fm = FileManager.default
        let home = homeDirectory ?? fm.homeDirectoryForCurrentUser

        // a) macOS .app bundles.
        let appDirs = additionalAppDirs ?? defaultAppDirs(home: home)
        for bundle in target.appBundleNames {
            for dir in appDirs where fm.fileExists(atPath: dir.appendingPathComponent(bundle).path) {
                return true
            }
        }

        // a2) Obsidian: the vault registry file itself proves an installation, even when the
        // .app bundle lives outside the searched app dirs (e.g. Setapp installs).
        if target == .obsidian,
           fm.fileExists(atPath: TerminalThemePaths.obsidianRegistryURL(applicationSupportDir: applicationSupportDir).path) {
            return true
        }

        // b) CLI executables (regular files only, must be executable).
        let binDirs = additionalBinDirs ?? defaultBinDirs(environment: environment, home: home)
        for exe in target.cliExecutableNames {
            for dir in binDirs where isExecutableRegularFile(dir.appendingPathComponent(exe).path) {
                return true
            }
        }

        // c) Primary user config markers — never DMS-generated theme output.
        let configHome = detectionConfigHome(environment: environment, home: home)
        for marker in target.configMarkers where fm.fileExists(atPath: configHome.appendingPathComponent(marker).path) {
            return true
        }
        for marker in target.homeConfigMarkers where fm.fileExists(atPath: home.appendingPathComponent(marker).path) {
            return true
        }
        return false
    }

    /// All targets detected as genuinely installed on this machine.
    public static func detectedTargets(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        additionalBinDirs: [URL]? = nil,
        additionalAppDirs: [URL]? = nil,
        homeDirectory: URL? = nil
    ) -> Set<ThemeSyncTarget> {
        detectedTargets(
            environment: environment,
            additionalBinDirs: additionalBinDirs,
            additionalAppDirs: additionalAppDirs,
            homeDirectory: homeDirectory,
            applicationSupportDir: homeDirectory.map {
                $0.appendingPathComponent("Library/Application Support", isDirectory: true)
            }
        )
    }

    /// Full detection with an injectable Application Support dir (used by hermetic tests).
    static func detectedTargets(
        environment: [String: String],
        additionalBinDirs: [URL]?,
        additionalAppDirs: [URL]?,
        homeDirectory: URL?,
        applicationSupportDir: URL?
    ) -> Set<ThemeSyncTarget> {
        Set(ThemeSyncTarget.allCases.filter {
            isTargetInstalled(
                $0,
                environment: environment,
                additionalBinDirs: additionalBinDirs,
                additionalAppDirs: additionalAppDirs,
                homeDirectory: homeDirectory,
                applicationSupportDir: applicationSupportDir
            )
        })
    }
}

/// Canonical machine-readable theme document written to
/// `~/Library/Application Support/DMS/theme.json`.
/// This is the read-only interface for home-manager / stylix-style setups.
public struct TerminalThemeDocument: Sendable, Codable, Equatable {
    public var themeName: String
    public var isDark: Bool
    public var palette: ThemePalette
    public var dank16: Dank16Palette
    public var generatedAt: Date

    public init(themeName: String, isDark: Bool, palette: ThemePalette, dank16: Dank16Palette, generatedAt: Date = Date()) {
        self.themeName = themeName
        self.isDark = isDark
        self.palette = palette
        self.dank16 = dank16
        self.generatedAt = generatedAt
    }

    public func encodeJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(self)
    }
}

public extension TerminalThemeDocument {
    /// Creates a document from a `DankThemeEngine` theme document.
    init(dte: DTEThemeDocument) {
        self.init(
            themeName: dte.themeName,
            isDark: dte.isDark,
            palette: ThemePalette(dte: dte.palette),
            dank16: Dank16Palette(dte.dank16),
            generatedAt: ISO8601DateFormatter().date(from: dte.generatedAt) ?? Date()
        )
    }

    /// Converts this document to a `DankThemeEngine` theme document.
    var dteDocument: DTEThemeDocument {
        DTEThemeDocument(
            themeName: themeName,
            isDark: isDark,
            palette: palette.dtePalette,
            dank16: dank16.dteDank16,
            generatedAt: ISO8601DateFormatter().string(from: generatedAt)
        )
    }
}

/// Path resolution for terminal emulator theme targets.
/// Config dirs resolve via `XDG_CONFIG_HOME` when set, else `~/.config` — never hardcoded.
public enum TerminalThemePaths {

    /// Resolves the XDG config home: `$XDG_CONFIG_HOME` when set and non-empty, else `~/.config`.
    public static func configHome(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let xdg = environment["XDG_CONFIG_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !xdg.isEmpty {
            let expanded = (xdg as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
    }

    /// Target theme file for a given emulator.
    /// iTerm2 DynamicProfiles live under `~/Library/Application Support` (not home-manager managed).
    public static func targetPath(
        for emulator: TerminalEmulator,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        switch emulator {
        case .ghostty:
            return configHome(environment: environment)
                .appendingPathComponent("ghostty/themes/dms", isDirectory: false)
        case .kitty:
            return configHome(environment: environment)
                .appendingPathComponent("kitty/dms-theme.conf", isDirectory: false)
        case .alacritty:
            return configHome(environment: environment)
                .appendingPathComponent("alacritty/dms-theme.toml", isDirectory: false)
        case .iterm2:
            return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("iTerm2/DynamicProfiles/dms.json", isDirectory: false)
        }
    }

    /// Target theme file for a given dank-theme-engine target (v0.9.2 full catalog).
    /// Paths mirror the engine's `TargetPaths`: under `configHome(environment:)` except
    /// iTerm2 DynamicProfiles and the Obsidian snippet, which live under Application Support.
    public static func targetPath(
        for target: ThemeSyncTarget,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        let config = configHome(environment: environment)
        switch target {
        case .ghostty:
            return config.appendingPathComponent("ghostty/themes/dms", isDirectory: false)
        case .kitty:
            return config.appendingPathComponent("kitty/dms-theme.conf", isDirectory: false)
        case .alacritty:
            return config.appendingPathComponent("alacritty/dms-theme.toml", isDirectory: false)
        case .iterm2:
            return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("iTerm2/DynamicProfiles/dms.json", isDirectory: false)
        case .wezterm:
            return config.appendingPathComponent("wezterm/colors/dms.lua", isDirectory: false)
        case .warp:
            return config.appendingPathComponent("warp/themes/dms.yaml", isDirectory: false)
        case .rio:
            return config.appendingPathComponent("rio/themes/dms.toml", isDirectory: false)
        case .neovim:
            return config.appendingPathComponent("nvim/colors/dms.lua", isDirectory: false)
        case .zed:
            return config.appendingPathComponent("zed/themes/dms.json", isDirectory: false)
        case .vscode:
            return config.appendingPathComponent("Code/User/dms-theme.json", isDirectory: false)
        case .cursor:
            return config.appendingPathComponent("Cursor/User/dms-theme.json", isDirectory: false)
        case .helix:
            return config.appendingPathComponent("helix/themes/dms.toml", isDirectory: false)
        case .emacs:
            return config.appendingPathComponent("emacs/dms-theme.el", isDirectory: false)
        case .tmux:
            return config.appendingPathComponent("tmux/dms.conf", isDirectory: false)
        case .starship:
            return config.appendingPathComponent("starship.dms.toml", isDirectory: false)
        case .fish:
            return config.appendingPathComponent("fish/conf.d/dms.fish", isDirectory: false)
        case .zsh:
            return config.appendingPathComponent("zsh/dms.zsh", isDirectory: false)
        case .btop:
            return config.appendingPathComponent("btop/themes/dms.theme", isDirectory: false)
        case .lazygit:
            return config.appendingPathComponent("lazygit/dms-theme.yml", isDirectory: false)
        case .yazi:
            return config.appendingPathComponent("yazi/theme.toml", isDirectory: false)
        case .bat:
            return config.appendingPathComponent("bat/themes/dms.tmTheme", isDirectory: false)
        case .delta:
            return config.appendingPathComponent("git/dms-delta.ini", isDirectory: false)
        case .fzf:
            return config.appendingPathComponent("fzf/dms.sh", isDirectory: false)
        case .fastfetch:
            return config.appendingPathComponent("fastfetch/dms.jsonc", isDirectory: false)
        case .eza:
            return config.appendingPathComponent("eza/theme.yml", isDirectory: false)
        case .cava:
            return config.appendingPathComponent("cava/dms.ini", isDirectory: false)
        case .sketchybar:
            return config.appendingPathComponent("sketchybar/dms-colors.sh", isDirectory: false)
        case .aerospace:
            return config.appendingPathComponent("aerospace/dms.toml", isDirectory: false)
        case .jankyborders:
            return config.appendingPathComponent("borders/dms-bordersrc", isDirectory: false)
        case .yabai:
            return config.appendingPathComponent("yabai/dms.sh", isDirectory: false)
        case .obsidian:
            return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("obsidian/snippets/dms.css", isDirectory: false)
        case .vesktop:
            return config.appendingPathComponent("vesktop/themes/dms.css", isDirectory: false)
        }
    }

    /// Stable, always-writable canonical theme document path.
    public static func appSupportThemeJSON() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DMS/theme.json", isDirectory: false)
    }

    /// Obsidian's vault registry: `<Application Support>/obsidian/obsidian.json`.
    public static func obsidianRegistryURL(applicationSupportDir: URL? = nil) -> URL {
        (applicationSupportDir ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!)
            .appendingPathComponent("obsidian/obsidian.json", isDirectory: false)
    }

    /// Parses Obsidian's registry JSON (`{"vaults": {"<id>": {"path": "/path/to/vault"}}}`)
    /// into sorted, unique vault directory URLs. Tilde paths are expanded; entries without a
    /// usable path are skipped.
    public static func parseObsidianVaultPaths(fromRegistryData data: Data) -> [URL] {
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let root = obj as? [String: Any],
              let vaults = root["vaults"] as? [String: Any] else { return [] }
        var seen = Set<String>()
        var urls: [URL] = []
        for (_, value) in vaults {
            guard let entry = value as? [String: Any],
                  let rawPath = entry["path"] as? String,
                  !rawPath.isEmpty else { continue }
            let expanded = (rawPath as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
            if seen.insert(url.path).inserted {
                urls.append(url)
            }
        }
        return urls.sorted { $0.path < $1.path }
    }

    /// Resolves every Obsidian snippet URL (`<vault>/.obsidian/snippets/dms.css`) DMS should
    /// write to: vaults auto-discovered from the registry plus user-configured custom vault
    /// paths. Only directories that exist on disk are kept; duplicates (by standardized path)
    /// are removed preserving order. When no vault directory exists, falls back to the default
    /// single-location snippet under Application Support.
    public static func resolveObsidianSnippetURLs(
        customVaultPaths: [String] = [],
        registryURL: URL? = nil,
        fallbackAppSupportDir: URL? = nil
    ) -> [URL] {
        let fm = FileManager.default
        let appSupport = fallbackAppSupportDir
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let registry = registryURL ?? obsidianRegistryURL(applicationSupportDir: appSupport)

        var ordered: [URL] = []
        var seen = Set<String>()

        func appendIfExistingDirectory(_ url: URL) {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return }
            let key = url.standardizedFileURL.path
            if seen.insert(key).inserted {
                ordered.append(url.standardizedFileURL)
            }
        }

        if let data = fm.fileExists(atPath: registry.path) ? try? Data(contentsOf: registry) : nil {
            for vault in parseObsidianVaultPaths(fromRegistryData: data) {
                appendIfExistingDirectory(vault)
            }
        }
        for raw in customVaultPaths {
            let expanded = (raw as NSString).expandingTildeInPath
            guard !expanded.isEmpty else { continue }
            appendIfExistingDirectory(URL(fileURLWithPath: expanded, isDirectory: true))
        }

        if ordered.isEmpty {
            return [appSupport.appendingPathComponent("obsidian/snippets/dms.css", isDirectory: false)]
        }
        return ordered.map { $0.appendingPathComponent(".obsidian/snippets/dms.css", isDirectory: false) }
    }
}

/// Nix / home-manager safety checks. Pure helpers so `swift test` covers them.
public enum TerminalThemeSecurity {

    /// Returns true when `path` is (or resolves through symlinks into) the read-only nix store,
    /// e.g. a home-manager managed symlink like `~/.config/kitty/dms-theme.conf -> /nix/store/...`.
    /// Such targets must never be written by DMS.
    ///
    /// The default `/nix/store` prefix is delegated to `DankThemeEngine.isManagedSymlink(_:)`;
    /// custom prefixes (used by tests) use the local symlink walk below.
    public static func isManagedSymlink(path: String, storePrefix: String = "/nix/store") -> Bool {
        var prefix = storePrefix.hasSuffix("/") ? String(storePrefix.dropLast()) : storePrefix
        if prefix == "/nix/store" {
            return DankThemeEngine.isManagedSymlink(path)
        }
        // Canonicalize the prefix too (realpath resolves /var -> /private/var style links).
        if let resolvedPrefix = prefix.withCString({ realpath($0, nil) }) {
            prefix = String(cString: resolvedPrefix)
            free(resolvedPrefix)
        }

        // Fast path: fully resolve existing paths (covers direct store files and live symlink chains).
        if let resolved = path.withCString({ realpath($0, nil) }) {
            let resolvedStr = String(cString: resolved)
            free(resolved)
            if resolvedStr == prefix || resolvedStr.hasPrefix(prefix + "/") {
                return true
            }
        }

        // Slow path: dangling symlink or unresolved chain — walk links manually.
        var current = (path as NSString).standardizingPath
        var statBuf = stat()
        for _ in 0..<40 {
            guard lstat(current, &statBuf) == 0 else { return false }
            if (statBuf.st_mode & S_IFMT) != S_IFLNK {
                return false
            }
            var buf = [CChar](repeating: 0, count: Int(PATH_MAX))
            let len = readlink(current, &buf, buf.count - 1)
            guard len > 0 else { return false }
            buf[len] = 0
            let target = String(cString: buf)
            if target.hasPrefix("/") {
                current = (target as NSString).standardizingPath
            } else {
                let dir = (current as NSString).deletingLastPathComponent
                current = ((dir as NSString).appendingPathComponent(target) as NSString).standardizingPath
            }
            // Canonicalize through the (existing) parent directory so unresolved
            // prefixes like /var match the realpath-resolved store prefix.
            let parent = (current as NSString).deletingLastPathComponent
            if let resolvedParent = parent.withCString({ realpath($0, nil) }) {
                let canonicalParent = String(cString: resolvedParent)
                free(resolvedParent)
                current = canonicalParent + "/" + (current as NSString).lastPathComponent
            }
            if current == prefix || current.hasPrefix(prefix + "/") {
                return true
            }
        }
        return false
    }
}

/// UI-free renderers turning a `ThemePalette` + `Dank16Palette` into terminal emulator
/// theme files. Rendering is delegated to the Rust-backed
/// `DankThemeEngine.renderTerminal(targetId:doc:)`.
public enum TerminalThemeRenderer {

    public static func render(
        emulator: TerminalEmulator,
        palette: ThemePalette,
        dank16: Dank16Palette,
        themeName: String
    ) -> String {
        let doc = TerminalThemeDocument(
            themeName: themeName,
            isDark: palette.isDark,
            palette: palette,
            dank16: dank16
        )
        if let target = try? DankThemeEngine.renderTerminal(targetId: emulator.dteTargetId, doc: doc.dteDocument) {
            return target.content
        }
        return ""
    }

    /// Renders any dank-theme-engine target (v0.9.2 full catalog) from a palette + Dank16.
    public static func render(
        target: ThemeSyncTarget,
        palette: ThemePalette,
        dank16: Dank16Palette,
        themeName: String
    ) -> String {
        let doc = TerminalThemeDocument(
            themeName: themeName,
            isDark: palette.isDark,
            palette: palette,
            dank16: dank16
        )
        if let rendered = try? DankThemeEngine.renderTerminal(targetId: target.dteTargetId, doc: doc.dteDocument) {
            return rendered.content
        }
        return ""
    }

    /// Ghostty theme file (`~/.config/ghostty/themes/dms`), included via `config-file = .../themes/dms`.
    public static func ghostty(palette: ThemePalette, dank16: Dank16Palette, themeName: String) -> String {
        render(emulator: .ghostty, palette: palette, dank16: dank16, themeName: themeName)
    }

    /// Kitty theme include (`~/.config/kitty/dms-theme.conf`), included via `include dms-theme.conf`.
    public static func kitty(palette: ThemePalette, dank16: Dank16Palette, themeName: String) -> String {
        render(emulator: .kitty, palette: palette, dank16: dank16, themeName: themeName)
    }

    /// Alacritty TOML theme (`~/.config/alacritty/dms-theme.toml`), imported via `import = [...]`.
    public static func alacritty(palette: ThemePalette, dank16: Dank16Palette, themeName: String) -> String {
        render(emulator: .alacritty, palette: palette, dank16: dank16, themeName: themeName)
    }

    /// iTerm2 Dynamic Profile JSON (`~/Library/Application Support/iTerm2/DynamicProfiles/dms.json`).
    public static func iterm2(palette: ThemePalette, dank16: Dank16Palette, themeName: String) -> String {
        render(emulator: .iterm2, palette: palette, dank16: dank16, themeName: themeName)
    }
}

/// Live-reload integration for terminal emulators (v0.7 THEME).
///
/// Kitty's auto-reload watcher only watches its *top-level* config paths (`all_config_paths`),
/// never `include`d files — and under home-manager the top-level kitty.conf is a read-only
/// /nix/store symlink that never changes. Kitty's own reload mechanism (used by its watcher and
/// by `reload_conf_in_all_kitties()`) is SIGUSR1 to the GUI process, so DMS sends that after
/// writing the kitty theme file.
public enum EmulatorReload {

    /// Pids of running kitty GUI boss processes, queried via `DankThemeEngine.kittyGUIPids()`.
    public static func kittyGUIPids() throws -> [Int32] {
        (try DankThemeEngine.kittyGUIPids()).map(Int32.init)
    }

    /// Checks whether a candidate parent-directory prefix before `/kitty` represents one
    /// filesystem path (which may contain spaces, e.g. `Home Manager Apps`) rather than an
    /// earlier command plus space-separated arguments.
    private static func isSingleKittyDirPrefix(_ prefix: Substring) -> Bool {
        guard let firstWS = prefix.firstIndex(where: { $0 == " " || $0 == "\t" }) else {
            return true
        }
        guard prefix[..<firstWS].contains("/") else { return false }
        if prefix.contains(" /") || prefix.contains("\t/") { return false }
        if prefix.hasSuffix(".app/Contents/MacOS") { return true }
        return !prefix.contains(" -")
            && !prefix.contains("\t-")
            && !prefix.contains(" +")
            && !prefix.contains("\t+")
            && !prefix.contains(" @")
            && !prefix.contains("\t@")
    }

    private static func splitKittyExeAndArgs(_ rest: Substring) -> Substring? {
        if rest == "kitty" {
            return rest[rest.endIndex...]
        }
        if rest.hasPrefix("kitty") {
            let after = rest.dropFirst("kitty".count)
            if let ch = after.first, ch == " " || ch == "\t" {
                return after
            }
        }

        let needle = "/kitty"
        var searchStart = rest.startIndex
        while let range = rest[searchStart...].range(of: needle) {
            let atBoundary = range.upperBound == rest.endIndex
                || rest[range.upperBound] == " "
                || rest[range.upperBound] == "\t"
            if atBoundary && isSingleKittyDirPrefix(rest[..<range.lowerBound]) {
                return rest[range.upperBound...]
            }
            searchStart = rest.index(after: range.lowerBound)
        }
        return nil
    }

    private static func isKittyGUITrailingArgs(_ trailing: Substring) -> Bool {
        let args = trailing.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard let firstArg = args.first else { return true }
        if firstArg.hasPrefix("@") { return false }
        if firstArg.hasPrefix("+") {
            if firstArg == "+" {
                return args.count > 1 && args[1] == "open"
            }
            return firstArg == "+open"
        }
        return true
    }

    /// Parses `ps -axww -o pid=,command=` output and returns the pids of kitty GUI boss processes,
    /// replicating kitty's `is_kitty_gui_cmdline`: executable basename `kitty` (including paths
    /// containing spaces such as Home Manager's `~/Applications/Home Manager Apps/kitty.app/...`),
    /// and the first argument must not be `@...` (remote-control CLI) or `+...` (kittens), except
    /// `+open`.
    public static func kittyGUIPids(fromPSOutput psOutput: String) -> [Int32] {
        var pids: [Int32] = []
        for rawLine in psOutput.split(separator: "\n") {
            let trimmed = rawLine.drop(while: { $0 == " " || $0 == "\t" })
            guard let pidEnd = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" }),
                  let pid = Int32(trimmed[..<pidEnd]) else {
                continue
            }
            let rest = trimmed[pidEnd...].drop(while: { $0 == " " || $0 == "\t" })
            guard !rest.isEmpty, let trailing = splitKittyExeAndArgs(rest) else { continue }
            if isKittyGUITrailingArgs(trailing) {
                pids.append(pid)
            }
        }
        return pids
    }

    /// Returns true when the kitty config file at `path` includes the dms theme file,
    /// via `DankThemeEngine.kittyConfigReferencesTheme(_:)`.
    public static func kittyConfigReferencesTheme(atPath path: String) -> Bool {
        DankThemeEngine.kittyConfigReferencesTheme(path)
    }

    /// Returns true when a kitty.conf text pulls in the DMS theme file via an include directive.
    public static func kittyConfigReferencesTheme(_ confText: String, themeFileName: String = "dms-theme.conf") -> Bool {
        let includeKeys: Set<String> = ["include", "globinclude", "envinclude", "geninclude"]
        for rawLine in confText.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let key = tokens.first?.lowercased(), includeKeys.contains(key) else { continue }
            if line.contains(themeFileName) { return true }
        }
        return false
    }

    /// Returns true when a tmux config text sources the DMS theme file via an uncommented
    /// `source` / `source-file` directive referencing `themeFileName`.
    public static func tmuxConfigReferencesTheme(_ confText: String, themeFileName: String = "dms.conf") -> Bool {
        for rawLine in confText.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let key = tokens.first?.lowercased(), key == "source" || key == "source-file" else { continue }
            if line.contains(themeFileName) { return true }
        }
        return false
    }

    /// Returns true when the tmux config file at `path` sources the DMS theme file.
    public static func tmuxConfigReferencesTheme(atPath path: String) -> Bool {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return false }
        return tmuxConfigReferencesTheme(text)
    }

    /// Parses `ps -axww -o pid=,command=` output and returns the pids of running interactive
    /// `nvim` processes — executable basename `nvim`, excluding `--headless` / `--embed`
    /// (RPC/headless instances must not be poked with SIGUSR1).
    public static func neovimPids(fromPSOutput psOutput: String) -> [Int32] {
        var pids: [Int32] = []
        for rawLine in psOutput.split(separator: "\n") {
            let trimmed = rawLine.drop(while: { $0 == " " || $0 == "\t" })
            guard let pidEnd = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" }),
                  let pid = Int32(trimmed[..<pidEnd]) else {
                continue
            }
            let rest = trimmed[pidEnd...].drop(while: { $0 == " " || $0 == "\t" })
            guard let exeEnd = rest.firstIndex(where: { $0 == " " || $0 == "\t" }) else {
                // Bare command with no args: `1234 nvim` or `1234 /usr/local/bin/nvim`.
                if (rest as NSString).lastPathComponent == "nvim" { pids.append(pid) }
                continue
            }
            let exe = rest[..<exeEnd]
            guard (exe as NSString).lastPathComponent == "nvim" else { continue }
            let args = rest[exeEnd...]
            if args.contains("--headless") || args.contains("--embed") { continue }
            pids.append(pid)
        }
        return pids
    }

    /// Sends SIGUSR1 (Neovim's `nvim_listen`-style reload signal used by `:colorscheme` reload
    /// plugins) to every running interactive nvim process; returns the signaled pids.
    public static func signalNeovimReload() -> [Int32] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axww", "-o", "pid=,command="]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return [] }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        var signaled: [Int32] = []
        for pid in neovimPids(fromPSOutput: output) {
            if kill(pid, SIGUSR1) == 0 {
                signaled.append(pid)
            }
        }
        return signaled
    }

    /// When a tmux server is running, sources the DMS theme file into it via
    /// `tmux source-file <themePath>`; returns true when the command exits with status 0.
    public static func reloadTmux(themePath: String) -> Bool {
        func runTmux(_ args: [String]) -> Int32? {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["tmux"] + args
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            guard (try? process.run()) != nil else { return nil }
            process.waitUntilExit()
            return process.terminationStatus
        }
        // No tmux server (or no tmux binary) -> nothing to reload.
        guard runTmux(["has-session"]) == 0 else { return false }
        return runTmux(["source-file", themePath]) == 0
    }
}

/// Staging helpers for `dms dmenu` requests (v0.7 CLI).
/// Candidates are staged in a temp file under `~/Library/Application Support/DMS/dmenu/<requestID>.txt`
/// and only the path + requestID travel over the socket, keeping the line protocol intact.
public enum DMenuStaging {

    /// Generates a fresh dmenu request ID (uppercase hex, no dashes).
    public static func newRequestID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").uppercased()
    }

    /// Validates a dmenu request ID: exactly 32 uppercase hex characters (`0-9`, `A-F`).
    /// Anything else (lowercase, wrong length, path separators, traversal) is rejected,
    /// so a request ID can never escape the staging directory.
    public static func isValidRequestID(_ id: String) -> Bool {
        guard id.count == 32 else { return false }
        return id.allSatisfy { c in
            (c >= "0" && c <= "9") || (c >= "A" && c <= "F")
        }
    }

    /// Default staging directory: `<appSupport>/DMS/dmenu`.
    public static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DMS/dmenu", isDirectory: true)
    }

    public static func candidatesPath(for requestID: String, in directory: URL? = nil) -> URL {
        (directory ?? defaultDirectory()).appendingPathComponent("\(requestID).txt")
    }

    public static func resultPath(for requestID: String, in directory: URL? = nil) -> URL {
        (directory ?? defaultDirectory()).appendingPathComponent("\(requestID).result")
    }

    /// Writes the newline-delimited candidates to `<requestID>.txt` and returns its URL.
    @discardableResult
    public static func stage(candidates: [String], requestID: String, in directory: URL? = nil) throws -> URL {
        let dir = directory ?? defaultDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = candidatesPath(for: requestID, in: dir)
        var content = candidates.joined(separator: "\n")
        if !content.isEmpty { content.append("\n") }
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Reads a staged candidates file back into lines (empty lines dropped — dmenu semantics).
    public static func readCandidates(at url: URL) -> [String] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return content.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    /// Reads the daemon-written result file, if present.
    /// Strips only trailing CR/LF — leading/trailing spaces in the selected line are
    /// significant (dmenu selections may legitimately contain them) and are preserved.
    public static func readResult(for requestID: String, in directory: URL? = nil) -> String? {
        let url = resultPath(for: requestID, in: directory)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        // Strip over unicode scalars: "\r\n" is a single grapheme cluster (Character),
        // so a Character-based loop would never match it.
        var scalars = Substring(content).unicodeScalars
        while let last = scalars.last, last == "\n" || last == "\r" {
            scalars.removeLast()
        }
        return String(String.UnicodeScalarView(scalars))
    }

    /// Removes staged candidates + result files for a request.
    public static func cleanup(requestID: String, in directory: URL? = nil) {
        let dir = directory ?? defaultDirectory()
        try? FileManager.default.removeItem(at: candidatesPath(for: requestID, in: dir))
        try? FileManager.default.removeItem(at: resultPath(for: requestID, in: dir))
    }
}
