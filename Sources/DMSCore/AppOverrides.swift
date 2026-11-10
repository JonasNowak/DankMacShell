import Foundation

/// Per-application customization edited in the launcher's AppEditView (spec 18-launcher.md).
/// Persisted inside `DMSConfig.AppOverrides.perApp` keyed by bundle identifier.
public struct AppOverrideEntry: Sendable, Codable, Equatable {
    /// Custom display name shown in launcher results instead of the bundle name.
    public var displayName: String?
    /// Custom arguments appended when launching the app (`open -a <path> --args ...`).
    public var launchArguments: [String]?
    /// When true, the app is hidden from launcher results entirely.
    /// (Persisted as `"hidden"`; distinct from `RunningAppsService.isHidden`, which hides windows.)
    public var hiddenFromLauncher: Bool
    /// Extra search tags matched by `LauncherScorer`.
    public var tags: [String]

    public init(
        displayName: String? = nil,
        launchArguments: [String]? = nil,
        hiddenFromLauncher: Bool = false,
        tags: [String] = []
    ) {
        self.displayName = displayName
        self.launchArguments = launchArguments
        self.hiddenFromLauncher = hiddenFromLauncher
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case displayName
        case launchArguments
        case hiddenFromLauncher = "hidden"
        case tags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.launchArguments = try container.decodeIfPresent([String].self, forKey: .launchArguments)
        self.hiddenFromLauncher = try container.decodeIfPresent(Bool.self, forKey: .hiddenFromLauncher) ?? false
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    /// True when the entry carries no customization and can be removed from the map.
    public var isDefault: Bool {
        (displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) &&
        (launchArguments?.isEmpty ?? true) &&
        !hiddenFromLauncher &&
        tags.isEmpty
    }
}

/// Pure helpers applying `AppOverrideEntry` values to launcher catalog items.
public enum AppOverrideApplier {

    /// Applies overrides to an app. Returns `nil` when the app is hidden from the launcher,
    /// otherwise a copy with the overridden display name.
    public static func apply(_ overrides: [String: AppOverrideEntry], to app: AppItem) -> AppItem? {
        guard let entry = overrides[app.bundleID] else { return app }
        if entry.hiddenFromLauncher { return nil }
        let name = entry.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty, name != app.name {
            return AppItem(
                id: app.id,
                name: name,
                bundleID: app.bundleID,
                path: app.path,
                subtitle: app.subtitle,
                category: app.category,
                isRunning: app.isRunning,
                isHidden: app.isHidden,
                isPinned: app.isPinned,
                launchCount: app.launchCount,
                lastLaunchedAt: app.lastLaunchedAt
            )
        }
        return app
    }

    /// Tags for an app from the override map (empty when none).
    public static func tags(_ overrides: [String: AppOverrideEntry], for bundleID: String) -> [String] {
        overrides[bundleID]?.tags ?? []
    }

    /// Launch arguments for an app from the override map (nil when none).
    public static func launchArguments(_ overrides: [String: AppOverrideEntry], for bundleID: String) -> [String]? {
        overrides[bundleID]?.launchArguments
    }

    /// Splits a raw launch-arguments string into argv using shell-like quoting rules.
    /// Supports single quotes, double quotes (with \" and \\ escapes), and backslash escapes.
    public static func splitShellArguments(_ raw: String) -> [String] {
        var args: [String] = []
        var current = ""
        var hasCurrent = false
        var index = raw.startIndex

        func flush() {
            if hasCurrent {
                args.append(current)
                current = ""
                hasCurrent = false
            }
        }

        while index < raw.endIndex {
            let c = raw[index]
            if c.isWhitespace {
                flush()
                index = raw.index(after: index)
                continue
            }
            if c == "'" {
                hasCurrent = true
                index = raw.index(after: index)
                while index < raw.endIndex, raw[index] != "'" {
                    current.append(raw[index])
                    index = raw.index(after: index)
                }
                if index < raw.endIndex { index = raw.index(after: index) } // closing quote
                continue
            }
            if c == "\"" {
                hasCurrent = true
                index = raw.index(after: index)
                while index < raw.endIndex, raw[index] != "\"" {
                    if raw[index] == "\\", index < raw.index(before: raw.endIndex) {
                        let next = raw.index(after: index)
                        if raw[next] == "\"" || raw[next] == "\\" {
                            current.append(raw[next])
                            index = raw.index(after: next)
                            continue
                        }
                    }
                    current.append(raw[index])
                    index = raw.index(after: index)
                }
                if index < raw.endIndex { index = raw.index(after: index) } // closing quote
                continue
            }
            if c == "\\" {
                hasCurrent = true
                let next = raw.index(after: index)
                if next < raw.endIndex {
                    current.append(raw[next])
                    index = raw.index(after: next)
                } else {
                    index = next
                }
                continue
            }
            hasCurrent = true
            current.append(c)
            index = raw.index(after: index)
        }
        flush()
        return args
    }
}
