import AppKit
import SwiftUI
import DMSCore

/// Controller managing the presentation, fast cycling, and live testing/reverting of the Slanted Wallpaper Picker HUD.
/// Automatically dismisses and resets the wallpaper whenever focus is lost.
@MainActor
public final class SlantedWallpaperPickerController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = SlantedWallpaperPickerController()

    public let panel: ShellPanel
    @Published public private(set) var isVisible = false
    @Published public var selectedIndex: Int = 0
    @Published public private(set) var originalDesktopPath: String = ""
    @Published public private(set) var isTestingSession: Bool = false

    // Filter state lives on the controller so `cycleNext()` / `select(index:)` / `commitSelection()`
    // always index into the exact filtered list the view displays (no View/Controller mismatch).
    @Published public var onlyFolder: Bool = false
    @Published public var selectedSource: WallpaperSource = .all
    @Published public var searchQuery: String = ""

    /// Theme name captured when the testing session started, restored on cancel if a
    /// gradient preset preview switched the theme.
    private var themeSnapshotOnShow: String?

    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var hostingView: NSHostingView<SlantedWallpaperPickerView>?

    /// The exact filtered wallpaper list the picker view renders for the current
    /// `onlyFolder` / `selectedSource` / `searchQuery` state.
    public var filteredWallpapers: [WallpaperItem] {
        let baseList = onlyFolder ? WallpaperService.shared.pickerWallpapers() : WallpaperService.shared.wallpapers
        return WallpaperItem.filterWallpapers(
            items: baseList,
            source: selectedSource,
            query: searchQuery
        )
    }

    /// Syncs picker filter state from the persisted config and snapshots the current theme.
    private func syncPickerStateFromConfig() {
        onlyFolder = ConfigStore.shared.config.wallpaperPickerOnlyFolder
        selectedSource = .all
        searchQuery = ""
        themeSnapshotOnShow = ThemeStore.shared.themeName
    }

    private override init() {
        panel = ShellPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isMovable = false
        panel.hasShadow = true

        super.init()

        panel.delegate = self

        panel.onEscape = { [weak self] in
            self?.cancelAndRevert()
        }

        setupFocusObservers()
    }

    private func ensureHostingView() {
        // Fresh `.id(UUID())` per presentation so SwiftUI recreates the view's `@State`
        // and re-runs `.onAppear` on every show instead of reusing stale state.
        let view = SlantedWallpaperPickerView(controller: self, sessionID: UUID())
        if let host = hostingView {
            host.rootView = view
        } else {
            let host = NSHostingView(rootView: view)
            panel.contentView = host
            self.hostingView = host
        }
    }

    private func setupFocusObservers() {
        // App resigns active (user switches to another app, Cmd-Tab, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFocusLost),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        // Another application becomes active in macOS
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleFocusLost),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // User switches spaces / virtual desktops
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleFocusLost),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleFocusLost() {
        guard isVisible else { return }
        Task { @MainActor [weak self] in
            self?.cancelAndRevert()
        }
    }

    // MARK: - NSWindowDelegate
    public func windowDidResignKey(_ notification: Notification) {
        guard isVisible else { return }
        cancelAndRevert()
    }

    public func windowDidResignMain(_ notification: Notification) {
        guard isVisible else { return }
        cancelAndRevert()
    }

    /// Invoked whenever the global hotkey is pressed.
    /// If closed: opens HUD instantly and cycles to the next wallpaper, live-previewing it on the desktop.
    /// If already open: cycles forward to the next wallpaper in the list, testing each one live.
    public func triggerShortcut() {
        if isVisible {
            cycleNext()
        } else {
            showAndCycle()
        }
    }

    public func toggle() {
        triggerShortcut()
    }

    /// Shows the picker HUD instantly and advances to the next wallpaper, live-previewing it on the desktop.
    public func showAndCycle() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        // Close other overlays
        LauncherController.shared.hide()
        ControlCenterController.shared.hide()
        PowerMenuController.shared.hide()
        DashController.shared.hide()

        syncPickerStateFromConfig()

        // Cache original desktop wallpaper for reset if user does not press Enter
        let current = WallpaperService.shared.currentDesktopPath
        self.originalDesktopPath = current
        self.isTestingSession = true

        let width: CGFloat = min(1160, screen.frame.width - 80)
        let height: CGFloat = 560
        let xPos = screen.frame.midX - (width / 2)
        let yPos = screen.frame.midY - (height / 2)
        panel.setFrame(NSRect(x: xPos, y: yPos, width: width, height: height), display: true)

        let items = filteredWallpapers
        if !items.isEmpty {
            let currentIndex = items.firstIndex(where: { $0.path == current }) ?? -1
            let nextIndex = (currentIndex + 1) % items.count
            self.selectedIndex = nextIndex
            WallpaperService.shared.previewWallpaper(items[nextIndex])
        }

        ensureHostingView()
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.isVisible = true

        installFocusMonitors()
    }

    /// Standard show without advancing.
    public func show() {
        guard !isVisible else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        LauncherController.shared.hide()
        ControlCenterController.shared.hide()
        PowerMenuController.shared.hide()
        DashController.shared.hide()

        syncPickerStateFromConfig()

        let current = WallpaperService.shared.currentDesktopPath
        self.originalDesktopPath = current
        self.isTestingSession = true

        let width: CGFloat = min(1160, screen.frame.width - 80)
        let height: CGFloat = 560
        let xPos = screen.frame.midX - (width / 2)
        let yPos = screen.frame.midY - (height / 2)
        panel.setFrame(NSRect(x: xPos, y: yPos, width: width, height: height), display: true)

        let items = filteredWallpapers
        if let idx = items.firstIndex(where: { $0.path == current }) {
            self.selectedIndex = idx
        } else {
            self.selectedIndex = 0
        }

        ensureHostingView()
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.isVisible = true

        installFocusMonitors()
    }

    /// Advances to the next wallpaper in the filtered list and live-previews it on desktop.
    public func cycleNext() {
        let items = filteredWallpapers
        guard !items.isEmpty else { return }
        select(index: (selectedIndex + 1) % items.count)
    }

    /// Rewinds to the previous wallpaper in the filtered list and live-previews it on desktop.
    public func cyclePrevious() {
        let items = filteredWallpapers
        guard !items.isEmpty else { return }
        select(index: (selectedIndex - 1 + items.count) % items.count)
    }

    /// Selects a specific index into the filtered list and live-previews it.
    public func select(index: Int) {
        let items = filteredWallpapers
        guard items.indices.contains(index) else { return }
        self.selectedIndex = index
        WallpaperService.shared.previewWallpaper(items[index])
    }

    /// Confirms and commits the currently selected wallpaper (Enter / Apply).
    public func commitSelection() {
        guard isVisible else { return }
        let items = filteredWallpapers
        if items.indices.contains(selectedIndex) {
            WallpaperService.shared.applyWallpaper(items[selectedIndex], autoGenerateColors: true)
        }
        self.isTestingSession = false
        themeSnapshotOnShow = nil
        hide(reverting: false)
    }

    /// Cancels selection and resets desktop back to the original wallpaper before testing session started (Esc / click outside / lost focus).
    public func cancelAndRevert() {
        guard isVisible else { return }
        if isTestingSession && !originalDesktopPath.isEmpty {
            WallpaperService.shared.revertWallpaper(to: originalDesktopPath)
        }
        // A gradient preset preview switches the theme live; restore the pre-session theme.
        if let snapshot = themeSnapshotOnShow, ThemeStore.shared.themeName != snapshot {
            ThemeStore.shared.apply(theme: snapshot)
        }
        themeSnapshotOnShow = nil
        self.isTestingSession = false
        hide(reverting: true)
    }

    public func hide(reverting: Bool = false) {
        guard isVisible else { return }
        self.isVisible = false
        if !reverting && isTestingSession && !originalDesktopPath.isEmpty {
            WallpaperService.shared.revertWallpaper(to: originalDesktopPath)
        }
        self.isTestingSession = false
        panel.orderOut(nil)
        removeFocusMonitors()
    }

    private func installFocusMonitors() {
        removeFocusMonitors()

        // 1. Global click monitor (clicks outside in other macOS apps or desktop background)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self = self, self.isVisible else { return }
            let screenPoint = NSEvent.mouseLocation
            if !self.panel.frame.contains(screenPoint) {
                Task { @MainActor [weak self] in
                    self?.cancelAndRevert()
                }
            }
        }

        // 2. Local click monitor (clicks outside within DMS, e.g. bar widgets or other panels)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            let screenPoint = NSEvent.mouseLocation
            if !self.panel.frame.contains(screenPoint) {
                Task { @MainActor [weak self] in
                    self?.cancelAndRevert()
                }
            }
            return event
        }
    }

    private func removeFocusMonitors() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }
}
