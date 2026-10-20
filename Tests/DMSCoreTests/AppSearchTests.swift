import Testing
import Foundation
@testable import DMSCore

@Suite("AppSearch and Launcher Logic Tests")
struct AppSearchTests {

    @Test("App Matching Scoring Hierarchy")
    func testScoringHierarchy() {
        let terminal = AppItem(
            name: "Terminal",
            bundleID: "com.apple.Terminal",
            path: "/System/Applications/Utilities/Terminal.app"
        )
        let chrome = AppItem(
            name: "Google Chrome",
            bundleID: "com.google.Chrome",
            path: "/Applications/Google Chrome.app"
        )

        // 1. Exact match (score = 1000)
        let exact = AppSearch.score(app: terminal, query: "terminal")
        #expect(exact == 1000)

        // Case insensitivity & whitespace trimming
        let exactTrimmed = AppSearch.score(app: terminal, query: "  TeRmInAl  ")
        #expect(exactTrimmed == 1000)

        // 2. Prefix match (score = 800 - (target.count - query.count))
        let prefix = AppSearch.score(app: terminal, query: "term")
        #expect(prefix != nil)
        #expect(prefix! == 800 - (8 - 4)) // 796

        // 3. Word boundary acronym initials (score = 600)
        let acronym = AppSearch.score(app: chrome, query: "gc")
        #expect(acronym == 600)

        // 4. Substring match (score = 400 - distance)
        let substring = AppSearch.score(app: terminal, query: "mina")
        #expect(substring != nil)
        #expect(substring! < 400 && substring! >= 390)

        // 5. Bundle ID match (score = 200)
        let bundleMatch = AppSearch.score(app: chrome, query: "google")
        #expect(bundleMatch != nil)

        // 6. Fuzzy subsequence (e.g. "trmnl" in "Terminal")
        let fuzzy = AppSearch.score(app: terminal, query: "trmnl")
        #expect(fuzzy != nil)
        #expect(fuzzy! > 0 && fuzzy! < 200)

        // 7. Non-match returns nil
        let noMatch = AppSearch.score(app: terminal, query: "firefox")
        #expect(noMatch == nil)

        // 8. Empty or whitespace query returns 0
        let emptyQuery = AppSearch.score(app: terminal, query: "   ")
        #expect(emptyQuery == 0)
    }

    @Test("Mathematical Expressions and Operators")
    func testMathEvaluation() {
        // Standard arithmetic
        #expect(AppSearch.evaluateMath(query: "3 + 7")?.result == "10")
        #expect(AppSearch.evaluateMath(query: "50 - 18")?.result == "32")
        #expect(AppSearch.evaluateMath(query: "6 * 9")?.result == "54")
        #expect(AppSearch.evaluateMath(query: "100 / 4")?.result == "25")

        // Unicode math symbols: × and ÷
        #expect(AppSearch.evaluateMath(query: "8 × 8")?.result == "64")
        #expect(AppSearch.evaluateMath(query: "81 ÷ 9")?.result == "9")

        // Exponentiation ^
        #expect(AppSearch.evaluateMath(query: "2 ^ 8")?.result == "256")

        // Parentheses and precedence
        #expect(AppSearch.evaluateMath(query: "(4 + 6) * 5")?.result == "50")

        // Decimal numbers and output formatting (accounting for system decimal separator e.g. . or ,)
        let decResult = AppSearch.evaluateMath(query: "5 / 2")
        #expect(decResult?.result == "2.5" || decResult?.result == "2,5")

        // Whole number decimals must not have trailing .0
        let wholeResult = AppSearch.evaluateMath(query: "12.00 / 3")
        #expect(wholeResult?.result == "4")
    }

    @Test("Percentage Expressions")
    func testPercentageCalculations() {
        // "X% of Y"
        let p1 = AppSearch.evaluateMath(query: "15% of 80")
        #expect(p1?.result == "12")

        let p2 = AppSearch.evaluateMath(query: "250% of 20")
        #expect(p2?.result == "50")

        let p3 = AppSearch.evaluateMath(query: "0% of 100")
        #expect(p3?.result == "0")

        let p4 = AppSearch.evaluateMath(query: "33.5% of 200")
        #expect(p4?.result == "67")
    }

    @Test("Math Rejections and Edge Cases")
    func testMathRejections() {
        // Plain words must be rejected
        #expect(AppSearch.evaluateMath(query: "Calculator") == nil)
        #expect(AppSearch.evaluateMath(query: "echo 123") == nil)
        #expect(AppSearch.evaluateMath(query: "rm -rf /") == nil)

        // Queries without operators must be rejected
        #expect(AppSearch.evaluateMath(query: "42") == nil)
        #expect(AppSearch.evaluateMath(query: "   ") == nil)

        // Invalid operator combinations
        #expect(AppSearch.evaluateMath(query: "++--**") == nil)
    }

    @Test("Emoji Search by Name and Keywords")
    func testEmojiSearch() {
        // Empty query defaults to top emojis
        let top = AppSearch.searchEmojis(query: "")
        #expect(top.count == 12)

        // Name match
        let fire = AppSearch.searchEmojis(query: "fire")
        #expect(fire.contains(where: { $0.emoji == "🔥" }))

        // Keyword match (e.g. "speed" should match rocket 🚀)
        let speed = AppSearch.searchEmojis(query: "speed")
        #expect(speed.contains(where: { $0.emoji == "🚀" }))

        // Case insensitivity
        let sparkles = AppSearch.searchEmojis(query: "SPARKLES")
        #expect(sparkles.contains(where: { $0.emoji == "✨" }))

        // Non-matching query
        let none = AppSearch.searchEmojis(query: "xyznonexistentemoji")
        #expect(none.isEmpty)
    }

    @Test("Web Search URL Generation")
    func testWebSearchURLs() {
        let query = "DMS & Shell"

        // Google (default and explicit)
        let google1 = AppSearch.webSearchURL(query: query, provider: "google")
        #expect(google1?.absoluteString.contains("google.com/search?q=") == true)
        #expect(google1?.absoluteString.contains("DMS%20&%20Shell") == true || google1?.absoluteString.contains("DMS") == true)

        let googleDefault = AppSearch.webSearchURL(query: query, provider: "unknown_search_engine")
        #expect(googleDefault?.absoluteString.contains("google.com/search?q=") == true)

        // DuckDuckGo / ddg
        let ddg1 = AppSearch.webSearchURL(query: query, provider: "duckduckgo")
        #expect(ddg1?.absoluteString.contains("duckduckgo.com/?q=") == true)

        let ddg2 = AppSearch.webSearchURL(query: query, provider: "ddg")
        #expect(ddg2?.absoluteString.contains("duckduckgo.com/?q=") == true)

        // Bing
        let bing = AppSearch.webSearchURL(query: query, provider: "bing")
        #expect(bing?.absoluteString.contains("bing.com/search?q=") == true)

        // Kagi
        let kagi = AppSearch.webSearchURL(query: query, provider: "kagi")
        #expect(kagi?.absoluteString.contains("kagi.com/search?q=") == true)
    }

    @Test("FileItem SF Symbol Mapping")
    func testFileItemSymbols() {
        // Folder
        let folder = FileItem(name: "Projects", path: "/Users/test/Projects", isDirectory: true)
        #expect(folder.sfSymbol == "folder.fill")
        #expect(folder.id == "/Users/test/Projects")

        // Code
        let code = FileItem(name: "main.swift", path: "/test/main.swift", isDirectory: false)
        #expect(code.sfSymbol == "chevron.left.forwardslash.chevron.right")

        // Photo
        let photo = FileItem(name: "wallpaper.png", path: "/test/wallpaper.png", isDirectory: false)
        #expect(photo.sfSymbol == "photo.fill")

        // Music
        let music = FileItem(name: "song.flac", path: "/test/song.flac", isDirectory: false)
        #expect(music.sfSymbol == "music.note")

        // Video
        let video = FileItem(name: "movie.mkv", path: "/test/movie.mkv", isDirectory: false)
        #expect(video.sfSymbol == "film.fill")

        // Document
        let doc = FileItem(name: "spec.pdf", path: "/test/spec.pdf", isDirectory: false)
        #expect(doc.sfSymbol == "doc.richtext.fill")

        // Archive
        let archive = FileItem(name: "backup.zip", path: "/test/backup.zip", isDirectory: false)
        #expect(archive.sfSymbol == "archivebox.fill")

        // Fallback text file
        let fallback = FileItem(name: "notes.xyz", path: "/test/notes.xyz", isDirectory: false)
        #expect(fallback.sfSymbol == "doc.text.fill")
    }

    @Test("WindowItem Properties")
    func testWindowItem() {
        let win = WindowItem(windowID: 101, ownerPID: 4321, ownerName: "Finder", title: "Downloads")
        #expect(win.id == 101)
        #expect(win.windowID == 101)
        #expect(win.ownerPID == 4321)
        #expect(win.ownerName == "Finder")
        #expect(win.title == "Downloads")
    }

    @Test("File Query Parsing and Search Mode")
    func testFileQueryParsing() {
        #expect(AppSearch.isFileSearchQuery("file: document") == true)
        #expect(AppSearch.isFileSearchQuery("files: notes") == true)
        #expect(AppSearch.isFileSearchQuery("f: report") == true)
        #expect(AppSearch.isFileSearchQuery("/Users/test") == true)
        #expect(AppSearch.isFileSearchQuery("~/Downloads") == true)
        #expect(AppSearch.isFileSearchQuery("FILE: UPPERCASE") == true)
        #expect(AppSearch.isFileSearchQuery("   f: trimmed   ") == true)

        #expect(AppSearch.isFileSearchQuery("terminal") == false)
        #expect(AppSearch.isFileSearchQuery("safari") == false)
        #expect(AppSearch.isFileSearchQuery("12 + 34") == false)
        #expect(AppSearch.isFileSearchQuery("") == false)

        #expect(AppSearch.extractFileQuery("file: my document") == "my document")
        #expect(AppSearch.extractFileQuery("files: budget.xlsx") == "budget.xlsx")
        #expect(AppSearch.extractFileQuery("f: code.swift") == "code.swift")
        #expect(AppSearch.extractFileQuery("~/Projects") == "~/Projects")
        #expect(AppSearch.extractFileQuery("/var/log") == "/var/log")
    }
}
