import AppKit
import SwiftUI
import Combine
import DMSCore

/// Hosts the wallpaper-level desktop widgets panel (clock + telemetry card).
///
/// The panel only exists while `desktopWidgetsEnabled` is true in the config.
/// While enabled it registers a `desktop.widgets` telemetry consumer so the
/// polling timer stays alive; when disabled the consumer is removed and the
/// panel is ordered out and released (0% idle CPU when disabled).
@MainActor
public final class DesktopWidgetsController: ObservableObject {
    public static let shared = DesktopWidgetsController()

    private static let consumerID = "desktop.widgets"
    private static let panelSize = NSSize(width: 248, height: 168)
    private static let margin: CGFloat = 16

    private var panel: NSPanel?
    private var configCancellable: AnyCancellable?
    private var screenObserver: Any?
    private var isStarted = false

    private init() {}

    /// Idempotent: starts observing `desktopWidgetsEnabled` and shows/hides the panel.
    public func start() {
        guard !isStarted else { return }
        isStarted = true

        configCancellable = ConfigStore.shared.$config
            .map { $0.rawSettings["desktopWidgetsEnabled"]?.boolValue ?? false }
            .removeDuplicates()
            .sink { [weak self] enabled in
                Task { @MainActor [weak self] in
                    self?.setEnabled(enabled)
                }
            }

        setEnabled(ConfigStore.shared.config.rawSettings["desktopWidgetsEnabled"]?.boolValue ?? false)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reposition()
            }
        }
    }

    private func setEnabled(_ enabled: Bool) {
        if enabled {
            TelemetryService.shared.addConsumer(Self.consumerID)
            showPanel()
        } else {
            TelemetryService.shared.removeConsumer(Self.consumerID)
            hidePanel()
        }
    }

    private func showPanel() {
        if panel == nil {
            guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
            let p = NSPanel(
                contentRect: Self.frame(for: Self.panelSize, on: screen),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            // Sit just above the desktop icon window level so it floats over the wallpaper.
            p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.isMovable = false
            p.hidesOnDeactivate = false
            p.contentView = NSHostingView(rootView: DesktopWidgetsView())
            panel = p
        }
        reposition()
        panel?.orderFrontRegardless()
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func reposition() {
        guard let panel, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        panel.setFrame(Self.frame(for: panel.frame.size, on: screen), display: false)
    }

    /// Bottom-right corner of the primary screen's visible frame (desktop safe area).
    private static func frame(for size: NSSize, on screen: NSScreen) -> NSRect {
        let v = screen.visibleFrame
        return NSRect(
            x: v.maxX - size.width - margin,
            y: v.minY + margin,
            width: size.width,
            height: size.height
        )
    }
}
