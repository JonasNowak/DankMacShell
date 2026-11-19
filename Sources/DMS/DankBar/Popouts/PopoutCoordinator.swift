import AppKit
import DMSCore

/// Common interface implemented by every DankBar popout controller
/// (`Audio`, `Battery`, `ColorPicker`, `Duration`, `Power`, `Symbian`).
@MainActor
public protocol PopoutController: AnyObject {
    /// Stable identifier used by the coordinator registry (e.g. `"power"`).
    var popoutID: String { get }
    /// The currently presented `ShellPanel`, if any.
    var popoutPanel: ShellPanel? { get }
    /// Whether the popout is currently visible.
    var isPopoutVisible: Bool { get }
    /// Dismisses the popout (same as `hide()`).
    func hidePopout()
}

/// Central registry for all open DankBar popouts.
///
/// - A newly shown popout calls `dismissAll(except:)` so opening one popout closes its
///   peers without each controller hand-maintaining a peer list.
/// - `DankBarController` reads `anyPopoutVisible` to pause auto-hide collapse while any
///   popout is open.
/// - Each controller additionally installs its own local + global mouse-down monitors in
///   `show(...)` (removed in `hide(...)`) so clicking another DMS panel or the desktop
///   dismisses the open popouts.
@MainActor
public final class PopoutCoordinator {
    public static let shared = PopoutCoordinator()

    private struct Entry {
        weak var controller: PopoutController?
    }

    private var entries: [String: Entry] = [:]

    private init() {}

    // MARK: - Registry

    public func register(_ controller: PopoutController) {
        entries[controller.popoutID] = Entry(controller: controller)
    }

    public func unregister(_ popoutID: String) {
        entries.removeValue(forKey: popoutID)
    }

    /// Dismisses every open popout except `exceptID` (used when a new popout opens).
    public func dismissAll(except exceptID: String? = nil) {
        for (id, entry) in entries where id != exceptID {
            entry.controller?.hidePopout()
        }
    }

    /// True when at least one popout is currently visible (optionally excluding one id).
    public func anyPopoutVisible(except exceptID: String? = nil) -> Bool {
        entries.contains { id, entry in
            id != exceptID && (entry.controller?.isPopoutVisible ?? false)
        }
    }

    /// True when the given point lies inside any open popout panel.
    public func isPointInsideAnyPopout(_ point: CGPoint, except exceptID: String? = nil) -> Bool {
        entries.contains { id, entry in
            guard id != exceptID,
                  let controller = entry.controller,
                  controller.isPopoutVisible,
                  let panel = controller.popoutPanel else { return false }
            return NSMouseInRect(point, panel.frame, false)
        }
    }

    /// True when the given point lies inside any DankBar panel (clicks there are handled
    /// by the bar buttons themselves and must not auto-dismiss popouts).
    public func isPointInsideAnyBar(_ point: CGPoint) -> Bool {
        DankBarController.shared.panels.values.contains { NSMouseInRect(point, $0.frame, false) }
    }
}
