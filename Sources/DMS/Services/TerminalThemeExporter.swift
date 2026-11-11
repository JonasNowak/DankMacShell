import Foundation
import DMSCore
import os.log

/// Live terminal emulator theme sync (v0.7 THEME).
/// Renders the active `ThemePalette` + `Dank16Palette` into Ghostty / Kitty / Alacritty / iTerm2
/// theme files whenever the palette changes (debounced ~150ms like `OmniWMThemeSyncService`).
///
/// Nix-darwin / home-manager compatibility:
/// - Config dirs resolve via `XDG_CONFIG_HOME` when set, else `~/.config` (never hardcoded).
/// - Targets that are symlinks resolving into `/nix/store` are skipped with an os.log warning;
///   one managed target never fails the whole export.
/// - A canonical machine-readable `theme.json` is always written atomically to
///   `~/Library/Application Support/DMS/theme.json` as the read-only interface for
///   home-manager / stylix-style setups.
@MainActor
public final class TerminalThemeExporter: ObservableObject {
    public static let shared = TerminalThemeExporter()

    private let logger = Logger(subsystem: "com.dank.macshell", category: "TerminalThemeExporter")
    private var debounceTask: Task<Void, Never>?

    @Published public private(set) var lastExportDate: Date?
    @Published public private(set) var lastExportError: String?
    /// Emulators skipped in the last export because their target is nix-store managed.
    @Published public private(set) var lastSkippedManaged: [String] = []

    private init() {}

    /// Debounced entry point called from `ThemeStore` palette changes.
    public func exportIfEnabled(palette: ThemePalette, themeName: String, isDark: Bool, config: DMSConfig? = nil) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
            guard !Task.isCancelled else { return }
            let activeConfig = config ?? ConfigStore.shared.config
            guard activeConfig.terminalThemeSync else { return }
            self?.export(palette: palette, themeName: themeName, isDark: isDark, config: activeConfig)
        }
    }

    /// Writes all enabled emulator theme files plus the canonical `theme.json`.
    /// Returns per-emulator success. Never throws: one failing/managed target does not abort the rest.
    @discardableResult
    public func export(palette: ThemePalette, themeName: String, isDark: Bool, config: DMSConfig? = nil) -> [TerminalEmulator: Bool] {
        let cfg = config ?? ConfigStore.shared.config
        let dank16 = Dank16Generator.generate(from: palette)
        var results: [TerminalEmulator: Bool] = [:]
        var skipped: [String] = []
        var firstError: String?

        // Canonical machine-readable document — always written, always writable.
        let document = TerminalThemeDocument(
            themeName: themeName,
            isDark: isDark,
            palette: palette,
            dank16: dank16
        )
        do {
            let data = try document.encodeJSON()
            try Self.writeAtomically(data: data, to: TerminalThemePaths.appSupportThemeJSON())
        } catch {
            firstError = error.localizedDescription
            logger.error("Failed to write canonical theme.json: \(error.localizedDescription)")
        }

        for emulator in TerminalEmulator.allCases where cfg.isTerminalThemeEnabled(emulator) {
            let target = TerminalThemePaths.targetPath(for: emulator)
            if TerminalThemeSecurity.isManagedSymlink(path: target.path) {
                logger.warning("Skipping \(emulator.rawValue) theme at \(target.path, privacy: .public): symlink resolves into /nix/store (home-manager managed). DMS only writes files home-manager does not declare.")
                skipped.append(emulator.displayName)
                results[emulator] = false
                continue
            }
            let content = TerminalThemeRenderer.render(
                emulator: emulator,
                palette: palette,
                dank16: dank16,
                themeName: themeName
            )
            do {
                try Self.writeAtomically(string: content, to: target)
                results[emulator] = true
                logger.info("Wrote \(emulator.rawValue) theme to \(target.path, privacy: .public)")
                if emulator == .kitty {
                    // Kitty only auto-reloads its top-level config (never includes, and under
                    // home-manager that file is a read-only /nix/store symlink), so poke the
                    // running kitty processes with its own reload signal.
                    Self.signalKittyConfigReload(logger: logger)
                    Self.warnIfKittyConfigMissesInclude(logger: logger)
                }
            } catch {
                results[emulator] = false
                firstError = firstError ?? error.localizedDescription
                logger.error("Failed to write \(emulator.rawValue) theme to \(target.path, privacy: .public): \(error.localizedDescription)")
            }
        }

        lastExportDate = Date()
        lastExportError = firstError
        lastSkippedManaged = skipped
        return results
    }

    /// Sends SIGUSR1 (kitty's config-reload signal, same one its own `__watch_conf__` kitten and
    /// `reload_conf_in_all_kitties()` use) to every running kitty GUI process.
    private static func signalKittyConfigReload(logger: Logger) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axww", "-o", "pid=,command="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return }
        for pid in EmulatorReload.kittyGUIPids(fromPSOutput: text) {
            if kill(pid, SIGUSR1) == 0 {
                logger.info("Sent SIGUSR1 to kitty (pid \(pid)) to reload its config")
            } else {
                logger.warning("Failed to signal kitty pid \(pid): errno \(errno)")
            }
        }
    }

    /// Warns when the resolved kitty.conf does not include the DMS theme file — the file is
    /// written, but kitty will never load it until the include exists (home-manager extraConfig).
    private static func warnIfKittyConfigMissesInclude(logger: Logger) {
        let confPath = TerminalThemePaths.configHome()
            .appendingPathComponent("kitty/kitty.conf", isDirectory: false)
        guard let text = try? String(contentsOf: confPath, encoding: .utf8) else { return }
        if !EmulatorReload.kittyConfigReferencesTheme(text) {
            logger.warning("\(confPath.path, privacy: .public) does not include dms-theme.conf — add `include dms-theme.conf` to your kitty config (e.g. home-manager programs.kitty.extraConfig) so kitty loads the DMS theme")
        }
    }

    /// Atomic tmp+rename write in the destination directory.
    public static func writeAtomically(string: String, to url: URL) throws {
        try writeAtomically(data: Data(string.utf8), to: url)
    }

    public static func writeAtomically(data: Data, to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        try data.write(to: tmp, options: .atomic)
        let result = rename(tmp.path, url.path)
        if result != 0 {
            try? fm.removeItem(at: tmp)
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: CocoaError.Code.fileWriteUnknown.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "rename to \(url.path) failed: errno \(errno)"]
            )
        }
    }
}
