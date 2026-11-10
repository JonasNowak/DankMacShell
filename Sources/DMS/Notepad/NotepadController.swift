import AppKit
import SwiftUI

/// Standard window for the Notepad: titled, closable, miniaturizable, resizable,
/// movable by background, and tileable like any regular macOS window.
final class NotepadWindow: NSWindow {
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

/// Controller for the Notepad scratchpad window.
@MainActor
public final class NotepadController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = NotepadController()

    private var window: NotepadWindow?
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
        if let window = window, isVisible {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        DashController.shared.hide()
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        let width: CGFloat = 780
        let height: CGFloat = 520
        let rect = NSRect(
            x: visibleFrame.maxX - width - 24,
            y: visibleFrame.minY + (visibleFrame.height - height) / 2,
            width: width,
            height: height
        )

        // Native macOS window with Server-Side Decorations (SSD): titled, closable, miniaturizable, resizable
        let window = NotepadWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Notepad"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.minSize = NSSize(width: 480, height: 360)
        window.collectionBehavior = [.fullScreenAuxiliary, .participatesInCycle]
        window.delegate = self

        let view = NotepadView { [weak self] in
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
        NotepadService.shared.flushPendingSave()
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
        NotepadService.shared.flushPendingSave()
        DispatchQueue.main.async { [weak self] in
            self?.window = nil
        }
    }
}
