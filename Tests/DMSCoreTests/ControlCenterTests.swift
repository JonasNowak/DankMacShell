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

    @Test("AvatarShapeGenerator Paths for All 12 User Shapes")
    func testAvatarShapeGeneratorAllShapes() {
        let rect = CGRect(x: 0, y: 0, width: 64, height: 64)

        for shapeName in ControlCenterUtils.userShapes {
            let path = AvatarShapeGenerator.path(for: shapeName, in: rect)
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
}
