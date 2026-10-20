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

    public func toggle(tab: DashTab? = nil, anchorX: CGFloat? = nil) {
        if isVisible {
            if let targetTab = tab, activeTab != targetTab {
                activeTab = targetTab
            } else {
                hide()
            }
        } else {
            show(tab: tab, anchorX: anchorX)
        }
    }

    public func show(tab: DashTab? = nil, anchorX: CGFloat? = nil) {
        if let targetTab = tab {
            self.activeTab = targetTab
        }

        if isVisible {
            panel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = screen else { return }

        // Close peer popouts
        AudioPopoutController.shared.hide()
        BatteryPopoutController.shared.hide()
        ProcessListController.shared.hide()
        ControlCenterController.shared.hide()
        LauncherController.shared.hide()
        PowerMenuController.shared.hide()

        let popoutWidth: CGFloat = Self.defaultWidth
        let popoutHeight: CGFloat = Self.defaultHeight
        let gap: CGFloat = 10
        let barPosition = ConfigStore.shared.config.barPosition.lowercased()
        let isBottom = barPosition == "bottom"
        let isVertical = barPosition == "left" || barPosition == "right"

        let visibleFrame = targetScreen.visibleFrame
        let fullFrame = targetScreen.frame

        let barPanel = DankBarController.shared.panels.values.first(where: { $0.screen == targetScreen }) ?? DankBarController.shared.panel
        let barFrame = barPanel.frame

        var xPos: CGFloat
        let yPos: CGFloat

        if isBottom {
            let targetX = fullFrame.midX
            xPos = targetX - popoutWidth / 2.0
            xPos = max(visibleFrame.minX + 12, min(visibleFrame.maxX - popoutWidth - 12, xPos))
            let barTop = barFrame.height > 0 ? barFrame.maxY : (fullFrame.minY + 8 + DankBarController.barHeight)
            yPos = min(visibleFrame.maxY - popoutHeight - gap, barTop + gap)
        } else if !isVertical {
            let targetX = fullFrame.midX
            xPos = targetX - popoutWidth / 2.0
            xPos = max(visibleFrame.minX + 12, min(visibleFrame.maxX - popoutWidth - 12, xPos))
            let barBottom = barFrame.height > 0 ? barFrame.minY : (fullFrame.maxY - 8 - DankBarController.barHeight)
            yPos = max(visibleFrame.minY + gap, barBottom - popoutHeight - gap)
        } else {
            let targetY = lastClockCenter?.y ?? mouseLoc.y
            yPos = max(visibleFrame.minY + 12, min(visibleFrame.maxY - popoutHeight - 12, targetY - popoutHeight / 2.0))
            let barRight = barFrame.width > 0 ? barFrame.maxX : (fullFrame.minX + DankBarController.verticalBarWidth + 8)
            let barLeft = barFrame.width > 0 ? barFrame.minX : (fullFrame.maxX - DankBarController.verticalBarWidth - 8)
            if barPosition == "left" {
                xPos = barRight + gap
            } else {
                xPos = barLeft - popoutWidth - gap
            }
        }

        let rect = NSRect(x: xPos, y: yPos, width: popoutWidth, height: popoutHeight)

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

        panel.makeKeyAndOrderFront(nil)
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
        panel?.orderOut(nil)
        panel = nil
        isVisible = false
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
