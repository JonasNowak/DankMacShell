import AppKit
import SwiftUI
import DMSCore

@MainActor
public final class ControlCenterController {
    public static let shared = ControlCenterController()

    public let panel: ShellPanel
    public private(set) var isVisible = false

    private var globalClickMonitor: Any?

    private init() {
        panel = ShellPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: ControlCenterView())
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
        PowerPopoutController.shared.hide()

        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = screen else { return }

        let columns = CcMetrics.clampColumns(ConfigStore.shared.config.controlCenterColumns)
        let bodyWidth: CGFloat = columns == 8 ? CcMetrics.defaultSheetWidth : CcMetrics.sheetWidthFor(columns: columns)
        let targetFrame = PopoutLayoutHelper.frame(
            bodyWidth: bodyWidth,
            bodyHeight: 348,
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
            bodyHeight: 348,
            screen: screen,
            isControlCenter: true
        )
        panel.setFrame(frame, display: true)
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
