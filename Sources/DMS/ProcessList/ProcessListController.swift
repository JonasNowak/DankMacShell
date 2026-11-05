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
        DurationPopoutController.shared.hide()
        ColorPickerPopoutController.shared.hide()
        SymbianPopoutController.shared.hide()
        PowerPopoutController.shared.hide()
        ControlCenterController.shared.hide()

        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let bodyWidth: CGFloat = 400
        let bodyHeight: CGFloat = 350

        let rect = PopoutLayoutHelper.frame(
            bodyWidth: bodyWidth,
            bodyHeight: bodyHeight,
            anchorX: anchorX,
            screen: screen
        )

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

        PopoutAnimationHelper.animateIn(panel: panel, targetFrame: rect, screen: screen)
        installClickMonitor()
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
