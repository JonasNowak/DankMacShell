import SwiftUI
import AppKit
import DMSCore

/// In-memory icon cache for smooth 60/120fps scrolling and rapid launcher responsiveness.
@MainActor
public final class AppIconCache {
    public static let shared = AppIconCache()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 600
    }

    public func icon(forPath path: String) -> NSImage {
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let image: NSImage
        if FileManager.default.fileExists(atPath: path) {
            image = NSWorkspace.shared.icon(forFile: path)
        } else {
            image = NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
        }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// Unified command palette and application launcher for macOS (DLauncherV2).
/// Follows `docs/spec/18-launcher.md` and matches the dark design in `launcher_dark.png`.
public struct LauncherView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var clipboard = ClipboardService.shared

    @State private var query: String
    @State private var selectedIndex: Int = 0
    @State private var selectedFileIndex: Int = 0
    @State private var viewMode: LauncherViewMode = .list
    @State private var showActionPanel: Bool = false
    @State private var asyncFileResults: [FileItem] = []
    @State private var isSearchingFiles: Bool = false
    @State private var searchWarning: String? = nil
    @State private var searchHealthState: DankSearchHealthState = .healthy
    @State private var fileSearchTask: Task<Void, Never>? = nil
    @FocusState private var isFieldFocused: Bool

    public var onClose: () -> Void

    public init(initialQuery: String = "", onClose: @escaping () -> Void) {
        self._query = State(initialValue: initialQuery)
        self.onClose = onClose
    }

    private var isFileSearch: Bool {
        AppSearch.isFileSearchQuery(query)
    }

    private var fileQuery: String {
        AppSearch.extractFileQuery(query)
    }

    private var appSearchResult: (math: MathResult?, results: [SearchResult]) {
        if isFileSearch {
            return (nil, [])
        }
        return AppCatalogService.shared.search(query: query)
    }

    private var fileResults: [FileItem] {
        asyncFileResults
    }

    private var currentApps: [AppItem] {
        appSearchResult.results.map(\.app)
    }

    private var safeSelectedIndex: Int {
        let apps = currentApps
        guard !apps.isEmpty else { return 0 }
        return min(max(0, selectedIndex), apps.count - 1)
    }

    private var selectedApp: AppItem? {
        let apps = currentApps
        guard !apps.isEmpty else { return nil }
        return apps[safeSelectedIndex]
    }

    private var safeSelectedFileIndex: Int {
        let files = fileResults
        guard !files.isEmpty else { return 0 }
        return min(max(0, selectedFileIndex), files.count - 1)
    }

    private var selectedFile: FileItem? {
        let files = fileResults
        guard !files.isEmpty else { return nil }
        return files[safeSelectedFileIndex]
    }

    private func triggerDebouncedFileSearch(for rawQuery: String, immediate: Bool = false) {
        fileSearchTask?.cancel()

        guard AppSearch.isFileSearchQuery(rawQuery) else {
            asyncFileResults = []
            isSearchingFiles = false
            searchWarning = nil
            return
        }

        let clean = AppSearch.extractFileQuery(rawQuery).trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else {
            asyncFileResults = []
            isSearchingFiles = false
            searchWarning = nil
            return
        }

        isSearchingFiles = true
        fileSearchTask = Task { @MainActor in
            if !immediate {
                try? await Task.sleep(nanoseconds: 120_000_000) // 120ms input debounce
            }
            guard !Task.isCancelled else { return }

            let response = await AppSearch.searchFilesAsync(query: clean, maxResults: 12)
            guard !Task.isCancelled else { return }

            self.asyncFileResults = response.items
            self.searchWarning = response.userWarning
            self.searchHealthState = response.healthState
            self.isSearchingFiles = false
        }
    }

    public var body: some View {
        let curApps = currentApps
        let curFiles = fileResults
        let curSelectedApp = selectedApp
        let curSelectedFile = selectedFile
        let math = appSearchResult.math

        HStack(spacing: 0) {
            // MARK: - Main Launcher Pane
            VStack(spacing: 0) {
                // Top Search & Mode Switcher Bar (matches launcher_dark.png)
                HStack(spacing: 12) {
                    // Search Pill Input
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.primary)

                        TextField("Search apps, calculate, or 'file: <name>'...", text: $query)
                            .textFieldStyle(.plain)
                            .font(theme.font(size: 15, weight: .medium))
                            .foregroundColor(theme.onSurface)
                            .focused($isFieldFocused)
                            .onSubmit {
                                executeSelection()
                            }
                            .onChange(of: query) { _, newQuery in
                                selectedIndex = 0
                                selectedFileIndex = 0
                                triggerDebouncedFileSearch(for: newQuery)
                            }

                        if isSearchingFiles {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.75)
                        }

                        if !query.isEmpty {
                            Button {
                                query = ""
                                selectedIndex = 0
                                selectedFileIndex = 0
                                asyncFileResults = []
                                searchWarning = nil
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
                    .frame(height: 52)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(RoundedRectangle(cornerRadius: theme.scaledRadius(16), style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.scaledRadius(16), style: .continuous)
                            .stroke(theme.primary.opacity(0.75), lineWidth: 1.5)
                    )

                    // View Mode Switcher: List vs Grid/Tile (matches launcher_dark.png)
                    HStack(spacing: 4) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewMode = .list
                            }
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(viewMode == .list ? theme.onSurface : theme.onSurfaceVariant.opacity(0.6))
                                .frame(width: 36, height: 36)
                                .background(viewMode == .list ? theme.surfaceContainerHighest : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: theme.scaledRadius(10), style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("List View")

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewMode = .tile
                            }
                        } label: {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(viewMode == .tile ? theme.onSurface : theme.onSurfaceVariant.opacity(0.6))
                                .frame(width: 36, height: 36)
                                .background(viewMode == .tile ? theme.surfaceContainerHighest : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: theme.scaledRadius(10), style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Grid / Tile View")
                    }
                    .padding(4)
                    .background(theme.surfaceContainerHigh.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: theme.scaledRadius(14), style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Non-intrusive DankSearch Fallback / Recovery Status Banner (Requirement 1)
                if let warning = searchWarning {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.warning)

                        Text(warning)
                            .font(theme.font(size: 11, weight: .medium))
                            .foregroundColor(theme.onSurface)
                            .lineLimit(2)

                        Spacer()

                        Button {
                            DankSearchClient.shared.resetHealthState()
                            searchWarning = nil
                            triggerDebouncedFileSearch(for: query, immediate: true)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Retry")
                                    .font(theme.font(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.warningContainer.opacity(0.6))
                            .foregroundColor(theme.onWarningContainer)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.surfaceContainerHigh.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: theme.scaledRadius(10), style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.scaledRadius(10), style: .continuous)
                            .stroke(theme.warning.opacity(0.45), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // Calculator Result Card (if query is a math expression)
                if let math = math {
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
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }

                // Results Container
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        if isFileSearch {
                            // MARK: - Dedicated File Search Results
                            if curFiles.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(.system(size: 32))
                                        .foregroundColor(theme.outline)
                                        .padding(.top, 24)

                                    Text(fileQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? "Type a filename or path to search..."
                                         : (isSearchingFiles ? "Searching files..." : "No files matching '\(fileQuery)'"))
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(theme.onSurfaceVariant)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                            } else {
                                LazyVStack(spacing: 6) {
                                    ForEach(curFiles) { file in
                                        FileItemRow(
                                            file: file,
                                            isSelected: file.id == curSelectedFile?.id
                                        ) {
                                            openFile(file.path)
                                            onClose()
                                        }
                                        .id(file.id)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            }
                        } else if curApps.isEmpty && math == nil && !query.isEmpty {
                            webSearchFallbackRow
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                        } else {
                            if viewMode == .list {
                                // MARK: - List Mode (matches launcher_dark.png)
                                LazyVStack(spacing: 6) {
                                    ForEach(curApps) { app in
                                        LauncherItemRow(
                                            item: app,
                                            isSelected: app.id == curSelectedApp?.id,
                                            onSelect: { launchApp(app) },
                                            onTogglePin: { togglePin(app) },
                                            onShowInFinder: { showInFinder(app) },
                                            onCopyID: { copyToClipboard(text: app.bundleID) },
                                            onCopyPath: { copyToClipboard(text: app.path) }
                                        )
                                        .id(app.id)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            } else {
                                // MARK: - Grid / Tile Mode (LAUNCH-002)
                                LazyVGrid(
                                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                                    spacing: 10
                                ) {
                                    ForEach(curApps) { app in
                                        LauncherTileItem(
                                            item: app,
                                            isSelected: app.id == curSelectedApp?.id,
                                            onSelect: { launchApp(app) },
                                            onTogglePin: { togglePin(app) },
                                            onShowInFinder: { showInFinder(app) },
                                            onCopyID: { copyToClipboard(text: app.bundleID) },
                                            onCopyPath: { copyToClipboard(text: app.path) }
                                        )
                                        .id(app.id)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            }
                        }
                    }
                    .frame(maxHeight: 410)
                    .onChange(of: isFileSearch ? curSelectedFile?.id : curSelectedApp?.id) { _, targetID in
                        if let id = targetID {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                // Footer (Shortcuts & Status)
                HStack {
                    HStack(spacing: 6) {
                        Text("↑↓ Navigate")
                        Text("•")
                        Text("↵ Open")
                        Text("•")
                        Text("Tab Actions")
                        Text("•")
                        Text("Esc Dismiss")
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.outline)

                    Spacer()

                    HStack(spacing: 8) {
                        if curSelectedApp != nil {
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    showActionPanel.toggle()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 10))
                                    Text(showActionPanel ? "Hide Actions" : "Actions")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(theme.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(theme.primaryContainer.opacity(0.3))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        Text("DLauncherV2")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.surfaceContainerLow)
            }
            .frame(width: 680)

            // MARK: - ActionPanel Sidebar (Spec 18-launcher.md Section 0 & 3)
            if showActionPanel, let app = curSelectedApp {
                Divider()
                    .background(theme.outlineVariant.opacity(0.4))

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        AppIconImage(path: app.path, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(theme.onSurface)
                                .lineLimit(1)
                            Text(app.subtitle)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(theme.onSurfaceVariant)
                                .lineLimit(2)
                        }
                    }
                    .padding(.top, 16)

                    if !app.category.isEmpty {
                        Text(app.category.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.primaryContainer.opacity(0.5))
                            .foregroundColor(theme.primary)
                            .clipShape(Capsule())
                    }

                    Divider()
                        .background(theme.outlineVariant.opacity(0.3))

                    VStack(spacing: 8) {
                        ActionPanelButton(
                            title: "Open Application",
                            icon: "arrow.forward.circle.fill",
                            theme: theme
                        ) {
                            launchApp(app)
                        }

                        let isPinned = ConfigStore.shared.config.pinnedApps.contains(app.bundleID)
                        ActionPanelButton(
                            title: isPinned ? "Unpin from Dock" : "Pin to Dock",
                            icon: isPinned ? "pin.slash.fill" : "pin.fill",
                            theme: theme
                        ) {
                            togglePin(app)
                        }

                        ActionPanelButton(
                            title: "Show in Finder",
                            icon: "folder.fill",
                            theme: theme
                        ) {
                            showInFinder(app)
                        }

                        ActionPanelButton(
                            title: "Open in Terminal",
                            icon: "terminal.fill",
                            theme: theme
                        ) {
                            openInTerminal(app)
                        }

                        ActionPanelButton(
                            title: "Copy Bundle ID",
                            icon: "doc.on.doc.fill",
                            theme: theme
                        ) {
                            copyToClipboard(text: app.bundleID)
                        }

                        ActionPanelButton(
                            title: "Copy Path",
                            icon: "link",
                            theme: theme
                        ) {
                            copyToClipboard(text: app.path)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(width: 220)
                .background(theme.surfaceContainerHigh.opacity(0.5))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(theme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(theme.outlineVariant.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 30, x: 0, y: 12)
        .onAppear {
            isFieldFocused = true
            selectedIndex = 0
            selectedFileIndex = 0
            if !query.isEmpty {
                triggerDebouncedFileSearch(for: query, immediate: true)
            }
        }
        .onDisappear {
            fileSearchTask?.cancel()
        }
        .onKeyPress(.downArrow) {
            navigate(delta: (!isFileSearch && viewMode == .tile) ? 5 : 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            navigate(delta: (!isFileSearch && viewMode == .tile) ? -5 : -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if !isFileSearch && viewMode == .tile {
                navigate(delta: 1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.leftArrow) {
            if !isFileSearch && viewMode == .tile {
                navigate(delta: -1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.tab) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                showActionPanel.toggle()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if showActionPanel {
                withAnimation { showActionPanel = false }
            } else {
                onClose()
            }
            return .handled
        }
    }

    private func navigate(delta: Int) {
        if isFileSearch {
            let files = fileResults
            guard !files.isEmpty else { return }
            let next = max(0, min(files.count - 1, safeSelectedFileIndex + delta))
            selectedFileIndex = next
        } else {
            let apps = currentApps
            guard !apps.isEmpty else { return }
            let next = max(0, min(apps.count - 1, safeSelectedIndex + delta))
            selectedIndex = next
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(theme.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func executeSelection() {
        if let math = appSearchResult.math {
            copyToClipboard(text: math.result)
            onClose()
            return
        }

        if isFileSearch {
            if let file = selectedFile {
                openFile(file.path)
                onClose()
            }
            return
        }

        if let app = selectedApp {
            launchApp(app)
            return
        }

        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            openWebSearch(query: clean)
            onClose()
        }
    }

    private func launchApp(_ app: AppItem) {
        AppCatalogService.shared.recordLaunch(app: app)
        RunningAppsService.shared.activate(app: app)
        onClose()
    }

    private func togglePin(_ app: AppItem) {
        RunningAppsService.shared.togglePin(bundleID: app.bundleID)
    }

    private func showInFinder(_ app: AppItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
        onClose()
    }

    private func openInTerminal(_ app: AppItem) {
        let terminal = ConfigStore.shared.config.apps.terminal
        if let termApp = AppCatalogService.shared.apps.first(where: { $0.name.localizedCaseInsensitiveContains(terminal) }) {
            RunningAppsService.shared.activate(app: termApp)
        }
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

/// Action panel row button in DLauncherV2.
private struct ActionPanelButton: View {
    let title: String
    let icon: String
    let theme: ThemeStore
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(theme.primary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(theme.onSurface)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(theme.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// List View Row representing an application (matches `launcher_dark.png`).
public struct LauncherItemRow: View {
    public let item: AppItem
    public let isSelected: Bool
    public let onSelect: () -> Void
    public var onTogglePin: (() -> Void)? = nil
    public var onShowInFinder: (() -> Void)? = nil
    public var onCopyID: (() -> Void)? = nil
    public var onCopyPath: (() -> Void)? = nil

    @ObservedObject private var theme = ThemeStore.shared
    @State private var isHovered = false

    public var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 14) {
                AppIconImage(path: item.path, size: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.onSurface)

                    Text(item.subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(theme.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.primary.opacity(0.85))
                        .padding(.trailing, 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(height: 54)
            .background(
                isSelected
                    ? theme.surfaceContainerHighest.opacity(0.85)
                    : (isHovered ? theme.surfaceContainerHigh.opacity(0.9) : theme.surfaceContainerHigh.opacity(0.55))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? theme.primary.opacity(0.35) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open \(item.name)") { onSelect() }
            Divider()
            if let pin = onTogglePin {
                let isPinned = ConfigStore.shared.config.pinnedApps.contains(item.bundleID)
                Button(isPinned ? "Unpin from Dock" : "Pin to Dock") { pin() }
            }
            if let show = onShowInFinder {
                Button("Show in Finder") { show() }
            }
            Divider()
            if let copyID = onCopyID {
                Button("Copy Bundle Identifier") { copyID() }
            }
            if let copyPath = onCopyPath {
                Button("Copy Path") { copyPath() }
            }
        }
    }
}

/// Grid / Tile View Item representing an application (LAUNCH-002).
public struct LauncherTileItem: View {
    public let item: AppItem
    public let isSelected: Bool
    public let onSelect: () -> Void
    public var onTogglePin: (() -> Void)? = nil
    public var onShowInFinder: (() -> Void)? = nil
    public var onCopyID: (() -> Void)? = nil
    public var onCopyPath: (() -> Void)? = nil

    @ObservedObject private var theme = ThemeStore.shared
    @State private var isHovered = false

    public var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: 8) {
                AppIconImage(path: item.path, size: 48)

                Text(item.name)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 104)
            .background(
                isSelected
                    ? theme.surfaceContainerHighest.opacity(0.85)
                    : (isHovered ? theme.surfaceContainerHigh.opacity(0.9) : theme.surfaceContainerHigh.opacity(0.55))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? theme.primary.opacity(0.4) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open \(item.name)") { onSelect() }
            Divider()
            if let pin = onTogglePin {
                let isPinned = ConfigStore.shared.config.pinnedApps.contains(item.bundleID)
                Button(isPinned ? "Unpin from Dock" : "Pin to Dock") { pin() }
            }
            if let show = onShowInFinder {
                Button("Show in Finder") { show() }
            }
            Divider()
            if let copyID = onCopyID {
                Button("Copy Bundle Identifier") { copyID() }
            }
            if let copyPath = onCopyPath {
                Button("Copy Path") { copyPath() }
            }
        }
    }
}

/// Performant, cached application icon image delegate.
public struct AppIconImage: View {
    public let path: String
    public let size: CGFloat

    public init(path: String, size: CGFloat = 36) {
        self.path = path
        self.size = size
    }

    public var body: some View {
        let icon = AppIconCache.shared.icon(forPath: path)
        Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

/// Row representing a file result in DLauncherV2.
public struct FileItemRow: View {
    public let file: FileItem
    public var isSelected: Bool = false
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

                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.primary.opacity(0.85))
                        .padding(.trailing, 4)
                } else {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 12))
                        .foregroundColor(theme.outline)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? theme.surfaceContainerHighest.opacity(0.85)
                    : theme.surfaceContainerHigh.opacity(0.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? theme.primary.opacity(0.35) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
