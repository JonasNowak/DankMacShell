import SwiftUI
import AppKit
import DMSCore

/// Shared 2-second TTL cache for WindowServer window titles so Dock magnification does not invoke
/// `CGWindowListCopyWindowInfo` per button on every mouse-move frame.
@MainActor
private enum DockWindowListCache {
    private static var lastFetchTime: TimeInterval = 0
    private static var titlesByPID: [pid_t: [String]] = [:]
    private static let ttl: TimeInterval = 2.0

    static func titles(for pid: pid_t, forceRefresh: Bool = false) -> [String] {
        let now = ProcessInfo.processInfo.systemUptime
        if forceRefresh || (now - lastFetchTime) > ttl {
            refresh(now: now)
        }
        return titlesByPID[pid] ?? []
    }

    private static func refresh(now: TimeInterval) {
        lastFetchTime = now
        let windowListInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var grouped: [pid_t: [String]] = [:]
        for info in windowListInfo {
            guard let windowPID = info[kCGWindowOwnerPID as String] as? pid_t else { continue }
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }
            let title = info[kCGWindowName as String] as? String ?? ""
            if !title.isEmpty {
                grouped[windowPID, default: []].append(title)
            }
        }
        titlesByPID = grouped
    }
}

/// Application button in the Desktop Dock with proximity magnification,
/// dot-to-pill elongation on active focus, grouped window indicators, and context menus.
public struct DockAppButton: View {
    public let app: AppItem
    public let config: DockConfig
    public let scale: Double
    public let isHovered: Bool
    public let onSelect: () -> Void

    @ObservedObject private var theme = ThemeStore.shared
    private let appsService = RunningAppsService.shared

    public init(
        app: AppItem,
        config: DockConfig,
        scale: Double = 1.0,
        isHovered: Bool = false,
        onSelect: @escaping () -> Void
    ) {
        self.app = app
        self.config = config
        self.scale = scale
        self.isHovered = isHovered
        self.onSelect = onSelect
    }

    private var runningAppInstance: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == app.bundleID }
    }

    private var isAppRunning: Bool {
        app.isRunning || runningAppInstance != nil
    }

    private var isFocused: Bool {
        appsService.activeApp?.bundleID == app.bundleID
    }

    private var windowTitles: [String] {
        guard let pid = runningAppInstance?.processIdentifier else { return [] }
        return DockWindowListCache.titles(for: pid)
    }

    private var windowCount: Int {
        guard config.groupByApp, isAppRunning else { return isAppRunning ? 1 : 0 }
        let count = windowTitles.count
        return max(1, count)
    }

    private var effectiveIconSize: CGFloat {
        CGFloat(config.iconSize) * CGFloat(scale)
    }

    public var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: 3) {
                if config.position == 0 {
                    // Top dock: indicator at top
                    indicatorView
                }

                // App Icon with proximity scaling
                AppIconImage(path: app.path)
                    .frame(width: effectiveIconSize, height: effectiveIconSize)
                    .dockHoverBounce(isHovered: isHovered, position: config.position, enabled: true)

                if config.position != 0 {
                    // Bottom / Left / Right dock: indicator at bottom
                    indicatorView
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            contextMenuItems
        }
    }

    // MARK: - Running & Focus Indicator
    @ViewBuilder
    private var indicatorView: some View {
        if isAppRunning {
            let actualSize = Double(effectiveIconSize)
            let isLine = config.indicatorStyle.lowercased() == "line"

            if isFocused {
                // Focused window dot expands to baseWidth * 3 pill
                if isLine {
                    let baseWidth = max(6.0, actualSize * 0.20)
                    let baseHeight = max(2.0, actualSize * 0.05)
                    Capsule()
                        .fill(theme.primary)
                        .frame(width: CGFloat(baseWidth * 3.0), height: CGFloat(baseHeight))
                        .animation(.easeInOut(duration: 0.15), value: isFocused)
                } else {
                    let baseSize = max(4.0, actualSize * 0.10)
                    Capsule()
                        .fill(theme.primary)
                        .frame(width: CGFloat(baseSize * 3.0), height: CGFloat(baseSize))
                        .animation(.easeInOut(duration: 0.15), value: isFocused)
                }
            } else if windowCount > 1 && config.groupByApp {
                // Grouped windows: up to 4 dots
                let dotsCount = min(4, windowCount)
                HStack(spacing: 2) {
                    ForEach(0..<dotsCount, id: \.self) { _ in
                        if isLine {
                            let w = max(3.0, actualSize * 0.10)
                            let h = max(2.0, actualSize * 0.05)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(theme.onSurfaceVariant.opacity(0.8))
                                .frame(width: CGFloat(w), height: CGFloat(h))
                        } else {
                            let dotSize = max(3.0, actualSize * 0.08)
                            Circle()
                                .fill(theme.onSurfaceVariant.opacity(0.8))
                                .frame(width: CGFloat(dotSize), height: CGFloat(dotSize))
                        }
                    }
                }
            } else {
                // Normal running dot / line
                if isLine {
                    let baseWidth = max(6.0, actualSize * 0.20)
                    let baseHeight = max(2.0, actualSize * 0.05)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(theme.onSurfaceVariant.opacity(0.7))
                        .frame(width: CGFloat(baseWidth), height: CGFloat(baseHeight))
                } else {
                    let baseSize = max(4.0, actualSize * 0.10)
                    Circle()
                        .fill(theme.onSurfaceVariant.opacity(0.7))
                        .frame(width: CGFloat(baseSize), height: CGFloat(baseSize))
                }
            }
        } else {
            // Invisible placeholder for height stability
            Color.clear.frame(width: 4, height: max(4.0, Double(effectiveIconSize) * 0.10))
        }
    }

    // MARK: - Context Menu
    @ViewBuilder
    private var contextMenuItems: some View {
        // App Name Header
        Text(app.name)
            .font(.headline)

        Divider()

        // Launch / New Window
        Button("New Window") {
            if let url = URL(string: "file://" + app.path) {
                let config = NSWorkspace.OpenConfiguration()
                config.createsNewApplicationInstance = true
                NSWorkspace.shared.openApplication(at: url, configuration: config)
            }
        }

        // List open windows
        let titles = windowTitles
        if !titles.isEmpty {
            Divider()
            Text("Windows (\(titles.count))")
            ForEach(Array(titles.enumerated()), id: \.offset) { _, title in
                Button(title) {
                    runningAppInstance?.activate()
                }
            }
        }

        Divider()

        // Pin / Unpin toggle
        let isPinned = ConfigStore.shared.config.pinnedApps.contains(app.bundleID)
        Button(isPinned ? "Unpin from Dock" : "Pin to Dock") {
            appsService.togglePin(bundleID: app.bundleID)
        }

        // Running actions
        if isAppRunning {
            Divider()
            Button("Quit") {
                appsService.quit(app: app)
            }
            Button("Force Quit") {
                runningAppInstance?.forceTerminate()
            }
        }
    }
}
