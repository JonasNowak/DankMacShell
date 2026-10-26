import Foundation

/// Geometry evaluation engine for Smart Auto-Hide detection.
/// Computes whether an active frontmost application window covers or overlaps
/// a display screen (fullscreen or maximized), matching Tralphium's
/// fullscreen auto-hiding behavior.
public struct SmartAutoHideSolver: Sendable {
    /// Evaluates if a given window's coordinates and dimensions cover the target screen.
    ///
    /// - Parameters:
    ///   - windowX: Window origin X in CoreGraphics coordinates.
    ///   - windowY: Window origin Y in CoreGraphics coordinates.
    ///   - windowWidth: Window width.
    ///   - windowHeight: Window height.
    ///   - screenWidth: Screen width in points.
    ///   - screenHeight: Screen height in points.
    ///   - screenVisibleHeight: Screen visible height (excluding menu bar/dock).
    ///   - screenCGX: Screen X origin in CoreGraphics coordinates (0 for primary display).
    ///   - screenCGY: Screen Y origin in CoreGraphics coordinates (0 for primary display).
    ///   - tolerance: Geometric margin of error (default 15.0 px).
    /// - Returns: `true` if the window spans the screen dimensions.
    public static func isWindowFullscreen(
        windowX: Double,
        windowY: Double,
        windowWidth: Double,
        windowHeight: Double,
        screenWidth: Double,
        screenHeight: Double,
        screenVisibleHeight: Double,
        screenCGX: Double = 0.0,
        screenCGY: Double = 0.0,
        tolerance: Double = 15.0
    ) -> Bool {
        let touchesBottom = (windowY + windowHeight) >= (screenCGY + screenHeight - tolerance)
        let touchesTop = windowY <= (screenCGY + 40.0)
        let isFullWidth = windowWidth >= (screenWidth - tolerance)
        let isFullHeight = windowHeight >= (screenVisibleHeight - tolerance) || windowHeight >= (screenHeight - tolerance)
        let matchesX = abs(windowX - screenCGX) <= tolerance

        return isFullWidth && isFullHeight && (touchesBottom || touchesTop) && matchesX
    }
}
