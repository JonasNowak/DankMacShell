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

    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var hostingView: NSHostingView<SlantedWallpaperPickerView>?

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
        if hostingView == nil {
            let view = SlantedWallpaperPickerView(controller: self)
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

        // Cache original desktop wallpaper for reset if user does not press Enter
        let current = WallpaperService.shared.currentDesktopPath
        self.originalDesktopPath = current
        self.isTestingSession = true

        let width: CGFloat = min(1160, screen.frame.width - 80)
        let height: CGFloat = 560
        let xPos = screen.frame.midX - (width / 2)
        let yPos = screen.frame.midY - (height / 2)
        panel.setFrame(NSRect(x: xPos, y: yPos, width: width, height: height), display: true)

        let items = WallpaperService.shared.pickerWallpapers()
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

        let current = WallpaperService.shared.currentDesktopPath
        self.originalDesktopPath = current
        self.isTestingSession = true

        let width: CGFloat = min(1160, screen.frame.width - 80)
        let height: CGFloat = 560
        let xPos = screen.frame.midX - (width / 2)
        let yPos = screen.frame.midY - (height / 2)
        panel.setFrame(NSRect(x: xPos, y: yPos, width: width, height: height), display: true)

        let items = WallpaperService.shared.pickerWallpapers()
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

    /// Advances to the next wallpaper and live-previews it on desktop.
    public func cycleNext() {
        let items = WallpaperService.shared.pickerWallpapers()
        guard !items.isEmpty else { return }
        let next = (selectedIndex + 1) % items.count
        self.selectedIndex = next
        WallpaperService.shared.previewWallpaper(items[next])
    }

    /// Rewinds to the previous wallpaper and live-previews it on desktop.
    public func cyclePrevious() {
        let items = WallpaperService.shared.pickerWallpapers()
        guard !items.isEmpty else { return }
        let prev = (selectedIndex - 1 + items.count) % items.count
        self.selectedIndex = prev
        WallpaperService.shared.previewWallpaper(items[prev])
    }

    /// Selects a specific index and live-previews it.
    public func select(index: Int) {
        let items = WallpaperService.shared.pickerWallpapers()
        guard items.indices.contains(index) else { return }
        self.selectedIndex = index
        WallpaperService.shared.previewWallpaper(items[index])
    }

    /// Confirms and commits the currently selected wallpaper (Enter / Apply).
    public func commitSelection() {
        guard isVisible else { return }
        let items = WallpaperService.shared.pickerWallpapers()
        if items.indices.contains(selectedIndex) {
            WallpaperService.shared.applyWallpaper(items[selectedIndex], autoGenerateColors: true)
        }
        self.isTestingSession = false
        hide(reverting: false)
    }

    /// Cancels selection and resets desktop back to the original wallpaper before testing session started (Esc / click outside / lost focus).
    public func cancelAndRevert() {
        guard isVisible else { return }
        if isTestingSession && !originalDesktopPath.isEmpty {
            WallpaperService.shared.revertWallpaper(to: originalDesktopPath)
        }
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
