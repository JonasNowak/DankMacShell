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
        let steps = max(1, Int((Double(safeColumns) / step).rounded()))
        let effectiveOrder = order ?? Array(0..<cards.count)

        var taken: [CellRect] = []
        var placedCells: [Int: CellRect] = [:]

        for sourceIndex in effectiveOrder {
            guard sourceIndex >= 0 && sourceIndex < cards.count else { continue }
            let card = cards[sourceIndex]
            if !card.isAvailable { continue }

            let w = max(1, min(steps, Int((card.w / step).rounded())))
            let h = max(1, Int((card.h / step).rounded()))

            let cellPlacement: (x: Int, y: Int, w: Int, h: Int)
            if let col = card.col, let row = card.row {
                let initialX = max(0, min(steps - w, Int((col / step).rounded())))
                let initialY = max(0, Int((row / step).rounded()))
                cellPlacement = settle(taken, x: initialX, startY: initialY, w: w, h: h)
            } else {
                cellPlacement = firstFit(taken, steps: steps, w: w, h: h)
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
            ? (width - gap * Double(safeColumns - 1)) / Double(safeColumns)
            : width

        var slots: [GridSlot] = []

        for i in 0..<cards.count {
            guard let cell = placedCells[i] else { continue }
            let col = Double(cell.x) * step
            let row = Double(cell.y) * step
            let cols = Double(cell.w) * step
            let rows = Double(cell.h) * step

            maxRows = max(maxRows, row + rows)

            let px = col * (colW + gap)
            let pw = cols * colW + max(0.0, cols - 1.0) * gap
            let x = mirror ? (width - px - pw) : px
            let y = row * (rowUnit + gap)
            let h = rows * rowUnit + max(0.0, rows - 1.0) * gap

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

        let totalHeight = maxRows > 0 ? maxRows * rowUnit + max(0.0, maxRows - 1.0) * gap : 0.0

        return LayoutResult(
            slots: slots,
            rows: maxRows,
            totalHeight: totalHeight,
            columns: safeColumns,
            width: width,
            colW: colW,
            rowUnit: rowUnit,
            gap: gap,
            step: step,
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
        let step = layout.step
        let pw = cols * layout.colW + max(0.0, cols - 1.0) * layout.gap
        let px = layout.mirror ? layout.width - x - pw : x

        let colPitch = (layout.colW + layout.gap) * step
        let rawCol = (px / colPitch).rounded() * step

        let rowPitch = (layout.rowUnit + layout.gap) * step
        let rawRow = (y / rowPitch).rounded() * step

        let clampedCol = max(0.0, min(Double(layout.columns) - cols, rawCol))
        let clampedRow = max(0.0, rawRow)

        return (clampedCol, clampedRow)
    }
}
