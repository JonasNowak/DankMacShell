import Foundation

/// Where the DLauncherV2 panel attaches on screen (ROADMAP v0.6 LAUNCH).
public enum LauncherAttachmentMode: String, Sendable, Codable, CaseIterable, Equatable {
    /// Legacy behavior: centered on the main screen, slightly above center.
    case center
    /// Anchored directly below the Dynamic Island / hardware notch (top-center on notchless displays).
    case island

    public static func parse(_ raw: String?) -> LauncherAttachmentMode {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return .center
        }
        return LauncherAttachmentMode(rawValue: raw) ?? .center
    }
}

/// Pure geometry solver for DLauncherV2 panel placement.
/// UI-free so it can be unit-tested in DMSCoreTests.
public enum LauncherPlacementSolver {

    /// Vertical gap between the notch/menu bar and the launcher panel in island mode.
    public static let islandGap: CGFloat = 8.0

    /// Legacy vertical offset applied in center mode (matches historical LauncherController behavior).
    public static let centerLift: CGFloat = 60.0

    /// Computes the launcher panel frame for the given screen and attachment mode.
    /// - Parameters:
    ///   - screenFrame: full frame of the target screen (global coordinates).
    ///   - visibleFrame: visible (menu-bar/dock-excluded) frame of the target screen.
    ///   - notch: notch geometry of the target screen (`ScreenNotchGeometry`).
    ///   - mode: attachment mode.
    ///   - panelWidth / panelHeight: desired panel size.
    /// - Returns: the panel frame, clamped into `visibleFrame` when it would overflow.
    public static func solve(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        notch: ScreenNotchGeometry,
        mode: LauncherAttachmentMode,
        panelWidth: CGFloat,
        panelHeight: CGFloat
    ) -> CGRect {
        let width = min(panelWidth, visibleFrame.width)
        let height = min(panelHeight, visibleFrame.height)

        let raw: CGRect
        switch mode {
        case .center:
            raw = CGRect(
                x: screenFrame.midX - width / 2,
                y: screenFrame.midY - height / 2 + centerLift,
                width: width,
                height: height
            )
        case .island:
            if notch.hasNotch {
                // Anchor directly below the hardware notch, centered on the notch.
                let notchMidXInScreen = screenFrame.minX + CGFloat(notch.notchMidX)
                raw = CGRect(
                    x: notchMidXInScreen - width / 2,
                    y: screenFrame.maxY - CGFloat(notch.notchHeight) - islandGap - height,
                    width: width,
                    height: height
                )
            } else {
                // No notch (external display): top-center, just below the menu bar.
                raw = CGRect(
                    x: visibleFrame.midX - width / 2,
                    y: visibleFrame.maxY - islandGap - height,
                    width: width,
                    height: height
                )
            }
        }

        return clamp(raw, into: visibleFrame)
    }

    /// Clamps a frame into the visible frame, shrinking it if larger than the screen.
    public static func clamp(_ frame: CGRect, into visible: CGRect) -> CGRect {
        let width = min(frame.width, visible.width)
        let height = min(frame.height, visible.height)
        let x = min(max(frame.minX, visible.minX), visible.maxX - width)
        let y = min(max(frame.minY, visible.minY), visible.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
