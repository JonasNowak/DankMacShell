import Foundation

/// Application item represented in the launcher and taskbar.
public struct AppItem: Sendable, Identifiable, Equatable, Hashable {
    public let id: String // bundleID or path
    public let name: String
    public let bundleID: String
    public let path: String
    public let isRunning: Bool
    public let isPinned: Bool

    public init(
        id: String? = nil,
        name: String,
        bundleID: String,
        path: String,
        isRunning: Bool = false,
        isPinned: Bool = false
    ) {
        self.id = id ?? bundleID
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.isRunning = isRunning
        self.isPinned = isPinned
    }
}

/// Search result item containing matching score.
public struct SearchResult: Sendable, Identifiable, Equatable {
    public var id: String { app.id }
    public let app: AppItem
    public let score: Int

    public init(app: AppItem, score: Int) {
        self.app = app
        self.score = score
    }
}

/// Quick math evaluator result.
public struct MathResult: Sendable, Equatable {
    public let expression: String
    public let result: String

    public init(expression: String, result: String) {
        self.expression = expression
        self.result = result
    }
}

/// App searching, fuzzy matching, and calculator evaluations for DLauncherV2.
public enum AppSearch {

    /// Scores an application against a search query.
    public static func score(app: AppItem, query: String) -> Int? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return 0
        }
        let target = app.name.lowercased()
        let idTarget = app.bundleID.lowercased()

        // Exact match
        if target == q {
            return 1000
        }

        // Prefix match
        if target.hasPrefix(q) {
            return 800 - (target.count - q.count)
        }

        // Word boundary match (e.g. "am" -> "Activity Monitor")
        let words = target.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let initials = String(words.compactMap { $0.first })
        if initials.hasPrefix(q) {
            return 600
        }

        // Substring match
        if let range = target.range(of: q) {
            let dist = target.distance(from: target.startIndex, to: range.lowerBound)
            return 400 - dist
        }

        // Bundle ID match
        if idTarget.contains(q) {
            return 200
        }

        // Fuzzy subsequence match
        if let fuzzyScore = fuzzySubsequence(query: q, target: target) {
            return fuzzyScore
        }

        return nil
    }

    private static func fuzzySubsequence(query: String, target: String) -> Int? {
        var qIdx = query.startIndex
        var tIdx = target.startIndex
        var matches = 0

        while qIdx < query.endIndex && tIdx < target.endIndex {
            if query[qIdx] == target[tIdx] {
                matches += 1
                qIdx = query.index(after: qIdx)
            }
            tIdx = target.index(after: tIdx)
        }

        if qIdx == query.endIndex {
            return max(10, 100 - (target.count - matches))
        }
        return nil
    }

    /// Evaluates mathematical expressions typed into the search bar.
    public static func evaluateMath(query: String) -> MathResult? {
        var clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return nil }

        // Percentage syntax: "15% of 80" -> "0.15 * 80"
        if let percentRange = clean.range(of: "% of ", options: .caseInsensitive) {
            let numPart = clean[..<percentRange.lowerBound].trimmingCharacters(in: .whitespaces)
            let basePart = clean[percentRange.upperBound...].trimmingCharacters(in: .whitespaces)
            if let num = Double(numPart), let base = Double(basePart) {
                let ans = (num / 100.0) * base
                return MathResult(expression: query, result: formatNumber(ans))
            }
        }

        // Normalize basic operators
        clean = clean.replacingOccurrences(of: "×", with: "*")
        clean = clean.replacingOccurrences(of: "÷", with: "/")

        // Check if query contains any math operator
        let mathChars = CharacterSet(charactersIn: "+-*/%^")
        guard clean.unicodeScalars.contains(where: { mathChars.contains($0) }) else {
            return nil
        }

        // Must not contain letters except sqrt, sin, cos, tan, pi, e
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/^%() ")
        let cleanFiltered = clean.components(separatedBy: allowed).joined()
        if !cleanFiltered.isEmpty {
            return nil
        }

        // Parse with NSExpression
        var exprString = clean.replacingOccurrences(of: "^", with: "**")
        // Basic protection: convert 5**2 to pow function or NSExpression compatible
        exprString = exprString.replacingOccurrences(of: "**", with: "**")

        let expr = NSExpression(format: exprString)
        if let val = expr.expressionValue(with: nil, context: nil) as? NSNumber {
            let doubleVal = val.doubleValue
            if !doubleVal.isNaN && !doubleVal.isInfinite {
                return MathResult(expression: clean, result: formatNumber(doubleVal))
            }
        }

        return nil
    }

    private static func formatNumber(_ num: Double) -> String {
        if floor(num) == num && abs(num) < 1e12 {
            return String(format: "%.0f", num)
        }
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
}
