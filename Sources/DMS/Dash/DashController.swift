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

    private init() {}

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

        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = screen else { return }

        let fullFrame = targetScreen.frame
        let bodyWidth: CGFloat = Self.defaultWidth
        let bodyHeight: CGFloat = Self.defaultHeight
        let targetX = (anchorX != nil && anchorX! > 0) ? anchorX! : fullFrame.midX

        let rect = PopoutLayoutHelper.frame(
            bodyWidth: bodyWidth,
            bodyHeight: bodyHeight,
            anchorX: targetX,
            screen: targetScreen
        )

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
