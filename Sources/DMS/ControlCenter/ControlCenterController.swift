import AppKit
import SwiftUI
import DMSCore

@MainActor
public final class ControlCenterController {
    public static let shared = ControlCenterController()
    public static let standardSheetHeight: CGFloat = 368.0

    public let panel: ShellPanel
    public private(set) var isVisible = false
    public private(set) var currentSheetHeight: CGFloat = standardSheetHeight

    private var globalClickMonitor: Any?

    private init() {
        panel = ShellPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
    }

    public func toggle(fromBar: Bool = false) {
        if isVisible {
            hide()
        } else {
            show(fromBar: fromBar)
        }
    }

    public func show(fromBar: Bool = false) {
        DashController.shared.hide()
        LauncherController.shared.hide()
        PowerMenuController.shared.hide()
        ProcessListController.shared.hide()
        AudioPopoutController.shared.hide()
        BatteryPopoutController.shared.hide()
        DurationPopoutController.shared.hide()
        ColorPickerPopoutController.shared.hide()
        SymbianPopoutController.shared.hide()
        PowerPopoutController.shared.hide()

        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = screen else { return }

        let columns = CcMetrics.clampColumns(ConfigStore.shared.config.controlCenterColumns)
        let bodyWidth: CGFloat = columns == 8 ? CcMetrics.defaultSheetWidth : CcMetrics.sheetWidthFor(columns: columns)
        currentSheetHeight = Self.standardSheetHeight
        let targetFrame = PopoutLayoutHelper.frame(
            bodyWidth: bodyWidth,
            bodyHeight: Self.standardSheetHeight,
            screen: targetScreen,
            isControlCenter: true
        )

        panel.setFrame(targetFrame, display: false)
        // Fresh-mount ControlCenterView so entrance scaling & state reset cleanly
        panel.contentView = NSHostingView(rootView: ControlCenterView())

        isVisible = true
        PopoutAnimationHelper.animateIn(panel: panel, targetFrame: targetFrame, screen: targetScreen)
        installClickMonitor()
    }

    public func hide() {
        guard isVisible else { return }
        removeClickMonitor()
        isVisible = false
        PowerPopoutController.shared.hide()

        let screen = panel.screen ?? NSScreen.main
        PopoutAnimationHelper.animateOut(panel: panel, screen: screen)
    }

    public func reposition(on screen: NSScreen) {
        let columns = CcMetrics.clampColumns(ConfigStore.shared.config.controlCenterColumns)
        let bodyWidth: CGFloat = columns == 8 ? CcMetrics.defaultSheetWidth : CcMetrics.sheetWidthFor(columns: columns)
        let frame = PopoutLayoutHelper.frame(
            bodyWidth: bodyWidth,
            bodyHeight: currentSheetHeight,
            screen: screen,
            isControlCenter: true
        )
        panel.setFrame(frame, display: true)
    }

    public func updateHeight(to newHeight: CGFloat) {
        guard isVisible else {
            currentSheetHeight = newHeight
            return
        }
        guard abs(currentSheetHeight - newHeight) > 1.0 else { return }
        currentSheetHeight = newHeight
        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let columns = CcMetrics.clampColumns(ConfigStore.shared.config.controlCenterColumns)
        let bodyWidth: CGFloat = columns == 8 ? CcMetrics.defaultSheetWidth : CcMetrics.sheetWidthFor(columns: columns)
        let frame = PopoutLayoutHelper.frame(
            bodyWidth: bodyWidth,
            bodyHeight: newHeight,
            screen: screen,
            isControlCenter: true
        )
        panel.setFrame(frame, display: true, animate: true)
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
