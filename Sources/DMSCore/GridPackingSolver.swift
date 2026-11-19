import Foundation

/// 2D Box bin packing solver with gravity and 0.5-step row quantization.
/// Ported 1:1 from upstream DMS `quickshell/Common/GridLayout.js` and `CcTileGrid.qml`.
public enum GridPackingSolver: Sendable {

    public struct CardItem: Sendable, Equatable, Identifiable {
        public var id: String
        public var col: Double?
        public var row: Double?
        public var w: Double
        public var h: Double
        public var small: Bool
        public var isAvailable: Bool

        public init(
            id: String,
            col: Double? = nil,
            row: Double? = nil,
            w: Double = 4.0,
            h: Double = 1.0,
            small: Bool = false,
            isAvailable: Bool = true
        ) {
            self.id = id
            self.col = col
            self.row = row
            self.w = w
            self.h = h
            self.small = small
            self.isAvailable = isAvailable
        }
    }

    public struct GridSlot: Sendable, Equatable, Identifiable {
        public var id: String
        public var x: Double
        public var y: Double
        public var w: Double
        public var h: Double
        public var col: Double
        public var row: Double
        public var cols: Double
        public var rows: Double

        public init(
            id: String,
            x: Double,
            y: Double,
            w: Double,
            h: Double,
            col: Double,
            row: Double,
            cols: Double,
            rows: Double
        ) {
            self.id = id
            self.x = x
            self.y = y
            self.w = w
            self.h = h
            self.col = col
            self.row = row
            self.cols = cols
            self.rows = rows
        }
    }

    public struct LayoutResult: Sendable, Equatable {
        public var slots: [GridSlot]
        public var rows: Double
        public var totalHeight: Double
        public var columns: Int
        public var width: Double
        public var colW: Double
        public var rowUnit: Double
        public var gap: Double
        public var step: Double
        public var mirror: Bool

        public init(
            slots: [GridSlot],
            rows: Double,
            totalHeight: Double,
            columns: Int,
            width: Double,
            colW: Double,
            rowUnit: Double,
            gap: Double,
            step: Double,
            mirror: Bool
        ) {
            self.slots = slots
            self.rows = rows
            self.totalHeight = totalHeight
            self.columns = columns
            self.width = width
            self.colW = colW
            self.rowUnit = rowUnit
            self.gap = gap
            self.step = step
            self.mirror = mirror
        }
    }

    internal final class CellRect {
        var id: String
        var x: Int
        var y: Int
        var w: Int
        var h: Int

        init(id: String, x: Int, y: Int, w: Int, h: Int) {
            self.id = id
            self.x = x
            self.y = y
            self.w = w
            self.h = h
        }
    }

    /// Upper bound (in step units) for card rows/heights so `compact()`/`firstFit()` loops stay bounded.
    private static let maxCellSteps = 10_000
    /// Upper bound for the number of horizontal steps so a tiny `step` cannot explode the search space.
    private static let maxTotalSteps = 2_048

    /// Converts a card dimension/position (in grid units) to a bounded cell span (in step units).
    /// Non-finite or overflowing values clamp to `maxSteps` instead of trapping in `Int(Double)`.
    /// `minimum` is 1 for spans (a card must cover at least one step) and 0 for positions.
    private static func cellSpan(_ value: Double, step: Double, maxSteps: Int, minimum: Double = 1.0) -> Int {
        let fallback = minimum >= 1.0 ? maxSteps : 0
        guard value.isFinite, step > 0 else { return fallback }
        let ratio = value / step
        guard ratio.isFinite else { return fallback }
        let clamped = min(max(ratio.rounded(), minimum), Double(maxSteps))
        return Int(clamped)
    }

    private static func overlaps(_ taken: [CellRect], x: Int, y: Int, w: Int, h: Int) -> Bool {
        for cell in taken {
            if x < cell.x + cell.w && cell.x < x + w && y < cell.y + cell.h && cell.y < y + h {
                return true
            }
        }
        return false
    }

    private static func settle(_ taken: [CellRect], x: Int, startY: Int, w: Int, h: Int) -> (x: Int, y: Int, w: Int, h: Int) {
        var y = startY
        while overlaps(taken, x: x, y: y, w: w, h: h) {
            y += 1
        }
        return (x, y, w, h)
    }

    private static func firstFit(_ taken: [CellRect], steps: Int, w: Int, h: Int) -> (x: Int, y: Int, w: Int, h: Int) {
        let ceiling = taken.reduce(0) { max($0, $1.y + $1.h) }
        guard steps >= w else { return (0, ceiling, w, h) }
        for y in 0..<ceiling {
            for x in 0...(steps - w) {
                if !overlaps(taken, x: x, y: y, w: w, h: h) {
                    return (x, y, w, h)
                }
            }
        }
        return (0, ceiling, w, h)
    }

    private static func compact(_ taken: inout [CellRect]) {
        // Sort by y then x
        taken.sort { a, b in
            if a.y != b.y {
                return a.y < b.y
            }
            return a.x < b.x
        }

        for cell in taken {
            let others = taken.filter { $0 !== cell }
            while cell.y > 0 && !overlaps(others, x: cell.x, y: cell.y - 1, w: cell.w, h: cell.h) {
                cell.y -= 1
            }
        }
    }

    /// Packs cards into 2D slots matching upstream `GridUtils.packCards`.
    public static func packCards(
        cards: [CardItem],
        order: [Int]? = nil,
        columns: Int = 8,
        width: Double,
        gap: Double = 8.0,
        rowUnit: Double = 64.0,
        mirror: Bool = false,
        step: Double = 0.5,
        gravity: Bool = true
    ) -> LayoutResult {
        let safeColumns = max(1, columns)
        let safeStep = (step.isFinite && step > 0) ? step : 0.5
        let steps = max(1, min(maxTotalSteps, cellSpan(Double(safeColumns), step: safeStep, maxSteps: maxTotalSteps)))
        let safeWidth = width.isFinite ? width : 0.0
        let safeGap = gap.isFinite ? gap : 8.0
        let safeRowUnit = (rowUnit.isFinite && rowUnit > 0) ? rowUnit : 64.0
        let effectiveOrder = order ?? Array(0..<cards.count)

        var taken: [CellRect] = []
        var placedCells: [Int: CellRect] = [:]

        for sourceIndex in effectiveOrder {
            guard sourceIndex >= 0 && sourceIndex < cards.count else { continue }
            let card = cards[sourceIndex]
            if !card.isAvailable { continue }

            let w = cellSpan(card.w, step: safeStep, maxSteps: steps)
            let h = cellSpan(card.h, step: safeStep, maxSteps: maxCellSteps)

            let cellPlacement: (x: Int, y: Int, w: Int, h: Int)
            if let col = card.col, let row = card.row, col.isFinite, row.isFinite {
                let initialX = max(0, min(steps - w, cellSpan(col, step: safeStep, maxSteps: steps, minimum: 0.0)))
                // Clamp huge rows so settle()/firstFit()/compact() loops stay bounded.
                let initialY = max(0, cellSpan(row, step: safeStep, maxSteps: maxCellSteps, minimum: 0.0))
                let settled = settle(taken, x: initialX, startY: initialY, w: w, h: h)
                cellPlacement = (settled.x, min(settled.y, maxCellSteps), settled.w, settled.h)
            } else {
                let fit = firstFit(taken, steps: steps, w: w, h: h)
                cellPlacement = (fit.x, min(fit.y, maxCellSteps), fit.w, fit.h)
            }

            let cellRect = CellRect(id: card.id, x: cellPlacement.x, y: cellPlacement.y, w: cellPlacement.w, h: cellPlacement.h)
            taken.append(cellRect)
            placedCells[sourceIndex] = cellRect
        }

        if gravity {
            compact(&taken)
        }

        var maxRows = 0.0
        let colW = safeColumns > 1
            ? (safeWidth - safeGap * Double(safeColumns - 1)) / Double(safeColumns)
            : safeWidth

        var slots: [GridSlot] = []

        for i in 0..<cards.count {
            guard let cell = placedCells[i] else { continue }
            let col = Double(cell.x) * safeStep
            let row = Double(cell.y) * safeStep
            let cols = Double(cell.w) * safeStep
            let rows = Double(cell.h) * safeStep

            maxRows = max(maxRows, row + rows)

            let px = col * (colW + safeGap)
            let pw = cols * colW + max(0.0, cols - 1.0) * safeGap
            let x = mirror ? (safeWidth - px - pw) : px
            let y = row * (safeRowUnit + safeGap)
            let h = rows * safeRowUnit + max(0.0, rows - 1.0) * safeGap

            slots.append(GridSlot(
                id: cell.id,
                x: x,
                y: y,
                w: pw,
                h: h,
                col: col,
                row: row,
                cols: cols,
                rows: rows
            ))
        }

        let totalHeight = maxRows > 0 ? maxRows * safeRowUnit + max(0.0, maxRows - 1.0) * safeGap : 0.0

        return LayoutResult(
            slots: slots,
            rows: maxRows,
            totalHeight: totalHeight,
            columns: safeColumns,
            width: safeWidth,
            colW: colW,
            rowUnit: safeRowUnit,
            gap: safeGap,
            step: safeStep,
            mirror: mirror
        )
    }

    /// Reverse calculates grid cell coordinate (col, row) from pixel coordinate (x, y).
    public static func cellAt(
        layout: LayoutResult,
        x: Double,
        y: Double,
        cols: Double,
        rows: Double
    ) -> (col: Double, row: Double) {
        let step = (layout.step.isFinite && layout.step > 0) ? layout.step : 0.5
        let safeCols = cols.isFinite ? cols : 1.0
        let pw = safeCols * layout.colW + max(0.0, safeCols - 1.0) * layout.gap
        let rawX = x.isFinite ? x : 0.0
        let px = layout.mirror ? layout.width - rawX - pw : rawX

        // Guard against zero/non-finite pitches (division by zero would produce NaN).
        let colPitch = (layout.colW + layout.gap) * step
        let rawCol: Double
        if colPitch.isFinite && colPitch > 0 {
            rawCol = (px / colPitch).rounded() * step
        } else {
            rawCol = 0.0
        }

        let rowPitch = (layout.rowUnit + layout.gap) * step
        let rawRow: Double
        if rowPitch.isFinite && rowPitch > 0 {
            let safeY = y.isFinite ? y : 0.0
            rawRow = (safeY / rowPitch).rounded() * step
        } else {
            rawRow = 0.0
        }

        let maxCol = max(0.0, Double(layout.columns) - safeCols)
        let clampedCol = max(0.0, min(maxCol, rawCol.isFinite ? rawCol : 0.0))
        let clampedRow = max(0.0, rawRow.isFinite ? rawRow : 0.0)

        return (clampedCol, clampedRow)
    }
}
