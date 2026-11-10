import Foundation

/// Literal (non-regex) find & replace engine for the Notepad find bar (ROADMAP v0.6 NOTE).
/// Pure and UI-free so match/wrap/replace behavior is unit-testable in DMSCoreTests.
public enum FindReplaceEngine {

    /// All non-overlapping match ranges of `query` in `text`. Empty query yields no matches.
    public static func matches(in text: String, query: String, caseSensitive: Bool) -> [Range<String.Index>] {
        guard !query.isEmpty, !text.isEmpty else { return [] }
        let options: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
        var results: [Range<String.Index>] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex {
            guard let range = text.range(of: query, options: options, range: searchStart..<text.endIndex) else {
                break
            }
            results.append(range)
            // Advance past this match (non-overlapping). Guard against zero-width loops.
            searchStart = range.upperBound
            if searchStart == range.lowerBound {
                searchStart = text.index(after: searchStart)
            }
        }
        return results
    }

    /// Index of the next match after `current`, wrapping around. Returns 0 when there are no matches.
    public static func nextIndex(current: Int, matchCount: Int) -> Int {
        guard matchCount > 0 else { return 0 }
        return (current + 1) % matchCount
    }

    /// Index of the previous match before `current`, wrapping around. Returns 0 when there are no matches.
    public static func previousIndex(current: Int, matchCount: Int) -> Int {
        guard matchCount > 0 else { return 0 }
        return (current - 1 + matchCount) % matchCount
    }

    /// Replaces a single match range in `text` with `replacement`.
    public static func replace(text: String, match: Range<String.Index>, with replacement: String) -> String {
        var result = text
        result.replaceSubrange(match, with: replacement)
        return result
    }

    /// Replaces every match of `query` in `text`. Returns the new text and the replacement count.
    public static func replaceAll(
        in text: String,
        query: String,
        replacement: String,
        caseSensitive: Bool
    ) -> (text: String, count: Int) {
        let ranges = matches(in: text, query: query, caseSensitive: caseSensitive)
        guard !ranges.isEmpty else { return (text, 0) }
        var result = text
        // Replace from the end so earlier ranges stay valid.
        for range in ranges.reversed() {
            result.replaceSubrange(range, with: replacement)
        }
        return (result, ranges.count)
    }
}
