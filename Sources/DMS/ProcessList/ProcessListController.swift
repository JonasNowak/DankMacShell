import AppKit
import SwiftUI

/// Controller for the Process Manager modal panel.
@MainActor
public final class ProcessListController: ObservableObject {
    public static let shared = ProcessListController()

    private var panel: ShellPanel?
    @Published public private(set) var isVisible: Bool = false
    public private(set) var currentSortByMemory: Bool = false
    private var globalClickMonitor: Any?

    private init() {}

    public func toggle(sortByMemory: Bool = false, anchorX: CGFloat? = nil) {
        if isVisible {
            if currentSortByMemory == sortByMemory {
                hide()
            } else {
                hide()
                show(sortByMemory: sortByMemory, anchorX: anchorX)
            }
        } else {
            show(sortByMemory: sortByMemory, anchorX: anchorX)
        }
    }

    public func show(sortByMemory: Bool = false, anchorX: CGFloat? = nil) {
        if isVisible {
            if currentSortByMemory == sortByMemory {
                return
            }
            hide()
        }

        // Close peer popouts
        DashController.shared.hide()
        AudioPopoutController.shared.hide()
        BatteryPopoutController.shared.hide()
        ControlCenterController.shared.hide()

        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visibleFrame = screen.visibleFrame
        let fullFrame = screen.frame

        let width: CGFloat = 400
        let height: CGFloat = 350
        let gap: CGFloat = 10
        let isBottom = ConfigStore.shared.config.barPosition.lowercased() == "bottom"
        let isVertical = ConfigStore.shared.config.barPosition.lowercased() == "left" || ConfigStore.shared.config.barPosition.lowercased() == "right"

        // Center on the trigger applet's X coordinate, clamped to visible screen margins
        let targetX = (anchorX != nil && anchorX! > 0) ? anchorX! : mouseLoc.x
        var xPos = targetX - width / 2.0
        xPos = max(visibleFrame.minX + 12, min(visibleFrame.maxX - width - 12, xPos))

        let barPanel = DankBarController.shared.panels.values.first(where: { $0.screen == screen }) ?? DankBarController.shared.panel
        let barFrame = barPanel.frame

        let yPos: CGFloat
        if isBottom {
            let barTop = barFrame.height > 0 ? barFrame.maxY : (fullFrame.minY + 8 + DankBarController.barHeight)
            yPos = min(visibleFrame.maxY - height - gap, barTop + gap)
        } else if !isVertical {
            let barBottom = barFrame.height > 0 ? barFrame.minY : (fullFrame.maxY - 8 - DankBarController.barHeight)
            yPos = max(visibleFrame.minY + gap, barBottom - height - gap)
        } else {
            let targetY = mouseLoc.y
            yPos = max(visibleFrame.minY + 12, min(visibleFrame.maxY - height - 12, targetY - height / 2.0))
            let barRight = barFrame.width > 0 ? barFrame.maxX : (fullFrame.minX + DankBarController.verticalBarWidth + 8)
            let barLeft = barFrame.width > 0 ? barFrame.minX : (fullFrame.maxX - DankBarController.verticalBarWidth - 8)
            if ConfigStore.shared.config.barPosition.lowercased() == "left" {
                xPos = barRight + gap
            } else {
                xPos = barLeft - width - gap
            }
        }

        let rect = NSRect(x: xPos, y: yPos, width: width, height: height)

        let panel = ShellPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating

        let view = ProcessListView(sortByMemory: sortByMemory) { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: view)

        self.panel = panel
        self.isVisible = true
        self.currentSortByMemory = sortByMemory

        panel.makeKeyAndOrderFront(nil)
        installClickMonitor()
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
