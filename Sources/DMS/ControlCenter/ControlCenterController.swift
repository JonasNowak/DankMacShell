import AppKit
import SwiftUI
import DMSCore
import MaterialMacLibrary

@MainActor
public final class ControlCenterController {
    public static let shared = ControlCenterController()
    public static let standardSheetHeight: CGFloat = 368.0

    /// Non-editing root dashboard height, matching `ControlCenterView.sheetHeight`
    /// (header 36 + sliders 40 + grid + bottom 44 + spacing + padding, min 180).
    public static func preferredSheetHeight(for config: DMSConfig? = nil) -> CGFloat {
        let effectiveConfig = config ?? ConfigStore.shared.config
        let columns = CcMetrics.clampColumns(effectiveConfig.controlCenterColumns)
        let sheetWidth: CGFloat = columns == CcMetrics.defaultColumns ? CcMetrics.defaultSheetWidth : CcMetrics.sheetWidthFor(columns: columns)
        let gridWidth = Double(sheetWidth - (CcMetrics.sheetPadding * 2.0))
        let widgets = ControlCenterUtils.normalizedGridTiles(from: effectiveConfig.controlCenterGridTiles, columns: columns)
        let layout = ControlCenterGridPlanner.layoutResult(for: widgets, columns: columns, width: gridWidth)

        let headerH: CGFloat = 36.0
        let slidersH: CGFloat = 40.0
        let gridOmitted = widgets.isEmpty
        let gridH: CGFloat = gridOmitted ? 0.0 : CGFloat(layout.totalHeight)
        let bottomH: CGFloat = 44.0
        let spacing: CGFloat = gridOmitted ? 8.0 * 2.0 : 8.0 * 3.0
        let padding: CGFloat = CcMetrics.sheetPadding * 2.0
        return max(180.0, headerH + slidersH + gridH + bottomH + spacing + padding)
    }

    public let panel: ShellPanel
    public private(set) var isVisible = false
    public private(set) var currentSheetHeight: CGFloat = standardSheetHeight

    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?

    /// Monotonic generation counter bumped on every `show()`/`hide()` so a stale
    /// exit-animation completion can never order out a freshly re-shown panel.
    private var animationGeneration: UInt64 = 0

    /// Phase 7 Shard 3: hot-plug observer token for `didChangeScreenParametersNotification`.
    private var screenParametersObserver: NSObjectProtocol?

    private init() {
        panel = ShellPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.onEscape = { [weak self] in self?.hide() }

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
        guard isVisible, panel.isVisible else { return }
        guard let targetScreen = survivingScreen(for: panel) else { return }
        reposition(on: targetScreen)
    }

    public func toggle(fromBar: Bool = false) {
        if isVisible {
            hide()
        } else {
            show(fromBar: fromBar)
        }
    }

    public func show(fromBar: Bool = false) {
        animationGeneration &+= 1
        DashController.shared.hide()
        LauncherController.shared.hide()
        PowerMenuController.shared.hide()
        ProcessListController.shared.hide()
        PopoutCoordinator.shared.dismissAll()

        guard let targetScreen = activeScreen() else { return }

        let columns = CcMetrics.clampColumns(ConfigStore.shared.config.controlCenterColumns)
        let bodyWidth: CGFloat = columns == CcMetrics.defaultColumns ? CcMetrics.defaultSheetWidth : CcMetrics.sheetWidthFor(columns: columns)
        currentSheetHeight = Self.preferredSheetHeight()
        let solved = PopoutLayoutHelper.frame(
            bodyWidth: bodyWidth,
            bodyHeight: currentSheetHeight,
            screen: targetScreen,
            isControlCenter: true
        )
        // Never open partially off-screen on asymmetrical multi-monitor setups.
        let targetFrame = clampedFrame(solved, in: targetScreen.visibleFrame)

        panel.setFrame(targetFrame, display: false)
        // Fresh-mount ControlCenterView so entrance scaling & state reset cleanly
        panel.contentView = NSHostingView(rootView: ControlCenterView())

        isVisible = true
        PopoutAnimationHelper.animateIn(panel: panel, targetFrame: targetFrame, screen: targetScreen)
        installClickMonitor()
    }

    public func hide() {
        guard isVisible else { return }
        animationGeneration &+= 1
        let capturedGen = animationGeneration
        removeClickMonitor()
        isVisible = false
        PowerPopoutController.shared.hide()

        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        animateOut(capturedGen: capturedGen, screen: screen)
    }

    /// Exit animation mirroring `PopoutAnimationHelper.animateOut`, but the completion
    /// only orders the panel out when no newer `show()`/`hide()` superseded it. When the
    /// panel is hidden its content view is detached so SwiftUI timers (e.g. the 30s
    /// uptime ticker) are suspended and consume zero CPU while hidden.
    private func animateOut(capturedGen: UInt64, screen: NSScreen?) {
        let panel = self.panel
        guard panel.isVisible else {
            if animationGeneration == capturedGen {
                panel.orderOut(nil)
                panel.contentView = nil
            }
            return
        }

        NotificationCenter.default.post(name: .popoutWillDismiss, object: panel)

        let exitCurve = MaterialComponents.PopoutAnimationHelper.exitCurve
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = MaterialComponents.PopoutAnimationHelper.exitDuration
            ctx.timingFunction = CAMediaTimingFunction(
                controlPoints: Float(exitCurve.c1x), Float(exitCurve.c1y), Float(exitCurve.c2x), Float(exitCurve.c2y)
            )
            panel.animator().alphaValue = 0.0
        } completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                guard let self, self.animationGeneration == capturedGen, !self.isVisible else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1.0
                // Detach the hosting view so timers inside ControlCenterView stop while hidden.
                panel.contentView = nil
            }
        }
    }

    public func reposition(on screen: NSScreen) {
        let columns = CcMetrics.clampColumns(ConfigStore.shared.config.controlCenterColumns)
        let bodyWidth: CGFloat = columns == CcMetrics.defaultColumns ? CcMetrics.defaultSheetWidth : CcMetrics.sheetWidthFor(columns: columns)
        let solved = PopoutLayoutHelper.frame(
            bodyWidth: bodyWidth,
            bodyHeight: currentSheetHeight,
            screen: screen,
            isControlCenter: true
        )
        let frame = clampedFrame(solved, in: screen.visibleFrame)
        panel.setFrame(frame, display: true)
    }

    public func updateHeight(to newHeight: CGFloat) {
        guard isVisible else {
            currentSheetHeight = newHeight
            return
        }
        guard abs(currentSheetHeight - newHeight) > 1.0 else { return }
        currentSheetHeight = newHeight
        guard let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let columns = CcMetrics.clampColumns(ConfigStore.shared.config.controlCenterColumns)
        let bodyWidth: CGFloat = columns == CcMetrics.defaultColumns ? CcMetrics.defaultSheetWidth : CcMetrics.sheetWidthFor(columns: columns)
        let solved = PopoutLayoutHelper.frame(
            bodyWidth: bodyWidth,
            bodyHeight: newHeight,
            screen: screen,
            isControlCenter: true
        )
        let frame = clampedFrame(solved, in: screen.visibleFrame)
        panel.setFrame(frame, display: true, animate: true)
    }

    private func installClickMonitor() {
        removeClickMonitor()
        // Global monitor: clicks in other apps always dismiss (mouse is outside the panel).
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isVisible else { return }
                let loc = NSEvent.mouseLocation
                if !NSMouseInRect(loc, self.panel.frame, false),
                   !PopoutCoordinator.shared.isPointInsideAnyPopout(loc) {
                    self.hide()
                }
            }
        }
        // Local monitor: clicks inside this app (e.g. another DMS panel) dismiss too,
        // but clicks within the Control Center panel or an anchored popout are left alone.
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, self.isVisible else { return }
                let loc = NSEvent.mouseLocation
                if !NSMouseInRect(loc, self.panel.frame, false),
                   !PopoutCoordinator.shared.isPointInsideAnyPopout(loc) {
                    self.hide()
                }
            }
            return event
        }
    }

    private func removeClickMonitor() {
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
