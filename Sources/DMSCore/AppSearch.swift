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

/// File search result item.
public struct FileItem: Sendable, Identifiable, Equatable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let sfSymbol: String

    public init(name: String, path: String, isDirectory: Bool) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory

        if isDirectory {
            self.sfSymbol = "folder.fill"
        } else {
            let ext = (path as NSString).pathExtension.lowercased()
            switch ext {
            case "swift", "py", "rs", "go", "js", "ts", "cpp", "c", "h", "html", "css", "json", "sh":
                self.sfSymbol = "chevron.left.forwardslash.chevron.right"
            case "png", "jpg", "jpeg", "webp", "gif", "svg", "heic":
                self.sfSymbol = "photo.fill"
            case "mp3", "m4a", "wav", "flac", "aac":
                self.sfSymbol = "music.note"
            case "mp4", "mov", "mkv", "avi":
                self.sfSymbol = "film.fill"
            case "pdf":
                self.sfSymbol = "doc.richtext.fill"
            case "zip", "tar", "gz", "bz2", "7z", "dmg":
                self.sfSymbol = "archivebox.fill"
            default:
                self.sfSymbol = "doc.text.fill"
            }
        }
    }
}

/// Running window item for launcher window switcher.
public struct WindowItem: Sendable, Identifiable, Equatable {
    public var id: Int { windowID }
    public let windowID: Int
    public let ownerPID: Int32
    public let ownerName: String
    public let title: String

    public init(windowID: Int, ownerPID: Int32, ownerName: String, title: String) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.title = title
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

/// Emoji search item.
public struct EmojiItem: Sendable, Identifiable, Equatable {
    public var id: String { emoji }
    public let emoji: String
    public let name: String
    public let keywords: [String]

    public init(emoji: String, name: String, keywords: [String] = []) {
        self.emoji = emoji
        self.name = name
        self.keywords = keywords
    }
}

/// App searching, fuzzy matching, files, windows, and calculator evaluations for DLauncherV2.
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
        let exprString = clean.replacingOccurrences(of: "^", with: "**")

        let expr = NSExpression(format: exprString)
        if let val = expr.expressionValue(with: nil, context: nil) as? NSNumber {
            let doubleVal = val.doubleValue
            if !doubleVal.isNaN && !doubleVal.isInfinite {
                return MathResult(expression: clean, result: formatNumber(doubleVal))
            }
        }

        return nil
    }

    /// Search for files in user common directories matching query.
    public static func searchFiles(query: String, maxResults: Int = 12) -> [FileItem] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard clean.count >= 2 else { return [] }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let searchDirs = [
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Projects"),
            home.appendingPathComponent("repos")
        ]

        var results: [FileItem] = []
        let fm = FileManager.default

        for dir in searchDirs {
            guard fm.fileExists(atPath: dir.path) else { continue }
            if let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                for case let fileURL as URL in enumerator {
                    let name = fileURL.lastPathComponent
                    if name.lowercased().contains(clean) {
                        let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                        results.append(FileItem(name: name, path: fileURL.path, isDirectory: isDir))
                        if results.count >= maxResults {
                            return results
                        }
                    }
                }
            }
        }
        return results
    }

    /// Common emojis dataset for quick emoji lookup.
    public static let commonEmojis: [EmojiItem] = [
        EmojiItem(emoji: "🚀", name: "Rocket", keywords: ["space", "launch", "fast", "speed"]),
        EmojiItem(emoji: "🔥", name: "Fire", keywords: ["lit", "hot", "flame", "cool"]),
        EmojiItem(emoji: "✨", name: "Sparkles", keywords: ["magic", "star", "clean", "shine"]),
        EmojiItem(emoji: "💡", name: "Light Bulb", keywords: ["idea", "smart", "bright", "think"]),
        EmojiItem(emoji: "⚡️", name: "Zap", keywords: ["fast", "electricity", "thunder", "power"]),
        EmojiItem(emoji: "🎉", name: "Party Popper", keywords: ["celebrate", "tada", "fun"]),
        EmojiItem(emoji: "👍", name: "Thumbs Up", keywords: ["ok", "good", "agree", "yes"]),
        EmojiItem(emoji: "❤️", name: "Red Heart", keywords: ["love", "heart", "like"]),
        EmojiItem(emoji: "💻", name: "Laptop", keywords: ["computer", "code", "tech", "mac"]),
        EmojiItem(emoji: "☕️", name: "Coffee", keywords: ["drink", "cafe", "espresso", "morning"]),
        EmojiItem(emoji: "🛠️", name: "Hammer and Wrench", keywords: ["tools", "build", "dev", "fix"]),
        EmojiItem(emoji: "📦", name: "Package", keywords: ["box", "delivery", "bundle", "repo"]),
        EmojiItem(emoji: "🔍", name: "Magnifying Glass", keywords: ["search", "find", "look"]),
        EmojiItem(emoji: "🎨", name: "Artist Palette", keywords: ["art", "theme", "design", "color"]),
        EmojiItem(emoji: "⏱️", name: "Stopwatch", keywords: ["time", "clock", "timer", "fast"]),
        EmojiItem(emoji: "✅", name: "Check Mark", keywords: ["done", "yes", "pass", "ok"]),
        EmojiItem(emoji: "❌", name: "Cross Mark", keywords: ["no", "fail", "bad", "delete"]),
        EmojiItem(emoji: "⚠️", name: "Warning", keywords: ["alert", "caution", "danger"]),
        EmojiItem(emoji: "🌟", name: "Glowing Star", keywords: ["fav", "star", "bright"]),
        EmojiItem(emoji: "🌙", name: "Crescent Moon", keywords: ["night", "dark", "sleep"]),
        EmojiItem(emoji: "☀️", name: "Sun", keywords: ["light", "day", "warm", "weather"]),
        EmojiItem(emoji: "🌧️", name: "Cloud with Rain", keywords: ["rain", "storm", "weather"]),
        EmojiItem(emoji: "❄️", name: "Snowflake", keywords: ["cold", "winter", "ice"])
    ]

    /// Searches emojis by name or keyword.
    public static func searchEmojis(query: String) -> [EmojiItem] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return Array(commonEmojis.prefix(12)) }

        return commonEmojis.filter { item in
            item.name.lowercased().contains(clean) ||
            item.keywords.contains { $0.lowercased().contains(clean) }
        }
    }

    /// Generates web search URL for configured provider.
    public static func webSearchURL(query: String, provider: String = "google") -> URL? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        switch provider.lowercased() {
        case "duckduckgo", "ddg":
            return URL(string: "https://duckduckgo.com/?q=\(encoded)")
        case "bing":
            return URL(string: "https://www.bing.com/search?q=\(encoded)")
        case "kagi":
            return URL(string: "https://kagi.com/search?q=\(encoded)")
        default:
            return URL(string: "https://www.google.com/search?q=\(encoded)")
        }
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
