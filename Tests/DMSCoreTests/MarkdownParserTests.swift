import Testing
import Foundation
@testable import DMSCore

@Suite("Markdown Parser Tests (v0.6 NOTE)")
struct MarkdownParserTests {

    @Test("Headings of All Levels")
    func testHeadings() {
        let doc = MarkdownParser.parse("# Title\n\n### Sub\n\n###### Deep\n## Closed ##")
        #expect(doc.blocks.count == 4)
        guard case .heading(let level, let runs) = doc.blocks[0] else {
            Issue.record("expected heading")
            return
        }
        #expect(level == 1)
        #expect(runs == [.text("Title")])
        guard case .heading(let l3, _) = doc.blocks[1] else { Issue.record(); return }
        #expect(l3 == 3)
        guard case .heading(let l6, _) = doc.blocks[2] else { Issue.record(); return }
        #expect(l6 == 6)
        guard case .heading(_, let closedRuns) = doc.blocks[3] else { Issue.record(); return }
        #expect(closedRuns == [.text("Closed")])
    }

    @Test("Inline Emphasis, Code, Strikethrough, Links")
    func testInline() {
        let runs = MarkdownParser.parseInline("a **bold** b *it* `code` ~~gone~~ [site](https://x.y)")
        #expect(runs == [
            .text("a "),
            .bold([.text("bold")]),
            .text(" b "),
            .italic([.text("it")]),
            .text(" "),
            .code("code"),
            .text(" "),
            .strikethrough([.text("gone")]),
            .text(" "),
            .link(text: "site", url: "https://x.y")
        ])
    }

    @Test("Nested Emphasis")
    func testNested() {
        let runs = MarkdownParser.parseInline("**bold *italic* text**")
        #expect(runs == [.bold([.text("bold "), .italic([.text("italic")]), .text(" text")])])
    }

    @Test("Fenced Code Block with Language")
    func testCodeBlock() {
        let doc = MarkdownParser.parse("```swift\nlet x = 1\nlet y = 2\n```\n\nafter")
        #expect(doc.blocks.count == 2)
        guard case .codeBlock(let lang, let code) = doc.blocks[0] else {
            Issue.record("expected code block")
            return
        }
        #expect(lang == "swift")
        #expect(code == "let x = 1\nlet y = 2")
        guard case .paragraph = doc.blocks[1] else { Issue.record(); return }
    }

    @Test("Unordered and Ordered Lists")
    func testLists() {
        let doc = MarkdownParser.parse("- one\n- two\n\n1. first\n2. second")
        #expect(doc.blocks.count == 2)
        guard case .unorderedList(let items) = doc.blocks[0] else { Issue.record(); return }
        #expect(items.count == 2)
        #expect(items[0] == [.text("one")])
        guard case .orderedList(let ordered) = doc.blocks[1] else { Issue.record(); return }
        #expect(ordered.count == 2)
        #expect(ordered[1] == [.text("second")])
    }

    @Test("Blockquote")
    func testQuote() {
        let doc = MarkdownParser.parse("> hello **world**\n> again")
        guard case .quote(let runs) = doc.blocks.first else { Issue.record(); return }
        #expect(runs == [.text("hello "), .bold([.text("world")]), .text(" again")])
    }

    @Test("Pipe Table")
    func testTable() {
        let doc = MarkdownParser.parse("| Name | Age |\n| --- | ---: |\n| Ann | 30 |\n| Bob | 40 |")
        guard case .table(let header, let rows) = doc.blocks.first else {
            Issue.record("expected table")
            return
        }
        #expect(header.count == 2)
        #expect(header[0] == [.text("Name")])
        #expect(rows.count == 2)
        #expect(rows[0][1] == [.text("30")])
    }

    @Test("Horizontal Rule and Paragraph Merging")
    func testDividerAndParagraph() {
        let doc = MarkdownParser.parse("line one\nline two\n\n---\n\nafter")
        #expect(doc.blocks.count == 3)
        guard case .paragraph(let runs) = doc.blocks[0] else { Issue.record(); return }
        #expect(runs == [.text("line one line two")])
        guard case .divider = doc.blocks[1] else { Issue.record(); return }
    }

    @Test("Malformed Input Degrades to Paragraphs Without Crashing")
    func testMalformed() {
        let doc = MarkdownParser.parse("#\n**unclosed\n[broken]( \n`nope\n~~\n| not | a |\n| table |")
        #expect(!doc.blocks.isEmpty)
        // Unclosed markers stay literal text
        let runs = MarkdownParser.parseInline("**unclosed")
        #expect(runs == [.text("**unclosed")])
    }

    @Test("Empty Input")
    func testEmpty() {
        #expect(MarkdownParser.parse("").blocks.isEmpty)
        #expect(MarkdownParser.parse("\n\n  \n").blocks.isEmpty)
    }
}
