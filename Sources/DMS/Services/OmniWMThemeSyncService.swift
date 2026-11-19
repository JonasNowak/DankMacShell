import Foundation
import SwiftUI
import DMSCore
import os.log

/// Service responsible for synchronizing active DankMacShell themes and wallpaper color gradients into OmniWM (`~/.config/omniwm/settings.toml`).
@MainActor
public final class OmniWMThemeSyncService: ObservableObject {
    public static let shared = OmniWMThemeSyncService()

    private let logger = Logger(subsystem: "com.dank.macshell", category: "OmniWMThemeSync")
    private var debounceTask: Task<Void, Never>?

    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var lastSyncError: String?
    @Published public private(set) var isSyncing: Bool = false

    public static var settingsURL: URL {
        TerminalThemePaths.configHome()
            .appendingPathComponent("omniwm/settings.toml")
    }

    public static var backupURL: URL {
        TerminalThemePaths.configHome()
            .appendingPathComponent("omniwm/settings.toml.dms-backup")
    }

    private init() {}

    /// Synchronizes the theme if `autoThemeOmniWM` is enabled, debouncing rapid calls.
    public func syncThemeIfEnabled(palette: ThemePalette, secondarySeed: M3Color? = nil, config: DMSConfig? = nil) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
            guard !Task.isCancelled else { return }
            let activeConfig = config ?? ConfigStore.shared.config
            guard activeConfig.autoThemeOmniWM else { return }
            self?.syncTheme(palette: palette, secondarySeed: secondarySeed, config: activeConfig)
        }
    }

    /// Surgically applies the palette and gradient options to OmniWM's `settings.toml`.
    @discardableResult
    public func syncTheme(palette: ThemePalette, secondarySeed: M3Color? = nil, config: DMSConfig? = nil, force: Bool = false) -> Bool {
        let effectiveConfig = config ?? ConfigStore.shared.config
        return updateSettingsFile(
            at: Self.settingsURL,
            backupURL: Self.backupURL,
            skipIfUnchanged: !force,
            successMessage: "Successfully updated OmniWM borders with theme '\(palette.name)' (mode: \(effectiveConfig.omniwmGradientMode.rawValue))"
        ) { currentContent in
            // Throwing variant: when `DankThemeEngine.updateOmniWMToml` fails, the error
            // propagates and the sync reports failure instead of a false-positive success.
            try OmniWMThemeUpdater.applyThemeThrowing(
                to: currentContent,
                palette: palette,
                secondarySeed: secondarySeed,
                mode: effectiveConfig.omniwmGradientMode,
                direction: effectiveConfig.omniwmGradientDirection,
                syncOverview: effectiveConfig.omniwmSyncOverview,
                syncWorkspaceBar: effectiveConfig.omniwmSyncWorkspaceBar
            )
        }
    }

    /// Surgically updates `[gaps.outer]` in OmniWM's `settings.toml` when DankBar moves between screen edges.
    @discardableResult
    public func syncBarPositionMargins(
        from oldPosition: String,
        to newPosition: String,
        barMargin: Double = OmniWMMarginUpdater.defaultBarReservedMargin,
        settingsURL: URL? = nil,
        backupURL: URL? = nil
    ) -> Bool {
        guard let oldEdge = OmniWMBarEdge(position: oldPosition),
              let newEdge = OmniWMBarEdge(position: newPosition),
              oldEdge != newEdge else {
            return false
        }

        return updateSettingsFile(
            at: settingsURL ?? Self.settingsURL,
            backupURL: backupURL ?? Self.backupURL,
            skipIfUnchanged: true,
            successMessage: "Updated OmniWM [gaps.outer] margins for bar move \(oldEdge.rawValue) -> \(newEdge.rawValue)"
        ) { currentContent in
            OmniWMMarginUpdater.updateOuterGaps(
                in: currentContent,
                from: oldEdge.rawValue,
                to: newEdge.rawValue,
                barMargin: barMargin
            )
        }
    }

    private func updateSettingsFile(
        at fileURL: URL,
        backupURL: URL,
        skipIfUnchanged: Bool,
        successMessage: String,
        transform: (String) throws -> String
    ) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.info("OmniWM settings.toml not found at \(fileURL.path); skipping sync")
            return false
        }

        if TerminalThemeSecurity.isManagedSymlink(path: fileURL.path) {
            logger.warning("Skipping OmniWM sync at \(fileURL.path, privacy: .public): symlink resolves into /nix/store")
            return false
        }

        // Resolve writable non-Nix symlinks (e.g. a dotfiles-managed settings.toml) so the
        // atomic write replaces the *target* file instead of detaching the user's symlink.
        let writeURL = fileURL.resolvingSymlinksInPath()

        isSyncing = true
        defer { isSyncing = false }

        // Ensure safety backup exists on first synchronization
        if !FileManager.default.fileExists(atPath: backupURL.path) {
            try? FileManager.default.copyItem(at: writeURL, to: backupURL)
            logger.info("Created initial OmniWM settings backup at \(backupURL.path)")
        }

        do {
            let currentContent = try String(contentsOf: writeURL, encoding: .utf8)
            let updatedContent = try transform(currentContent)

            if skipIfUnchanged && updatedContent == currentContent {
                lastSyncError = nil
                return true
            }

            // Write atomically to trigger OmniWM's settingsFileWatcher
            try updatedContent.write(to: writeURL, atomically: true, encoding: .utf8)
            lastSyncDate = Date()
            lastSyncError = nil
            logger.info("\(successMessage)")
            return true
        } catch {
            lastSyncError = error.localizedDescription
            logger.error("Failed to update OmniWM settings: \(error.localizedDescription)")
            return false
        }
    }
}
