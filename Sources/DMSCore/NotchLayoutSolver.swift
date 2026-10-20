import Foundation

/// Per-display geometry describing the physical MacBook camera notch and auxiliary safe areas.
public struct ScreenNotchGeometry: Sendable, Codable, Equatable {
    public let screenID: String
    public let screenWidth: Double
    public let screenHeight: Double
    public let hasNotch: Bool
    public let notchMinX: Double
    public let notchMaxX: Double
    public let notchHeight: Double

    public var notchWidth: Double {
        hasNotch ? max(0.0, notchMaxX - notchMinX) : 0.0
    }

    public var notchMidX: Double {
        hasNotch ? (notchMinX + notchMaxX) / 2.0 : (screenWidth / 2.0)
    }

    /// Safe width available to the left of the physical notch.
    public var leftSafeAreaWidth: Double {
        hasNotch ? max(0.0, notchMinX) : screenWidth
    }

    /// Starting X coordinate of the safe area to the right of the physical notch.
    public var rightSafeAreaMinX: Double {
        hasNotch ? min(screenWidth, notchMaxX) : 0.0
    }

    /// Safe width available to the right of the physical notch.
    public var rightSafeAreaWidth: Double {
        hasNotch ? max(0.0, screenWidth - notchMaxX) : screenWidth
    }

    public init(
        screenID: String = "main",
        screenWidth: Double,
        screenHeight: Double,
        hasNotch: Bool,
        notchMinX: Double = 0.0,
        notchMaxX: Double = 0.0,
        notchHeight: Double = 0.0
    ) {
        self.screenID = screenID
        self.screenWidth = max(1.0, screenWidth)
        self.screenHeight = max(1.0, screenHeight)
        self.hasNotch = hasNotch && (notchMaxX > notchMinX) && (notchHeight > 0.0)
        self.notchMinX = self.hasNotch ? max(0.0, notchMinX) : 0.0
        self.notchMaxX = self.hasNotch ? min(screenWidth, notchMaxX) : 0.0
        self.notchHeight = self.hasNotch ? max(0.0, notchHeight) : 0.0
    }

    /// Creates a `ScreenNotchGeometry` from `NSScreen` safe area and auxiliary top area measurements.
    public static func fromScreenMeasurements(
        screenID: String,
        screenWidth: Double,
        screenHeight: Double,
        safeAreaTop: Double,
        auxiliaryLeftWidth: Double?,
        auxiliaryRightMinX: Double?,
        auxiliaryRightWidth: Double?,
        simulateNotch: Bool = false,
        simulatedNotchWidth: Double = 200.0,
        simulatedNotchHeight: Double = 34.0
    ) -> ScreenNotchGeometry {
        if let auxLeft = auxiliaryLeftWidth,
           let auxRightMinX = auxiliaryRightMinX,
           auxLeft > 0,
           auxRightMinX > auxLeft,
           safeAreaTop > 0 {
            return ScreenNotchGeometry(
                screenID: screenID,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                hasNotch: true,
                notchMinX: auxLeft,
                notchMaxX: auxRightMinX,
                notchHeight: safeAreaTop
            )
        }

        if simulateNotch && simulatedNotchWidth > 0 && simulatedNotchHeight > 0 {
            let half = min(screenWidth * 0.4, simulatedNotchWidth) / 2.0
            let mid = screenWidth / 2.0
            return ScreenNotchGeometry(
                screenID: screenID,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                hasNotch: true,
                notchMinX: mid - half,
                notchMaxX: mid + half,
                notchHeight: simulatedNotchHeight
            )
        }

        return ScreenNotchGeometry(
            screenID: screenID,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            hasNotch: false
        )
    }

    /// Standard non-notched external display geometry.
    public static func standardMonitor(
        screenID: String = "external",
        width: Double = 1920.0,
        height: Double = 1080.0
    ) -> ScreenNotchGeometry {
        ScreenNotchGeometry(
            screenID: screenID,
            screenWidth: width,
            screenHeight: height,
            hasNotch: false
        )
    }

    /// Standard notched MacBook Pro 14"/16" geometry.
    public static func notchedMacBook(
        screenID: String = "built-in",
        width: Double = 1512.0,
        height: Double = 982.0,
        notchWidth: Double = 200.0,
        notchHeight: Double = 34.0
    ) -> ScreenNotchGeometry {
        let mid = width / 2.0
        return ScreenNotchGeometry(
            screenID: screenID,
            screenWidth: width,
            screenHeight: height,
            hasNotch: true,
            notchMinX: mid - (notchWidth / 2.0),
            notchMaxX: mid + (notchWidth / 2.0),
            notchHeight: notchHeight
        )
    }
}

/// Adaptive layout solver for DankBar that accounts for Mac display notches and Dynamic Island safe zones.
public enum NotchAwareBarLayoutSolver: Sendable {

    public enum SafeZonePlacement: String, Sendable, Equatable {
        case leftSafeZone
        case centerZone
        case rightSafeZone
        case delegatedToIsland
        case overflowHidden
    }

    public struct PlacedWidget: Sendable, Equatable {
        public let section: SettingsWidgetCatalog.Section
        public let index: Int
        public let x: Double
        public let width: Double
        public let zone: SafeZonePlacement

        public var maxX: Double { x + width }
    }

    public struct LayoutSolution: Sendable, Equatable {
        public let isNotchSplitActive: Bool
        public let exclusionMinX: Double?
        public let exclusionMaxX: Double?
        public let leftSafeZoneBounds: ClosedRange<Double>
        public let rightSafeZoneBounds: ClosedRange<Double>
        public let leftPlacements: [PlacedWidget?]
        public let centerPlacements: [PlacedWidget?]
        public let rightPlacements: [PlacedWidget?]
        public let overflowCount: Int

        /// All visible placed widgets across left, center, and right sections.
        public var allVisiblePlacements: [PlacedWidget] {
            let l = leftPlacements.compactMap { $0 }.filter { $0.zone != .overflowHidden && $0.zone != .delegatedToIsland }
            let c = centerPlacements.compactMap { $0 }.filter { $0.zone != .overflowHidden && $0.zone != .delegatedToIsland }
            let r = rightPlacements.compactMap { $0 }.filter { $0.zone != .overflowHidden && $0.zone != .delegatedToIsland }
            return l + c + r
        }
    }

    /// Solves the horizontal positions of all bar widgets across left, center, and right sections,
    /// splitting and reflowing around the Mac hardware notch and/or Dynamic Island when present.
    public static func solve(
        barLength: Double,
        barPosition: String = "top",
        barMargin: Double = 8.0,
        paddingH: Double = 10.0,
        spacing: Double = 8.0,
        notchSafetyPadding: Double = 10.0,
        screenNotch: ScreenNotchGeometry,
        islandReservedWidth: Double = 0.0,
        islandHorizontalOffset: Double = 0.0,
        delegateCenterToIslandIndices: Set<Int> = [],
        leftSizes: [Double?],
        centerSizes: [Double?],
        rightSizes: [Double?]
    ) -> LayoutSolution {
        let isTopBar = barPosition.lowercased() == "top"
        let hasCentralObstruction = isTopBar && (screenNotch.hasNotch || islandReservedWidth > 0.0)

        // Convert screen-space notch coordinates into bar-local coordinates (accounting for barMargin)
        let barMinXInScreen = barMargin
        let localCenter = (barLength / 2.0) + islandHorizontalOffset

        var exMin: Double? = nil
        var exMax: Double? = nil

        if hasCentralObstruction {
            var minVal = Double.infinity
            var maxVal = -Double.infinity

            if screenNotch.hasNotch {
                minVal = min(minVal, screenNotch.notchMinX - barMinXInScreen)
                maxVal = max(maxVal, screenNotch.notchMaxX - barMinXInScreen)
            }
            if islandReservedWidth > 0.0 {
                let halfIsland = islandReservedWidth / 2.0
                minVal = min(minVal, localCenter - halfIsland)
                maxVal = max(maxVal, localCenter + halfIsland)
            }

            if minVal < maxVal {
                exMin = max(paddingH, minVal - notchSafetyPadding)
                exMax = min(barLength - paddingH, maxVal + notchSafetyPadding)
            }
        }

        // Case 1: Standard unsplit bar (no notch or bar is on bottom/left/right without island obstruction)
        guard let exclusionMinX = exMin, let exclusionMaxX = exMax, exclusionMaxX > exclusionMinX else {
            return solveStandardLayout(
                barLength: barLength,
                paddingH: paddingH,
                spacing: spacing,
                leftSizes: leftSizes,
                centerSizes: centerSizes,
                rightSizes: rightSizes
            )
        }

        // Case 2: Notch-split / Island-coordinated layout
        let leftBoundsMin = min(paddingH, exclusionMinX)
        let leftBoundsMax = max(leftBoundsMin, exclusionMinX)
        let rightBoundsMin = min(barLength - paddingH, exclusionMaxX)
        let rightBoundsMax = max(rightBoundsMin, barLength - paddingH)

        var leftPlacements: [PlacedWidget?] = Array(repeating: nil, count: leftSizes.count)
        var centerPlacements: [PlacedWidget?] = Array(repeating: nil, count: centerSizes.count)
        var rightPlacements: [PlacedWidget?] = Array(repeating: nil, count: rightSizes.count)
        var overflowCount = 0

        // 2a. Place Left widgets from leftBoundsMin rightward up to leftBoundsMax
        var leftCursor = leftBoundsMin
        for (idx, maybeWidth) in leftSizes.enumerated() {
            guard let w = maybeWidth, w > 0 else { continue }
            let needed = (leftCursor > leftBoundsMin ? spacing : 0.0) + w
            if leftCursor + needed <= leftBoundsMax + 0.01 {
                let startX = leftCursor > leftBoundsMin ? leftCursor + spacing : leftCursor
                leftPlacements[idx] = PlacedWidget(
                    section: .left,
                    index: idx,
                    x: startX,
                    width: w,
                    zone: .leftSafeZone
                )
                leftCursor = startX + w
            } else {
                leftPlacements[idx] = PlacedWidget(
                    section: .left,
                    index: idx,
                    x: leftCursor,
                    width: w,
                    zone: .overflowHidden
                )
                overflowCount += 1
            }
        }

        // 2b. Place Right widgets from rightBoundsMax leftward down to rightBoundsMin
        // Collect visible right widgets so their left-to-right visual order is preserved while anchoring to rightBoundsMax
        let visibleRight: [(index: Int, width: Double)] = rightSizes.enumerated().compactMap { idx, w in
            guard let w, w > 0 else { return nil }
            return (idx, w)
        }
        var rightCursor = rightBoundsMax
        var fittedRight: [(index: Int, width: Double)] = []
        // Fit from rightmost (end of array) or leftmost (priority)? Keep rightmost system icons visible first, or fit in order:
        for item in visibleRight.reversed() {
            let needed = (fittedRight.isEmpty ? 0.0 : spacing) + item.width
            if rightCursor - needed >= rightBoundsMin - 0.01 {
                rightCursor -= needed
                fittedRight.insert(item, at: 0)
            } else {
                rightPlacements[item.index] = PlacedWidget(
                    section: .right,
                    index: item.index,
                    x: rightBoundsMin,
                    width: item.width,
                    zone: .overflowHidden
                )
                overflowCount += 1
            }
        }
        var placeRightX = rightCursor
        for item in fittedRight {
            rightPlacements[item.index] = PlacedWidget(
                section: .right,
                index: item.index,
                x: placeRightX,
                width: item.width,
                zone: .rightSafeZone
            )
            placeRightX += item.width + spacing
        }

        // 2c. Reflow Center widgets into the inner edges of Left Safe Zone (near exclusionMinX)
        // and Right Safe Zone (near exclusionMaxX), balanced by remaining safe zone width!
        var leftInnerMax = leftBoundsMax
        var rightInnerMin = rightBoundsMin

        var centerLeftAssigned: [(index: Int, width: Double)] = []
        var centerRightAssigned: [(index: Int, width: Double)] = []

        for (idx, maybeWidth) in centerSizes.enumerated() {
            guard let w = maybeWidth, w > 0 else { continue }
            if delegateCenterToIslandIndices.contains(idx) {
                centerPlacements[idx] = PlacedWidget(
                    section: .center,
                    index: idx,
                    x: (exclusionMinX + exclusionMaxX - w) / 2.0,
                    width: w,
                    zone: .delegatedToIsland
                )
                continue
            }

            let availLeft = max(0.0, leftInnerMax - leftCursor - (leftCursor > leftBoundsMin ? spacing : 0.0) - (centerLeftAssigned.isEmpty ? 0.0 : spacing))
            let availRight = max(0.0, rightCursor - rightInnerMin - (fittedRight.isEmpty ? 0.0 : spacing) - (centerRightAssigned.isEmpty ? 0.0 : spacing))

            if availLeft >= w && (availLeft >= availRight || availRight < w) {
                centerLeftAssigned.append((idx, w))
                leftInnerMax -= (w + (centerLeftAssigned.count > 1 ? spacing : 0.0))
            } else if availRight >= w {
                centerRightAssigned.append((idx, w))
                rightInnerMin += (w + (centerRightAssigned.count > 1 ? spacing : 0.0))
            } else {
                centerPlacements[idx] = PlacedWidget(
                    section: .center,
                    index: idx,
                    x: exclusionMinX,
                    width: w,
                    zone: .overflowHidden
                )
                overflowCount += 1
            }
        }

        // Position center widgets assigned to Left Safe Zone flush against `leftBoundsMax` (just left of the notch)
        let totalCenterLeftWidth = centerLeftAssigned.reduce(0.0) { $0 + $1.width }
            + Double(max(0, centerLeftAssigned.count - 1)) * spacing
        var clX = max(leftCursor + (leftCursor > leftBoundsMin ? spacing : 0.0), leftBoundsMax - totalCenterLeftWidth)
        for item in centerLeftAssigned {
            centerPlacements[item.index] = PlacedWidget(
                section: .center,
                index: item.index,
                x: clX,
                width: item.width,
                zone: .leftSafeZone
            )
            clX += item.width + spacing
        }

        // Position center widgets assigned to Right Safe Zone flush against `rightBoundsMin` (just right of the notch)
        var crX = rightBoundsMin
        for item in centerRightAssigned {
            centerPlacements[item.index] = PlacedWidget(
                section: .center,
                index: item.index,
                x: crX,
                width: item.width,
                zone: .rightSafeZone
            )
            crX += item.width + spacing
        }

        return LayoutSolution(
            isNotchSplitActive: true,
            exclusionMinX: exclusionMinX,
            exclusionMaxX: exclusionMaxX,
            leftSafeZoneBounds: leftBoundsMin...leftBoundsMax,
            rightSafeZoneBounds: rightBoundsMin...rightBoundsMax,
            leftPlacements: leftPlacements,
            centerPlacements: centerPlacements,
            rightPlacements: rightPlacements,
            overflowCount: overflowCount
        )
    }

    private static func solveStandardLayout(
        barLength: Double,
        paddingH: Double,
        spacing: Double,
        leftSizes: [Double?],
        centerSizes: [Double?],
        rightSizes: [Double?]
    ) -> LayoutSolution {
        var leftPlacements: [PlacedWidget?] = Array(repeating: nil, count: leftSizes.count)
        var centerPlacements: [PlacedWidget?] = Array(repeating: nil, count: centerSizes.count)
        var rightPlacements: [PlacedWidget?] = Array(repeating: nil, count: rightSizes.count)

        var leftCursor = paddingH
        for (idx, maybeWidth) in leftSizes.enumerated() {
            guard let w = maybeWidth, w > 0 else { continue }
            if leftCursor > paddingH { leftCursor += spacing }
            leftPlacements[idx] = PlacedWidget(section: .left, index: idx, x: leftCursor, width: w, zone: .leftSafeZone)
            leftCursor += w
        }

        let visibleRight: [(index: Int, width: Double)] = rightSizes.enumerated().compactMap { idx, w in
            guard let w, w > 0 else { return nil }
            return (idx, w)
        }
        let totalRightWidth = visibleRight.reduce(0.0) { $0 + $1.width }
            + Double(max(0, visibleRight.count - 1)) * spacing
        let rightStart = max(leftCursor + spacing, barLength - paddingH - totalRightWidth)
        var rightCursor = rightStart
        for item in visibleRight {
            rightPlacements[item.index] = PlacedWidget(section: .right, index: item.index, x: rightCursor, width: item.width, zone: .rightSafeZone)
            rightCursor += item.width + spacing
        }

        let centerBounds = BarCenterLayoutSolver.Bounds(
            min: leftCursor + spacing,
            max: max(leftCursor + spacing, rightStart - spacing)
        )
        let centerSolved = BarCenterLayoutSolver.resolve(
            sizes: centerSizes,
            length: barLength,
            spacing: spacing,
            mode: "geometric",
            bounds: centerBounds
        )
        for (idx, maybePos) in centerSolved.positions.enumerated() {
            if let pos = maybePos, let w = centerSizes[idx] {
                centerPlacements[idx] = PlacedWidget(section: .center, index: idx, x: pos, width: w, zone: .centerZone)
            }
        }

        let fullBounds = paddingH...max(paddingH, barLength - paddingH)
        return LayoutSolution(
            isNotchSplitActive: false,
            exclusionMinX: nil,
            exclusionMaxX: nil,
            leftSafeZoneBounds: fullBounds,
            rightSafeZoneBounds: fullBounds,
            leftPlacements: leftPlacements,
            centerPlacements: centerPlacements,
            rightPlacements: rightPlacements,
            overflowCount: 0
        )
    }

    public struct SimpleSplitSolution: Sendable, Equatable {
        public let leftSafeEndX: Double
        public let rightSafeStartX: Double
        public let leftSafeWidgets: [BarWidgetEntry]
        public let rightSafeWidgets: [BarWidgetEntry]

        public init(
            leftSafeEndX: Double,
            rightSafeStartX: Double,
            leftSafeWidgets: [BarWidgetEntry],
            rightSafeWidgets: [BarWidgetEntry]
        ) {
            self.leftSafeEndX = leftSafeEndX
            self.rightSafeStartX = rightSafeStartX
            self.leftSafeWidgets = leftSafeWidgets
            self.rightSafeWidgets = rightSafeWidgets
        }
    }

    public static func solve(
        layout: BarLayout,
        notch: ScreenNotchGeometry,
        barMargin: Double = 8.0,
        spacing: Double = 8.0,
        islandExclusionWidth: Double = 0.0
    ) -> SimpleSplitSolution {
        let halfIsland = islandExclusionWidth > 0 ? (islandExclusionWidth / 2.0) : 0.0
        let islandMinX = halfIsland > 0 ? ((notch.screenWidth / 2.0) - halfIsland) : Double.infinity
        let islandMaxX = halfIsland > 0 ? ((notch.screenWidth / 2.0) + halfIsland) : -Double.infinity

        let rawExclusionMinX: Double
        let rawExclusionMaxX: Double
        if notch.hasNotch && islandExclusionWidth > 0 {
            rawExclusionMinX = min(notch.notchMinX, islandMinX)
            rawExclusionMaxX = max(notch.notchMaxX, islandMaxX)
        } else if notch.hasNotch {
            rawExclusionMinX = notch.notchMinX
            rawExclusionMaxX = notch.notchMaxX
        } else if islandExclusionWidth > 0 {
            rawExclusionMinX = islandMinX
            rawExclusionMaxX = islandMaxX
        } else {
            rawExclusionMinX = notch.screenWidth / 2.0
            rawExclusionMaxX = notch.screenWidth / 2.0
        }

        let leftBound = max(60.0, rawExclusionMinX - barMargin - 8.0)
        let rightBound = min(notch.screenWidth - barMargin, rawExclusionMaxX - barMargin + 8.0)

        var leftWings = layout.left
        var rightWings = layout.right

        for (idx, entry) in layout.center.enumerated() {
            if idx % 2 == 0 {
                leftWings.append(entry)
            } else {
                rightWings.insert(entry, at: 0)
            }
        }

        return SimpleSplitSolution(
            leftSafeEndX: leftBound,
            rightSafeStartX: rightBound,
            leftSafeWidgets: leftWings,
            rightSafeWidgets: rightWings
        )
    }
}
