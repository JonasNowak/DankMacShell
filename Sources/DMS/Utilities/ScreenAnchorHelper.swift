import AppKit
import CoreGraphics

/// Stable display anchoring helpers for multi-monitor window management.
///
/// `NSScreen.screens` array indices are volatile across hot-plug, display reordering,
/// and sleep/wake cycles. `CGDirectDisplayID` values are stable for the lifetime of a
/// display connection and are the correct key for per-monitor panels, notch
/// geometries, and fullscreen state.
public extension NSScreen {
    /// The stable `CGDirectDisplayID` for this screen, or 0 when it cannot be determined.
    var displayID: CGDirectDisplayID {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return 0
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    /// Whether this screen is the current main (primary) display.
    var isPrimaryDisplay: Bool {
        displayID == CGMainDisplayID()
    }

    /// The screen currently under the mouse pointer, falling back to the main display
    /// and then to the first connected screen.
    static func activeScreenForPointer() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    /// Looks up a connected screen by its stable display id.
    static func screen(forDisplayID id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.displayID == id }
    }
}
