import AppKit
import Observation
import DMSCore

/// Indexes installed applications and provides fast real-time search with math evaluation.
@MainActor
@Observable
public final class AppCatalogService {
    public static let shared = AppCatalogService()

    public private(set) var apps: [AppItem] = []

    private init() {
        refresh()
    }

    public func refresh() {
        Task.detached(priority: .userInitiated) {
            let scanned = Self.scanApplications()
            await MainActor.run {
                self.apps = scanned
            }
        }
    }

    public func search(query: String) -> (math: MathResult?, results: [SearchResult]) {
        let math = AppSearch.evaluateMath(query: query)

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            // Return all installed apps sorted alphabetically so user can scroll through all
            let all = apps.map { SearchResult(app: $0, score: 0) }
            return (math, all)
        }

        var matches: [SearchResult] = []
        for app in apps {
            if let score = AppSearch.score(app: app, query: trimmed) {
                matches.append(SearchResult(app: app, score: score))
            }
        }

        matches.sort { $0.score > $1.score }
        return (math, matches)
    }

    nonisolated private static func scanApplications() -> [AppItem] {
        let dirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
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
                        let item = AppItem(name: name, bundleID: bid, path: fileURL.path)
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
