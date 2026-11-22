import AppKit
import Observation
import DMSCore

/// Indexes installed applications and provides fast real-time search with math evaluation.
@MainActor
@Observable
public final class AppCatalogService {
    public static let shared = AppCatalogService()

    public private(set) var apps: [AppItem] = []

    private var scanTask: Task<Void, Never>?

    private init() {
        refresh()
    }

    public func refresh() {
        scanTask?.cancel()
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            let scanned = Self.scanApplications()
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                self.apps = scanned
            }
        }
        scanTask = task
    }

    /// Records an application launch, immediately updating frecency tracking and re-sorting results.
    public func recordLaunch(app: AppItem) {
        LauncherFrecencyStore.shared.recordLaunch(id: app.bundleID)
        let (count, lastLaunch) = LauncherFrecencyStore.shared.launchInfo(for: app.bundleID)
        if let idx = apps.firstIndex(where: { $0.id == app.id }) {
            let old = apps[idx]
            apps[idx] = AppItem(
                id: old.id,
                name: old.name,
                bundleID: old.bundleID,
                path: old.path,
                subtitle: old.subtitle,
                category: old.category,
                isRunning: old.isRunning,
                isHidden: old.isHidden,
                launchCount: count,
                lastLaunchedAt: lastLaunch
            )
        }
    }

    public func search(query: String) -> (math: MathResult?, results: [SearchResult]) {
        let math = AppSearch.evaluateMath(query: query)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // v0.6 LAUNCH: apply per-app overrides (display name, hidden flag) from the AppEditView.
        let overrides = ConfigStore.shared.config.apps.perApp
        var catalog = apps.compactMap { AppOverrideApplier.apply(overrides, to: $0) }
        if ConfigStore.shared.config.enabledPlugins.contains("symbian-belle-sync") {
            let binPath = SymbianClient.shared.resolveExecutablePath() ?? "/usr/local/bin/dms-symbian"
            catalog.append(AppItem(
                id: "io.dms.plugin.symbian-belle-sync",
                name: "Nokia Belle USB Sync",
                bundleID: "io.dms.plugin.symbian-belle-sync",
                path: binPath,
                subtitle: "USB sync for Nokia C7: MP3 music & SISX apps",
                category: "Utilities"
            ))
        }

        if trimmed.isEmpty {
            // Return installed apps prioritized by frecency, then alphabetical
            let now = Date()
            let scored: [(app: AppItem, frecency: Int)] = catalog.map { app in
                (app, LauncherScorer.calculateFrecency(launchCount: app.launchCount, lastLaunch: app.lastLaunchedAt, now: now))
            }
            let sortedApps = scored.sorted { a1, a2 in
                if a1.frecency != a2.frecency {
                    return a1.frecency > a2.frecency
                }
                return a1.app.name.localizedCaseInsensitiveCompare(a2.app.name) == .orderedAscending
            }
            let all = sortedApps.map { SearchResult(app: $0.app, score: 0) }
            return (math, all)
        }

        var matches: [SearchResult] = []
        let now = Date()
        for app in catalog {
            let candidate = LauncherCandidate(app: app, tags: AppOverrideApplier.tags(overrides, for: app.bundleID))
            if let score = LauncherScorer.score(candidate: candidate, query: trimmed, now: now) {
                matches.append(SearchResult(app: app, score: score))
            } else if let legacyScore = AppSearch.score(app: app, query: trimmed) {
                matches.append(SearchResult(app: app, score: legacyScore))
            }
        }

        // v0.9.5: built-in DMS Settings & DMS Actions are scored through LauncherScorer
        // (type .setting / .action) so they rank alongside real apps; no legacy fallback.
        for entry in Self.builtinEntries {
            let app = AppItem(
                id: entry.id,
                name: entry.name,
                bundleID: entry.id,
                path: "/System/Library/CoreServices/Finder.app",
                subtitle: entry.subtitle,
                category: entry.type == .setting ? "DMS Setting" : "DMS Action"
            )
            let candidate = LauncherCandidate(
                id: entry.id,
                name: entry.name,
                genericName: entry.subtitle,
                identifier: entry.id,
                type: entry.type,
                tags: entry.tags
            )
            if let score = LauncherScorer.score(candidate: candidate, query: trimmed, now: now) {
                matches.append(SearchResult(app: app, score: score))
            }
        }

        // v0.9.6: active local plugins are surfaced as launcher entries (type .plugin)
        // and scored through LauncherScorer so they rank alongside apps and built-ins.
        for id in PluginRuntimeService.shared.activeLauncherPluginIDs {
            guard let manifest = PluginRuntimeService.shared.manifests[id] else { continue }
            let app = AppItem(
                id: "io.dms.localplugin.\(id)",
                name: manifest.name,
                bundleID: "io.dms.localplugin.\(id)",
                path: "/System/Library/CoreServices/Finder.app",
                subtitle: "Plugin • \(manifest.description)",
                category: "Plugin"
            )
            let candidate = LauncherCandidate(
                id: "io.dms.localplugin.\(id)",
                name: manifest.name,
                genericName: manifest.description,
                identifier: id,
                type: .plugin,
                tags: [manifest.launcherPrefix ?? "", manifest.author].filter { !$0.isEmpty }
            )
            if let score = LauncherScorer.score(candidate: candidate, query: trimmed, now: now) {
                matches.append(SearchResult(app: app, score: score))
            }
        }

        matches.sort { $0.score > $1.score }
        return (math, matches)
    }

    /// A synthetic launcher entry for a built-in DMS Setting or DMS Action.
    private struct BuiltinEntry {
        let id: String
        let name: String
        let subtitle: String
        let type: LauncherCandidateType
        let tags: [String]
    }

    /// Built-in DMS Settings (`.setting`) and DMS Actions (`.action`) surfaced in search.
    private static let builtinEntries: [BuiltinEntry] = [
        // MARK: DMS Settings
        BuiltinEntry(
            id: "io.dms.setting.theme",
            name: "Theme & Colors",
            subtitle: "DMS Setting • Matugen palette, dark/light mode, and 32-target app sync",
            type: .setting,
            tags: ["theme", "color", "palette", "matugen", "dark", "light", "terminal", "nvim", "tmux", "obsidian"]
        ),
        BuiltinEntry(
            id: "io.dms.setting.bar",
            name: "DankBar & Widgets",
            subtitle: "DMS Setting • Bar position, height, multi-bar layout, and widget pills",
            type: .setting,
            tags: ["bar", "dankbar", "widgets", "top", "bottom", "dock"]
        ),
        BuiltinEntry(
            id: "io.dms.setting.typography",
            name: "Typography & Fonts",
            subtitle: "DMS Setting • Custom fonts, Nerd Fonts, global default font, and motion",
            type: .setting,
            tags: ["font", "typography", "nerdfont", "nerd", "monospace", "scale", "motion"]
        ),
        BuiltinEntry(
            id: "io.dms.setting.surfaces",
            name: "Surfaces & Glass",
            subtitle: "DMS Setting • Blur, opacity, corner radius, borders, and shadows",
            type: .setting,
            tags: ["glass", "blur", "opacity", "transparency", "corner", "border"]
        ),
        BuiltinEntry(
            id: "io.dms.setting.island",
            name: "Dynamic Island",
            subtitle: "DMS Setting • Notch pill sizing, media visualizer, and auto-expand",
            type: .setting,
            tags: ["island", "notch", "dynamic", "visualizer"]
        ),
        BuiltinEntry(
            id: "io.dms.setting.shortcuts",
            name: "Keyboard Shortcuts",
            subtitle: "DMS Setting • Global hotkeys for Launcher, Dash, Clipboard, and Notepad",
            type: .setting,
            tags: ["shortcuts", "keybinds", "hotkeys", "keys"]
        ),
        BuiltinEntry(
            id: "io.dms.setting.plugins",
            name: "Plugins & Extensions",
            subtitle: "DMS Setting • Manage enabled DankMacShell plugins",
            type: .setting,
            tags: ["plugins", "extensions", "addons"]
        ),
        BuiltinEntry(
            id: "io.dms.setting.system",
            name: "System & Updates",
            subtitle: "DMS Setting • Weather, updates, permissions wizard, and config backup",
            type: .setting,
            tags: ["system", "updates", "weather", "permissions", "onboarding"]
        ),
        // MARK: DMS Actions
        BuiltinEntry(
            id: "io.dms.action.clipboard",
            name: "Toggle Clipboard History",
            subtitle: "DMS Action • Open searchable clipboard manager",
            type: .action,
            tags: ["clipboard", "paste", "history", "copy"]
        ),
        BuiltinEntry(
            id: "io.dms.action.notepad",
            name: "Toggle Scratchpad Notepad",
            subtitle: "DMS Action • Open markdown scratchpad notepad",
            type: .action,
            tags: ["notepad", "notes", "scratchpad", "markdown"]
        ),
        BuiltinEntry(
            id: "io.dms.action.processes",
            name: "Open Process Monitor",
            subtitle: "DMS Action • Inspect CPU and memory usage in Dash",
            type: .action,
            tags: ["process", "cpu", "ram", "memory", "activity", "kill"]
        ),
        BuiltinEntry(
            id: "io.dms.action.controlcenter",
            name: "Toggle Control Center",
            subtitle: "DMS Action • Quick tiles, audio, network, and battery controls",
            type: .action,
            tags: ["control", "wifi", "bluetooth", "audio", "volume"]
        ),
        BuiltinEntry(
            id: "io.dms.action.onboard",
            name: "Open Setup & Permissions Wizard",
            subtitle: "DMS Action • Run the 5-step DankMacShell setup and permissions guide",
            type: .action,
            tags: ["onboard", "setup", "wizard", "permissions", "welcome"]
        ),
        BuiltinEntry(
            id: "io.dms.action.colorpicker",
            name: "Pick Screen Color",
            subtitle: "DMS Action • Sample any pixel on screen to clipboard as HEX",
            type: .action,
            tags: ["color", "picker", "eyedropper", "hex"]
        ),
        BuiltinEntry(
            id: "io.dms.action.lock",
            name: "Lock Mac Screen",
            subtitle: "DMS Action • Immediately lock the macOS session",
            type: .action,
            tags: ["lock", "screen", "sleep", "security"]
        )
    ]

    nonisolated private static func scanApplications() -> [AppItem] {
        // /System/Applications is enumerated recursively, which already covers
        // /System/Applications/Utilities — scanning it separately only duplicates work.
        let dirs = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications",
            "/System/Cryptexes/App/System/Applications"
        ]

        var found: [String: AppItem] = [:]
        let fm = FileManager.default

        for dir in dirs {
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app" {
                    if let bundle = Bundle(url: fileURL), let bid = bundle.bundleIdentifier {
                        let name = fm.displayName(atPath: fileURL.path)
                        var subtitle = ""
                        var category = ""

                        if let info = bundle.infoDictionary {
                            if let desc = info["CFBundleDescription"] as? String, !desc.isEmpty {
                                subtitle = desc
                            } else if let getInfo = info["CFBundleGetInfoString"] as? String, !getInfo.isEmpty, !getInfo.allSatisfy({ $0.isNumber || $0 == "." }) {
                                subtitle = getInfo
                            }
                            if let cat = info["NSApplicationCategoryType"] as? String, !cat.isEmpty {
                                category = cat.replacingOccurrences(of: "public.app-category.", with: "")
                                    .replacingOccurrences(of: "-", with: " ")
                                    .capitalized
                                if subtitle.isEmpty {
                                    subtitle = category
                                }
                            }
                        }

                        let (count, lastLaunch) = LauncherFrecencyStore.shared.launchInfo(for: bid)

                        let item = AppItem(
                            name: name,
                            bundleID: bid,
                            path: fileURL.path,
                            subtitle: subtitle,
                            category: category,
                            launchCount: count,
                            lastLaunchedAt: lastLaunch
                        )

                        if found[bid] == nil {
                            found[bid] = item
                        }
                    }
                }
            }
        }

        return found.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
