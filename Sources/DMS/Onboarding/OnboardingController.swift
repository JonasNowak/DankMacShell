import AppKit
import SwiftUI
import ServiceManagement
import DMSCore
import os

/// Manages "Launch DankMacShell at Login" through `SMAppService` and mirrors the
/// choice into `settings.json` (`rawSettings["launchAtLogin"]`) so the CLI and
/// other tooling can read it without touching ServiceManagement.
@MainActor
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    private static let log = Logger(subsystem: "com.dank.macshell", category: "LaunchAtLoginManager")

    @Published public private(set) var isEnabled: Bool = SMAppService.mainApp.status == .enabled

    private init() {
        refreshStatus()
    }

    /// True when the main app is registered as a login item.
    public static var isEnabled: Bool {
        shared.isEnabled
    }

    public func refreshStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Self.log.error("Failed to \(enabled ? "enable" : "disable", privacy: .public) launch at login: \(error.localizedDescription, privacy: .public)")
        }
        refreshStatus()
        ConfigStore.shared.update { $0.launchAtLogin = enabled }
    }

    /// Static convenience forwarder.
    public static func setEnabled(_ enabled: Bool) {
        shared.setEnabled(enabled)
    }
}

/// Controller for the first-run 5-step onboarding wizard window.
/// Hosts a centered, titled `OnboardingView` in a 680x540 window.
@MainActor
public final class OnboardingController: NSObject, NSWindowDelegate {
    public static let shared = OnboardingController()

    private var window: NSWindow?
    @Published public private(set) var isVisible: Bool = false

    private override init() {
        super.init()
    }

    public func show() {
        if let window = window, isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let width: CGFloat = 680
        let height: CGFloat = 540
        let visibleFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: width, height: height)
        let rect = NSRect(
            x: visibleFrame.minX + (visibleFrame.width - width) / 2,
            y: visibleFrame.minY + (visibleFrame.height - height) / 2,
            width: width,
            height: height
        )

        let window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "DankMacShell Setup"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.delegate = self
        window.contentView = NSHostingView(rootView: OnboardingView(onFinish: { [weak self] in
            self?.hide()
        }))

        self.window = window
        self.isVisible = true

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func hide() {
        window?.orderOut(nil)
        isVisible = false
        window = nil
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - NSWindowDelegate

    public func windowWillClose(_ notification: Notification) {
        isVisible = false
        window = nil
    }
}
