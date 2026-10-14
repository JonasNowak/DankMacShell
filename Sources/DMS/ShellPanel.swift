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

    public override var canBecomeKey: Bool {
        // Overlay modals (Launcher, PowerMenu) can become key to receive typing/keyboard events.
        return true
    }

    public override var canBecomeMain: Bool {
        return false
    }
}
