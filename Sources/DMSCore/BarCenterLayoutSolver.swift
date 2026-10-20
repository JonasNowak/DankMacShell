import Foundation

/// Mathematical true-center geometric collision solver for DankBar center sections.
/// Ported verbatim from upstream DankMaterialShell (`quickshell/Modules/DBar/CenterLayout.js`).
public enum BarCenterLayoutSolver: Sendable {

    public struct Anchor: Sendable, Equatable {
        public var middle: Int?
        public var count: Int?
        public var previous: Int?

        public init(middle: Int? = nil, count: Int? = nil, previous: Int? = nil) {
            self.middle = middle
            self.count = count
            self.previous = previous
        }
    }

    public struct Bounds: Sendable, Equatable {
        public var min: Double?
        public var max: Double?

        public init(min: Double? = nil, max: Double? = nil) {
            self.min = min
            self.max = max
        }
    }

    public struct Result: Sendable, Equatable {
        public var positions: [Double?]
        public var totalSize: Double

        public init(positions: [Double?], totalSize: Double) {
            self.positions = positions
            self.totalSize = totalSize
        }
    }

    public static func indexCenter(
        sizes: [Double?],
        indices: [Int],
        offsets: [Double],
        spacing: Double,
        anchor: Anchor?
    ) -> Double {
        let configuredMiddle = anchor?.middle ?? (sizes.count / 2)
        let configuredCount = anchor?.count ?? sizes.count
        let configuredPrevious = anchor?.previous ?? (configuredMiddle - 1)

        let middle = indices.firstIndex(of: configuredMiddle)
        if configuredCount % 2 == 1, let middle = middle, let midSize = sizes[configuredMiddle] {
            return offsets[middle] + midSize / 2.0
        }
        let previous = indices.firstIndex(of: configuredPrevious)
        if configuredCount % 2 == 0, let middle = middle, let previous = previous, let prevSize = sizes[configuredPrevious] {
            return (offsets[previous] + prevSize + offsets[middle]) / 2.0
        }

        let visibleMiddle = indices.count / 2
        if indices.count % 2 == 1, let visSize = sizes[indices[visibleMiddle]] {
            return offsets[visibleMiddle] + visSize / 2.0
        }
        return offsets[visibleMiddle] - spacing / 2.0
    }

    public static func confine(start: Double, totalSize: Double, bounds: Bounds?) -> Double {
        guard let bounds = bounds else { return start }
        let minBound = bounds.min ?? -.infinity
        let maxBound = bounds.max ?? .infinity
        if maxBound - minBound < totalSize {
            return (minBound + maxBound - totalSize) / 2.0
        }
        return min(max(start, minBound), maxBound - totalSize)
    }

    /// Resolves the absolute starting position of each widget in the center section.
    ///
    /// - Parameters:
    ///   - sizes: Array of individual widget lengths along layout axis (or nil for hidden).
    ///   - length: Total available bar length along the layout axis (e.g. screen width or height).
    ///   - spacing: Spacing in points between adjacent widgets.
    ///   - mode: "geometric" (exact physical center) or "index" (centered on middle widget index).
    ///   - bounds: Left/Right or Top/Bottom bounding coordinates (e.g. left segment end, right segment start).
    ///   - anchor: Optional anchor config.
    /// - Returns: Result containing calculated start coordinate for each widget and total section length.
    public static func resolve(
        sizes: [Double?],
        length: Double,
        spacing: Double,
        mode: String = "geometric",
        bounds: Bounds? = nil,
        anchor: Anchor? = nil
    ) -> Result {
        var indices: [Int] = []
        var offsets: [Double] = []
        var positions: [Double?] = Array(repeating: nil, count: sizes.count)
        var totalSize: Double = 0

        for index in 0..<sizes.count {
            guard let size = sizes[index] else { continue }
            if !indices.isEmpty {
                totalSize += spacing
            }
            indices.append(index)
            offsets.append(totalSize)
            totalSize += size
        }

        if indices.isEmpty {
            return Result(positions: positions, totalSize: 0)
        }

        let centerOffset: Double
        if mode == "geometric" {
            centerOffset = totalSize / 2.0
        } else {
            centerOffset = indexCenter(sizes: sizes, indices: indices, offsets: offsets, spacing: spacing, anchor: anchor)
        }

        let idealStart = length / 2.0 - centerOffset
        let start = confine(start: idealStart, totalSize: totalSize, bounds: bounds)

        for i in 0..<indices.count {
            positions[indices[i]] = start + offsets[i]
        }

        return Result(positions: positions, totalSize: totalSize)
    }
}
