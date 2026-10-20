import AppKit
import SwiftUI
import DMSCore

final class SettingsWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            self.performClose(nil)
            return true
        }
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
            self.performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Controller for the comprehensive DMS Settings window.
/// Displays a large, full-featured settings application with macOS server-side decorations (SSD).
@MainActor
public final class SettingsController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = SettingsController()

    private var window: SettingsWindow?
    @Published public private(set) var isVisible: Bool = false
    @Published public var currentTab: DMSSettingsTab = .theme

    private override init() {
        super.init()
    }

    public func toggle(tab: String? = nil) {
        if isVisible {
            hide()
        } else {
            show(tab: tab)
        }
    }

    public func show(tab: String? = nil) {
        if let tab = tab {
            currentTab = DMSSettingsTab.resolve(tab: tab)
        }

        if let window = window, isVisible {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        DashController.shared.hide()
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = screen else { return }
        let visibleFrame = targetScreen.visibleFrame

        // Large Settings Window (per spec 31-settings-ui-a: 980x700 pt)
        let width: CGFloat = 980
        let height: CGFloat = 700
        let rect = NSRect(
            x: visibleFrame.minX + (visibleFrame.width - width) / 2,
            y: visibleFrame.minY + (visibleFrame.height - height) / 2,
            width: width,
            height: height
        )

        // Native macOS window with Server-Side Decorations (SSD): titled, closable, miniaturizable, resizable
        let window = SettingsWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.minSize = NSSize(width: 840, height: 560)
        window.collectionBehavior = [.fullScreenAuxiliary, .participatesInCycle]
        window.delegate = self

        let view = SettingsView(initialTab: tab) { [weak self] in
            self?.hide()
        }
        window.contentView = NSHostingView(rootView: view)

        self.window = window
        self.isVisible = true

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    public func hide() {
        guard isVisible else { return }
        ConfigStore.shared.flushSave()
        window?.orderOut(nil)
        isVisible = false
        DispatchQueue.main.async { [weak self] in
            self?.window = nil
        }
    }

    // MARK: - NSWindowDelegate
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }

    public func windowWillClose(_ notification: Notification) {
        isVisible = false
        ConfigStore.shared.flushSave()
        DispatchQueue.main.async { [weak self] in
            self?.window = nil
        }
    }
}
