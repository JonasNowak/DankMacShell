import SwiftUI
import DMSCore

/// Material 3 Clipboard History manager modal view.
public struct ClipboardView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var clipboard = ClipboardService.shared
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0

    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    private var filteredItems: [ClipboardItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return clipboard.items
        }
        return clipboard.search(query: searchText)
    }

    public var body: some View {
        let p = themeStore.palette

        VStack(spacing: 0) {
            // Search & Header Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: p.primary.hex))

                TextField("Search clipboard history...", text: $searchText)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .foregroundColor(Color(hex: p.onSurface.hex))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(hex: p.outline.hex))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if !clipboard.items.isEmpty {
                    Button(action: { clipboard.clearAll() }) {
                        Label("Clear", systemImage: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: p.error.hex))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: p.errorContainer.hex).opacity(0.4))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: p.surfaceVariant.hex))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(hex: p.surfaceContainerHigh.hex))

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Clips List
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clipboard")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: p.outline.hex))
                    Text(clipboard.items.isEmpty ? "Clipboard is empty" : "No matches found")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            Button(action: {
                                clipboard.copyItem(text: item.text)
                                onClose()
                            }) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: item.isURL ? "link" : (item.lineCount > 1 ? "doc.plaintext" : "text.quote"))
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: p.primary.hex))
                                        .frame(width: 28, height: 28)
                                        .background(Color(hex: p.primaryContainer.hex))
                                        .cornerRadius(8)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.preview)
                                            .font(.system(size: 13, design: item.lineCount > 1 ? .monospaced : .default))
                                            .foregroundColor(Color(hex: p.onSurface.hex))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)

                                        HStack(spacing: 8) {
                                            Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                                            Text("•")
                                            Text("\(item.characterCount) chars")
                                            if item.lineCount > 1 {
                                                Text("•")
                                                Text("\(item.lineCount) lines")
                                            }
                                        }
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: p.outline.hex))
                                    }

                                    Spacer()

                                    Button(action: { clipboard.removeItem(id: item.id) }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color(hex: p.outline.hex))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(index == selectedIndex ? Color(hex: p.secondaryContainer.hex).opacity(0.4) : Color(hex: p.surfaceContainerLow.hex))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
            }

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Footer
            HStack {
                Text("\(filteredItems.count) items in history")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: p.outline.hex))

                Spacer()

                Text("Click to copy & paste • Esc to dismiss")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: p.outline.hex))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: p.surfaceContainerHigh.hex))
        }
        .frame(width: 480, height: 440)
        .background(Color(hex: p.surface.hex))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: p.outlineVariant.hex).opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 12)
    }
}
