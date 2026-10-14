import SwiftUI
import AppKit
import DMSCore

public struct LauncherView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var clipboard = ClipboardService.shared
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var activeTab: LauncherTab = .all
    @FocusState private var isFieldFocused: Bool

    public var onClose: () -> Void

    public enum LauncherTab: String, CaseIterable, Identifiable {
        case all = "All"
        case apps = "Apps"
        case files = "Files"
        case calc = "Calc"
        case clipboard = "Clipboard"
        case emojis = "Emojis"

        public var id: String { rawValue }
    }

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    private var appSearchResult: (math: MathResult?, results: [SearchResult]) {
        AppCatalogService.shared.search(query: query)
    }

    private var fileResults: [FileItem] {
        guard !query.isEmpty else { return [] }
        return AppSearch.searchFiles(query: query, maxResults: 12)
    }

    private var emojiResults: [EmojiItem] {
        AppSearch.searchEmojis(query: query)
    }

    private var clipboardResults: [ClipboardItem] {
        if query.isEmpty {
            return Array(clipboard.items.prefix(10))
        }
        return Array(clipboard.search(query: query).prefix(10))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Search Pill Input
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.primary)

                TextField("Search apps, files, calculate, or emojis...", text: $query)
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

            // MARK: - Category Filter Chips Row
            HStack(spacing: 8) {
                ForEach(LauncherTab.allCases) { tab in
                    Button(action: {
                        activeTab = tab
                        selectedIndex = 0
                    }) {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: activeTab == tab ? .bold : .medium, design: .rounded))
                            .foregroundColor(activeTab == tab ? theme.onPrimary : theme.onSurfaceVariant)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(activeTab == tab ? theme.primary : theme.surfaceContainerHigh)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // MARK: - Calculator Result Card (if query is math)
            if (activeTab == .all || activeTab == .calc), let math = appSearchResult.math {
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
                .padding(.top, 10)
            }

            // MARK: - Results List
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 4) {
                    switch activeTab {
                    case .all:
                        // Apps section
                        let appList = appSearchResult.results
                        if !appList.isEmpty {
                            ForEach(Array(appList.prefix(8).enumerated()), id: \.element.id) { index, item in
                                LauncherItemRow(
                                    item: item.app,
                                    isSelected: index == selectedIndex,
                                    onSelect: { launchApp(item.app) }
                                )
                            }
                        }

                        // Files section
                        let files = fileResults
                        if !files.isEmpty {
                            HStack {
                                Text("FILES")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(theme.primary)
                                Spacer()
                            }
                            .padding(.top, 6)
                            .padding(.horizontal, 6)

                            ForEach(files.prefix(5)) { file in
                                FileItemRow(file: file) {
                                    openFile(file.path)
                                    onClose()
                                }
                            }
                        }

                        // Web search fallback if no local results
                        if appList.isEmpty && files.isEmpty && appSearchResult.math == nil && !query.isEmpty {
                            webSearchFallbackRow
                        }

                    case .apps:
                        let list = appSearchResult.results
                        if list.isEmpty && !query.isEmpty {
                            webSearchFallbackRow
                        } else {
                            ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                                LauncherItemRow(
                                    item: item.app,
                                    isSelected: index == selectedIndex,
                                    onSelect: { launchApp(item.app) }
                                )
                            }
                        }

                    case .files:
                        let files = fileResults
                        if files.isEmpty {
                            Text(query.isEmpty ? "Type to search files in Documents, Downloads, Desktop..." : "No matching files")
                                .font(.system(size: 13))
                                .foregroundColor(theme.outline)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(files) { file in
                                FileItemRow(file: file) {
                                    openFile(file.path)
                                    onClose()
                                }
                            }
                        }

                    case .calc:
                        if appSearchResult.math != nil {
                            EmptyView()
                        } else {
                            Text("Type a math expression like '15% of 80', '24 * 60', or '1024 / 8'")
                                .font(.system(size: 13))
                                .foregroundColor(theme.outline)
                                .padding(.vertical, 24)
                        }

                    case .clipboard:
                        let clips = clipboardResults
                        if clips.isEmpty {
                            Text("Clipboard history is empty")
                                .font(.system(size: 13))
                                .foregroundColor(theme.outline)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(clips) { clip in
                                Button(action: {
                                    clipboard.copyItem(text: clip.text)
                                    onClose()
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: clip.isURL ? "link" : "doc.plaintext")
                                            .foregroundColor(theme.primary)
                                            .frame(width: 24, height: 24)
                                        Text(clip.preview)
                                            .font(.system(size: 13))
                                            .foregroundColor(theme.onSurface)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(clip.createdAt.formatted(date: .omitted, time: .shortened))
                                            .font(.system(size: 11))
                                            .foregroundColor(theme.outline)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(theme.surfaceContainerHigh)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                    case .emojis:
                        let emojis = emojiResults
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                            ForEach(emojis) { emojiItem in
                                Button(action: {
                                    copyToClipboard(text: emojiItem.emoji)
                                    onClose()
                                }) {
                                    VStack(spacing: 4) {
                                        Text(emojiItem.emoji)
                                            .font(.system(size: 26))
                                        Text(emojiItem.name)
                                            .font(.system(size: 10))
                                            .foregroundColor(theme.onSurfaceVariant)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(theme.surfaceContainerHigh)
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(maxHeight: 380)

            // MARK: - Footer
            HStack {
                HStack(spacing: 4) {
                    Text("↑↓ Navigate")
                    Text("•")
                    Text("↵ Open / Copy")
                    Text("•")
                    Text("Esc Dismiss")
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(theme.outline)

                Spacer()

                Text("DLauncherV2")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primary)
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
            let maxIdx = max(0, appSearchResult.results.count - 1)
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

    @ViewBuilder
    private var webSearchFallbackRow: some View {
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

                    Text("Opens in default browser")
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
    }

    private func executeSelection() {
        if let math = appSearchResult.math {
            copyToClipboard(text: math.result)
            onClose()
            return
        }

        let list = appSearchResult.results
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

    private func openFile(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func copyToClipboard(text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        ToastCenter.shared.show(
            icon: "doc.on.clipboard.fill",
            message: "Copied '\(text)'"
        )
    }

    private func openWebSearch(query: String) {
        if let url = AppSearch.webSearchURL(query: query, provider: ConfigStore.shared.config.webSearchProvider) {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Row representing a file result in DLauncherV2.
public struct FileItemRow: View {
    public let file: FileItem
    public let onSelect: () -> Void

    @ObservedObject private var theme = ThemeStore.shared

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: file.sfSymbol)
                    .font(.system(size: 16))
                    .foregroundColor(theme.primary)
                    .frame(width: 28, height: 28)
                    .background(theme.primaryContainer.opacity(0.4))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.onSurface)

                    Text(file.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(theme.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 12))
                    .foregroundColor(theme.outline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.surfaceContainerHigh)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
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
