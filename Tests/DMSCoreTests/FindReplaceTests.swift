import Testing
import Foundation
@testable import DMSCore

@Suite("Find & Replace Engine Tests (v0.6 NOTE)")
struct FindReplaceTests {

    @Test("Match Ranges Are Non-Overlapping and Ordered")
    func testMatches() {
        let text = "ab ab ab"
        let ranges = FindReplaceEngine.matches(in: text, query: "ab", caseSensitive: true)
        #expect(ranges.count == 3)
        #expect(text[ranges[0]] == "ab")
        #expect(text[ranges[2]] == "ab")
    }

    @Test("Case Sensitivity")
    func testCaseSensitivity() {
        let text = "Foo foo FOO"
        #expect(FindReplaceEngine.matches(in: text, query: "foo", caseSensitive: true).count == 1)
        #expect(FindReplaceEngine.matches(in: text, query: "foo", caseSensitive: false).count == 3)
    }

    @Test("Empty Query or Empty Text Yields No Matches")
    func testEmpty() {
        #expect(FindReplaceEngine.matches(in: "abc", query: "", caseSensitive: true).isEmpty)
        #expect(FindReplaceEngine.matches(in: "", query: "a", caseSensitive: true).isEmpty)
    }

    @Test("Wrap-Around Navigation")
    func testWrapAround() {
        // next wraps from last to first
        #expect(FindReplaceEngine.nextIndex(current: 2, matchCount: 3) == 0)
        #expect(FindReplaceEngine.nextIndex(current: 0, matchCount: 3) == 1)
        // previous wraps from first to last
        #expect(FindReplaceEngine.previousIndex(current: 0, matchCount: 3) == 2)
        #expect(FindReplaceEngine.previousIndex(current: 2, matchCount: 3) == 1)
        // no matches -> 0
        #expect(FindReplaceEngine.nextIndex(current: 0, matchCount: 0) == 0)
        #expect(FindReplaceEngine.previousIndex(current: 0, matchCount: 0) == 0)
    }

    @Test("Replace Single Match")
    func testReplaceSingle() {
        let text = "hello world hello"
        let ranges = FindReplaceEngine.matches(in: text, query: "hello", caseSensitive: true)
        let result = FindReplaceEngine.replace(text: text, match: ranges[1], with: "bye")
        #expect(result == "hello world bye")
    }

    @Test("Replace All Counts and Rewrites")
    func testReplaceAll() {
        let (text, count) = FindReplaceEngine.replaceAll(
            in: "cat dog cat",
            query: "cat",
            replacement: "fox",
            caseSensitive: false
        )
        #expect(count == 2)
        #expect(text == "fox dog fox")

        let none = FindReplaceEngine.replaceAll(in: "abc", query: "zzz", replacement: "x", caseSensitive: true)
        #expect(none.count == 0)
        #expect(none.text == "abc")
    }

    @Test("Replace All With Overlapping-Prone Query Stays Stable")
    func testReplaceAllOverlapping() {
        // Non-overlapping semantics: "aa" in "aaaa" matches twice
        let (text, count) = FindReplaceEngine.replaceAll(
            in: "aaaa",
            query: "aa",
            replacement: "b",
            caseSensitive: true
        )
        #expect(count == 2)
        #expect(text == "bb")
    }
}
