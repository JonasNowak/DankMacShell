import AppKit
import SwiftUI
import DMSCore

@MainActor
public final class PowerMenuController {
    public static let shared = PowerMenuController()

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
        panel.level = .floating

        let rootView = PowerMenuView { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: rootView)
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
        ControlCenterController.shared.hide()
        LauncherController.shared.hide()

        let width: CGFloat = 440
        let height: CGFloat = 200
        let xPos = screen.frame.midX - (width / 2)
        let yPos = screen.frame.midY - (height / 2)

        panel.setFrame(NSRect(x: xPos, y: yPos, width: width, height: height), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true

        installClickMonitor()
    }

    public func hide() {
        guard isVisible else { return }
        panel.orderOut(nil)
        isVisible = false
        removeClickMonitor()
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
