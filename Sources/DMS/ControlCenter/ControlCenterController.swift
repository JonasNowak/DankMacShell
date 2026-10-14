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
        LauncherController.shared.hide()
        PowerMenuController.shared.hide()

        reposition(on: screen)
        panel.orderFront(nil)
        isVisible = true

        installClickMonitor()
    }

    public func hide() {
        guard isVisible else { return }
        panel.orderOut(nil)
        isVisible = false
        removeClickMonitor()
    }

    public func reposition(on screen: NSScreen) {
        let isBottom = ConfigStore.shared.config.barPosition.lowercased() == "bottom"
        let popoutWidth: CGFloat = 360
        let marginX: CGFloat = CGFloat(ConfigStore.shared.config.barMarginX)
        let gap: CGFloat = 12

        let visibleFrame = screen.visibleFrame
        let fullFrame = screen.frame

        let xPos = fullFrame.maxX - popoutWidth - marginX

        let popoutHeight: CGFloat
        let yPos: CGFloat

        if isBottom {
            // Anchor strictly above the top edge of the bottom bar
            let barFrame = DankBarController.shared.panel.frame
            let barTop = barFrame.height > 0 ? barFrame.maxY : (fullFrame.minY + 8 + DankBarController.barHeight)
            yPos = barTop + gap

            let availableHeight = visibleFrame.maxY - yPos - gap
            popoutHeight = min(620, max(300, availableHeight))
        } else {
            // Anchor strictly below the bottom edge of the top bar
            let barFrame = DankBarController.shared.panel.frame
            let barBottom = barFrame.height > 0 ? barFrame.minY : (fullFrame.maxY - 8 - DankBarController.barHeight)

            let availableHeight = barBottom - visibleFrame.minY - gap
            popoutHeight = min(620, max(300, availableHeight))
            yPos = barBottom - popoutHeight - gap
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
