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

    /// v0.7 CLI: the in-flight `dms dmenu` request whose result must be delivered on dismiss.
    private var activeDMenuRequestID: String?

    private init() {
        panel = ShellPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.onEscape = { [weak self] in
            self?.hide()
        }

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
        // Fresh session ID per presentation so SwiftUI recreates `@State` and re-runs `.onAppear`
        // (search field focus, initial query) instead of reusing stale state on the hosting view.
        let sessionID = UUID()
        present {
            LauncherView(initialQuery: initialQuery, sessionID: sessionID) { [weak self] in
                self?.hide()
            }
        }
    }

    /// v0.7 CLI: shows the launcher in dmenu filter mode listing plain string candidates
    /// staged by `dms dmenu`. The selection is streamed back over the requesting socket connection.
    public func showDMenu(prompt: String, candidatesFile: String, requestID: String) {
        let sessionID = UUID()
        activeDMenuRequestID = requestID
        present {
            LauncherView(
                dmenuPrompt: prompt,
                candidatesFile: candidatesFile,
                requestID: requestID,
                sessionID: sessionID,
                onDMenuResolved: { [weak self] in
                    self?.activeDMenuRequestID = nil
                }
            ) { [weak self] in
                self?.hide()
            }
        }
    }

    /// Resizes the panel between the plain launcher width and the wider width that fits the
    /// per-app action sidebar without clipping it.
    public func resizeForActionPanel(_ show: Bool) {
        let frame = panel.frame
        let newWidth: CGFloat = show ? 900 : 680
        guard frame.width != newWidth else { return }
        panel.setFrame(
            NSRect(x: frame.midX - newWidth / 2, y: frame.minY, width: newWidth, height: frame.height),
            display: true
        )
    }

    private func present(_ makeView: () -> LauncherView) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        // Capture the previously active app before taking focus so `:emoji` / `nf:` auto-paste
        // targets the app the user came from.
        AutoPasteService.shared.capturePreviousApp()
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

        let wasVisible = isVisible
        AppCatalogService.shared.refresh()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
        if !wasVisible {
            SoundEffectService.shared.playLauncherOpen()
        }

        installClickMonitor()
    }

    public func hide() {
        guard isVisible else { return }
        panel.orderOut(nil)
        isVisible = false
        removeClickMonitor()
        // Never leave a `dms dmenu` request hanging: clicking outside or pressing Escape
        // delivers a cancelled result so the CLI exits instead of blocking forever.
        if let reqID = activeDMenuRequestID {
            activeDMenuRequestID = nil
            IPCSocketServer.shared.deliverDMenuResult(requestID: reqID, line: nil, cancelled: true)
        }
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
