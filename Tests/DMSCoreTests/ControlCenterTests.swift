import Testing
import Foundation
import CoreGraphics
@testable import DMSCore

@Suite("Control Center Specification Tests")
struct ControlCenterTests {

    @Test("CcMetrics Sheet Width Calculation")
    func testCcMetricsSheetWidth() {
        // Spec formula: width = sheetPadding * 2 + columns * columnWidth + (columns - 1) * gridGap
        // sheetPadding = 12, columnWidth = 44, gridGap = 6
        // For 8 columns: 24 + 352 + 42 = 418
        #expect(CcMetrics.sheetWidthFor(columns: 8) == 418.0)
        // For 6 columns (min): 24 + 264 + 30 = 318
        #expect(CcMetrics.sheetWidthFor(columns: 6) == 318.0)
        // For 12 columns (max): 24 + 528 + 66 = 618
        #expect(CcMetrics.sheetWidthFor(columns: 12) == 618.0)
        // Clamping check: below minimum columns clamps to 6
        #expect(CcMetrics.sheetWidthFor(columns: 4) == 318.0)
        // Above maximum columns clamps to 12
        #expect(CcMetrics.sheetWidthFor(columns: 20) == 618.0)
    }

    @Test("CcMetrics Column Clamping and Capacities")
    func testCcMetricsCaps() {
        #expect(CcMetrics.clampColumns(5) == 6)
        #expect(CcMetrics.clampColumns(8) == 8)
        #expect(CcMetrics.clampColumns(15) == 12)

        // columnCapFor available width
        // availableWidth = 500 => (500 - 24 + 6) / (44 + 6) = 482 / 50 = 9 columns
        let cap = CcMetrics.columnCapFor(availableWidth: 500)
        #expect(cap == 9)

        // rowCapFor available height
        // availableHeight = 400, cellHeight = 44, gap = 6 => (400 + 6) / 50 = 8 rows
        let rowCap = CcMetrics.rowCapFor(availableHeight: 400, cellHeight: 44)
        #expect(rowCap == 8)
    }

    @Test("CcMetrics Preferred Detail Heights")
    func testCcMetricsDetailHeights() {
        #expect(CcMetrics.preferredDetailHeight(section: "wifi") == CcMetrics.detailHeightList)
        #expect(CcMetrics.preferredDetailHeight(section: "network") == CcMetrics.detailHeightList)
        #expect(CcMetrics.preferredDetailHeight(section: "bluetooth") == CcMetrics.detailHeightList)
        #expect(CcMetrics.preferredDetailHeight(section: "audioOutput") == CcMetrics.detailHeightList)
        #expect(CcMetrics.preferredDetailHeight(section: "audioInput") == CcMetrics.detailHeightList)
        #expect(CcMetrics.preferredDetailHeight(section: "battery") == CcMetrics.detailHeightList)
        #expect(CcMetrics.preferredDetailHeight(section: "diskUsage") == CcMetrics.detailHeightList)
        #expect(CcMetrics.preferredDetailHeight(section: "brightnessSlider") == CcMetrics.detailHeightBrightness)
        #expect(CcMetrics.preferredDetailHeight(section: "brightnessSlider_screen1") == CcMetrics.detailHeightBrightness)
        #expect(CcMetrics.preferredDetailHeight(section: "other") == CcMetrics.detailHeightDefault)
        #expect(CcMetrics.preferredDetailHeight(section: "") == 0)
    }

    @Test("Control Center Avatar Shape Cycler")
    func testUserShapesCycler() {
        #expect(ControlCenterUtils.userShapes.count == 12)
        #expect(ControlCenterUtils.userShapes.first == "circle")
        #expect(ControlCenterUtils.userShapes.contains("cookie4"))
        #expect(ControlCenterUtils.userShapes.contains("cookie7"))
        #expect(ControlCenterUtils.userShapes.contains("gem"))
        #expect(ControlCenterUtils.userShapes.contains("square"))

        let nextFromCircle = ControlCenterUtils.nextUserShape("circle")
        #expect(nextFromCircle == "cookie4")

        let nextFromLast = ControlCenterUtils.nextUserShape("square")
        #expect(nextFromLast == "circle")
    }

    @Test("Control Center Widget Specifications and Rules")
    func testWidgetSpecsAndRules() {
        // Slider widgets
        #expect(ControlCenterUtils.isSliderWidget("volumeSlider"))
        #expect(ControlCenterUtils.isSliderWidget("brightnessSlider"))
        #expect(ControlCenterUtils.isSliderWidget("inputVolumeSlider"))
        #expect(!ControlCenterUtils.isSliderWidget("wifi"))
        #expect(!ControlCenterUtils.isSliderWidget("user"))

        // Shrinkable widgets
        #expect(!ControlCenterUtils.canShrink("user"))
        #expect(!ControlCenterUtils.canShrink("volumeSlider"))
        #expect(ControlCenterUtils.canShrink("wifi"))
        #expect(ControlCenterUtils.canShrink("bluetooth"))
        #expect(ControlCenterUtils.canShrink("battery"))

        // Button and action IDs
        #expect(ControlCenterUtils.actionIds == ["settings", "lock", "power"])
        #expect(ControlCenterUtils.buttonIds.contains("edit"))

        // Edit button cannot be removed
        let editWidget = ControlCenterWidgetConfig(id: "edit", small: true)
        let wifiWidget = ControlCenterWidgetConfig(id: "wifi")
        #expect(!ControlCenterUtils.isRemovable(editWidget))
        #expect(ControlCenterUtils.isRemovable(wifiWidget))
    }

    @Test("Control Center Ensure Edit Button")
    func testEnsureEditButton() {
        let widgetsWithoutEdit = [
            ControlCenterWidgetConfig(id: "user"),
            ControlCenterWidgetConfig(id: "wifi")
        ]
        let ensured = ControlCenterUtils.ensureEditButton(widgets: widgetsWithoutEdit)
        #expect(ensured.contains(where: { $0.id == "edit" }))

        let widgetsWithEdit = [
            ControlCenterWidgetConfig(id: "user"),
            ControlCenterWidgetConfig(id: "edit", small: true)
        ]
        let ensuredSame = ControlCenterUtils.ensureEditButton(widgets: widgetsWithEdit)
        #expect(ensuredSame.count == 2)
    }

    @Test("Control Center Widget Size Clamping")
    func testWidgetSizeClamping() {
        // User tile occupies remaining top columns: columns - actionIds.length (8 - 3 = 5)
        let userTile = ControlCenterWidgetConfig(id: "user")
        let clampedUser = ControlCenterUtils.clampSize(widget: userTile, columns: 8)
        #expect(clampedUser.w == 5)
        #expect(clampedUser.h == 1)

        // Action button is always 1x1
        let lockTile = ControlCenterWidgetConfig(id: "lock", w: 4, h: 2)
        let clampedLock = ControlCenterUtils.clampSize(widget: lockTile, columns: 8)
        #expect(clampedLock.w == 1)
        #expect(clampedLock.h == 1)

        // Slider minimum width is 2
        let slider = ControlCenterWidgetConfig(id: "volumeSlider", w: 1, h: 1)
        let clampedSlider = ControlCenterUtils.clampSize(widget: slider, columns: 8)
        #expect(clampedSlider.w == 2)
    }

    @Test("Storage Formatting Matches DMS Spec and cc.png")
    func testStorageFormatting() {
        // Example from cc.png: "80.0G / 186.7G (43%)"
        let usedBytes: Int64 = Int64(80.0 * 1024 * 1024 * 1024)
        let totalBytes: Int64 = Int64(186.7 * 1024 * 1024 * 1024)
        let formatted = ControlCenterUtils.formatStorage(usedBytes: usedBytes, totalBytes: totalBytes)
        #expect(formatted.summary.contains("80.0G / 186.7G (43%)"))
        #expect(formatted.rawPercent >= 0.42 && formatted.rawPercent <= 0.44)
    }

    @Test("Default Widgets Match DMS Reference and cc.png Structure")
    func testDefaultWidgetsContent() {
        let defaults = ControlCenterWidgetConfig.defaultWidgets
        let ids = defaults.map { $0.id }

        // Must contain all components from cc.png
        #expect(ids.contains("user"))
        #expect(ids.contains("lock"))
        #expect(ids.contains("power"))
        #expect(ids.contains("settings"))
        #expect(ids.contains("edit"))
        #expect(ids.contains("volumeSlider"))
        #expect(ids.contains("brightnessSlider"))
        #expect(ids.contains("wifi") || ids.contains("network"))
        #expect(ids.contains("bluetooth"))
        #expect(ids.contains("audioOutput") || ids.contains("audioDevice"))
        #expect(ids.contains("audioInput"))
        #expect(ids.contains("battery"))
        #expect(ids.contains("diskUsage"))
        #expect(ids.contains("colorPicker"))
        #expect(ids.contains("idleInhibitor"))
        #expect(ids.contains("doNotDisturb"))
    }

    @Test("Control Center Undo Stack 50-Step Capacity and Restore")
    func testControlCenterUndoStack() {
        let initial = [ControlCenterWidgetConfig(id: "wifi")]
        let stack = ControlCenterUndoStack(initialWidgets: initial, initialColumns: 8, maxCapacity: 50)

        #expect(!stack.canUndo)
        #expect(!stack.canRedo)

        // Record a new state
        let state1 = [ControlCenterWidgetConfig(id: "wifi"), ControlCenterWidgetConfig(id: "bluetooth")]
        stack.record(widgets: state1, columns: 8)

        #expect(stack.canUndo)
        #expect(!stack.canRedo)

        // Undo back to initial
        let undone = stack.undo()
        #expect(undone?.widgets == initial)
        #expect(!stack.canUndo)
        #expect(stack.canRedo)

        // Redo forward to state1
        let redone = stack.redo()
        #expect(redone?.widgets == state1)
        #expect(stack.canUndo)
        #expect(!stack.canRedo)

        // Capacity clamping at 50
        for i in 2...60 {
            stack.record(widgets: [ControlCenterWidgetConfig(id: "tile_\(i)")], columns: 8)
        }
        // Undo back through history should not exceed 50
        var undoCount = 0
        while stack.canUndo {
            _ = stack.undo()
            undoCount += 1
        }
        #expect(undoCount <= 50)
    }

    @Test("AvatarShapeGenerator Paths for All 12 User Shapes and 35 M3 Expressive Shapes")
    func testAvatarShapeGeneratorAllShapes() {
        let rect = CGRect(x: 0, y: 0, width: 64, height: 64)

        for shapeName in ControlCenterUtils.userShapes {
            let path = AvatarShapeGenerator.path(for: shapeName, in: rect)
            #expect(!path.isEmpty)
            let bounds = path.boundingBox
            #expect(bounds.width > 0)
            #expect(bounds.height > 0)
        }

        #expect(ControlCenterUtils.expressiveUserShapes.count == 35)
        for shape in M3ExpressiveShape.allCases {
            let path = AvatarShapeGenerator.path(for: shape, in: rect)
            #expect(!path.isEmpty)
            let bounds = path.boundingBox
            #expect(bounds.width > 0)
            #expect(bounds.height > 0)
        }
    }

    @Test("Control Center Tile Span Cycling")
    func testTileSpanCycling() {
        let wifi = ControlCenterWidgetConfig(id: "wifi", w: 4, h: 1)
        let (w1, _) = ControlCenterUtils.nextSpan(for: wifi, columns: 8)
        #expect(w1 == 2) // 4 -> 2

        let halfWifi = ControlCenterWidgetConfig(id: "wifi", w: 2, h: 1)
        let (w2, _) = ControlCenterUtils.nextSpan(for: halfWifi, columns: 8)
        #expect(w2 == 1) // 2 -> 1

        let compactWifi = ControlCenterWidgetConfig(id: "wifi", w: 1, h: 1)
        let (w3, _) = ControlCenterUtils.nextSpan(for: compactWifi, columns: 8)
        #expect(w3 == 4) // 1 -> 4

        // Non-shrinkable widget stays clamped
        let userWidget = ControlCenterWidgetConfig(id: "user", w: 5, h: 1)
        let (userW, _) = ControlCenterUtils.nextSpan(for: userWidget, columns: 8)
        #expect(userW == 5)
    }

    @Test("Control Center Catalog Widgets and Titles")
    func testCatalogWidgets() {
        #expect(ControlCenterUtils.catalogWidgets.count >= 15)
        for widget in ControlCenterUtils.catalogWidgets {
            #expect(!ControlCenterUtils.title(for: widget.id).isEmpty)
            #expect(!ControlCenterUtils.subtitle(for: widget.id).isEmpty)
            #expect(!ControlCenterUtils.icon(for: widget.id).isEmpty)
        }
    }

    // MARK: - Grid Customization (Stage 2c)

    private func tileRectsOverlap(_ a: ControlCenterWidgetConfig, _ b: ControlCenterWidgetConfig) -> Bool {
        a.col < b.col + b.w && b.col < a.col + a.w && a.row < b.row + b.h && b.row < a.row + a.h
    }

    private func hasAnyOverlap(_ tiles: [ControlCenterWidgetConfig]) -> Bool {
        for i in tiles.indices {
            for j in tiles.indices where j > i {
                if tileRectsOverlap(tiles[i], tiles[j]) { return true }
            }
        }
        return false
    }

    private struct GridPos: Equatable {
        let col: Int
        let row: Int
    }

    private func position(of id: String, in tiles: [ControlCenterWidgetConfig]) -> GridPos? {
        guard let tile = tiles.first(where: { $0.id == id }) else { return nil }
        return GridPos(col: tile.col, row: tile.row)
    }

    @Test("Default Grid Tiles Equal Canonical Hardware Tiles")
    func testDefaultGridTilesEqualCanonicalHardwareTiles() {
        #expect(ControlCenterWidgetConfig.defaultGridTiles == ControlCenterUtils.canonicalHardwareTiles)
        #expect(ControlCenterWidgetConfig.defaultGridTiles.count == 8)
    }

    @Test("Normalized Grid Tiles Preserve Unlocked Catalog Tiles")
    func testNormalizedGridTilesPreserveUnlockedCatalogTiles() {
        let unlockedIds = ["doNotDisturb", "nightMode", "darkMode", "theme", "media", "quickTiles"]
        let input = ControlCenterWidgetConfig.defaultGridTiles
            + unlockedIds.map { ControlCenterWidgetConfig(id: $0) }
        let normalized = ControlCenterUtils.normalizedGridTiles(from: input)
        let ids = normalized.map { $0.id }
        #expect(normalized.count == 14)
        for id in unlockedIds {
            #expect(ids.contains(id))
        }
    }

    @Test("Normalized Grid Tiles Do Not Snap Back to Canonical on Removal")
    func testNormalizedGridTilesNoSnapBackOnRemoval() {
        let removed = ControlCenterWidgetConfig.defaultGridTiles.filter {
            $0.id != "audioOutput" && $0.id != "colorPicker"
        }
        let normalized = ControlCenterUtils.normalizedGridTiles(from: removed)
        #expect(normalized.count == 6)
        #expect(!normalized.contains { $0.id == "audioOutput" || $0.id == "colorPicker" })
        #expect(normalized != ControlCenterUtils.canonicalHardwareTiles)

        let empty = ControlCenterUtils.normalizedGridTiles(from: [])
        #expect(empty.isEmpty)
        #expect(empty != ControlCenterUtils.canonicalHardwareTiles)
    }

    @Test("Normalized Grid Tiles Strip Fixed Chrome and Disabled, Normalize Aliases, Dedupe IDs")
    func testNormalizedGridTilesFilteringAliasesDedupe() {
        let input: [ControlCenterWidgetConfig] = [
            ControlCenterWidgetConfig(id: "user"),
            ControlCenterWidgetConfig(id: "lock"),
            ControlCenterWidgetConfig(id: "power"),
            ControlCenterWidgetConfig(id: "settings"),
            ControlCenterWidgetConfig(id: "edit"),
            ControlCenterWidgetConfig(id: "volumeSlider"),
            ControlCenterWidgetConfig(id: "brightnessSlider"),
            ControlCenterWidgetConfig(id: "inputVolumeSlider"),
            ControlCenterWidgetConfig(id: "wifi", enabled: false),
            ControlCenterWidgetConfig(id: "network"),
            ControlCenterWidgetConfig(id: "caffeine"),
            ControlCenterWidgetConfig(id: "audioDevice"),
            ControlCenterWidgetConfig(id: "wifi")
        ]
        let normalized = ControlCenterUtils.normalizedGridTiles(from: input)
        let ids = normalized.map { $0.id }
        #expect(ids == ["wifi", "idleInhibitor", "audioOutput"])
        for chromeId in ControlCenterUtils.fixedChromeIds {
            #expect(!ids.contains(chromeId))
        }
    }

    @Test("Grid Planner Move Later Tile Onto Origin Shifts Displaced Tiles Without Overlap")
    func testPlannerMoveLaterTileToOrigin() {
        let tiles = ControlCenterWidgetConfig.defaultGridTiles
        for movedId in ["idleInhibitor", "bluetooth"] {
            let result = ControlCenterGridPlanner.move(widgetID: movedId, toCol: 0, toRow: 0, in: tiles, columns: 8, width: 418)
            #expect(result.count == 8)
            #expect(position(of: movedId, in: result) == GridPos(col: 0, row: 0))
            #expect(!hasAnyOverlap(result))
        }
    }

    @Test("Grid Planner Move Earlier Tile Down Compacts Vacated Left Column Upward")
    func testPlannerMoveWifiDownCompactsColumn() {
        let tiles = ControlCenterWidgetConfig.defaultGridTiles
        let result = ControlCenterGridPlanner.move(widgetID: "wifi", toCol: 0, toRow: 3, in: tiles, columns: 8, width: 418)
        #expect(result.count == 8)
        #expect(position(of: "wifi", in: result) == GridPos(col: 0, row: 3))
        #expect(position(of: "audioOutput", in: result) == GridPos(col: 0, row: 0))
        #expect(position(of: "battery", in: result) == GridPos(col: 0, row: 1))
        #expect(position(of: "colorPicker", in: result) == GridPos(col: 0, row: 2))
        #expect(!hasAnyOverlap(result))
    }

    @Test("Grid Planner Insert Fills Open First-Fit Gap Instead of Next Row")
    func testPlannerInsertFirstFitGap() {
        let withoutBluetooth = ControlCenterWidgetConfig.defaultGridTiles.filter { $0.id != "bluetooth" }
        let newTile = ControlCenterWidgetConfig(id: "doNotDisturb", w: 4, h: 1)
        let result = ControlCenterGridPlanner.insert(newTile, into: withoutBluetooth, columns: 8, width: 418)
        #expect(result.count == 8)
        #expect(position(of: "doNotDisturb", in: result) == GridPos(col: 4, row: 0))
        #expect(!hasAnyOverlap(result))
    }

    @Test("Grid Planner Cycle Span 4-2-1-4, Col Clamp on Expand, QuickTiles Floor")
    func testPlannerCycleSpan() {
        var tiles = ControlCenterWidgetConfig.defaultGridTiles
        tiles = ControlCenterGridPlanner.cycleSpan(widgetID: "wifi", in: tiles, columns: 8, width: 418)
        #expect(tiles.first { $0.id == "wifi" }?.w == 2)
        tiles = ControlCenterGridPlanner.cycleSpan(widgetID: "wifi", in: tiles, columns: 8, width: 418)
        #expect(tiles.first { $0.id == "wifi" }?.w == 1)
        tiles = ControlCenterGridPlanner.cycleSpan(widgetID: "wifi", in: tiles, columns: 8, width: 418)
        #expect(tiles.first { $0.id == "wifi" }?.w == 4)
        #expect(!hasAnyOverlap(tiles))

        // Expanding a 1-wide tile at col 7 clamps col to columns - w = 4
        let single = [ControlCenterWidgetConfig(id: "wifi", col: 7, row: 0, w: 1, h: 1, small: true)]
        let cycled = ControlCenterGridPlanner.cycleSpan(widgetID: "wifi", in: single, columns: 8, width: 418)
        let wifi = cycled.first { $0.id == "wifi" }
        #expect(wifi?.w == 4)
        #expect(wifi?.col == 4)

        // quickTiles never drops below 4 columns: 8 -> 4 -> 8
        var quick = [ControlCenterWidgetConfig(id: "quickTiles", col: 0, row: 0, w: 8, h: 1)]
        quick = ControlCenterGridPlanner.cycleSpan(widgetID: "quickTiles", in: quick, columns: 8, width: 418)
        #expect(quick.first { $0.id == "quickTiles" }?.w == 4)
        quick = ControlCenterGridPlanner.cycleSpan(widgetID: "quickTiles", in: quick, columns: 8, width: 418)
        #expect(quick.first { $0.id == "quickTiles" }?.w == 8)
    }

    @Test("Grid Catalog Widgets Completeness")
    func testGridCatalogWidgetsCompleteness() {
        let catalog = ControlCenterUtils.gridCatalogWidgets
        #expect(catalog.count == 14)
        let expectedIds: Set<String> = [
            "wifi", "bluetooth", "audioOutput", "audioInput", "battery", "diskUsage",
            "colorPicker", "idleInhibitor", "doNotDisturb", "nightMode", "darkMode",
            "theme", "media", "quickTiles"
        ]
        #expect(Set(catalog.map { $0.id }) == expectedIds)
        for widget in catalog {
            #expect(!ControlCenterUtils.fixedChromeIds.contains(widget.id))
            #expect(!ControlCenterUtils.title(for: widget.id).isEmpty)
            #expect(!ControlCenterUtils.subtitle(for: widget.id).isEmpty)
            #expect(!ControlCenterUtils.icon(for: widget.id).isEmpty)
        }
    }
}
