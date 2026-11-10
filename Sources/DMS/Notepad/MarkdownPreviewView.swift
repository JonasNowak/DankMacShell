import SwiftUI
import DMSCore

/// Live Markdown preview pane for NotepadView (ROADMAP v0.6 NOTE, spec 27 §1.2).
/// Renders the UI-free `MarkdownDocument` produced by `MarkdownParser` with the M3 palette.
public struct MarkdownPreviewView: View {
    public let markdown: String

    @ObservedObject private var themeStore = ThemeStore.shared

    public init(markdown: String) {
        self.markdown = markdown
    }

    private var document: MarkdownDocument {
        MarkdownParser.parse(markdown)
    }

    public var body: some View {
        let p = themeStore.palette

        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block, palette: p)
                }
            }
            .padding(14)
        }
        .background(Color(hex: p.surfaceContainerLowest.hex).opacity(0.6))
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock, palette p: DMSPalette) -> some View {
        switch block {
        case .heading(let level, let runs):
            inlineText(runs, palette: p)
                .font(.system(size: headingSize(level), weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: p.onSurface.hex))

        case .paragraph(let runs):
            inlineText(runs, palette: p)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: p.onSurface.hex))
                .fixedSize(horizontal: false, vertical: true)

        case .codeBlock(let language, let code):
            VStack(alignment: .leading, spacing: 4) {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: p.primary.hex))
                }
                Text(code)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: p.surfaceContainerHigh.hex))
            .cornerRadius(10)

        case .quote(let runs):
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(hex: p.primary.hex).opacity(0.6))
                    .frame(width: 3)
                inlineText(runs, palette: p)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: p.primary.hex))
                        inlineText(item, palette: p)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: p.onSurface.hex))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: p.primary.hex))
                            .frame(width: 20, alignment: .trailing)
                        inlineText(item, palette: p)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: p.onSurface.hex))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .table(let header, let rows):
            VStack(alignment: .leading, spacing: 0) {
                tableRow(header.map { inlineText($0, palette: p) }, palette: p, isHeader: true)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    tableRow(row.map { inlineText($0, palette: p) }, palette: p, isHeader: false)
                }
            }
            .background(Color(hex: p.surfaceContainerHigh.hex).opacity(0.5))
            .cornerRadius(10)

        case .divider:
            Divider()
                .background(Color(hex: p.outlineVariant.hex))
                .padding(.vertical, 4)
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 20
        case 2: return 17
        case 3: return 15
        default: return 13
        }
    }

    private func tableRow(_ cells: [Text], palette p: DMSPalette, isHeader: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                cell
                    .font(.system(size: 11, weight: isHeader ? .bold : .regular))
                    .foregroundColor(Color(hex: isHeader ? p.onSurface.hex : p.onSurfaceVariant.hex))
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(isHeader ? Color(hex: p.primaryContainer.hex).opacity(0.4) : Color.clear)
    }

    /// Flattens inline runs into a single styled `Text` (recursive for bold/italic/strike).
    private func inlineText(_ runs: [MarkdownInlineRun], palette p: DMSPalette) -> Text {
        Text(attributed(runs, palette: p))
    }

    /// Builds an `AttributedString` from inline runs so per-run styling (color, weight,
    /// strike, underline) composes inside one wrapping `Text`.
    private func attributed(_ runs: [MarkdownInlineRun], palette p: DMSPalette, baseSize: CGFloat = 13) -> AttributedString {
        var result = AttributedString()
        for run in runs {
            switch run {
            case .text(let string):
                var a = AttributedString(string)
                a.font = .systemFont(ofSize: baseSize)
                a.foregroundColor = NSColor(Color(hex: p.onSurface.hex))
                result.append(a)
            case .bold(let inner):
                var a = attributed(inner, palette: p, baseSize: baseSize)
                a.font = .systemFont(ofSize: baseSize, weight: .bold)
                result.append(a)
            case .italic(let inner):
                var a = attributed(inner, palette: p, baseSize: baseSize)
                let base = NSFont.systemFont(ofSize: baseSize)
                a.font = NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
                result.append(a)
            case .strikethrough(let inner):
                var a = attributed(inner, palette: p, baseSize: baseSize)
                a.strikethroughStyle = .single
                result.append(a)
            case .code(let code):
                var a = AttributedString(code)
                a.font = .monospacedSystemFont(ofSize: baseSize - 1, weight: .regular)
                a.foregroundColor = NSColor(Color(hex: p.primary.hex))
                result.append(a)
            case .link(let text, _):
                var a = AttributedString(text)
                a.font = .systemFont(ofSize: baseSize)
                a.foregroundColor = NSColor(Color(hex: p.primary.hex))
                a.underlineStyle = .single
                result.append(a)
            }
        }
        return result
    }
}
