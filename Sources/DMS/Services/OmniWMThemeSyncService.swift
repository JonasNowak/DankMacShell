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
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/omniwm/settings.toml")
    }

    public static var backupURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/omniwm/settings.toml.dms-backup")
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
        let fileURL = Self.settingsURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.info("OmniWM settings.toml not found at \(fileURL.path); skipping sync")
            return false
        }

        isSyncing = true
        defer { isSyncing = false }

        // Ensure safety backup exists on first synchronization
        let backupURL = Self.backupURL
        if !FileManager.default.fileExists(atPath: backupURL.path) {
            try? FileManager.default.copyItem(at: fileURL, to: backupURL)
            logger.info("Created initial OmniWM settings backup at \(backupURL.path)")
        }

        do {
            let currentContent = try String(contentsOf: fileURL, encoding: .utf8)
            let effectiveConfig = config ?? ConfigStore.shared.config

            let updatedContent = OmniWMThemeUpdater.applyTheme(
                to: currentContent,
                palette: palette,
                secondarySeed: secondarySeed,
                mode: effectiveConfig.omniwmGradientMode,
                direction: effectiveConfig.omniwmGradientDirection,
                syncOverview: effectiveConfig.omniwmSyncOverview,
                syncWorkspaceBar: effectiveConfig.omniwmSyncWorkspaceBar
            )

            // Write atomically to trigger OmniWM's settingsFileWatcher
            try updatedContent.write(to: fileURL, atomically: true, encoding: .utf8)
            lastSyncDate = Date()
            lastSyncError = nil
            logger.info("Successfully updated OmniWM borders with theme '\(palette.name)' (mode: \(effectiveConfig.omniwmGradientMode.rawValue))")
            return true
        } catch {
            lastSyncError = error.localizedDescription
            logger.error("Failed to update OmniWM settings: \(error.localizedDescription)")
            return false
        }
    }
}
