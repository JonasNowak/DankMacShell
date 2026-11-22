import AppKit
import SwiftUI
import DMSCore

/// Controller for the DankDash dashboard modal overlay.
@MainActor
public final class DashController: ObservableObject {
    public static let shared = DashController()

    public static let defaultWidth: CGFloat = 580
    public static let defaultHeight: CGFloat = 414


    private var panel: ShellPanel?
    @Published public private(set) var isVisible: Bool = false
    @Published public var activeTab: DashTab = .overview

    public var lastClockCenter: CGPoint?
    public var lastClockFrame: NSRect?
    public var lastMediaFrame: NSRect?
    public var lastCenterRowFrame: NSRect?
    private var globalClickMonitor: Any?

    /// Phase 7 Shard 3: hot-plug observer token for `didChangeScreenParametersNotification`.
    private var screenParametersObserver: NSObjectProtocol?
    /// Anchor X used by the current presentation, reused when re-anchoring on hot-plug.
    private var lastAnchorX: CGFloat?

    private init() {
        observeScreenParameters()
    }

    deinit {
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
        }
    }

    // MARK: - Phase 7 Shard 3: Multi-Monitor Anchoring & Hot-Plug

    /// Screen under the pointer, falling back to the main screen then any screen.
    private func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// The panel's current screen when still connected, else the active pointer screen.
    private func survivingScreen(for panel: NSPanel?) -> NSScreen? {
        if let screen = panel?.screen, NSScreen.screens.contains(screen) {
            return screen
        }
        return activeScreen()
    }

    /// Clamps a frame fully inside `bounds`, shrinking it when larger than the screen.
    private func clampedFrame(_ frame: NSRect, in bounds: NSRect) -> NSRect {
        let width = min(frame.width, bounds.width)
        let height = min(frame.height, bounds.height)
        let x = min(max(frame.minX, bounds.minX), bounds.maxX - width)
        let y = min(max(frame.minY, bounds.minY), bounds.maxY - height)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func observeScreenParameters() {
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleScreenParametersChanged()
            }
        }
    }

    /// Hot-plug / resolution change: re-anchor the visible panel onto the surviving screen
    /// without closing it or losing state.
    private func handleScreenParametersChanged() {
        guard isVisible, let panel = panel, panel.isVisible else { return }
        guard let targetScreen = survivingScreen(for: panel) else { return }
        let anchorX: CGFloat
        if let lastAnchorX,
           lastAnchorX >= targetScreen.frame.minX, lastAnchorX <= targetScreen.frame.maxX {
            anchorX = lastAnchorX
        } else {
            anchorX = targetScreen.frame.midX
        }
        let rect = PopoutLayoutHelper.frame(
            bodyWidth: Self.defaultWidth,
            bodyHeight: Self.defaultHeight,
            anchorX: anchorX,
            screen: targetScreen
        )
        panel.setFrame(clampedFrame(rect, in: targetScreen.visibleFrame), display: true)
    }

    public func reportClockFrame(_ frameInWindow: NSRect, in window: NSWindow?) {
        guard let window = window else { return }
        let screenRect = window.convertToScreen(frameInWindow)
        self.lastClockFrame = screenRect
        self.lastClockCenter = CGPoint(x: screenRect.midX, y: screenRect.midY)
    }

    public func reportMediaFrame(_ frameInWindow: NSRect?, in window: NSWindow?) {
        guard let window = window, let frame = frameInWindow else {
            self.lastMediaFrame = nil
            return
        }
        let screenRect = window.convertToScreen(frame)
        self.lastMediaFrame = screenRect
    }

    public func reportCenterRowFrame(_ frameInWindow: NSRect, in window: NSWindow?) {
        guard let window = window else { return }
        let screenRect = window.convertToScreen(frameInWindow)
        self.lastCenterRowFrame = screenRect
    }

    public func toggle(tab: DashTab? = nil, anchorX: CGFloat? = nil, fromBar: Bool = false) {
        if isVisible {
            if let targetTab = tab, activeTab != targetTab {
                activeTab = targetTab
            } else {
                hide()
            }
        } else {
            show(tab: tab, anchorX: anchorX, fromBar: fromBar)
        }
    }

    public func show(tab: DashTab? = nil, anchorX: CGFloat? = nil, fromBar: Bool = false) {
        if let targetTab = tab {
            self.activeTab = targetTab
        }

        // Close peer popouts
        AudioPopoutController.shared.hide()
        BatteryPopoutController.shared.hide()
        DurationPopoutController.shared.hide()
        ColorPickerPopoutController.shared.hide()
        SymbianPopoutController.shared.hide()
        PowerPopoutController.shared.hide()
        ProcessListController.shared.hide()
        ControlCenterController.shared.hide()
        LauncherController.shared.hide()
        PowerMenuController.shared.hide()

        if isVisible {
            panel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let targetScreen = activeScreen()
        guard let targetScreen else { return }
        lastAnchorX = anchorX

        let fullFrame = targetScreen.frame
        let bodyWidth: CGFloat = Self.defaultWidth
        let bodyHeight: CGFloat = Self.defaultHeight
        let targetX = anchorX ?? fullFrame.midX

        let solved = PopoutLayoutHelper.frame(
            bodyWidth: bodyWidth,
            bodyHeight: bodyHeight,
            anchorX: targetX,
            screen: targetScreen
        )
        // Never open partially off-screen on asymmetrical multi-monitor setups.
        let rect = clampedFrame(solved, in: targetScreen.visibleFrame)

        let panel = ShellPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.onEscape = { [weak self] in self?.hide() }

        let dashView = DashView(initialTab: activeTab) { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: dashView)

        self.panel = panel
        self.isVisible = true

        PopoutAnimationHelper.animateIn(panel: panel, targetFrame: rect, screen: targetScreen)
        NSApp.activate(ignoringOtherApps: true)
        installClickMonitor()
    }

    public func openTab(_ tab: DashTab) {
        self.activeTab = tab
        if !isVisible {
            show(tab: tab)
        }
    }

    public func hide() {
        guard isVisible else { return }
        removeClickMonitor()
        isVisible = false

        let panelToClose = self.panel
        let screen = panelToClose?.screen ?? NSScreen.main
        self.panel = nil

        PopoutAnimationHelper.animateOut(panel: panelToClose, screen: screen)
    }

    private func installClickMonitor() {
        removeClickMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hide()
            }
        }
    }

    private func removeClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}
