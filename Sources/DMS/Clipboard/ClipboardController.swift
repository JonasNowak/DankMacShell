import AppKit
import SwiftUI

/// Controller for the Clipboard History modal panel.
@MainActor
public final class ClipboardController: ObservableObject {
    public static let shared = ClipboardController()

    private var panel: ShellPanel?
    private var globalClickMonitor: Any?
    @Published public private(set) var isVisible: Bool = false

    /// Phase 7 Shard 3: hot-plug observer token for `didChangeScreenParametersNotification`.
    private var screenParametersObserver: NSObjectProtocol?

    private init() {
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

    /// Centered frame inside the screen's visible frame.
    private func centeredFrame(on screen: NSScreen, width: CGFloat, height: CGFloat) -> NSRect {
        let visibleFrame = screen.visibleFrame
        let raw = NSRect(
            x: visibleFrame.minX + (visibleFrame.width - width) / 2,
            y: visibleFrame.minY + (visibleFrame.height - height) / 2,
            width: width,
            height: height
        )
        return clampedFrame(raw, in: visibleFrame)
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
        guard isVisible, let panel = panel, panel.isVisible else { return }
        guard let targetScreen = survivingScreen(for: panel) else { return }
        panel.setFrame(centeredFrame(on: targetScreen, width: panel.frame.width, height: panel.frame.height), display: true)
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        guard !isVisible else { return }

        DashController.shared.hide()
        // v0.6 CLIP: remember the app that had focus before the panel activates,
        // so Return on a history item can auto-paste back into it.
        AutoPasteService.shared.capturePreviousApp()
        guard let screen = activeScreen() else { return }

        let width: CGFloat = 480
        let height: CGFloat = 440
        // Never open partially off-screen on asymmetrical multi-monitor setups.
        let rect = centeredFrame(on: screen, width: width, height: height)

        let panel = ShellPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.onEscape = { [weak self] in self?.hide() }

        let view = ClipboardView { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: view)

        self.panel = panel
        self.isVisible = true

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        installClickMonitor()
    }

    public func hide() {
        guard isVisible else { return }
        panel?.orderOut(nil)
        panel = nil
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
