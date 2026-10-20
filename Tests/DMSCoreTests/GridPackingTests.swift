import Testing
import Foundation
@testable import DMSCore

@Suite("Grid Packing Solver Tests")
struct GridPackingTests {

    @Test("Disabled Cards Ignored in Layout")
    func testDisabledCards() {
        let cards = [
            GridPackingSolver.CardItem(id: "card_enabled", w: 4, h: 1, isAvailable: true),
            GridPackingSolver.CardItem(id: "card_disabled", w: 4, h: 1, isAvailable: false)
        ]

        let layout = GridPackingSolver.packCards(
            cards: cards,
            columns: 8,
            width: 600,
            gap: 8,
            rowUnit: 64
        )

        #expect(layout.slots.count == 1)
        #expect(layout.slots.first?.id == "card_enabled")
    }

    @Test("Custom Placement Order and Collisions")
    func testCustomOrderAndFixedPositions() {
        // card_b placed at fixed (0, 0), card_a has no fixed position
        let cards = [
            GridPackingSolver.CardItem(id: "card_a", w: 4, h: 1),
            GridPackingSolver.CardItem(id: "card_b", col: 0, row: 0, w: 4, h: 1)
        ]

        // Custom order placing card_b first
        let layout = GridPackingSolver.packCards(
            cards: cards,
            order: [1, 0],
            columns: 8,
            width: 600,
            gravity: false
        )

        #expect(layout.slots.count == 2)
        let slotB = layout.slots.first(where: { $0.id == "card_b" })
        #expect(slotB?.col == 0)
        #expect(slotB?.row == 0)
    }

    @Test("Mirror Mode Flips X Coordinates")
    func testMirrorMode() {
        let cards = [
            GridPackingSolver.CardItem(id: "left_card", col: 0, row: 0, w: 2, h: 1)
        ]

        let normalLayout = GridPackingSolver.packCards(
            cards: cards,
            columns: 8,
            width: 800,
            gap: 0,
            rowUnit: 64,
            mirror: false
        )
        let mirroredLayout = GridPackingSolver.packCards(
            cards: cards,
            columns: 8,
            width: 800,
            gap: 0,
            rowUnit: 64,
            mirror: true
        )

        let normalSlot = normalLayout.slots[0]
        let mirroredSlot = mirroredLayout.slots[0]

        #expect(normalSlot.x == 0.0)
        #expect(mirroredSlot.x == 800.0 - mirroredSlot.w)
    }

    @Test("cellAt Reverse Coordinate Calculation and Clamping")
    func testCellAtReverseCoordinates() {
        let cards = [
            GridPackingSolver.CardItem(id: "c1", w: 4, h: 1)
        ]
        let layout = GridPackingSolver.packCards(
            cards: cards,
            columns: 8,
            width: 800,
            gap: 8,
            rowUnit: 64
        )

        // Near top-left
        let topLeft = GridPackingSolver.cellAt(layout: layout, x: 0, y: 0, cols: 4, rows: 1)
        #expect(topLeft.col == 0.0)
        #expect(topLeft.row == 0.0)

        // Beyond right edge clamped to max col (columns - cols = 8 - 4 = 4)
        let farRight = GridPackingSolver.cellAt(layout: layout, x: 2000, y: 0, cols: 4, rows: 1)
        #expect(farRight.col == 4.0)

        // Negative coordinates clamped to 0
        let negative = GridPackingSolver.cellAt(layout: layout, x: -500, y: -200, cols: 4, rows: 1)
        #expect(negative.col == 0.0)
        #expect(negative.row == 0.0)
    }

    @Test("Empty Cards Array Produces Empty Layout")
    func testEmptyCards() {
        let layout = GridPackingSolver.packCards(
            cards: [],
            columns: 8,
            width: 600
        )
        #expect(layout.slots.isEmpty)
        #expect(layout.rows == 0.0)
        #expect(layout.totalHeight == 0.0)
    }
}
