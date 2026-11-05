import Foundation

/// Mathematical and calendar utilities for high-precision wall-clock synchronization.
public enum ClockSyncMath {

    /// Computes the exact time interval to the next whole wall-clock second boundary (:xx.000),
    /// plus an optional small forward epsilon (default 5ms) to prevent boundary underflow.
    ///
    /// - Parameters:
    ///   - date: The current point in time.
    ///   - epsilon: Small forward offset in seconds (default: 0.005, i.e. 5ms).
    /// - Returns: Non-negative delay to the next second boundary.
    public static func delayToNextSecond(from date: Date, epsilon: TimeInterval = 0.005) -> TimeInterval {
        let timestamp = date.timeIntervalSinceReferenceDate
        let fractional = timestamp.truncatingRemainder(dividingBy: 1.0)
        let delta: TimeInterval
        if fractional >= 0 {
            delta = 1.0 - fractional
        } else {
            delta = -fractional
        }
        return max(0.001, delta + epsilon)
    }

    /// Aligns a date to the nearest whole integer second.
    public static func floorToSecond(_ date: Date) -> Date {
        let ts = floor(date.timeIntervalSinceReferenceDate)
        return Date(timeIntervalSinceReferenceDate: ts)
    }
}
