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
    // AppCatalogService / RunningAppsService are `@Observable`, so plain stored properties
    // are tracked by the Observation framework (no `@ObservedObject` wrapper needed).
    private let appCatalog = AppCatalogService.shared
    private let runningApps = RunningAppsService.shared
    @ObservedObject private var configStore = ConfigStore.shared

    /// Fresh per-presentation identity; applied via `.id(sessionID)` so SwiftUI recreates
    /// all `@State` and re-runs `.onAppear` on every `show` / `showDMenu` call.
    public let sessionID: UUID

    @State private var query: String
    @State private var selectedIndex: Int = 0
    @State private var selectedFileIndex: Int = 0
    @State private var selectedEmojiIndex: Int = 0
    @State private var viewMode: LauncherViewMode = .list
    @State private var showActionPanel: Bool = false
    @State private var asyncFileResults: [FileItem] = []
    @State private var isSearchingFiles: Bool = false
    @State private var searchWarning: String? = nil
    @State private var searchHealthState: DankSearchHealthState = .healthy
    @State private var fileSearchTask: Task<Void, Never>? = nil
    @State private var editingApp: AppItem? = nil
    @FocusState private var isFieldFocused: Bool

    // v0.7 CLI: dmenu filter mode state (plain string candidates instead of apps)
    @State private var dmenuRequestID: String? = nil
    @State private var dmenuPrompt: String? = nil
    @State private var dmenuCandidates: [String] = []

    public var onClose: () -> Void
    /// v0.7 CLI: called after a dmenu selection/cancel has been delivered so the controller
    /// can clear its in-flight request ID.
    public var onDMenuResolved: (() -> Void)?

    /// Root background opacity for this floating panel: `floatingWindowTransparency`
    /// (clamped `0.2...1.0`) multiplied into the usual popup/surface opacity.
    private var floatingWindowOpacity: Double {
        let clamped = max(0.2, min(1.0, theme.surfaceTokens.floatingWindowTransparency))
        return clamped * min(theme.surfaceTokens.popupTransparency, theme.surfaceTokens.surfaceOpacity)
    }

    public init(initialQuery: String = "", sessionID: UUID = UUID(), onClose: @escaping () -> Void) {
        self._query = State(initialValue: initialQuery)
        self.sessionID = sessionID
        self.onClose = onClose
        self.onDMenuResolved = nil
    }

    /// v0.7 CLI: dmenu mode — candidates are staged in `candidatesFile` by `dms dmenu`.
    public init(
        dmenuPrompt: String,
        candidatesFile: String,
        requestID: String,
        sessionID: UUID = UUID(),
        onDMenuResolved: (() -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self._query = State(initialValue: "")
        self.sessionID = sessionID
        self.onClose = onClose
        self.onDMenuResolved = onDMenuResolved
        self._dmenuRequestID = State(initialValue: requestID)
        self._dmenuPrompt = State(initialValue: dmenuPrompt)
        self._dmenuCandidates = State(initialValue: DMenuStaging.readCandidates(at: URL(fileURLWithPath: candidatesFile)))
    }

    private var isDMenuMode: Bool {
        dmenuRequestID != nil
    }

    /// Fuzzy-filtered dmenu candidates for the current query.
    private var dmenuResults: [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return dmenuCandidates
        }
        return dmenuCandidates
            .compactMap { candidate -> (String, Int)? in
                guard let score = AppSearch.scoreText(candidate, query: q) else { return nil }
                return (candidate, score)
            }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    private var safeSelectedDMenuIndex: Int {
        let rows = dmenuResults
        guard !rows.isEmpty else { return 0 }
        return min(max(0, selectedIndex), rows.count - 1)
    }

    private var selectedDMenuRow: String? {
        let rows = dmenuResults
        guard !rows.isEmpty else { return nil }
        return rows[safeSelectedDMenuIndex]
    }

    private var isFileSearch: Bool {
        !isDMenuMode && AppSearch.isFileSearchQuery(query)
    }

    private var fileQuery: String {
        AppSearch.extractFileQuery(query)
    }

    /// v0.9.5: emoji / Nerd Font picker mode (`:emoji`, `nf:icon`).
    private var isEmojiSearch: Bool {
        !isDMenuMode && AppSearch.isEmojiQuery(query)
    }

    private var emojiResults: [EmojiItem] {
        isEmojiSearch ? AppSearch.searchEmojis(query: query) : []
    }

    private var safeSelectedEmojiIndex: Int {
        let items = emojiResults
        guard !items.isEmpty else { return 0 }
        return min(max(0, selectedEmojiIndex), items.count - 1)
    }

    private var selectedEmoji: EmojiItem? {
        let items = emojiResults
        guard !items.isEmpty else { return nil }
        return items[safeSelectedEmojiIndex]
    }

    private var appSearchResult: (math: MathResult?, results: [SearchResult]) {
        if isDMenuMode || isFileSearch || isEmojiSearch {
            return (nil, [])
        }
        return appCatalog.search(query: query)
    }

    private var fileResults: [FileItem] {
        asyncFileResults
    }

    private var currentApps: [AppItem] {
        let runningService = runningApps
        return appSearchResult.results.map { res in
            let app = res.app
            let isRunning = runningService.isRunning(bundleID: app.bundleID)
            let isHidden = isRunning ? runningService.isHidden(bundleID: app.bundleID) : false
            if app.isRunning != isRunning || app.isHidden != isHidden {
                return AppItem(
                    id: app.id,
                    name: app.name,
                    bundleID: app.bundleID,
                    path: app.path,
                    subtitle: app.subtitle,
                    category: app.category,
                    isRunning: isRunning,
                    isHidden: isHidden,
                    launchCount: app.launchCount,
                    lastLaunchedAt: app.lastLaunchedAt
                )
            }
            return app
        }
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
                            .font(ThemeStore.shared.font(size: 16, weight: .bold))
                            .foregroundColor(theme.primary)

                        TextField(isDMenuMode ? (dmenuPrompt ?? "Filter...") : "Search apps, calculate, convert, ':emoji', 'nf:icon', or 'file: <name>'...", text: $query)
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
                                selectedEmojiIndex = 0
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
                                selectedEmojiIndex = 0
                                asyncFileResults = []
                                searchWarning = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(ThemeStore.shared.font(size: 14))
                                    .foregroundColor(theme.onSurfaceVariant)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear search")
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
                    if !isDMenuMode {
                    HStack(spacing: 4) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewMode = .list
                            }
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(ThemeStore.shared.font(size: 14, weight: .semibold))
                                .foregroundColor(viewMode == .list ? theme.onSurface : theme.onSurfaceVariant.opacity(0.6))
                                .frame(width: 36, height: 36)
                                .background(viewMode == .list ? theme.surfaceContainerHighest : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: theme.scaledRadius(10), style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("List View")
                        .accessibilityLabel("List view")

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewMode = .tile
                            }
                        } label: {
                            Image(systemName: "square.grid.2x2")
                                .font(ThemeStore.shared.font(size: 14, weight: .semibold))
                                .foregroundColor(viewMode == .tile ? theme.onSurface : theme.onSurfaceVariant.opacity(0.6))
                                .frame(width: 36, height: 36)
                                .background(viewMode == .tile ? theme.surfaceContainerHighest : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: theme.scaledRadius(10), style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Grid / Tile View")
                        .accessibilityLabel("Grid / tile view")
                    }
                    .padding(4)
                    .background(theme.surfaceContainerHigh.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: theme.scaledRadius(14), style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Non-intrusive DankSearch Fallback / Recovery Status Banner (Requirement 1)
                if let warning = searchWarning {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(ThemeStore.shared.font(size: 13, weight: .semibold))
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
                                    .font(ThemeStore.shared.font(size: 10, weight: .bold))
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
                                .font(ThemeStore.shared.font(size: 26, weight: .bold))
                                .foregroundColor(theme.primary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(math.expression)
                                    .font(ThemeStore.shared.font(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(theme.onSurfaceVariant)

                                Text(math.result)
                                    .font(ThemeStore.shared.font(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(theme.primary)
                            }

                            Spacer()

                            Text("Press ↵ to copy")
                                .font(ThemeStore.shared.font(size: 11, weight: .medium, design: .rounded))
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
                        if isDMenuMode {
                            // MARK: - dmenu Filter Mode (v0.7 CLI): plain string rows
                            let rows = dmenuResults
                            if rows.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(ThemeStore.shared.font(size: 32))
                                        .foregroundColor(theme.outline)
                                        .padding(.top, 24)
                                    Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? "Type to filter..."
                                         : "No entries matching '\(query)'")
                                        .font(ThemeStore.shared.font(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(theme.onSurfaceVariant)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                            } else {
                                LazyVStack(spacing: 6) {
                                    ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                                        DMenuRow(
                                            text: row,
                                            isSelected: idx == safeSelectedDMenuIndex
                                        ) {
                                            completeDMenuSelection(row)
                                        }
                                        .id("dmenu-\(idx)")
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            }
                        } else if isFileSearch {
                            // MARK: - Dedicated File Search Results
                            if curFiles.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(ThemeStore.shared.font(size: 32))
                                        .foregroundColor(theme.outline)
                                        .padding(.top, 24)

                                    Text(fileQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? "Type a filename or path to search..."
                                         : (isSearchingFiles ? "Searching files..." : "No files matching '\(fileQuery)'"))
                                        .font(ThemeStore.shared.font(size: 13, weight: .medium, design: .rounded))
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
                        } else if isEmojiSearch {
                            // MARK: - Emoji & Nerd Font Picker (v0.9.5: ':emoji' / 'nf:icon')
                            let emojis = emojiResults
                            if emojis.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "face.smiling")
                                        .font(ThemeStore.shared.font(size: 32))
                                        .foregroundColor(theme.outline)
                                        .padding(.top, 24)

                                    Text("No emojis or Nerd Font glyphs matching '\(query)'")
                                        .font(ThemeStore.shared.font(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(theme.onSurfaceVariant)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                            } else {
                                LazyVStack(spacing: 6) {
                                    ForEach(emojis) { item in
                                        EmojiItemRow(
                                            item: item,
                                            isSelected: item.id == selectedEmoji?.id
                                        ) {
                                            selectEmoji(item)
                                        }
                                        .id(item.id)
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
                            // v0.9.5: a bang query (e.g. "!gh foo") pins the web-search row
                            // at the top of the app results.
                            let webTarget = AppSearch.resolveWebSearch(query: query, defaultProvider: configStore.config.webSearchProvider)
                            VStack(spacing: 0) {
                                if let target = webTarget, target.isBang {
                                    webSearchFallbackRow
                                        .padding(.horizontal, 16)
                                        .padding(.top, 10)
                                        .padding(.bottom, 4)
                                }
                                if viewMode == .list {
                                    // MARK: - List Mode (matches launcher_dark.png)
                                    LazyVStack(spacing: 6) {
                                        ForEach(curApps) { app in
                                            LauncherItemRow(
                                                item: app,
                                                isSelected: app.id == curSelectedApp?.id,
                                                onSelect: { launchApp(app) },
                                                onShowInFinder: { showInFinder(app) },
                                                onUnhideInBackground: { runningApps.unhide(app: app, inBackground: true) },
                                                onHide: { runningApps.hide(app: app) },
                                                onQuit: { runningApps.quit(app: app) },
                                                onCopyID: { copyToClipboard(text: app.bundleID) },
                                                onCopyPath: { copyToClipboard(text: app.path) },
                                                onEdit: { editingApp = app }
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
                                                onShowInFinder: { showInFinder(app) },
                                                onUnhideInBackground: { runningApps.unhide(app: app, inBackground: true) },
                                                onHide: { runningApps.hide(app: app) },
                                                onQuit: { runningApps.quit(app: app) },
                                                onCopyID: { copyToClipboard(text: app.bundleID) },
                                                onCopyPath: { copyToClipboard(text: app.path) },
                                                onEdit: { editingApp = app }
                                            )
                                            .id(app.id)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 410)
                    .onChange(of: isDMenuMode ? "dmenu-\(safeSelectedDMenuIndex)" : (isFileSearch ? curSelectedFile?.id : (isEmojiSearch ? selectedEmoji?.id : curSelectedApp?.id))) { _, targetID in
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
                        Text(isDMenuMode ? "↵ Select" : "↵ Open")
                        Text("•")
                        if isDMenuMode {
                            Text("Esc Cancel")
                        } else {
                            Text("Tab Actions")
                            Text("•")
                            Text("Esc Dismiss")
                        }
                    }
                    .font(ThemeStore.shared.font(size: 11, weight: .medium, design: .rounded))
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
                                        .font(ThemeStore.shared.font(size: 10))
                                    Text(showActionPanel ? "Hide Actions" : "Actions")
                                        .font(ThemeStore.shared.font(size: 11, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(theme.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(theme.primaryContainer.opacity(0.3))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        Text(isDMenuMode ? "dms dmenu" : "DLauncherV2")
                            .font(ThemeStore.shared.font(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.panelHeaderBackground)
            }
            .frame(maxWidth: .infinity)

            // MARK: - ActionPanel Sidebar (Spec 18-launcher.md Section 0 & 3)
            if showActionPanel, let app = curSelectedApp {
                Divider()
                    .background(theme.outlineVariant.opacity(0.4))

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        AppIconImage(path: app.path, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(ThemeStore.shared.font(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(theme.onSurface)
                                .lineLimit(1)
                            Text(app.subtitle)
                                .font(ThemeStore.shared.font(size: 11, design: .rounded))
                                .foregroundColor(theme.onSurfaceVariant)
                                .lineLimit(2)
                        }
                    }
                    .padding(.top, 16)

                    if !app.category.isEmpty {
                        Text(app.category.uppercased())
                            .font(ThemeStore.shared.font(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.primaryContainer.opacity(0.5))
                            .foregroundColor(theme.primary)
                            .clipShape(Capsule())
                    }

                    Divider()
                        .background(theme.outlineVariant.opacity(0.3))

                    VStack(spacing: 8) {
                        let isRunning = runningApps.isRunning(bundleID: app.bundleID)
                        let isHidden = runningApps.isHidden(bundleID: app.bundleID)

                        if isRunning && isHidden {
                            ActionPanelButton(
                                title: "Unhide Application",
                                icon: "eye.fill",
                                theme: theme
                            ) {
                                launchApp(app)
                            }

                            ActionPanelButton(
                                title: "Unhide in Background",
                                icon: "eye.slash.fill",
                                theme: theme
                            ) {
                                runningApps.unhide(app: app, inBackground: true)
                            }
                        } else {
                            ActionPanelButton(
                                title: isRunning ? "Focus Application" : "Open Application",
                                icon: "arrow.forward.circle.fill",
                                theme: theme
                            ) {
                                launchApp(app)
                            }
                        }

                        if isRunning && !isHidden {
                            ActionPanelButton(
                                title: "Hide Application",
                                icon: "eye.slash",
                                theme: theme
                            ) {
                                runningApps.hide(app: app)
                            }
                        }

                        if isRunning {
                            ActionPanelButton(
                                title: "Quit Application",
                                icon: "xmark.circle.fill",
                                theme: theme
                            ) {
                                runningApps.quit(app: app)
                            }
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

                        Divider()
                            .background(theme.outlineVariant.opacity(0.3))

                        ActionPanelButton(
                            title: "Edit App…",
                            icon: "pencil.circle.fill",
                            theme: theme
                        ) {
                            editingApp = app
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
        .id(sessionID)
        .onChange(of: showActionPanel) { _, newValue in
            // Grow the panel to 900pt so the 220pt action sidebar fits without clipping.
            LauncherController.shared.resizeForActionPanel(newValue)
        }
        .background(GlassSurfaceBackground(opacity: floatingWindowOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(theme.panelBorderColor, lineWidth: 1)
        )
        .shadow(color: theme.adaptiveShadowColor(baseOpacity: 0.42), radius: 30, x: 0, y: 12)
        .onAppear {
            isFieldFocused = true
            selectedIndex = 0
            selectedFileIndex = 0
            selectedEmojiIndex = 0
            if !query.isEmpty {
                triggerDebouncedFileSearch(for: query, immediate: true)
            }
        }
        .onDisappear {
            fileSearchTask?.cancel()
        }
        .onKeyPress(.downArrow) {
            navigate(delta: (!isFileSearch && !isEmojiSearch && viewMode == .tile) ? 5 : 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            navigate(delta: (!isFileSearch && !isEmojiSearch && viewMode == .tile) ? -5 : -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            // Only navigate tiles when the search field is empty, so left/right still move
            // the text cursor inside the query field while typing.
            if !isDMenuMode && !isFileSearch && viewMode == .tile && query.isEmpty {
                navigate(delta: 1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.leftArrow) {
            if !isDMenuMode && !isFileSearch && viewMode == .tile && query.isEmpty {
                navigate(delta: -1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.tab) {
            if isDMenuMode || curSelectedApp == nil {
                return .ignored
            }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                showActionPanel.toggle()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if isDMenuMode {
                cancelDMenu()
                return .handled
            }
            if showActionPanel {
                withAnimation { showActionPanel = false }
            } else {
                onClose()
            }
            return .handled
        }
        .sheet(item: $editingApp) { app in
            AppEditView(app: app)
        }
    }

    private func navigate(delta: Int) {
        if isDMenuMode {
            let rows = dmenuResults
            guard !rows.isEmpty else { return }
            let next = max(0, min(rows.count - 1, safeSelectedDMenuIndex + delta))
            selectedIndex = next
        } else if isFileSearch {
            let files = fileResults
            guard !files.isEmpty else { return }
            let next = max(0, min(files.count - 1, safeSelectedFileIndex + delta))
            selectedFileIndex = next
        } else if isEmojiSearch {
            let items = emojiResults
            guard !items.isEmpty else { return }
            let next = max(0, min(items.count - 1, safeSelectedEmojiIndex + delta))
            selectedEmojiIndex = next
        } else {
            let apps = currentApps
            guard !apps.isEmpty else { return }
            let next = max(0, min(apps.count - 1, safeSelectedIndex + delta))
            selectedIndex = next
        }
    }

    /// v0.7 CLI: streams the picked dmenu line back over the requesting socket connection.
    private func completeDMenuSelection(_ line: String) {
        if let requestID = dmenuRequestID {
            IPCSocketServer.shared.deliverDMenuResult(requestID: requestID, line: line, cancelled: false)
        }
        onDMenuResolved?()
        onClose()
    }

    /// v0.7 CLI: Esc cancels the dmenu request (CLI exits 1, prints nothing).
    private func cancelDMenu() {
        if let requestID = dmenuRequestID {
            IPCSocketServer.shared.deliverDMenuResult(requestID: requestID, line: nil, cancelled: true)
        }
        onDMenuResolved?()
        onClose()
    }

    @ViewBuilder
    private var webSearchFallbackRow: some View {
        // v0.9.5: resolve through AppSearch so bangs (!gh, !wiki, ...) target their provider.
        let target = AppSearch.resolveWebSearch(query: query, defaultProvider: configStore.config.webSearchProvider)
        let title: String = {
            if let target, target.isBang {
                return "Search \(Self.webSearchDisplayName(for: target.providerName)) for '\(target.query)'"
            } else {
                return "Search the Web for '\(query)'"
            }
        }()
        Button {
            openWebSearch(query: query)
            onClose()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(ThemeStore.shared.font(size: 20, weight: .semibold))
                    .foregroundColor(theme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ThemeStore.shared.font(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.onSurface)

                    Text("Opens in default browser")
                        .font(ThemeStore.shared.font(size: 11, weight: .medium, design: .rounded))
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
        if isDMenuMode {
            if let row = selectedDMenuRow {
                completeDMenuSelection(row)
            }
            return
        }

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

        if isEmojiSearch {
            if let emoji = selectedEmoji {
                selectEmoji(emoji)
            }
            return
        }

        if let app = selectedApp {
            launchApp(app)
            return
        }

        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            // v0.9.5: bang queries open their provider URL immediately.
            if let target = AppSearch.resolveWebSearch(query: clean, defaultProvider: configStore.config.webSearchProvider), target.isBang {
                NSWorkspace.shared.open(target.url)
                onClose()
                return
            }
            openWebSearch(query: clean)
            onClose()
        }
    }

    /// v0.9.5: copies the emoji/glyph, or auto-pastes it into the previous app when
    /// `clipboardAutoPaste` is on and Accessibility (key-event posting) is trusted.
    private func selectEmoji(_ item: EmojiItem) {
        if configStore.config.clipboardAutoPaste && AutoPasteService.shared.canPostKeyEvents {
            onClose()
            copyToClipboard(text: item.emoji)
            _ = AutoPasteService.shared.pasteIntoPreviousApp()
        } else {
            copyToClipboard(text: item.emoji)
            onClose()
        }
    }

    private func launchApp(_ app: AppItem) {
        // v0.9.5: built-in DMS Settings open the settings window on the matching tab.
        if app.bundleID.hasPrefix("io.dms.setting.") {
            let suffix = String(app.bundleID.dropFirst("io.dms.setting.".count))
            // "surfaces" has no dedicated tab; bar appearance owns blur/opacity/corners.
            let targetTab = suffix == "surfaces" ? "bar" : suffix
            onClose()
            SettingsController.shared.show(tab: targetTab)
            return
        }
        // v0.9.5: built-in DMS Actions dispatch to their controllers/services.
        if app.bundleID.hasPrefix("io.dms.action.") {
            onClose()
            switch app.bundleID {
            case "io.dms.action.clipboard":
                ClipboardController.shared.toggle()
            case "io.dms.action.notepad":
                NotepadController.shared.toggle()
            case "io.dms.action.processes":
                ProcessListController.shared.toggle()
            case "io.dms.action.controlcenter":
                ControlCenterController.shared.toggle()
            case "io.dms.action.onboard":
                OnboardingController.shared.show()
            case "io.dms.action.colorpicker":
                ColorPickerService.shared.sampleColor()
            case "io.dms.action.lock":
                PowerMenuView.lockScreen()
            default:
                break
            }
            return
        }
        // v0.9.6: local plugins trigger their click handler instead of launching an app.
        if app.bundleID.hasPrefix("io.dms.localplugin.") {
            let pluginID = String(app.bundleID.dropFirst("io.dms.localplugin.".count))
            onClose()
            PluginRuntimeService.shared.triggerClick(pluginID: pluginID)
            return
        }
        if app.bundleID == "io.dms.plugin.symbian-belle-sync" {
            _ = SymbianClient.shared.launchCompanion()
            onClose()
            return
        }
        appCatalog.recordLaunch(app: app)
        runningApps.activate(app: app)
        onClose()
    }

    private func showInFinder(_ app: AppItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
        onClose()
    }

    private func openInTerminal(_ app: AppItem) {
        let terminal = configStore.config.apps.terminal
        guard let termApp = appCatalog.apps.first(where: { $0.name.localizedCaseInsensitiveContains(terminal) }) else {
            onClose()
            return
        }
        // Open the app's bundle in the configured terminal: `open -a <terminal> <app path>`.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", termApp.path, app.path]
        do {
            try process.run()
        } catch {
            runningApps.activate(app: termApp)
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
        // v0.9.5: resolveWebSearch handles bangs and the configured default provider.
        if let target = AppSearch.resolveWebSearch(query: query, defaultProvider: configStore.config.webSearchProvider) {
            NSWorkspace.shared.open(target.url)
        }
    }

    private static func webSearchDisplayName(for provider: String) -> String {
        switch provider.lowercased() {
        case "github": return "GitHub"
        case "duckduckgo": return "DuckDuckGo"
        case "youtube": return "YouTube"
        case "wikipedia": return "Wikipedia"
        case "stackoverflow": return "Stack Overflow"
        case "homebrew": return "Homebrew"
        case "crates": return "crates.io"
        case "npm": return "npm"
        case "apple": return "Apple Developer"
        case "kagi": return "Kagi"
        case "bing": return "Bing"
        default: return "Google"
        }
    }
}

/// Action panel row button in DLauncherV2.
private struct ActionPanelButton: View {
    let title: String
    let icon: String
    @ObservedObject var theme: ThemeStore
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(ThemeStore.shared.font(size: 13))
                    .foregroundColor(theme.primary)
                    .frame(width: 20)

                Text(title)
                    .font(ThemeStore.shared.font(size: 12, weight: .medium, design: .rounded))
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
    public var onShowInFinder: (() -> Void)? = nil
    public var onUnhideInBackground: (() -> Void)? = nil
    public var onHide: (() -> Void)? = nil
    public var onQuit: (() -> Void)? = nil
    public var onCopyID: (() -> Void)? = nil
    public var onCopyPath: (() -> Void)? = nil
    public var onEdit: (() -> Void)? = nil

    @ObservedObject private var theme = ThemeStore.shared
    @State private var isHovered = false

    public var body: some View {
        let isRunning = RunningAppsService.shared.isRunning(bundleID: item.bundleID)
        let isHidden = RunningAppsService.shared.isHidden(bundleID: item.bundleID)
        let isDMSSetting = item.bundleID.hasPrefix("io.dms.setting.")
        let isDMSAction = item.bundleID.hasPrefix("io.dms.action.")
        let isLocalPlugin = item.bundleID.hasPrefix("io.dms.localplugin.")

        Button {
            onSelect()
        } label: {
            HStack(spacing: 14) {
                if isDMSSetting || isDMSAction || isLocalPlugin {
                    // v0.9.5: built-in DMS entries get a themed SF Symbol badge
                    // instead of the Finder file icon; v0.9.6: local plugins too.
                    Image(systemName: isDMSSetting ? "gearshape.fill" : (isDMSAction ? "bolt.fill" : "puzzlepiece.extension.fill"))
                        .font(ThemeStore.shared.font(size: 16, weight: .semibold))
                        .foregroundColor(theme.primary)
                        .frame(width: 36, height: 36)
                        .background(theme.primaryContainer.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    AppIconImage(path: item.path, size: 36)
                        .opacity(isRunning && isHidden ? 0.6 : 1.0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(ThemeStore.shared.font(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.onSurface)

                        if isDMSSetting {
                            Text("DMS SETTING")
                                .font(ThemeStore.shared.font(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(theme.primaryContainer.opacity(0.5))
                                .foregroundColor(theme.primary)
                                .clipShape(Capsule())
                        } else if isDMSAction {
                            Text("DMS ACTION")
                                .font(ThemeStore.shared.font(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(theme.primaryContainer.opacity(0.5))
                                .foregroundColor(theme.primary)
                                .clipShape(Capsule())
                        } else if isLocalPlugin {
                            Text("PLUGIN")
                                .font(ThemeStore.shared.font(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(theme.primaryContainer.opacity(0.5))
                                .foregroundColor(theme.primary)
                                .clipShape(Capsule())
                        } else if isRunning && isHidden {
                            Text("HIDDEN")
                                .font(ThemeStore.shared.font(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(theme.surfaceContainerHighest)
                                .foregroundColor(theme.onSurfaceVariant)
                                .clipShape(Capsule())
                        } else if isRunning {
                            Circle()
                                .fill(theme.primary.opacity(0.8))
                                .frame(width: 5, height: 5)
                        }
                    }

                    Text(item.subtitle)
                        .font(ThemeStore.shared.font(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(theme.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "return")
                        .font(ThemeStore.shared.font(size: 11, weight: .bold))
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
            if isRunning && isHidden {
                Button("Unhide \(item.name)") { onSelect() }
                Button("Unhide in Background") {
                    if let unhideBg = onUnhideInBackground {
                        unhideBg()
                    } else {
                        RunningAppsService.shared.unhide(bundleID: item.bundleID, fallbackPath: item.path, inBackground: true)
                    }
                }
                Divider()
            }

            Button(isRunning && isHidden ? "Unhide and Focus" : "Open \(item.name)") { onSelect() }
            Divider()
            if let show = onShowInFinder {
                Button("Show in Finder") { show() }
            }
            if isRunning {
                Divider()
                if !isHidden {
                    Button("Hide") {
                        if let hide = onHide { hide() } else {
                            RunningAppsService.shared.hide(bundleID: item.bundleID, fallbackPath: item.path)
                        }
                    }
                }
                Button("Quit") {
                    if let quit = onQuit { quit() } else {
                        RunningAppsService.shared.quit(bundleID: item.bundleID, fallbackPath: item.path)
                    }
                }
            }
            Divider()
            if let copyID = onCopyID {
                Button("Copy Bundle Identifier") { copyID() }
            }
            if let copyPath = onCopyPath {
                Button("Copy Path") { copyPath() }
            }
            if let edit = onEdit {
                Divider()
                Button("Edit App…") { edit() }
            }
        }
    }
}

/// Grid / Tile View Item representing an application (LAUNCH-002).
public struct LauncherTileItem: View {
    public let item: AppItem
    public let isSelected: Bool
    public let onSelect: () -> Void
    public var onShowInFinder: (() -> Void)? = nil
    public var onUnhideInBackground: (() -> Void)? = nil
    public var onHide: (() -> Void)? = nil
    public var onQuit: (() -> Void)? = nil
    public var onCopyID: (() -> Void)? = nil
    public var onCopyPath: (() -> Void)? = nil
    public var onEdit: (() -> Void)? = nil

    @ObservedObject private var theme = ThemeStore.shared
    @State private var isHovered = false

    public var body: some View {
        let isRunning = RunningAppsService.shared.isRunning(bundleID: item.bundleID)
        let isHidden = RunningAppsService.shared.isHidden(bundleID: item.bundleID)

        Button {
            onSelect()
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    AppIconImage(path: item.path, size: 48)
                        .opacity(isRunning && isHidden ? 0.6 : 1.0)

                    if isRunning && isHidden {
                        Image(systemName: "eye.slash.fill")
                            .font(ThemeStore.shared.font(size: 10, weight: .bold))
                            .foregroundColor(theme.onSurfaceVariant)
                            .padding(2)
                            .background(theme.surfaceContainerHighest)
                            .clipShape(Circle())
                    } else if isRunning {
                        Circle()
                            .fill(theme.primary)
                            .frame(width: 6, height: 6)
                            .offset(x: 2, y: 2)
                    }
                }

                Text(item.name)
                    .font(ThemeStore.shared.font(size: 12, weight: .medium, design: .rounded))
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
            if isRunning && isHidden {
                Button("Unhide \(item.name)") { onSelect() }
                Button("Unhide in Background") {
                    if let unhideBg = onUnhideInBackground {
                        unhideBg()
                    } else {
                        RunningAppsService.shared.unhide(bundleID: item.bundleID, fallbackPath: item.path, inBackground: true)
                    }
                }
                Divider()
            }

            Button(isRunning && isHidden ? "Unhide and Focus" : "Open \(item.name)") { onSelect() }
            Divider()
            if let show = onShowInFinder {
                Button("Show in Finder") { show() }
            }
            if isRunning {
                Divider()
                if !isHidden {
                    Button("Hide") {
                        if let hide = onHide { hide() } else {
                            RunningAppsService.shared.hide(bundleID: item.bundleID, fallbackPath: item.path)
                        }
                    }
                }
                Button("Quit") {
                    if let quit = onQuit { quit() } else {
                        RunningAppsService.shared.quit(bundleID: item.bundleID, fallbackPath: item.path)
                    }
                }
            }
            Divider()
            if let copyID = onCopyID {
                Button("Copy Bundle Identifier") { copyID() }
            }
            if let copyPath = onCopyPath {
                Button("Copy Path") { copyPath() }
            }
            if let edit = onEdit {
                Divider()
                Button("Edit App…") { edit() }
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
                    .font(ThemeStore.shared.font(size: 16))
                    .foregroundColor(theme.primary)
                    .frame(width: 28, height: 28)
                    .background(theme.primaryContainer.opacity(0.4))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(ThemeStore.shared.font(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.onSurface)

                    Text(file.path)
                        .font(ThemeStore.shared.font(size: 10, design: .monospaced))
                        .foregroundColor(theme.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "return")
                        .font(ThemeStore.shared.font(size: 11, weight: .bold))
                        .foregroundColor(theme.primary.opacity(0.85))
                        .padding(.trailing, 4)
                } else {
                    Image(systemName: "arrow.right.circle")
                        .font(ThemeStore.shared.font(size: 12))
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

/// Plain string row for `dms dmenu` filter mode (v0.7 CLI).
public struct DMenuRow: View {
    public let text: String
    public var isSelected: Bool = false
    public let onSelect: () -> Void

    @ObservedObject private var theme = ThemeStore.shared

    public init(text: String, isSelected: Bool = false, onSelect: @escaping () -> Void) {
        self.text = text
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal")
                    .font(ThemeStore.shared.font(size: 13, weight: .semibold))
                    .foregroundColor(theme.primary)
                    .frame(width: 28, height: 28)
                    .background(theme.primaryContainer.opacity(0.4))
                    .cornerRadius(8)

                Text(text)
                    .font(ThemeStore.shared.font(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "return")
                        .font(ThemeStore.shared.font(size: 11, weight: .bold))
                        .foregroundColor(theme.primary.opacity(0.85))
                        .padding(.trailing, 4)
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

/// Row representing an emoji or Nerd Font glyph in the `:emoji` / `nf:` picker (v0.9.5).
public struct EmojiItemRow: View {
    public let item: EmojiItem
    public var isSelected: Bool = false
    public let onSelect: () -> Void

    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var configStore = ConfigStore.shared

    public init(item: EmojiItem, isSelected: Bool = false, onSelect: @escaping () -> Void) {
        self.item = item
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(item.emoji)
                    .font(item.isNerdFont ? theme.nerdFont(size: 22) : theme.font(size: 22))
                    .frame(width: 36, height: 36)
                    .background(theme.surfaceContainerHighest.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(ThemeStore.shared.font(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.onSurface)
                        .lineLimit(1)

                    if !item.shortcode.isEmpty {
                        Text(":\(item.shortcode):")
                            .font(ThemeStore.shared.font(size: 11, design: .monospaced))
                            .foregroundColor(theme.onSurfaceVariant)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(item.isNerdFont ? "NERD FONT" : "EMOJI")
                    .font(ThemeStore.shared.font(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.primaryContainer.opacity(0.5))
                    .foregroundColor(theme.primary)
                    .clipShape(Capsule())

                Text((configStore.config.clipboardAutoPaste && AutoPasteService.shared.canPostKeyEvents) ? "Press ↵ to paste" : "Press ↵ to copy")
                    .font(ThemeStore.shared.font(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.outline)

                if isSelected {
                    Image(systemName: "return")
                        .font(ThemeStore.shared.font(size: 11, weight: .bold))
                        .foregroundColor(theme.primary.opacity(0.85))
                        .padding(.trailing, 4)
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
