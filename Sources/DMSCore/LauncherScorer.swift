import Foundation

/// View mode for DLauncherV2 (matching LAUNCH-002 and launcher_dark.png).
public enum LauncherViewMode: String, Sendable, Codable, CaseIterable, Identifiable {
    case list
    case tile

    public var id: String { rawValue }
}

/// Candidate types for DLauncherV2 scoring and ranking.
/// Type bonuses match `docs/spec/18-launcher.md` Section 2.
public enum LauncherCandidateType: String, Sendable, Codable, CaseIterable, Equatable {
    case app
    case plugin
    case setting
    case clipboard
    case file
    case action

    public var typeBonus: Int {
        switch self {
        case .app: return 1000
        case .plugin: return 900
        case .setting: return 850
        case .clipboard: return 825
        case .file: return 800
        case .action: return 600
        }
    }
}

/// A candidate item submitted to `LauncherScorer`.
public struct LauncherCandidate: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let genericName: String
    public let identifier: String
    public let type: LauncherCandidateType
    public let launchCount: Int
    public let lastLaunchTime: Date?

    public init(
        id: String,
        name: String,
        genericName: String = "",
        identifier: String = "",
        type: LauncherCandidateType = .app,
        launchCount: Int = 0,
        lastLaunchTime: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.genericName = genericName
        self.identifier = identifier
        self.type = type
        self.launchCount = launchCount
        self.lastLaunchTime = lastLaunchTime
    }

    public init(app: AppItem) {
        self.id = app.id
        self.name = app.name
        self.genericName = app.subtitle
        self.identifier = app.bundleID
        self.type = .app
        self.launchCount = app.launchCount
        self.lastLaunchTime = app.lastLaunchedAt
    }
}

/// High-performance mathematical scoring engine for DLauncherV2.
/// Implements `Scorer.js` weights, bounded Levenshtein distance, and half-life frecency decay
/// as specified in `docs/spec/18-launcher.md`.
public enum LauncherScorer {
    // Weights from spec 18-launcher.md Section 2
    public static let exactMatchWeight = 10_000
    public static let prefixMatchWeight = 5_000
    public static let wordBoundaryWeight = 3_000
    public static let genericPrefixWeight = 800
    public static let substringWeight = 500
    public static let genericWeight = 400
    public static let idWeight = 350
    public static let fuzzyWeight = 100
    public static let frecencyMax = 2_000

    /// Half-life frecency formula:
    /// frecency = (launchCount * 10) / (1.0 + (now - lastLaunch) / 86400000 ms), capped at 2,000 points.
    public static func calculateFrecency(
        launchCount: Int,
        lastLaunch: Date?,
        now: Date = Date()
    ) -> Int {
        guard launchCount > 0, let lastLaunch = lastLaunch else { return 0 }
        let elapsedMs = max(0.0, now.timeIntervalSince(lastLaunch) * 1000.0)
        let decay = 1.0 + (elapsedMs / 86_400_000.0)
        let score = (Double(launchCount) * 10.0) / decay
        return min(frecencyMax, max(0, Int(score.rounded())))
    }

    /// Fast, bounded Levenshtein distance calculation.
    /// If the edit distance is strictly greater than 2, returns 3 immediately without computing the full matrix.
    public static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let count1 = s1.count
        let count2 = s2.count
        if abs(count1 - count2) > 2 { return 3 }
        if s1 == s2 { return 0 }
        if count1 == 0 { return min(3, count2) }
        if count2 == 0 { return min(3, count1) }

        let arr1 = Array(s1.utf16)
        let arr2 = Array(s2.utf16)

        var prevRow = Array(0...arr2.count)
        var currRow = [Int](repeating: 0, count: arr2.count + 1)

        for i in 1...arr1.count {
            currRow[0] = i
            var minInRow = currRow[0]
            for j in 1...arr2.count {
                let cost = arr1[i - 1] == arr2[j - 1] ? 0 : 1
                currRow[j] = min(
                    prevRow[j] + 1,       // deletion
                    currRow[j - 1] + 1,   // insertion
                    prevRow[j - 1] + cost // substitution
                )
                minInRow = min(minInRow, currRow[j])
            }
            if minInRow > 2 { return 3 } // Early exit
            prevRow = currRow
        }

        return prevRow[arr2.count]
    }

    /// Checks if query matches at a word boundary (e.g. acronym initials or start of any component word).
    public static func isWordBoundaryMatch(query: String, target: String) -> Bool {
        let words = target.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let initials = String(words.compactMap { $0.first })
        if initials.hasPrefix(query) {
            return true
        }
        for word in words {
            if word.hasPrefix(query) {
                return true
            }
        }
        return false
    }

    /// Scores a candidate against a query string according to spec 18-launcher.md.
    /// Returns nil if there is no match.
    public static func score(
        candidate: LauncherCandidate,
        query: String,
        now: Date = Date()
    ) -> Int? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let frecency = calculateFrecency(
            launchCount: candidate.launchCount,
            lastLaunch: candidate.lastLaunchTime,
            now: now
        )
        let bonus = candidate.type.typeBonus

        if q.isEmpty {
            // When query is empty, candidates rank by frecency + type bonus
            return frecency + bonus
        }

        let name = candidate.name.lowercased()
        let generic = candidate.genericName.lowercased()
        let id = candidate.identifier.lowercased()

        var matchScore: Int? = nil

        if name == q {
            matchScore = exactMatchWeight
        } else if name.hasPrefix(q) {
            matchScore = prefixMatchWeight
        } else if isWordBoundaryMatch(query: q, target: name) {
            matchScore = wordBoundaryWeight
        } else if !generic.isEmpty && generic.hasPrefix(q) {
            matchScore = genericPrefixWeight
        } else if name.contains(q) {
            matchScore = substringWeight
        } else if !generic.isEmpty && generic.contains(q) {
            matchScore = genericWeight
        } else if !id.isEmpty && id.contains(q) {
            matchScore = idWeight
        } else {
            // Fuzzy match (Levenshtein distance <= 2)
            let dist = levenshteinDistance(q, name)
            if dist <= 2 {
                matchScore = fuzzyWeight - (dist * 25)
            } else {
                return nil
            }
        }

        guard let baseScore = matchScore else { return nil }
        return baseScore + bonus + frecency
    }
}
