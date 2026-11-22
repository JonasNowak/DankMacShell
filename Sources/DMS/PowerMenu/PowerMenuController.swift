import AppKit
import SwiftUI
import DMSCore

@MainActor
public final class PowerMenuController {
    public static let shared = PowerMenuController()

    public let panel: ShellPanel
    public private(set) var isVisible = false

    private var globalClickMonitor: Any?

    /// Phase 7 Shard 3: hot-plug observer token for `didChangeScreenParametersNotification`.
    private var screenParametersObserver: NSObjectProtocol?

    private init() {
        panel = ShellPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.onEscape = { [weak self] in self?.hide() }

        let rootView = PowerMenuView { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: rootView)

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

    /// Centered frame for the power menu on the given screen (full-screen overlay bounds).
    private func centeredFrame(on screen: NSScreen, width: CGFloat, height: CGFloat) -> NSRect {
        let raw = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.midY - height / 2,
            width: width,
            height: height
        )
        return clampedFrame(raw, in: screen.frame)
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

    /// Hot-plug / resolution change: keep the visible power menu centered on the surviving
    /// (or active) screen without closing it.
    private func handleScreenParametersChanged() {
        guard isVisible, panel.isVisible else { return }
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
        guard let screen = activeScreen() else { return }
        ControlCenterController.shared.hide()
        LauncherController.shared.hide()
        DashController.shared.hide()

        let width: CGFloat = 360
        let height: CGFloat = 195
        // Full-screen overlay: clamp into the screen's full frame so it can never open
        // partially off-screen on asymmetrical multi-monitor setups.
        panel.setFrame(centeredFrame(on: screen, width: width, height: height), display: true)
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
