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

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        guard let screen = NSScreen.main else { return }
        DashController.shared.hide()
        LauncherController.shared.hide()
        PowerMenuController.shared.hide()
        ProcessListController.shared.hide()
        AudioPopoutController.shared.hide()
        BatteryPopoutController.shared.hide()
        DurationPopoutController.shared.hide()
        ColorPickerPopoutController.shared.hide()
        PowerPopoutController.shared.hide()

        reposition(on: screen)
        panel.orderFront(nil)
        isVisible = true

        installClickMonitor()
    }

    public func hide() {
        guard isVisible else { return }
        PowerPopoutController.shared.hide()
        panel.orderOut(nil)
        isVisible = false
        removeClickMonitor()
    }

    public func reposition(on screen: NSScreen) {
        let barPosition = ConfigStore.shared.config.barPosition.lowercased()
        let isBottom = barPosition == "bottom"
        let isVertical = barPosition == "left" || barPosition == "right"
        let columns = CcMetrics.clampColumns(ConfigStore.shared.config.controlCenterColumns)
        let popoutWidth: CGFloat = columns == 8 ? CcMetrics.defaultSheetWidth : CcMetrics.sheetWidthFor(columns: columns)
        let marginX: CGFloat = CGFloat(ConfigStore.shared.config.barMarginX)
        let gap: CGFloat = 10
        let popoutHeight: CGFloat = 348

        let visibleFrame = screen.visibleFrame
        let fullFrame = screen.frame

        let barPanel = DankBarController.shared.panels.values.first(where: { $0.screen == screen }) ?? DankBarController.shared.panel
        let barFrame = barPanel.frame

        let yPos: CGFloat
        let xPos: CGFloat

        if isVertical {
            let mouseLoc = NSEvent.mouseLocation
            yPos = max(visibleFrame.minY + 12, min(visibleFrame.maxY - popoutHeight - 12, mouseLoc.y - popoutHeight / 2.0))
            if barPosition == "left" {
                let barRight = barFrame.width > 0 ? barFrame.maxX : (fullFrame.minX + DankBarController.verticalBarWidth + 8)
                xPos = barRight + gap
            } else {
                let barLeft = barFrame.width > 0 ? barFrame.minX : (fullFrame.maxX - DankBarController.verticalBarWidth - 8)
                xPos = barLeft - popoutWidth - gap
            }
        } else if isBottom {
            xPos = fullFrame.maxX - popoutWidth - marginX
            let barTop = barFrame.height > 0 ? barFrame.maxY : (fullFrame.minY + 8 + DankBarController.barHeight)
            yPos = min(visibleFrame.maxY - popoutHeight - gap, barTop + gap)
        } else {
            xPos = fullFrame.maxX - popoutWidth - marginX
            let barBottom = barFrame.height > 0 ? barFrame.minY : (fullFrame.maxY - 8 - DankBarController.barHeight)
            yPos = max(visibleFrame.minY + gap, barBottom - popoutHeight - gap)
        }

        let frame = NSRect(x: xPos, y: yPos, width: popoutWidth, height: popoutHeight)
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
