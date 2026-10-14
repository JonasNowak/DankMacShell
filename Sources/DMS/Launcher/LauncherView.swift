import SwiftUI
import AppKit
import DMSCore

public struct LauncherView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isFieldFocused: Bool

    public var onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    private var searchResult: (math: MathResult?, results: [SearchResult]) {
        AppCatalogService.shared.search(query: query)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Search Pill Input
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.primary)

                TextField("Search apps, calculate, or type commands...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(theme.onSurface)
                    .focused($isFieldFocused)
                    .onSubmit {
                        executeSelection()
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                        selectedIndex = 0
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(theme.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.primary.opacity(0.6), lineWidth: 1.5)
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // MARK: - Calculator Result (if query is math)
            if let math = searchResult.math {
                Button {
                    copyToClipboard(text: math.result)
                    onClose()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "equal.circle.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(theme.primary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(math.expression)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(theme.onSurfaceVariant)

                            Text(math.result)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(theme.primary)
                        }

                        Spacer()

                        Text("Press ↵ to copy")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(theme.outline)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(theme.primaryContainer.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // MARK: - Results List
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 4) {
                        let list = searchResult.results
                        if list.isEmpty && !query.isEmpty && searchResult.math == nil {
                            // Web Search Fallback
                            Button {
                                openWebSearch(query: query)
                                onClose()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(theme.primary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Search the Web for '\(query)'")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundColor(theme.onSurface)

                                        Text("Opens default browser")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(theme.onSurfaceVariant)
                                    }

                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundColor(theme.outline)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(theme.surfaceContainerHigh)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        } else {
                            ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                                LauncherItemRow(
                                    item: item.app,
                                    isSelected: index == selectedIndex,
                                    onSelect: {
                                        launchApp(item.app)
                                    }
                                )
                                .id(index)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 380)
            }

            // MARK: - Footer
            HStack {
                HStack(spacing: 4) {
                    Text("↑↓ Navigate")
                    Text("•")
                    Text("↵ Open")
                    Text("•")
                    Text("Esc Dismiss")
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(theme.outline)

                Spacer()

                Text("\(searchResult.results.count) results")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.outline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.surfaceContainerLow)
        }
        .frame(width: 580)
        .background(theme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.outlineVariant.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 25, x: 0, y: 10)
        .onAppear {
            isFieldFocused = true
            selectedIndex = 0
        }
        .onKeyPress(.downArrow) {
            let maxIdx = max(0, searchResult.results.count - 1)
            if selectedIndex < maxIdx {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }

    private func executeSelection() {
        if let math = searchResult.math {
            copyToClipboard(text: math.result)
            onClose()
            return
        }

        let list = searchResult.results
        if !list.isEmpty && selectedIndex < list.count {
            launchApp(list[selectedIndex].app)
        } else if !query.isEmpty {
            openWebSearch(query: query)
            onClose()
        }
    }

    private func launchApp(_ app: AppItem) {
        RunningAppsService.shared.activate(app: app)
        onClose()
    }

    private func copyToClipboard(text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        ToastCenter.shared.show(
            icon: "doc.on.clipboard.fill",
            message: "Copied \(text) to clipboard"
        )
    }

    private func openWebSearch(query: String) {
        if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://duckduckgo.com/?q=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Row representing an application in the DLauncherV2 results list.
public struct LauncherItemRow: View {
    public let item: AppItem
    public let isSelected: Bool
    public let onSelect: () -> Void

    @ObservedObject private var theme = ThemeStore.shared

    public var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                AppIconImage(path: item.path, size: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? theme.onPrimary : theme.onSurface)

                    Text(item.bundleID)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(isSelected ? theme.onPrimary.opacity(0.8) : theme.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.onPrimary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? theme.primary : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
