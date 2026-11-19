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

    @Test("AppItem isHidden Property and Codable Roundtrip")
    func testAppItemHiddenAndCodable() throws {
        let visibleApp = AppItem(
            name: "Finder",
            bundleID: "com.apple.finder",
            path: "/System/Library/CoreServices/Finder.app",
            isRunning: true,
            isHidden: false
        )
        #expect(visibleApp.isRunning == true)
        #expect(visibleApp.isHidden == false)

        let hiddenApp = AppItem(
            name: "Calculator",
            bundleID: "com.apple.calculator",
            path: "/System/Applications/Calculator.app",
            isRunning: true,
            isHidden: true
        )
        #expect(hiddenApp.isRunning == true)
        #expect(hiddenApp.isHidden == true)

        let encoder = JSONEncoder()
        let data = try encoder.encode(hiddenApp)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppItem.self, from: data)
        #expect(decoded.name == "Calculator")
        #expect(decoded.bundleID == "com.apple.calculator")
        #expect(decoded.isRunning == true)
        #expect(decoded.isHidden == true)

        // Backwards compatibility test: JSON without isHidden key defaults to false
        let legacyJSON = """
        {
            "id": "com.test.app",
            "name": "Legacy App",
            "bundleID": "com.test.app",
            "path": "/Applications/Legacy.app",
            "isRunning": true
        }
        """.data(using: .utf8)!
        let legacyDecoded = try decoder.decode(AppItem.self, from: legacyJSON)
        #expect(legacyDecoded.name == "Legacy App")
        #expect(legacyDecoded.isRunning == true)
        #expect(legacyDecoded.isHidden == false)
    }

    @Test("Math Power Precedence Binds Tighter Than Unary Minus")
    func testMathPowerPrecedence() {
        // ^ binds tighter than unary -: -2^2 == -(2^2) == -4
        #expect(AppSearch.evaluateMath(query: "-2^2")?.result == "-4")
        // Parenthesized base: (-2)^2 == 4
        #expect(AppSearch.evaluateMath(query: "(-2)^2")?.result == "4")
        // Right-associative power chain: 2^3^2 == 2^(3^2) == 512
        #expect(AppSearch.evaluateMath(query: "2^3^2")?.result == "512")
        // Negative exponent: 2^-3 == 0.125
        let negExp = AppSearch.evaluateMath(query: "2^-3")
        #expect(negExp?.result == "0.125" || negExp?.result == "0,125")
    }

    @Test("Math Allows Unary Minus After Binary Plus/Minus")
    func testMathUnaryAfterBinaryOperator() {
        #expect(AppSearch.evaluateMath(query: "5 + -3")?.result == "2")
        #expect(AppSearch.evaluateMath(query: "5 - -3")?.result == "8")
        #expect(AppSearch.evaluateMath(query: "2 * -3")?.result == "-6")
        // Chained unary operators are still rejected
        #expect(AppSearch.evaluateMath(query: "5 + --3") == nil)
        #expect(AppSearch.evaluateMath(query: "5 + * 3") == nil)
    }

    @Test("Math Never Formats Negative Zero")
    func testMathNegativeZeroNormalization() {
        #expect(AppSearch.evaluateMath(query: "0 * -1")?.result == "0")
        #expect(AppSearch.evaluateMath(query: "-0 + 0")?.result == "0")
        #expect(AppSearch.evaluateMath(query: "0 - 0")?.result == "0")
    }

    @Test("Math Parser Depth and Input Length Caps Prevent Stack Overflow")
    func testMathDepthAndLengthCaps() {
        // 50,000 nested parens must return nil instead of overflowing the stack
        let deep = String(repeating: "(", count: 50_000) + "1" + String(repeating: ")", count: 50_000)
        #expect(AppSearch.evaluateMath(query: deep) == nil)

        // Deep power chain (within the length cap but beyond the depth cap) must also return nil
        let deepPower = "2" + String(repeating: "^2", count: 100)
        #expect(deepPower.count <= 512)
        #expect(AppSearch.evaluateMath(query: deepPower) == nil)

        // Inputs longer than 512 characters are rejected outright
        let longInput = "1 + " + String(repeating: "1 + ", count: 200) + "1"
        #expect(longInput.count > 512)
        #expect(AppSearch.evaluateMath(query: longInput) == nil)

        // Reasonable nesting (within the depth cap) still evaluates
        let okDepth = String(repeating: "(", count: 60) + "1 + 1" + String(repeating: ")", count: 60)
        #expect(AppSearch.evaluateMath(query: okDepth)?.result == "2")
    }

    @Test("Web Search URL Percent-Encodes Reserved Characters")
    func testWebSearchURLEncoding() {
        let tricky = "C++ & Tom & Jerry = ? # 100%"
        for provider in ["google", "duckduckgo", "bing", "kagi"] {
            let url = AppSearch.webSearchURL(query: tricky, provider: provider)
            #expect(url != nil)
            guard let url else { continue }
            // Round-trip: the query item must decode back to the exact original string
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            #expect(comps?.queryItems?.first(where: { $0.name == "q" })?.value == tricky)
            // Raw query must not contain unencoded &, +, =, ?, # from the search text
            let raw = url.absoluteString
            let queryPart = raw.split(separator: "?", maxSplits: 1).last ?? ""
            #expect(!queryPart.contains("&"))
            #expect(!queryPart.contains("+"))
            #expect(!queryPart.contains("=") || queryPart.hasPrefix("q="))
            #expect(!queryPart.contains("#"))
        }

        // Simple queries still encode spaces
        let cpp = AppSearch.webSearchURL(query: "C++", provider: "google")
        #expect(cpp?.absoluteString.contains("C%2B%2B") == true)
    }

    @Test("DankSearch parseOutput Handles Pretty-Printed Whole-Document JSON")
    func testParseOutputPrettyPrintedObject() {
        let pretty = """
        {
          "results": [
            { "name": "a.txt", "path": "/Users/test/a.txt" },
            { "name": "b.txt", "path": "/Users/test/b.txt", "isDirectory": false }
          ]
        }
        """.data(using: .utf8)!

        switch DankSearchClient.parseOutput(pretty, maxResults: 10) {
        case .success(let items):
            #expect(items.count == 2)
            #expect(items[0].path == "/Users/test/a.txt")
            #expect(items[1].name == "b.txt")
        case .failure(let err):
            Issue.record("Pretty-printed results object should parse: \(err)")
        }

        // Pretty-printed JSON array
        let prettyArray = """
        [
          { "path": "/Users/test/c.txt" },
          { "path": "/Users/test/d.txt" }
        ]
        """.data(using: .utf8)!
        switch DankSearchClient.parseOutput(prettyArray, maxResults: 10) {
        case .success(let items):
            #expect(items.count == 2)
        case .failure(let err):
            Issue.record("Pretty-printed array should parse: \(err)")
        }
    }

    @Test("DankSearch parseOutput Returns Empty for Non-Positive maxResults Before Appending")
    func testParseOutputNonPositiveMaxResults() {
        let json = """
        [{"name": "a", "path": "/Users/test/a"}, {"name": "b", "path": "/Users/test/b"}]
        """.data(using: .utf8)!

        for limit in [0, -1, -100] {
            switch DankSearchClient.parseOutput(json, maxResults: limit) {
            case .success(let items):
                #expect(items.isEmpty, "maxResults=\(limit) must yield zero items")
            case .failure(let err):
                Issue.record("maxResults=\(limit) should succeed with empty list, got \(err)")
            }
        }
    }

    @Test("DankSearch configure(timeout:) Does Not Clear a Configured Custom Executor")
    func testConfigureKeepsCustomExecutor() {
        let client = DankSearchClient(timeout: 0.1)
        client.configure(customExecutor: { _, _, _ in
            .success("[{\"path\": \"/Users/test/kept.txt\"}]".data(using: .utf8)!)
        })
        // Reconfiguring only the timeout must not drop the executor
        client.configure(timeout: 0.5)
        let response = client.searchFiles(query: "kept", maxResults: 5)
        #expect(response.usedFallback == false)
        #expect(response.files.count == 1)
        #expect(response.files[0].path == "/Users/test/kept.txt")
        #expect(response.backendUsed == "danksearch")
    }

    @Test("SafeProcessRunner Captures Output, Caps at 4MB, and Enforces Timeout")
    func testSafeProcessRunnerBasics() {
        // Normal execution
        guard case .success(let out) = SafeProcessRunner.run(
            executablePath: "/bin/echo",
            arguments: ["hello-dms"],
            timeout: 2.0
        ) else {
            Issue.record("echo should succeed")
            return
        }
        #expect(String(data: out.stdout, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "hello-dms")
        #expect(out.terminationStatus == 0)

        // Bounded buffer: 5 MB of output is capped at 4 MB
        guard case .success(let big) = SafeProcessRunner.run(
            executablePath: "/bin/sh",
            arguments: ["-c", "head -c 5000000 /dev/zero | tr '\\0' 'a'"],
            timeout: 10.0
        ) else {
            Issue.record("large output run should succeed")
            return
        }
        #expect(big.stdout.count == 4 * 1024 * 1024)

        // Watchdog timeout
        if case .failure(let err) = SafeProcessRunner.run(
            executablePath: "/bin/sleep",
            arguments: ["5"],
            timeout: 0.1
        ) {
            if case .timedOut = err {
                // expected
            } else {
                Issue.record("Expected .timedOut, got \(err)")
            }
        } else {
            Issue.record("sleep 5 with 0.1s timeout should time out")
        }

        // Non-zero exit
        if case .failure(let err) = SafeProcessRunner.run(
            executablePath: "/bin/sh",
            arguments: ["-c", "echo oops >&2; exit 3"],
            timeout: 2.0
        ) {
            if case .nonZeroExit(let code, let stderr) = err {
                #expect(code == 3)
                #expect(stderr.contains("oops"))
            } else {
                Issue.record("Expected .nonZeroExit, got \(err)")
            }
        } else {
            Issue.record("exit 3 should produce .nonZeroExit")
        }
    }

    @Test("DankSearch searchFiles Inserts -- Before Dash-Prefixed Queries")
    func testSearchFilesDashDashGuard() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dms_dashdash_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let argsFile = dir.appendingPathComponent("args.txt")
        let script = dir.appendingPathComponent("fake-danksearch.sh")
        let scriptBody = """
        #!/bin/sh
        printf '%s\\n' "$@" > \(argsFile.path)
        echo '[{"name":"x","path":"/tmp/x"}]'
        """
        try scriptBody.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        let client = DankSearchClient(customExecutablePath: script.path, timeout: 2.0)
        let response = client.searchFiles(query: "-rf", maxResults: 5)
        #expect(response.files.count == 1)

        let args = try String(contentsOf: argsFile, encoding: .utf8)
            .components(separatedBy: .newlines).filter { !$0.isEmpty }
        #expect(args == ["--json", "--limit", "5", "--", "-rf"])

        // A normal query must NOT get a stray "--"
        _ = client.searchFiles(query: "report", maxResults: 5)
        let args2 = try String(contentsOf: argsFile, encoding: .utf8)
            .components(separatedBy: .newlines).filter { !$0.isEmpty }
        #expect(args2 == ["--json", "--limit", "5", "report"])
    }
}
