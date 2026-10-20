import AppKit
import SwiftUI
import DMSCore

@MainActor
public final class LauncherController {
    public static let shared = LauncherController()

    public let panel: ShellPanel
    public private(set) var isVisible = false

    private var globalClickMonitor: Any?

    private var hostingView: NSHostingView<LauncherView>?

    private init() {
        panel = ShellPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating

        let rootView = LauncherView(initialQuery: "") { [weak self] in
            self?.hide()
        }
        let host = NSHostingView(rootView: rootView)
        panel.contentView = host
        self.hostingView = host
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show(query initialQuery: String = "") {
        guard let screen = NSScreen.main else { return }
        ControlCenterController.shared.hide()
        PowerMenuController.shared.hide()
        DashController.shared.hide()

        let width: CGFloat = 680
        let height: CGFloat = 540
        let xPos = screen.frame.midX - (width / 2)
        let yPos = screen.frame.midY - (height / 2) + 60

        let frame = NSRect(x: xPos, y: yPos, width: width, height: height)
        panel.setFrame(frame, display: true)

        let rootView = LauncherView(initialQuery: initialQuery) { [weak self] in
            self?.hide()
        }
        if let host = hostingView {
            host.rootView = rootView
        } else {
            let host = NSHostingView(rootView: rootView)
            panel.contentView = host
            self.hostingView = host
        }

        AppCatalogService.shared.refresh()
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
