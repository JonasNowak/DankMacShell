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
        present {
            LauncherView(initialQuery: initialQuery) { [weak self] in
                self?.hide()
            }
        }
    }

    /// v0.7 CLI: shows the launcher in dmenu filter mode listing plain string candidates
    /// staged by `dms dmenu`. The selection is streamed back over the requesting socket connection.
    public func showDMenu(prompt: String, candidatesFile: String, requestID: String) {
        present {
            LauncherView(dmenuPrompt: prompt, candidatesFile: candidatesFile, requestID: requestID) { [weak self] in
                self?.hide()
            }
        }
    }

    private func present(_ makeView: () -> LauncherView) {
        guard let screen = NSScreen.main else { return }
        ControlCenterController.shared.hide()
        PowerMenuController.shared.hide()
        DashController.shared.hide()

        let width: CGFloat = 680
        let height: CGFloat = 540

        // v0.6 LAUNCH: "island" attachment anchors the launcher directly below the
        // Dynamic Island / notch (top-center below the menu bar on notchless displays).
        let mode = LauncherAttachmentMode.parse(ConfigStore.shared.config.launcherAttachment)
        if mode == .island {
            DIslandController.shared.collapse()
        }
        let notch = screen.extractNotchGeometry()
        let frame = LauncherPlacementSolver.solve(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            notch: notch,
            mode: mode,
            panelWidth: width,
            panelHeight: height
        )
        panel.setFrame(frame, display: true)

        let rootView = makeView()
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
