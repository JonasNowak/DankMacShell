import Foundation

/// Dependency-free Markdown model and parser (ROADMAP v0.6 NOTE, spec 27 §1.2).
/// Pure Swift value types so rendering stays in DMS and parsing is unit-testable in DMSCoreTests.
/// Scope: ATX headings, paragraphs, fenced code blocks, blockquotes, unordered/ordered lists,
/// pipe tables, horizontal rules, and inline code / bold / italic / strikethrough / links.
/// Malformed input degrades to plain paragraphs; the parser never throws.

public struct MarkdownDocument: Sendable, Equatable {
    public var blocks: [MarkdownBlock]

    public init(blocks: [MarkdownBlock] = []) {
        self.blocks = blocks
    }
}

public enum MarkdownBlock: Sendable, Equatable {
    case heading(level: Int, runs: [MarkdownInlineRun])
    case paragraph(runs: [MarkdownInlineRun])
    case codeBlock(language: String?, code: String)
    case quote(runs: [MarkdownInlineRun])
    case unorderedList(items: [[MarkdownInlineRun]])
    case orderedList(items: [[MarkdownInlineRun]])
    case table(header: [[MarkdownInlineRun]], rows: [[[MarkdownInlineRun]]])
    case divider
}

public enum MarkdownInlineRun: Sendable, Equatable {
    case text(String)
    case bold([MarkdownInlineRun])
    case italic([MarkdownInlineRun])
    case strikethrough([MarkdownInlineRun])
    case code(String)
    case link(text: String, url: String)
}

public enum MarkdownParser {

    public static func parse(_ markdown: String) -> MarkdownDocument {
        var blocks: [MarkdownBlock] = []
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Fenced code block
            if let fence = fenceMarker(trimmed) {
                var codeLines: [String] = []
                let language = String(trimmed.dropFirst(fence.count)).trimmingCharacters(in: .whitespaces)
                i += 1
                while i < lines.count, !isClosingFence(lines[i], fence: fence) {
                    codeLines.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 } // skip closing fence
                blocks.append(.codeBlock(language: language.isEmpty ? nil : language, code: codeLines.joined(separator: "\n")))
                continue
            }

            // ATX heading
            if let (level, content) = headingMarker(trimmed) {
                blocks.append(.heading(level: level, runs: parseInline(content)))
                i += 1
                continue
            }

            // Horizontal rule
            if isHorizontalRule(trimmed) {
                blocks.append(.divider)
                i += 1
                continue
            }

            // Blockquote (consecutive lines)
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix(">") {
                        quoteLines.append(String(t.dropFirst()).trimmingCharacters(in: .whitespaces))
                        i += 1
                    } else if !t.isEmpty {
                        break
                    } else {
                        i += 1
                    }
                }
                blocks.append(.quote(runs: parseInline(quoteLines.joined(separator: " "))))
                continue
            }

            // Unordered list
            if isUnorderedListItem(trimmed) {
                var items: [[MarkdownInlineRun]] = []
                while i < lines.count, isUnorderedListItem(lines[i].trimmingCharacters(in: .whitespaces)) {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    items.append(parseInline(String(t.drop(while: { $0 == "-" || $0 == "*" || $0 == "+" }).dropFirst().trimmingCharacters(in: .whitespaces))))
                    i += 1
                }
                blocks.append(.unorderedList(items: items))
                continue
            }

            // Ordered list
            if isOrderedListItem(trimmed) {
                var items: [[MarkdownInlineRun]] = []
                while i < lines.count, isOrderedListItem(lines[i].trimmingCharacters(in: .whitespaces)) {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    let content = t.drop(while: { $0.isNumber }).dropFirst().trimmingCharacters(in: .whitespaces)
                    items.append(parseInline(String(content)))
                    i += 1
                }
                blocks.append(.orderedList(items: items))
                continue
            }

            // Table (header row + separator row)
            if trimmed.contains("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                let headerCells = parseTableRow(trimmed)
                i += 2
                var rows: [[[MarkdownInlineRun]]] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).contains("|"),
                      !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    rows.append(parseTableRow(lines[i].trimmingCharacters(in: .whitespaces)).map { parseInline($0) })
                    i += 1
                }
                blocks.append(.table(
                    header: headerCells.map { parseInline($0) },
                    rows: rows
                ))
                continue
            }

            // Paragraph (consecutive non-empty, non-special lines)
            var paraLines: [String] = []
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty { break }
                if fenceMarker(t) != nil || headingMarker(t) != nil || isHorizontalRule(t)
                    || t.hasPrefix(">") || isUnorderedListItem(t) || isOrderedListItem(t) {
                    break
                }
                if t.contains("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                    break
                }
                paraLines.append(t)
                i += 1
            }
            if !paraLines.isEmpty {
                blocks.append(.paragraph(runs: parseInline(paraLines.joined(separator: " "))))
            }
        }

        return MarkdownDocument(blocks: blocks)
    }

    // MARK: - Block helpers

    private static func fenceMarker(_ line: String) -> String? {
        for fence in ["```", "~~~"] {
            if line.hasPrefix(fence) { return fence }
        }
        return nil
    }

    private static func isClosingFence(_ line: String, fence: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(fence)
    }

    private static func headingMarker(_ line: String) -> (level: Int, content: String)? {
        var level = 0
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == "#", level < 6 {
            level += 1
            idx = line.index(after: idx)
        }
        guard level > 0, idx < line.endIndex, line[idx] == " " || line[idx] == "\t" else {
            if level > 0, idx == line.endIndex { return (level, "") }
            return nil
        }
        var content = String(line[idx...]).trimmingCharacters(in: .whitespaces)
        // Strip optional closing hashes: "## Title ##"
        while content.hasSuffix("#") {
            content = String(content.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return (level, content)
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let stripped = line.filter { !$0.isWhitespace }
        guard stripped.count >= 3 else { return false }
        let first = stripped.first
        return stripped.allSatisfy { $0 == first } && (first == "-" || first == "*" || first == "_")
    }

    private static func isUnorderedListItem(_ line: String) -> Bool {
        guard line.count >= 2 else { return false }
        let c = line.first
        guard c == "-" || c == "*" || c == "+" else { return false }
        return line[line.index(after: line.startIndex)].isWhitespace
    }

    private static func isOrderedListItem(_ line: String) -> Bool {
        guard let dotIdx = line.firstIndex(of: ".") else { return false }
        let digits = line[line.startIndex..<dotIdx]
        guard !digits.isEmpty, digits.allSatisfy({ $0.isNumber }) else { return false }
        let after = line.index(after: dotIdx)
        return after == line.endIndex || line[after].isWhitespace
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.contains("|") || t.contains("-") else { return false }
        let cells = t.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            guard cell.count >= 3 else { return false }
            let inner = cell.dropFirst().dropLast()
            return cell.first == ":" || cell.first == "-" || cell.first == " " || cell.first == "\t"
                ? cell.allSatisfy({ $0 == "-" || $0 == ":" || $0.isWhitespace }) && inner.contains("-")
                : cell.allSatisfy({ $0 == "-" || $0 == ":" || $0.isWhitespace })
        }
    }

    private static func parseTableRow(_ line: String) -> [String] {
        var t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t = String(t.dropFirst()) }
        if t.hasSuffix("|") { t = String(t.dropLast()) }
        return t.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Inline parsing

    /// Parses inline markup: `code`, **bold**, *italic* / _italic_, ~~strike~~, [text](url).
    public static func parseInline(_ text: String) -> [MarkdownInlineRun] {
        var runs: [MarkdownInlineRun] = []
        var buffer = ""

        func flush() {
            if !buffer.isEmpty {
                runs.append(.text(buffer))
                buffer = ""
            }
        }

        var index = text.startIndex
        while index < text.endIndex {
            let c = text[index]

            // Inline code
            if c == "`" {
                if let (code, next) = readDelimited(text, at: index, delimiter: "`") {
                    flush()
                    runs.append(.code(code))
                    index = next
                    continue
                }
            }

            // Bold ** or __
            if (c == "*" && peek(text, index, offset: 1) == "*") || (c == "_" && peek(text, index, offset: 1) == "_") {
                let delim = String(c) + String(c)
                if let (inner, next) = readDelimited(text, at: index, delimiter: delim) {
                    flush()
                    runs.append(.bold(parseInline(inner)))
                    index = next
                    continue
                }
            }

            // Strikethrough ~~
            if c == "~" && peek(text, index, offset: 1) == "~" {
                if let (inner, next) = readDelimited(text, at: index, delimiter: "~~") {
                    flush()
                    runs.append(.strikethrough(parseInline(inner)))
                    index = next
                    continue
                }
            }

            // Italic * or _
            if c == "*" || c == "_" {
                if let (inner, next) = readDelimited(text, at: index, delimiter: String(c)) {
                    flush()
                    runs.append(.italic(parseInline(inner)))
                    index = next
                    continue
                }
            }

            // Link [text](url)
            if c == "[" {
                let afterBracket = text.index(after: index)
                if let closeBracket = text.range(of: "]", range: afterBracket..<text.endIndex)?.lowerBound,
                   closeBracket < text.endIndex,
                   text[text.index(after: closeBracket)] == "(",
                   let closeParen = text.range(of: ")", range: text.index(after: text.index(after: closeBracket))..<text.endIndex)?.lowerBound {
                    let linkText = String(text[text.index(after: index)..<closeBracket])
                    let url = String(text[text.index(after: text.index(after: closeBracket))..<closeParen])
                    flush()
                    runs.append(.link(text: linkText, url: url))
                    index = text.index(after: closeParen)
                    continue
                }
            }

            buffer.append(c)
            index = text.index(after: index)
        }
        flush()
        return runs
    }

    private static func peek(_ text: String, _ index: String.Index, offset: Int) -> Character? {
        var i = index
        for _ in 0..<offset {
            i = text.index(after: i)
            if i >= text.endIndex { return nil }
        }
        return text[i]
    }

    /// Reads a delimited span starting at `index` (which must point at `delimiter`).
    /// Returns the inner content and the index just past the closing delimiter.
    private static func readDelimited(_ text: String, at index: String.Index, delimiter: String) -> (String, String.Index)? {
        let start = text.index(index, offsetBy: delimiter.count)
        guard start <= text.endIndex else { return nil }
        guard let close = text.range(of: delimiter, range: start..<text.endIndex)?.lowerBound else { return nil }
        let inner = String(text[start..<close])
        if inner.isEmpty { return nil }
        return (inner, text.index(close, offsetBy: delimiter.count))
    }
}
