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

    /// Stable, always-writable canonical theme document path.
    public static func appSupportThemeJSON() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DMS/theme.json", isDirectory: false)
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

    /// Parses `ps -axww -o pid=,command=` output and returns the pids of kitty GUI boss processes,
    /// replicating kitty's `is_kitty_gui_cmdline`: executable basename `kitty`, and the second
    /// argument must not be `@...` (remote-control CLI) or `+...` (kittens), except `+open`.
    public static func kittyGUIPids(fromPSOutput psOutput: String) -> [Int32] {
        var pids: [Int32] = []
        for line in psOutput.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let pid = Int32(parts.first ?? ""), parts.count >= 2 else { continue }
            let cmd = Array(parts.dropFirst())
            guard (cmd[0] as NSString).lastPathComponent == "kitty" else { continue }
            if cmd.count == 1 {
                pids.append(pid)
                continue
            }
            let second = cmd[1]
            if second.hasPrefix("@") { continue }
            if second.hasPrefix("+") {
                if second == "+" {
                    if cmd.count > 2 && cmd[2] == "open" { pids.append(pid) }
                } else if second == "+open" {
                    pids.append(pid)
                }
                continue
            }
            pids.append(pid)
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
}

/// Staging helpers for `dms dmenu` requests (v0.7 CLI).
/// Candidates are staged in a temp file under `~/Library/Application Support/DMS/dmenu/<requestID>.txt`
/// and only the path + requestID travel over the socket, keeping the line protocol intact.
public enum DMenuStaging {

    /// Generates a fresh dmenu request ID (uppercase hex, no dashes).
    public static func newRequestID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").uppercased()
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
    public static func readResult(for requestID: String, in directory: URL? = nil) -> String? {
        let url = resultPath(for: requestID, in: directory)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Removes staged candidates + result files for a request.
    public static func cleanup(requestID: String, in directory: URL? = nil) {
        let dir = directory ?? defaultDirectory()
        try? FileManager.default.removeItem(at: candidatesPath(for: requestID, in: dir))
        try? FileManager.default.removeItem(at: resultPath(for: requestID, in: dir))
    }
}
