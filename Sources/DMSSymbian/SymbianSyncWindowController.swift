import AppKit
import SwiftUI
import DMSCore

final class SymbianSyncWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            self.performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Controller managing the presentation and lifecycle of the Nokia Belle USB Sync companion window.
@MainActor
public final class SymbianSyncWindowController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = SymbianSyncWindowController()

    private var window: SymbianSyncWindow?
    @Published public private(set) var isVisible: Bool = false

    private override init() {
        super.init()
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        if !SymbianSyncService.shared.isRunning {
            SymbianSyncService.shared.start()
        }

        if let win = window, isVisible {
            win.makeKeyAndOrderFront(nil)
            win.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let width: CGFloat = 720
        let height: CGFloat = 560

        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 100, y: 100, width: 1200, height: 800)

        let rect = NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )

        let win = SymbianSyncWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        win.title = "Nokia Belle USB Sync"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.backgroundColor = .clear
        win.isReleasedWhenClosed = false
        win.delegate = self

        let view = SymbianSyncView { [weak self] in
            self?.hide()
        }
        win.contentView = NSHostingView(rootView: view)

        self.window = win
        self.isVisible = true

        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    public func hide() {
        guard isVisible else { return }
        window?.orderOut(nil)
        window = nil
        isVisible = false
        // If run as a standalone app, exit when closed
        if CommandLine.arguments.contains("--gui") || CommandLine.arguments.count <= 1 {
            NSApp.terminate(nil)
        }
    }

    public func windowWillClose(_ notification: Notification) {
        isVisible = false
        window = nil
        if CommandLine.arguments.contains("--gui") || CommandLine.arguments.count <= 1 {
            NSApp.terminate(nil)
        }
    }
}
