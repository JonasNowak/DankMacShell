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
            inlineText(
                runs,
                palette: p,
                baseFont: .systemFont(ofSize: headingSize(level), weight: .bold),
                baseColor: NSColor(Color(hex: p.onSurface.hex))
            )

        case .paragraph(let runs):
            inlineText(
                runs,
                palette: p,
                baseFont: .systemFont(ofSize: 13),
                baseColor: NSColor(Color(hex: p.onSurface.hex))
            )
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
                inlineText(
                    runs,
                    palette: p,
                    baseFont: .systemFont(ofSize: 13, weight: .regular),
                    baseColor: NSColor(Color(hex: p.onSurfaceVariant.hex))
                )
                .fixedSize(horizontal: false, vertical: true)
            }

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: p.primary.hex))
                        inlineText(
                            item,
                            palette: p,
                            baseFont: .systemFont(ofSize: 13),
                            baseColor: NSColor(Color(hex: p.onSurface.hex))
                        )
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
                        inlineText(
                            item,
                            palette: p,
                            baseFont: .systemFont(ofSize: 13),
                            baseColor: NSColor(Color(hex: p.onSurface.hex))
                        )
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .table(let header, let rows):
            VStack(alignment: .leading, spacing: 0) {
                tableRow(header.map { inlineText($0, palette: p, baseFont: .systemFont(ofSize: 11, weight: .bold), baseColor: NSColor(Color(hex: p.onSurface.hex))) }, palette: p, isHeader: true)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    tableRow(row.map { inlineText($0, palette: p, baseFont: .systemFont(ofSize: 11), baseColor: NSColor(Color(hex: p.onSurfaceVariant.hex))) }, palette: p, isHeader: false)
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
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(isHeader ? Color(hex: p.primaryContainer.hex).opacity(0.4) : Color.clear)
    }

    /// Flattens inline runs into a single styled `Text` (recursive for bold/italic/strike).
    private func inlineText(_ runs: [MarkdownInlineRun], palette p: DMSPalette, baseFont: NSFont? = nil, baseColor: NSColor? = nil) -> Text {
        Text(attributed(runs, palette: p, baseFont: baseFont, baseColor: baseColor))
    }

    /// Builds an `AttributedString` from inline runs so per-run styling (color, weight,
    /// strike, underline) composes inside one wrapping `Text`. `baseFont`/`baseColor`
    /// carry the block-level typography so inline runs never override heading sizes or
    /// blockquote colors.
    private func attributed(_ runs: [MarkdownInlineRun], palette p: DMSPalette, baseFont: NSFont? = nil, baseColor: NSColor? = nil) -> AttributedString {
        attributed(
            runs,
            palette: p,
            baseFont: baseFont ?? .systemFont(ofSize: 13),
            baseColor: baseColor ?? NSColor(Color(hex: p.onSurface.hex)),
            traits: []
        )
    }

    private func attributed(_ runs: [MarkdownInlineRun], palette p: DMSPalette, baseFont: NSFont, baseColor: NSColor, traits: NSFontTraitMask) -> AttributedString {
        let styledFont = traits.isEmpty ? Font(baseFont) : Font(NSFontManager.shared.convert(baseFont, toHaveTrait: traits))
        var result = AttributedString()
        for run in runs {
            switch run {
            case .text(let string):
                var a = AttributedString(string)
                a.font = styledFont
                a.foregroundColor = baseColor
                result.append(a)
            case .bold(let inner):
                result.append(attributed(inner, palette: p, baseFont: baseFont, baseColor: baseColor, traits: traits.union(.boldFontMask)))
            case .italic(let inner):
                result.append(attributed(inner, palette: p, baseFont: baseFont, baseColor: baseColor, traits: traits.union(.italicFontMask)))
            case .strikethrough(let inner):
                var a = attributed(inner, palette: p, baseFont: baseFont, baseColor: baseColor, traits: traits)
                a.strikethroughStyle = .single
                result.append(a)
            case .code(let code):
                var a = AttributedString(code)
                a.font = Font.system(size: max(9, baseFont.pointSize - 1), weight: .regular, design: .monospaced)
                a.foregroundColor = NSColor(Color(hex: p.primary.hex))
                result.append(a)
            case .link(let text, let url):
                var a = AttributedString(text)
                a.font = styledFont
                a.foregroundColor = NSColor(Color(hex: p.primary.hex))
                a.underlineStyle = .single
                if let linkURL = URL(string: url) {
                    a.link = linkURL
                }
                result.append(a)
            }
        }
        return result
    }
}
