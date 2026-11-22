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
        // Empty query defaults to the first 24 items of the combined pool
        let top = AppSearch.searchEmojis(query: "")
        #expect(top.count == 24)

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

    @Test("Emoji Query Detection and Prefix Pools")
    func testIsEmojiQueryAndPrefixes() {
        // isEmojiQuery
        #expect(AppSearch.isEmojiQuery("emoji:fire") == true)
        #expect(AppSearch.isEmojiQuery("nf:folder") == true)
        #expect(AppSearch.isEmojiQuery(":fire") == true)
        #expect(AppSearch.isEmojiQuery(":f") == true)
        #expect(AppSearch.isEmojiQuery("  :fire  ") == true)
        #expect(AppSearch.isEmojiQuery("EMOJI:fire") == true)
        #expect(AppSearch.isEmojiQuery(":") == false)
        #expect(AppSearch.isEmojiQuery(": fire") == false)
        #expect(AppSearch.isEmojiQuery("fire") == false)
        #expect(AppSearch.isEmojiQuery("") == false)
        #expect(AppSearch.isEmojiQuery("emoji search") == false)

        // "nf:" searches only the nerd font pool
        let nf = AppSearch.searchEmojis(query: "nf:folder")
        #expect(!nf.isEmpty)
        #expect(nf.allSatisfy { $0.isNerdFont })
        #expect(nf.contains(where: { $0.shortcode == "nf-fa-folder" }))

        // "emoji:" searches only the common pool
        let em = AppSearch.searchEmojis(query: "emoji:fire")
        #expect(em.contains(where: { $0.emoji == "🔥" }))
        #expect(em.allSatisfy { !$0.isNerdFont })

        // ":" searches both pools; shortcode/name prefix matches sort first
        let colon = AppSearch.searchEmojis(query: ":rocket")
        #expect(colon.first?.emoji == "🚀")

        // Trailing colon is stripped
        let trailing = AppSearch.searchEmojis(query: ":fire:")
        #expect(trailing.contains(where: { $0.emoji == "🔥" }))

        // Empty stripped query returns the first 24 items of the pool
        #expect(AppSearch.searchEmojis(query: "").count == 24)
        let nfEmpty = AppSearch.searchEmojis(query: "nf:")
        #expect(nfEmpty.count == 24)
        #expect(nfEmpty.allSatisfy { $0.isNerdFont })

        // Shortcode matching
        let byShortcode = AppSearch.searchEmojis(query: "nf-dev-git")
        #expect(byShortcode.contains(where: { $0.shortcode == "nf-dev-git_branch" }))
    }

    @Test("Web Search !bang Resolution")
    func testResolveWebSearchBangs() {
        // Bang at start
        let gh = AppSearch.resolveWebSearch(query: "!gh dankmacshell")
        #expect(gh?.isBang == true)
        #expect(gh?.providerName == "github")
        #expect(gh?.query == "dankmacshell")
        #expect(gh?.url.absoluteString.contains("github.com/search?q=dankmacshell") == true)

        let ddg = AppSearch.resolveWebSearch(query: "!ddg swift concurrency")
        #expect(ddg?.isBang == true)
        #expect(ddg?.providerName == "duckduckgo")
        #expect(ddg?.url.absoluteString.contains("duckduckgo.com/?q=swift%20concurrency") == true)

        // Bang at end
        let yt = AppSearch.resolveWebSearch(query: "swift tips !yt")
        #expect(yt?.isBang == true)
        #expect(yt?.providerName == "youtube")
        #expect(yt?.query == "swift tips")
        #expect(yt?.url.absoluteString.contains("youtube.com/results?search_query=swift%20tips") == true)

        let w = AppSearch.resolveWebSearch(query: "!w actor model")
        #expect(w?.providerName == "wikipedia")
        #expect(w?.url.absoluteString.contains("en.wikipedia.org/w/index.php?search=actor%20model") == true)

        let kagi = AppSearch.resolveWebSearch(query: "!kagi m3 design")
        #expect(kagi?.providerName == "kagi")
        #expect(kagi?.url.absoluteString.contains("kagi.com/search?q=m3%20design") == true)

        let brew = AppSearch.resolveWebSearch(query: "!brew neovim")
        #expect(brew?.providerName == "homebrew")
        #expect(brew?.url.absoluteString.contains("formulae.brew.sh") == true)

        let crates = AppSearch.resolveWebSearch(query: "!crates serde")
        #expect(crates?.providerName == "crates")
        #expect(crates?.url.absoluteString.contains("crates.io/search?q=serde") == true)

        let npm = AppSearch.resolveWebSearch(query: "!npm react")
        #expect(npm?.providerName == "npm")
        #expect(npm?.url.absoluteString.contains("npmjs.com/search?q=react") == true)

        let so = AppSearch.resolveWebSearch(query: "!so optional chaining")
        #expect(so?.providerName == "stackoverflow")
        #expect(so?.url.absoluteString.contains("stackoverflow.com/search?q=optional%20chaining") == true)

        let apple = AppSearch.resolveWebSearch(query: "!apple swiftui")
        #expect(apple?.providerName == "apple")
        #expect(apple?.url.absoluteString.contains("developer.apple.com/search/") == true)

        let g = AppSearch.resolveWebSearch(query: "!g dank shell")
        #expect(g?.providerName == "google")
        #expect(g?.url.absoluteString.contains("google.com/search?q=dank%20shell") == true)

        // No bang -> default provider, isBang false
        let plain = AppSearch.resolveWebSearch(query: "hello world")
        #expect(plain?.isBang == false)
        #expect(plain?.providerName == "google")
        #expect(plain?.query == "hello world")
        #expect(plain?.url.absoluteString.contains("google.com/search?q=hello%20world") == true)

        let ddgDefault = AppSearch.resolveWebSearch(query: "hello", defaultProvider: "ddg")
        #expect(ddgDefault?.isBang == false)
        #expect(ddgDefault?.providerName == "duckduckgo")
        #expect(ddgDefault?.url.absoluteString.contains("duckduckgo.com/?q=hello") == true)

        // webSearchURL honors bangs over the configured provider
        let viaURL = AppSearch.webSearchURL(query: "!gh dms", provider: "google")
        #expect(viaURL?.absoluteString.contains("github.com/search?q=dms") == true)

        // Unknown bang token is not treated as a bang
        let unknown = AppSearch.resolveWebSearch(query: "!xyz hello")
        #expect(unknown?.isBang == false)
        #expect(unknown?.query == "!xyz hello")

        // Empty queries resolve to nil
        #expect(AppSearch.resolveWebSearch(query: "   ") == nil)
        #expect(AppSearch.resolveWebSearch(query: "!g") == nil)
    }

    @Test("Math Evaluation Routes Unit Conversions")
    func testMathRoutesUnitConverter() {
        let km = AppSearch.evaluateMath(query: "1 km in mi")
        #expect(km?.expression == "1 km → mi")
        #expect(km?.result == "0.62 mi")

        let currency = AppSearch.evaluateMath(query: "100 usd in eur")
        #expect(currency?.expression == "100 USD → EUR")
        #expect(currency?.result == "92.00 EUR")

        // Plain math still evaluates through the math parser
        #expect(AppSearch.evaluateMath(query: "3 + 7")?.result == "10")
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
