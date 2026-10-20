import Foundation

/// Mathematical magnification physics engine and dock geometry utilities.
/// Ported 1:1 from upstream DMS `quickshell/Common/settings/DockConfig.js`.
public enum DockMagnificationEngine: Sendable {
    public static let supportedProfiles = ["parabolic", "gaussian", "cosine"]
    public static let defaultProfile = "parabolic"

    /// Proximity magnification influence radius per profile curve.
    public static func magnificationRadius(baseSize: Double, profile: String) -> Double {
        let size = baseSize > 0 ? baseSize : 42.0
        switch profile.lowercased() {
        case "parabolic":
            return size * 1.8
        case "gaussian":
            return size * 2.2
        case "cosine":
            return size * 2.5
        default:
            return size * 1.8
        }
    }

    /// Magnification scale decay factor (1.0 at dist=0, tapering to 0.0 at dist>=radius).
    public static func magnificationFactor(dist: Double, radius: Double, profile: String) -> Double {
        if dist >= radius || radius <= 0 {
            return 0.0
        }
        let u = max(0.0, dist / radius)
        switch profile.lowercased() {
        case "cosine":
            return 0.5 * (1.0 + cos(Double.pi * u))
        case "gaussian":
            let e3 = exp(-3.0)
            return (exp(-3.0 * u * u) - e3) / (1.0 - e3)
        case "parabolic":
            return 1.0 - (u * u)
        default:
            return 1.0 - (u * u)
        }
    }

    /// Computes the final magnification scale multiplier for an item at distance `dist`.
    /// `maxScalePercent` is typically between 105 and 160 (e.g. 130.0 for 1.30x zoom).
    public static func magnificationScale(
        dist: Double,
        baseSize: Double,
        maxScalePercent: Double,
        profile: String
    ) -> Double {
        let radius = magnificationRadius(baseSize: baseSize, profile: profile)
        let factor = magnificationFactor(dist: dist, radius: radius, profile: profile)
        let maxScale = max(1.0, maxScalePercent / 100.0)
        return 1.0 + (maxScale - 1.0) * factor
    }

    /// Midpoint hysteresis calculation for drag-and-drop unit reordering.
    /// The leading edge decides, so a wide unit swaps with a narrow neighbor at the dock's end.
    public static func unitTarget(
        spans: [(id: String, start: Double, end: Double)],
        id: String,
        offset: Double
    ) -> String {
        guard let from = spans.firstIndex(where: { $0.id == id }) else {
            return id
        }
        let middle: ((id: String, start: Double, end: Double)) -> Double = { ($0.start + $0.end) / 2.0 }
        var target = from

        // Search forward
        var i = from + 1
        while i < spans.count && (spans[from].end + offset > middle(spans[i])) {
            target = i
            i += 1
        }

        // Search backward
        var j = from - 1
        while j >= 0 && (spans[from].start + offset < middle(spans[j])) {
            target = j
            j -= 1
        }

        return spans[target].id
    }

    /// Lane kept clear beside icons for running indicators.
    public static func indicatorLane(iconSize: Double) -> Double {
        return max(8.0, (iconSize * 0.18).rounded())
    }

    /// Effective thickness is derived, never set: content decides it and padding surrounds it.
    public static func effectiveThickness(iconSize: Double, spacing: Double) -> Double {
        return iconSize + spacing * 2.0
    }
}
