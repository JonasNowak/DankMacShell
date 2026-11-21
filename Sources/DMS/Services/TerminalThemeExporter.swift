import Foundation
import DMSCore
import DankThemeEngine
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
    /// dank-theme-engine target ids detected as installed on this machine (v0.9.2).
    @Published public private(set) var detectedTargetIds: Set<String> = []

    private init() {
        refreshDetectedTargets()
    }

    /// Re-queries installed targets and stores the detected target ids.
    /// Uses `TerminalThemeDetector.detectedTargets()` exclusively so DMS's own generated
    /// theme files can never cause a false-positive "installed" detection.
    public func refreshDetectedTargets() {
        detectedTargetIds = Set(TerminalThemeDetector.detectedTargets().map(\.dteTargetId))
    }

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
    /// Delegates to `exportAllTargets` and maps the four legacy `TerminalEmulator` cases back
    /// for full backward compatibility (v0.9.2).
    @discardableResult
    public func export(palette: ThemePalette, themeName: String, isDark: Bool, config: DMSConfig? = nil) -> [TerminalEmulator: Bool] {
        let allResults = exportAllTargets(palette: palette, themeName: themeName, isDark: isDark, config: config)
        var results: [TerminalEmulator: Bool] = [:]
        for emulator in TerminalEmulator.allCases {
            guard let target = ThemeSyncTarget(rawValue: emulator.rawValue),
                  let success = allResults[target] else { continue }
            results[emulator] = success
        }
        return results
    }

    /// Writes every enabled dank-theme-engine target theme file plus the canonical `theme.json` (v0.9.2).
    /// Returns per-target success. Never throws: one failing/managed target does not abort the rest.
    @discardableResult
    public func exportAllTargets(palette: ThemePalette, themeName: String, isDark: Bool, config: DMSConfig? = nil) -> [ThemeSyncTarget: Bool] {
        let cfg = config ?? ConfigStore.shared.config
        let dank16 = Dank16Generator.generate(from: palette)
        // Local detection is the gate: only genuinely installed targets are written, so DMS
        // never creates config directories/files for uninstalled apps.
        let detected = TerminalThemeDetector.detectedTargets()
        detectedTargetIds = Set(detected.map(\.dteTargetId))
        var results: [ThemeSyncTarget: Bool] = [:]
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

        for target in ThemeSyncTarget.allCases where cfg.isThemeTargetEnabled(target, detected: detected) {
            let targetURL = TerminalThemePaths.targetPath(for: target)
            // Obsidian syncs every discovered vault; all other targets have a single path.
            let writeURLs: [URL]
            if target == .obsidian {
                writeURLs = TerminalThemePaths.resolveObsidianSnippetURLs(customVaultPaths: cfg.obsidianVaultPaths)
            } else {
                writeURLs = [targetURL]
            }
            let content = TerminalThemeRenderer.render(
                target: target,
                palette: palette,
                dank16: dank16,
                themeName: themeName
            )
            // Never write empty / whitespace-only output — a render failure must not
            // overwrite the user's existing theme file with a 0-byte document.
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                results[target] = false
                firstError = firstError ?? "Rendered \(target.rawValue) theme is empty; refusing to overwrite \(targetURL.path)"
                logger.error("Rendered \(target.rawValue) theme is empty; skipping write to \(targetURL.path, privacy: .public)")
                continue
            }
            var wroteAny = false
            for url in writeURLs {
                if TerminalThemeSecurity.isManagedSymlink(path: url.path) {
                    logger.warning("Skipping \(target.rawValue) theme at \(url.path, privacy: .public): symlink resolves into /nix/store (home-manager managed). DMS only writes files home-manager does not declare.")
                    skipped.append(target.displayName)
                    continue
                }
                do {
                    try Self.writeAtomically(string: content, to: url)
                    wroteAny = true
                    logger.info("Wrote \(target.rawValue) theme to \(url.path, privacy: .public)")
                } catch {
                    firstError = firstError ?? error.localizedDescription
                    logger.error("Failed to write \(target.rawValue) theme to \(url.path, privacy: .public): \(error.localizedDescription)")
                }
            }
            results[target] = wroteAny
            if wroteAny {
                switch target {
                case .kitty:
                    // Kitty only auto-reloads its top-level config (never includes, and under
                    // home-manager that file is a read-only /nix/store symlink), so poke the
                    // running kitty processes with its own reload signal.
                    Self.signalKittyConfigReload(logger: logger)
                    Self.warnIfKittyConfigMissesInclude(logger: logger)
                case .tmux:
                    _ = EmulatorReload.reloadTmux(themePath: targetURL.path)
                case .neovim:
                    _ = EmulatorReload.signalNeovimReload()
                default:
                    break
                }
            }
        }

        lastExportDate = Date()
        lastExportError = firstError
        lastSkippedManaged = skipped
        return results
    }

    /// Sends SIGUSR1 (kitty's config-reload signal, same one its own `__watch_conf__` kitten and
    /// `reload_conf_in_all_kitties()` use) to every running kitty GUI process.
    /// Process discovery + signaling live in the Rust-backed DankThemeEngine.
    private static func signalKittyConfigReload(logger: Logger) {
        do {
            let pids = try DankThemeEngine.signalKittyReload()
            if pids.isEmpty {
                logger.debug("No running kitty GUI process found to signal SIGUSR1")
                return
            }
            for pid in pids {
                logger.info("Sent SIGUSR1 to kitty (pid \(pid)) to reload its config")
            }
        } catch {
            logger.error("Failed to signal kitty reload: \(error.localizedDescription)")
        }
    }

    /// Warns when the resolved kitty.conf does not include the DMS theme file — or when
    /// kitty OS auto-theme files (`*-theme.auto.conf`) are present and would shadow `dms-theme.conf`.
    private static func warnIfKittyConfigMissesInclude(logger: Logger) {
        let kittyDir = TerminalThemePaths.configHome()
            .appendingPathComponent("kitty", isDirectory: true)
        let fm = FileManager.default
        for autoFile in ["dark-theme.auto.conf", "light-theme.auto.conf", "no-preference-theme.auto.conf"] {
            let autoPath = kittyDir.appendingPathComponent(autoFile, isDirectory: false)
            if fm.fileExists(atPath: autoPath.path) {
                logger.warning("\(autoPath.path, privacy: .public) exists and overrides kitty.conf colors on appearance changes — remove it so DMS controls kitty colors")
            }
        }
        let confPath = kittyDir.appendingPathComponent("kitty.conf", isDirectory: false)
        guard fm.fileExists(atPath: confPath.path) else { return }
        if !EmulatorReload.kittyConfigReferencesTheme(atPath: confPath.path) {
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
        // Unique temp name in the destination directory; the rename below is the atomic
        // step, so the temp write itself does not need `.atomic`.
        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        try data.write(to: tmp)
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
