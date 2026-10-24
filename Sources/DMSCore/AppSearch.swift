import Foundation

/// Application item represented in the launcher and taskbar.
public struct AppItem: Sendable, Identifiable, Equatable, Hashable, Codable {
    public let id: String // bundleID or path
    public let name: String
    public let bundleID: String
    public let path: String
    public let subtitle: String
    public let category: String
    public let isRunning: Bool
    public let isHidden: Bool
    public let isPinned: Bool
    public let launchCount: Int
    public let lastLaunchedAt: Date?

    public init(
        id: String? = nil,
        name: String,
        bundleID: String,
        path: String,
        subtitle: String = "",
        category: String = "",
        isRunning: Bool = false,
        isHidden: Bool = false,
        isPinned: Bool = false,
        launchCount: Int = 0,
        lastLaunchedAt: Date? = nil
    ) {
        self.id = id ?? bundleID
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.subtitle = subtitle.isEmpty ? AppItem.defaultSubtitle(name: name, bundleID: bundleID) : subtitle
        self.category = category
        self.isRunning = isRunning
        self.isHidden = isHidden
        self.isPinned = isPinned
        self.launchCount = launchCount
        self.lastLaunchedAt = lastLaunchedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, bundleID, path, subtitle, category, isRunning, isHidden, isPinned, launchCount, lastLaunchedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.bundleID = try container.decode(String.self, forKey: .bundleID)
        self.path = try container.decode(String.self, forKey: .path)
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.isRunning = try container.decodeIfPresent(Bool.self, forKey: .isRunning) ?? false
        self.isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.launchCount = try container.decodeIfPresent(Int.self, forKey: .launchCount) ?? 0
        self.lastLaunchedAt = try container.decodeIfPresent(Date.self, forKey: .lastLaunchedAt)
    }

    /// Resolves high-fidelity application subtitles and comments matching `launcher_dark.png`
    /// and standard desktop metadata.
    public static func defaultSubtitle(name: String, bundleID: String) -> String {
        let n = name.lowercased()
        let b = bundleID.lowercased()

        if n.contains("visual studio code") || n == "code" || b.contains("vscode") {
            return "Code Editing. Redefined."
        }
        if n.contains("google chrome") || n == "chrome" || b.contains("chrome") {
            return "Access the Internet"
        }
        if n.contains("vesktop") || n.contains("discord") || b.contains("discord") {
            return "Vesktop is a custom Discord desktop app"
        }
        if n == "files" || n == "finder" || b.contains("finder") {
            return "Access and organize files"
        }
        if n.contains("ghostty") || b.contains("ghostty") {
            return "A terminal emulator"
        }
        if n.contains("kitty") || b.contains("kitty") {
            return "Fast, feature-rich, GPU based terminal"
        }
        if n.contains("virtual machine manager") || n.contains("utm") || b.contains("utm") {
            return "Manage virtual machines"
        }
        if n.contains("firefox") || b.contains("firefox") {
            return "Browse the World Wide Web"
        }
        if n.contains("dolphin") {
            return "Manage your files"
        }
        if n.contains("safari") || b.contains("safari") {
            return "Browse the World Wide Web"
        }
        if n.contains("terminal") || n.contains("iterm") || b.contains("terminal") || b.contains("iterm") {
            return "A terminal emulator"
        }
        if n.contains("settings") || n.contains("preferences") || b.contains("systempreferences") {
            return "System Configuration & Preferences"
        }
        if n.contains("notes") || b.contains("notes") {
            return "Notes and scratchpad"
        }
        if n.contains("music") || n.contains("spotify") || b.contains("spotify") || b.contains("music") {
            return "Play and organize music"
        }
        if n.contains("mail") || b.contains("mail") {
            return "Read, write, and organize emails"
        }
        if n.contains("calculator") || b.contains("calculator") {
            return "Perform calculations"
        }
        if n.contains("activity monitor") || b.contains("activitymonitor") {
            return "Monitor system resources and processes"
        }
        if n.contains("slack") || b.contains("slack") {
            return "Team communication and collaboration"
        }
        if n.contains("docker") || b.contains("docker") {
            return "Container runtime and management"
        }
        if n.contains("xcode") || b.contains("xcode") {
            return "Apple developer tools and IDE"
        }
        if n.contains("sublime") || b.contains("sublime") {
            return "Sophisticated text editor for code"
        }
        if n.contains("textedit") || b.contains("textedit") {
            return "Simple text and document editor"
        }
        return "Application"
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

    /// Evaluates mathematical expressions typed into the search bar using a pure-Swift
    /// recursive-descent parser that never throws Objective-C NSExceptions on malformed input.
    public static func evaluateMath(query: String) -> MathResult? {
        var clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return nil }

        // Percentage syntax: "15% of 80" -> "0.15 * 80"
        if let percentRange = clean.range(of: "% of ", options: .caseInsensitive) {
            let numPart = clean[..<percentRange.lowerBound].trimmingCharacters(in: .whitespaces)
            let basePart = clean[percentRange.upperBound...].trimmingCharacters(in: .whitespaces)
            if let num = Double(numPart), let base = Double(basePart) {
                let ans = (num / 100.0) * base
                if ans.isFinite {
                    return MathResult(expression: query, result: formatNumber(ans))
                }
            }
            return nil
        }

        // Normalize Unicode operators
        clean = clean.replacingOccurrences(of: "×", with: "*")
        clean = clean.replacingOccurrences(of: "÷", with: "/")
        clean = clean.replacingOccurrences(of: "**", with: "^")

        // Reject shell commands or paths like "rm -rf /" or "/usr/bin"
        let lower = clean.lowercased()
        if lower.hasPrefix("/") || lower.hasPrefix("~") {
            return nil
        }

        var parser = SafeMathParser(clean)
        guard let value = parser.evaluate(),
              parser.didUseOperatorOrFunction,
              value.isFinite else {
            return nil
        }
        return MathResult(expression: clean, result: formatNumber(value))
    }

    private struct SafeMathParser {
        private let chars: [Character]
        private var index: Int = 0
        var didUseOperatorOrFunction: Bool = false

        init(_ input: String) {
            self.chars = Array(input)
        }

        mutating func evaluate() -> Double? {
            skipWhitespace()
            guard index < chars.count else { return nil }
            // Must not start with binary-only operators
            if let first = current, "*/%^)".contains(first) {
                return nil
            }
            guard let val = parseExpression(), val.isFinite else { return nil }
            skipWhitespace()
            guard index == chars.count else { return nil }
            return val
        }

        private var current: Character? {
            index < chars.count ? chars[index] : nil
        }

        private mutating func skipWhitespace() {
            while let c = current, c.isWhitespace {
                index += 1
            }
        }

        // Expression := Term (( '+' | '-' ) Term)*
        private mutating func parseExpression() -> Double? {
            guard var lhs = parseTerm() else { return nil }
            while true {
                skipWhitespace()
                guard let op = current, op == "+" || op == "-" else { break }
                index += 1
                skipWhitespace()
                // Reject consecutive +/- or operator right after +/-
                if let next = current, "+-*/%^)".contains(next) {
                    return nil
                }
                guard let rhs = parseTerm() else { return nil }
                didUseOperatorOrFunction = true
                lhs = (op == "+") ? (lhs + rhs) : (lhs - rhs)
                if !lhs.isFinite { return nil }
            }
            return lhs
        }

        // Term := Power (( '*' | '/' | '%' ) Power)*
        private mutating func parseTerm() -> Double? {
            guard var lhs = parsePower() else { return nil }
            while true {
                skipWhitespace()
                guard let op = current, op == "*" || op == "/" || op == "%" else { break }
                index += 1
                skipWhitespace()
                if let next = current, "*/%^)".contains(next) {
                    return nil
                }
                guard let rhs = parsePower() else { return nil }
                didUseOperatorOrFunction = true
                if op == "*" {
                    lhs *= rhs
                } else if op == "/" {
                    guard rhs != 0 else { return nil }
                    lhs /= rhs
                } else {
                    guard rhs != 0 else { return nil }
                    lhs = lhs.truncatingRemainder(dividingBy: rhs)
                }
                if !lhs.isFinite { return nil }
            }
            return lhs
        }

        // Power := Unary ( '^' Power )?
        private mutating func parsePower() -> Double? {
            guard let base = parseUnary() else { return nil }
            skipWhitespace()
            if current == "^" {
                index += 1
                skipWhitespace()
                if let next = current, "*/%^)".contains(next) {
                    return nil
                }
                guard let exp = parsePower() else { return nil }
                didUseOperatorOrFunction = true
                let res = Foundation.pow(base, exp)
                return res.isFinite ? res : nil
            }
            return base
        }

        // Unary := ('+' | '-')? Primary
        private mutating func parseUnary() -> Double? {
            skipWhitespace()
            if let c = current, c == "+" || c == "-" {
                index += 1
                skipWhitespace()
                // Do not allow chained unary operators like "++5" or "--5"
                if let next = current, "+-*/%^)".contains(next) {
                    return nil
                }
                guard let val = parsePrimary() else { return nil }
                return (c == "-") ? -val : val
            }
            return parsePrimary()
        }

        // Primary := '(' Expression ')' | FunctionOrConstant | Number
        private mutating func parsePrimary() -> Double? {
            skipWhitespace()
            guard let c = current else { return nil }

            if c == "(" {
                index += 1
                skipWhitespace()
                if current == ")" { return nil } // reject empty "()"
                guard let val = parseExpression() else { return nil }
                skipWhitespace()
                guard current == ")" else { return nil }
                index += 1
                return val
            }

            if c.isLetter {
                return parseIdentifier()
            }

            if c.isNumber || c == "." {
                return parseNumber()
            }

            return nil
        }

        private mutating func parseIdentifier() -> Double? {
            let start = index
            while let c = current, c.isLetter || c.isNumber {
                index += 1
            }
            let ident = String(chars[start..<index]).lowercased()
            skipWhitespace()

            if ident == "pi" {
                return Double.pi
            } else if ident == "e" {
                return M_E
            }

            // Functions require '(' argument ')'
            guard current == "(" else { return nil }
            index += 1
            skipWhitespace()
            if current == ")" { return nil }
            guard let arg = parseExpression() else { return nil }
            skipWhitespace()
            guard current == ")" else { return nil }
            index += 1

            didUseOperatorOrFunction = true
            let result: Double
            switch ident {
            case "sqrt":
                guard arg >= 0 else { return nil }
                result = Foundation.sqrt(arg)
            case "sin":
                result = Foundation.sin(arg)
            case "cos":
                result = Foundation.cos(arg)
            case "tan":
                result = Foundation.tan(arg)
            case "abs":
                result = Swift.abs(arg)
            case "log", "log10":
                guard arg > 0 else { return nil }
                result = Foundation.log10(arg)
            case "ln":
                guard arg > 0 else { return nil }
                result = Foundation.log(arg)
            case "round":
                result = Foundation.round(arg)
            case "floor":
                result = Foundation.floor(arg)
            case "ceil":
                result = Foundation.ceil(arg)
            default:
                return nil
            }
            return result.isFinite ? result : nil
        }

        private mutating func parseNumber() -> Double? {
            // Check hex literal 0x...
            if current == "0", index + 1 < chars.count, (chars[index + 1] == "x" || chars[index + 1] == "X") {
                index += 2
                let hexStart = index
                while let c = current, c.isHexDigit {
                    index += 1
                }
                guard index > hexStart else { return nil }
                let hexStr = String(chars[hexStart..<index])
                guard let intVal = UInt64(hexStr, radix: 16) else { return nil }
                return Double(intVal)
            }

            let start = index
            var hasDot = false
            while let c = current {
                if c.isNumber {
                    index += 1
                } else if c == "." {
                    if hasDot { return nil }
                    hasDot = true
                    index += 1
                } else {
                    break
                }
            }
            guard index > start else { return nil }
            let numStr = String(chars[start..<index])
            guard numStr != "." else { return nil }
            return Double(numStr)
        }
    }

    /// Determines whether the input query is requesting a file search.
    /// Prefixes: "file:", "files:", "f:", or paths starting with "/" or "~".
    public static func isFileSearchQuery(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("file:") ||
               trimmed.hasPrefix("files:") ||
               trimmed.hasPrefix("f:") ||
               trimmed.hasPrefix("/") ||
               trimmed.hasPrefix("~")
    }

    /// Extracts the file query string from a prefixed or path query.
    /// E.g. "file: document" -> "document", "f: notes" -> "notes", "~/docs" -> "~/docs".
    public static func extractFileQuery(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.hasPrefix("file:") {
            return String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        } else if lower.hasPrefix("files:") {
            return String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else if lower.hasPrefix("f:") {
            return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }

    /// Search for files in user common directories matching query with full fault tolerance and diagnostics.
    public static func searchFilesWithDiagnostics(
        query: String,
        maxResults: Int = 12,
        client: DankSearchClient = .shared
    ) -> DankSearchResponse {
        let clean = extractFileQuery(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else {
            return DankSearchResponse(
                files: [],
                usedFallback: false,
                backendUsed: "none",
                healthState: client.healthState
            )
        }

        // Path direct search: if user entered a specific directory path starting with ~ or /
        if clean.hasPrefix("~") || clean.hasPrefix("/") {
            let expanded = (clean as NSString).expandingTildeInPath
            var isDir: ObjCBool = false
            let fm = FileManager.default
            if fm.fileExists(atPath: expanded, isDirectory: &isDir) {
                if isDir.boolValue {
                    if let items = try? fm.contentsOfDirectory(atPath: expanded) {
                        let files = items.prefix(maxResults).map { name in
                            let fullPath = (expanded as NSString).appendingPathComponent(name)
                            var subIsDir: ObjCBool = false
                            fm.fileExists(atPath: fullPath, isDirectory: &subIsDir)
                            return FileItem(name: name, path: fullPath, isDirectory: subIsDir.boolValue)
                        }
                        return DankSearchResponse(
                            files: files,
                            usedFallback: false,
                            backendUsed: "filesystem",
                            healthState: client.healthState
                        )
                    }
                } else {
                    let name = (expanded as NSString).lastPathComponent
                    return DankSearchResponse(
                        files: [FileItem(name: name, path: expanded, isDirectory: false)],
                        usedFallback: false,
                        backendUsed: "filesystem",
                        healthState: client.healthState
                    )
                }
            }
        }

        return client.searchFiles(query: clean, maxResults: maxResults) { cleanQuery, limit in
            let mdfindResults = runSpotlightSearch(nameQuery: cleanQuery, maxResults: limit, timeout: client.timeout)
            if !mdfindResults.isEmpty {
                return mdfindResults
            }
            return safeShallowSearch(query: cleanQuery, maxResults: limit)
        }
    }

    /// Search for files in user common directories matching query.
    /// Uses `DankSearchClient`, timeout-protected Spotlight `mdfind`, and safe shallow fallback.
    public static func searchFiles(
        query: String,
        maxResults: Int = 12,
        client: DankSearchClient = .shared
    ) -> [FileItem] {
        searchFilesWithDiagnostics(query: query, maxResults: maxResults, client: client).files
    }

    /// Asynchronous non-blocking file search dispatched to a background thread with diagnostics and fallback.
    public static func searchFilesAsync(
        query: String,
        maxResults: Int = 12,
        client: DankSearchClient = .shared
    ) async -> DankSearchResponse {
        await Task.detached(priority: .userInitiated) {
            searchFilesWithDiagnostics(query: query, maxResults: maxResults, client: client)
        }.value
    }

    private static func runSpotlightSearch(nameQuery: String, maxResults: Int, timeout: TimeInterval = 1.5) -> [FileItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let args = [
            "-name", nameQuery,
            "-onlyin", (home as NSString).appendingPathComponent("Documents"),
            "-onlyin", (home as NSString).appendingPathComponent("Downloads"),
            "-onlyin", (home as NSString).appendingPathComponent("Desktop")
        ]

        guard case .success(let output) = SafeProcessRunner.run(
            executablePath: "/usr/bin/mdfind",
            arguments: args,
            timeout: timeout
        ) else {
            return []
        }

        guard let text = String(data: output.stdout, encoding: .utf8) else { return [] }

        let fm = FileManager.default
        var items: [FileItem] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: trimmed, isDirectory: &isDir) {
                let name = (trimmed as NSString).lastPathComponent
                items.append(FileItem(name: name, path: trimmed, isDirectory: isDir.boolValue))
                if items.count >= maxResults {
                    break
                }
            }
        }
        return items
    }

    private static func safeShallowSearch(query: String, maxResults: Int) -> [FileItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let searchDirs = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop")
        ]

        let skipNames: Set<String> = [
            "node_modules", ".build", "build", "DerivedData", "Library", "Caches",
            "Pods", ".git", ".svn", ".Trash", "target", "vendor", ".cache"
        ]

        var results: [FileItem] = []
        let fm = FileManager.default

        for dir in searchDirs {
            guard fm.fileExists(atPath: dir.path) else { continue }
            if let enumerator = fm.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                for case let fileURL as URL in enumerator {
                    let name = fileURL.lastPathComponent
                    if skipNames.contains(name) || enumerator.level > 2 {
                        enumerator.skipDescendants()
                        continue
                    }

                    if name.localizedCaseInsensitiveContains(query) {
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

    private static let sharedDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.numberStyle = .decimal
        return formatter
    }()

    private static let formatterLock = NSLock()

    private static func formatNumber(_ num: Double) -> String {
        if floor(num) == num && abs(num) < 1e12 {
            return String(format: "%.0f", num)
        }
        formatterLock.lock()
        defer { formatterLock.unlock() }
        return sharedDecimalFormatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
}
