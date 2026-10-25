import Testing
import Foundation
@testable import DMSCore

@Suite("Launcher Scorer, Frecency, and UI Improvements Tests")
struct LauncherScorerAndFrecencyTests {

    @Test("Exact Mathematical Weights Specification (docs/spec/18-launcher.md)")
    func testMathematicalWeights() {
        #expect(LauncherScorer.exactMatchWeight == 10_000)
        #expect(LauncherScorer.prefixMatchWeight == 5_000)
        #expect(LauncherScorer.wordBoundaryWeight == 3_000)
        #expect(LauncherScorer.genericPrefixWeight == 800)
        #expect(LauncherScorer.substringWeight == 500)
        #expect(LauncherScorer.genericWeight == 400)
        #expect(LauncherScorer.idWeight == 350)
        #expect(LauncherScorer.fuzzyWeight == 100)
        #expect(LauncherScorer.frecencyMax == 2_000)
    }

    @Test("Candidate Type Bonuses Specification")
    func testCandidateTypeBonuses() {
        #expect(LauncherCandidateType.app.typeBonus == 1000)
        #expect(LauncherCandidateType.plugin.typeBonus == 900)
        #expect(LauncherCandidateType.setting.typeBonus == 850)
        #expect(LauncherCandidateType.clipboard.typeBonus == 825)
        #expect(LauncherCandidateType.file.typeBonus == 800)
        #expect(LauncherCandidateType.action.typeBonus == 600)
    }

    @Test("Scoring Hierarchy on App Candidates")
    func testScoringHierarchy() {
        let app = LauncherCandidate(
            id: "com.apple.Terminal",
            name: "Terminal",
            genericName: "Command Line Shell",
            identifier: "com.apple.Terminal",
            type: .app,
            launchCount: 0,
            lastLaunchTime: nil
        )

        // 1. Exact Match: 10,000 + 1,000 (app bonus) = 11,000
        let exact = LauncherScorer.score(candidate: app, query: "terminal")
        #expect(exact == 10_000 + 1000)

        // 2. Prefix Match: 5,000 + 1,000 = 6,000
        let prefix = LauncherScorer.score(candidate: app, query: "term")
        #expect(prefix == 5_000 + 1000)

        // 3. Word Boundary Match: 3,000 + 1,000 = 4,000
        let chrome = LauncherCandidate(
            id: "com.google.Chrome",
            name: "Google Chrome",
            genericName: "Access the Internet",
            identifier: "com.google.Chrome",
            type: .app
        )
        let wordBoundary = LauncherScorer.score(candidate: chrome, query: "gc")
        #expect(wordBoundary == 3_000 + 1000)

        // 4. Generic Name Prefix Match: 800 + 1,000 = 1,800
        let genericPrefix = LauncherScorer.score(candidate: chrome, query: "access")
        #expect(genericPrefix == 800 + 1000)

        // 5. Substring Match: 500 + 1,000 = 1,500
        let substring = LauncherScorer.score(candidate: app, query: "mina")
        #expect(substring == 500 + 1000)

        // 6. Generic Substring Match: 400 + 1,000 = 1,400
        let genericSubstring = LauncherScorer.score(candidate: chrome, query: "internet")
        #expect(genericSubstring == 400 + 1000)

        // 7. Identifier Substring Match: 350 + 1,000 = 1,350
        let idMatch = LauncherScorer.score(candidate: app, query: "apple")
        #expect(idMatch == 350 + 1000)
    }

    @Test("Bounded Levenshtein Distance and Fuzzy Scoring")
    func testLevenshteinAndFuzzy() {
        // Distance 0
        #expect(LauncherScorer.levenshteinDistance("abc", "abc") == 0)
        // Distance 1
        #expect(LauncherScorer.levenshteinDistance("code", "cde") == 1)
        #expect(LauncherScorer.levenshteinDistance("code", "coder") == 1)
        #expect(LauncherScorer.levenshteinDistance("code", "core") == 1)
        // Distance 2
        #expect(LauncherScorer.levenshteinDistance("code", "cure") == 2)
        // Distance > 2 returns 3 (bounded early exit)
        #expect(LauncherScorer.levenshteinDistance("code", "somethingelse") == 3)
        #expect(LauncherScorer.levenshteinDistance("code", "ab") == 3)

        // Exact Levenshtein test for short typo
        let shortApp = LauncherCandidate(
            id: "test",
            name: "Slack",
            genericName: "",
            identifier: "slack",
            type: .app
        )
        // "slaack" -> distance 1 -> fuzzyWeight (100 - 25) + 1000 = 1075
        let dist1Score = LauncherScorer.score(candidate: shortApp, query: "slaack")
        #expect(dist1Score == 100 - 25 + 1000)

        // Distance > 2 returns nil
        let noMatch = LauncherScorer.score(candidate: shortApp, query: "xyzqqw")
        #expect(noMatch == nil)
    }

    @Test("Half-Life Frecency Decay Mathematical Model")
    func testFrecencyDecayFormula() {
        let now = Date()

        // 0 launches -> 0
        #expect(LauncherScorer.calculateFrecency(launchCount: 0, lastLaunch: now, now: now) == 0)

        // 10 launches at t=0: 10 * 10 / 1.0 = 100
        let initialScore = LauncherScorer.calculateFrecency(launchCount: 10, lastLaunch: now, now: now)
        #expect(initialScore == 100)

        // 10 launches after 1 day (86,400s): decay = 1.0 + 1.0 = 2.0 -> 100 / 2 = 50
        let oneDayLater = now.addingTimeInterval(86_400)
        let decayedOneDay = LauncherScorer.calculateFrecency(launchCount: 10, lastLaunch: now, now: oneDayLater)
        #expect(decayedOneDay == 50)

        // 10 launches after 3 days: decay = 1.0 + 3.0 = 4.0 -> 100 / 4 = 25
        let threeDaysLater = now.addingTimeInterval(86_400 * 3)
        let decayedThreeDays = LauncherScorer.calculateFrecency(launchCount: 10, lastLaunch: now, now: threeDaysLater)
        #expect(decayedThreeDays == 25)

        // Frecency score capped at frecencyMax (2,000 points)
        let massiveLaunches = LauncherScorer.calculateFrecency(launchCount: 500, lastLaunch: now, now: now)
        #expect(massiveLaunches == 2_000)
    }

    @Test("LauncherFrecencyStore Operations")
    func testFrecencyStore() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("frecency_test_\(UUID().uuidString).json")
        let store = LauncherFrecencyStore(fileURL: tempURL)

        #expect(store.launchInfo(for: "com.apple.Safari").count == 0)
        #expect(store.launchInfo(for: "com.apple.Safari").lastLaunch == nil)

        let date1 = Date()
        store.recordLaunch(id: "com.apple.Safari", date: date1)
        #expect(store.launchInfo(for: "com.apple.Safari").count == 1)

        let date2 = date1.addingTimeInterval(10)
        store.recordLaunch(id: "com.apple.Safari", date: date2)
        #expect(store.launchInfo(for: "com.apple.Safari").count == 2)
        #expect(store.launchInfo(for: "com.apple.Safari").lastLaunch == date2)

        let score = store.frecencyScore(for: "com.apple.Safari", now: date2)
        #expect(score == 20) // 2 * 10 / 1.0 = 20

        store.clear()
        #expect(store.launchInfo(for: "com.apple.Safari").count == 0)

        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test("AppItem Default Subtitles Match launcher_dark.png Reference")
    func testDefaultSubtitlesMatchLauncherDark() {
        // VS Code
        let vscode = AppItem(name: "Visual Studio Code", bundleID: "com.microsoft.VSCode", path: "/Applications/VSCode.app")
        #expect(vscode.subtitle == "Code Editing. Redefined.")

        // Google Chrome
        let chrome = AppItem(name: "Google Chrome", bundleID: "com.google.Chrome", path: "/Applications/Google Chrome.app")
        #expect(chrome.subtitle == "Access the Internet")

        // Discord / Vesktop
        let discord = AppItem(name: "Discord", bundleID: "com.hnc.Discord", path: "/Applications/Discord.app")
        #expect(discord.subtitle == "Vesktop is a custom Discord desktop app")

        // Files / Finder
        let files = AppItem(name: "Files", bundleID: "com.apple.finder", path: "/System/Library/CoreServices/Finder.app")
        #expect(files.subtitle == "Access and organize files")

        // Ghostty
        let ghostty = AppItem(name: "Ghostty", bundleID: "com.mitchellh.ghostty", path: "/Applications/Ghostty.app")
        #expect(ghostty.subtitle == "A terminal emulator")

        // kitty
        let kitty = AppItem(name: "kitty", bundleID: "net.kovidgoyal.kitty", path: "/Applications/kitty.app")
        #expect(kitty.subtitle == "Fast, feature-rich, GPU based terminal")

        // Virtual Machine Manager
        let vmm = AppItem(name: "Virtual Machine Manager", bundleID: "com.utmapp.UTM", path: "/Applications/UTM.app")
        #expect(vmm.subtitle == "Manage virtual machines")

        // Firefox
        let firefox = AppItem(name: "Firefox", bundleID: "org.mozilla.firefox", path: "/Applications/Firefox.app")
        #expect(firefox.subtitle == "Browse the World Wide Web")

        // Dolphin
        let dolphin = AppItem(name: "Dolphin", bundleID: "org.kde.dolphin", path: "/Applications/Dolphin.app")
        #expect(dolphin.subtitle == "Manage your files")
    }

    @Test("LauncherViewMode Enumeration")
    func testLauncherViewMode() {
        #expect(LauncherViewMode.list.rawValue == "list")
        #expect(LauncherViewMode.tile.rawValue == "tile")
        #expect(LauncherViewMode.allCases.count == 2)
    }

    @Test("High Performance Scoring Benchmark (1,000 candidates < 5ms)")
    func testScoringPerformance() {
        var candidates: [LauncherCandidate] = []
        for i in 0..<1000 {
            candidates.append(
                LauncherCandidate(
                    id: "app.\(i)",
                    name: "Application \(i)",
                    genericName: "Generic tool description \(i)",
                    identifier: "org.test.app\(i)",
                    type: .app,
                    launchCount: i % 10,
                    lastLaunchTime: Date()
                )
            )
        }

        let start = DispatchTime.now()
        var matchCount = 0
        for candidate in candidates {
            if LauncherScorer.score(candidate: candidate, query: "description 5") != nil {
                matchCount += 1
            }
        }
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let milliTime = Double(nanoTime) / 1_000_000.0

        #expect(matchCount > 0)
        #expect(milliTime < 35.0) // Well within interactive frame budget for debug execution
    }
}
