import AppKit
import SwiftUI

/// Non-activating borderless NSPanel configured for desktop shell surfaces.
public class ShellPanel: NSPanel {
    public override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel],
        backing: NSWindow.BackingStoreType = .buffered,
        defer flag: Bool = false
    ) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .statusBar
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
    }

    public var onEscape: (() -> Void)?

    public override var canBecomeKey: Bool {
        // Overlay modals (Launcher, PowerMenu, Settings) can become key to receive typing/keyboard events.
        return true
    }

    public override var canBecomeMain: Bool {
        return false
    }

    public override func cancelOperation(_ sender: Any?) {
        if let onEscape = onEscape {
            onEscape()
        } else {
            super.cancelOperation(sender)
        }
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            if let onEscape = onEscape {
                onEscape()
                return
            }
        }
        super.keyDown(with: event)
    }
}
