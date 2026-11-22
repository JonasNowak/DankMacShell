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

    /// Phase 7 Shard 3: hot-plug observer token for `didChangeScreenParametersNotification`.
    private var screenParametersObserver: NSObjectProtocol?
    /// Attachment mode used by the current presentation, reused when re-anchoring on hot-plug.
    private var activeAttachmentMode: LauncherAttachmentMode = .center

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

        observeScreenParameters()
    }

    deinit {
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
        }
    }

    // MARK: - Phase 7 Shard 3: Multi-Monitor Anchoring & Hot-Plug

    /// Screen under the pointer, falling back to the main screen then any screen.
    private func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// The panel's current screen when still connected, else the active pointer screen.
    private func survivingScreen(for panel: NSPanel?) -> NSScreen? {
        if let screen = panel?.screen, NSScreen.screens.contains(screen) {
            return screen
        }
        return activeScreen()
    }

    /// Clamps a frame fully inside `bounds`, shrinking it when larger than the screen.
    private func clampedFrame(_ frame: NSRect, in bounds: NSRect) -> NSRect {
        let width = min(frame.width, bounds.width)
        let height = min(frame.height, bounds.height)
        let x = min(max(frame.minX, bounds.minX), bounds.maxX - width)
        let y = min(max(frame.minY, bounds.minY), bounds.maxY - height)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func observeScreenParameters() {
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleScreenParametersChanged()
            }
        }
    }

    /// Hot-plug / resolution change: re-anchor the visible panel onto the surviving screen
    /// without closing it or losing state.
    private func handleScreenParametersChanged() {
        guard isVisible, panel.isVisible else { return }
        guard let targetScreen = survivingScreen(for: panel) else { return }
        let notch = targetScreen.extractNotchGeometry()
        let solved = LauncherPlacementSolver.solve(
            screenFrame: targetScreen.frame,
            visibleFrame: targetScreen.visibleFrame,
            notch: notch,
            mode: activeAttachmentMode,
            panelWidth: panel.frame.width,
            panelHeight: panel.frame.height
        )
        panel.setFrame(clampedFrame(solved, in: targetScreen.visibleFrame), display: true)
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
        let resized = NSRect(x: frame.midX - newWidth / 2, y: frame.minY, width: newWidth, height: frame.height)
        let bounds = panel.screen?.visibleFrame ?? activeScreen()?.visibleFrame
        panel.setFrame(bounds.map { clampedFrame(resized, in: $0) } ?? resized, display: true)
    }

    private func present(_ makeView: () -> LauncherView) {
        guard let screen = activeScreen() else { return }
        if ConfigStore.shared.config.disableCapsLock {
            CapsLockGuardService.shared.clearHardwareCapsLock()
        }
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
        activeAttachmentMode = mode
        if mode == .island {
            DIslandController.shared.collapse()
        }
        let notch = screen.extractNotchGeometry()
        let solved = LauncherPlacementSolver.solve(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            notch: notch,
            mode: mode,
            panelWidth: width,
            panelHeight: height
        )
        // Never open partially off-screen on asymmetrical multi-monitor setups.
        let frame = clampedFrame(solved, in: screen.visibleFrame)
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
