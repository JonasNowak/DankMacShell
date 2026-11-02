import Foundation

/// Geometry evaluation engine for Smart Auto-Hide detection.
/// Computes whether an active frontmost or on-screen application window covers or overlaps
/// a display screen (fullscreen/maximized) or intersects the bar/dock boundary.
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
        tolerance: Double = 10.0
    ) -> Bool {
        let touchesBottom = (windowY + windowHeight) >= (screenCGY + screenHeight - tolerance)
        let touchesTop = windowY <= (screenCGY + max(48.0, tolerance))
        let isFullWidth = windowWidth >= (screenWidth - tolerance)
        let isFullHeight = windowHeight >= (screenVisibleHeight - tolerance) || windowHeight >= (screenHeight - tolerance)
        let matchesX = abs(windowX - screenCGX) <= tolerance

        return isFullWidth && isFullHeight && touchesTop && touchesBottom && matchesX
    }

    /// Evaluates if a given window strictly spans the full physical display (strict native or game fullscreen).
    public static func isWindowStrictFullscreen(
        windowX: Double,
        windowY: Double,
        windowWidth: Double,
        windowHeight: Double,
        screenWidth: Double,
        screenHeight: Double,
        screenCGX: Double = 0.0,
        screenCGY: Double = 0.0,
        tolerance: Double = 6.0
    ) -> Bool {
        let matchesX = abs(windowX - screenCGX) <= tolerance
        let matchesY = abs(windowY - screenCGY) <= tolerance
        let matchesWidth = abs(windowWidth - screenWidth) <= tolerance
        let matchesHeight = abs(windowHeight - screenHeight) <= tolerance
        return matchesX && matchesY && matchesWidth && matchesHeight
    }

    /// Evaluates if a given window's bounding box intersects or overlaps the target bar rectangle.
    public static func isWindowOverlappingBar(
        windowBounds: CGRect,
        barBounds: CGRect,
        tolerance: CGFloat = 4.0
    ) -> Bool {
        guard windowBounds.width > 20 && windowBounds.height > 20 else { return false }
        let expandedBar = barBounds.insetBy(dx: -tolerance, dy: -tolerance)
        return windowBounds.intersects(expandedBar)
    }

    /// Evaluates whether an on-screen window obstructs the bar area on the specified screen.
    public static func isWindowObstructing(
        windowX: Double,
        windowY: Double,
        windowWidth: Double,
        windowHeight: Double,
        screenWidth: Double,
        screenHeight: Double,
        screenVisibleHeight: Double,
        screenCGX: Double,
        screenCGY: Double,
        barCGX: Double,
        barCGY: Double,
        barCGWidth: Double,
        barCGHeight: Double,
        tolerance: Double = 4.0
    ) -> Bool {
        // 1. Check if window covers the screen (fullscreen or maximized)
        let isFS = isWindowFullscreen(
            windowX: windowX,
            windowY: windowY,
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            screenVisibleHeight: screenVisibleHeight,
            screenCGX: screenCGX,
            screenCGY: screenCGY,
            tolerance: 10.0
        )
        if isFS { return true }

        // 2. Direct geometric intersection with the bar's bounding box expanded by tolerance
        let winRect = CGRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
        let barRect = CGRect(x: barCGX, y: barCGY, width: barCGWidth, height: barCGHeight)
        return isWindowOverlappingBar(windowBounds: winRect, barBounds: barRect, tolerance: CGFloat(tolerance))
    }
}
