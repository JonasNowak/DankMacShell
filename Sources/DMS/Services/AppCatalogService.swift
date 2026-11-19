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

        matches.sort { $0.score > $1.score }
        return (math, matches)
    }

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
