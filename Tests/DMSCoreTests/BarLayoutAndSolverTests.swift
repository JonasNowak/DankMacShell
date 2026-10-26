import Testing
import Foundation
@testable import DMSCore

@Suite("Bar Layout and Solvers Tests")
struct BarLayoutAndSolverTests {

    @Test("BarCenterLayoutSolver Geometric Centering")
    func testGeometricCentering() {
        // 2 items: 100pt and 200pt, spacing 10pt -> totalSize = 310pt in length 1000pt
        // Ideal start = 500 - 155 = 345
        let res = BarCenterLayoutSolver.resolve(
            sizes: [100.0, 200.0],
            length: 1000.0,
            spacing: 10.0,
            mode: "geometric"
        )

        #expect(res.totalSize == 310.0)
        #expect(res.positions.count == 2)
        if let p0 = res.positions[0], let p1 = res.positions[1] {
            #expect(abs(p0 - 345.0) < 0.001)
            #expect(abs(p1 - (345.0 + 100.0 + 10.0)) < 0.001) // 455
        } else {
            Issue.record("Positions should not be nil")
        }
    }

    @Test("BarCenterLayoutSolver with Hidden or Nil Items")
    func testHiddenItems() {
        // Hidden item in the middle (nil)
        let res = BarCenterLayoutSolver.resolve(
            sizes: [100.0, nil, 100.0],
            length: 1000.0,
            spacing: 20.0,
            mode: "geometric"
        )

        #expect(res.totalSize == 220.0)
        #expect(res.positions[0] != nil)
        #expect(res.positions[1] == nil)
        #expect(res.positions[2] != nil)

        // Ideal start = 500 - 110 = 390
        #expect(abs(res.positions[0]! - 390.0) < 0.001)
        #expect(abs(res.positions[2]! - (390.0 + 100.0 + 20.0)) < 0.001)
    }

    @Test("BarCenterLayoutSolver Empty and All Nil Sizes")
    func testEmptySizes() {
        let empty = BarCenterLayoutSolver.resolve(sizes: [], length: 1000.0, spacing: 8.0)
        #expect(empty.totalSize == 0.0)
        #expect(empty.positions.isEmpty)

        let allNil = BarCenterLayoutSolver.resolve(sizes: [nil, nil], length: 1000.0, spacing: 8.0)
        #expect(allNil.totalSize == 0.0)
        #expect(allNil.positions == [nil, nil])
    }

    @Test("BarCenterLayoutSolver Index Mode Centering")
    func testIndexCentering() {
        // Odd count: 3 widgets of size 60, 80, 100 with spacing 10
        let anchor = BarCenterLayoutSolver.Anchor(middle: 1, count: 3, previous: 0)
        let res = BarCenterLayoutSolver.resolve(
            sizes: [60.0, 80.0, 100.0],
            length: 1000.0,
            spacing: 10.0,
            mode: "index",
            anchor: anchor
        )

        #expect(res.positions.count == 3)
        // Middle widget (index 1) center should be placed at 500
        if let p1 = res.positions[1] {
            let midCenter = p1 + 40.0
            #expect(abs(midCenter - 500.0) < 0.001)
        }
    }

    @Test("BarCenterLayoutSolver Bounds Confinement")
    func testBoundsConfinement() {
        // Right bounds encroachment: max bound 400 when ideal start would be 500 - 150 = 350, totalSize 300
        // end would be 650 > 400, so confined start should be 400 - 300 = 100
        let rightConfined = BarCenterLayoutSolver.resolve(
            sizes: [300.0],
            length: 1000.0,
            spacing: 0.0,
            bounds: BarCenterLayoutSolver.Bounds(min: nil, max: 400.0)
        )
        #expect(rightConfined.positions[0] == 100.0)

        // Tight bounds: max - min < totalSize (e.g. min 200, max 300, totalSize 200)
        // should center within (minBound + maxBound - totalSize) / 2
        let tightConfined = BarCenterLayoutSolver.resolve(
            sizes: [200.0],
            length: 1000.0,
            spacing: 0.0,
            bounds: BarCenterLayoutSolver.Bounds(min: 200.0, max: 300.0)
        )
        // (200 + 300 - 200) / 2 = 150
        #expect(tightConfined.positions[0] == 150.0)
    }

    @Test("BarSegmentRoleSolver Continuous Runs and Breaks")
    func testSegmentRoles() {
        // 1. Empty entries
        let emptyRoles = BarSegmentRoleSolver.resolve(entries: [], participating: [])
        #expect(emptyRoles.isEmpty)

        // 2. Run of 2 elements -> first, last
        let e2 = [
            BarWidgetEntry(id: "w1", widgetId: "w1"),
            BarWidgetEntry(id: "w2", widgetId: "w2")
        ]
        let roles2 = BarSegmentRoleSolver.resolve(entries: e2, participating: [true, true])
        #expect(roles2 == [.first, .last])

        // 3. Run of 4 elements -> first, middle, middle, last
        let e4 = [
            BarWidgetEntry(id: "w1"),
            BarWidgetEntry(id: "w2"),
            BarWidgetEntry(id: "w3"),
            BarWidgetEntry(id: "w4")
        ]
        let roles4 = BarSegmentRoleSolver.resolve(entries: e4, participating: [true, true, true, true])
        #expect(roles4 == [.first, .middle, .middle, .last])

        // 4. Run broken by spacer
        let eSpacer = [
            BarWidgetEntry(id: "w1"),
            BarWidgetEntry(id: "spacer1", widgetId: "spacer"),
            BarWidgetEntry(id: "w2")
        ]
        let rolesSpacer = BarSegmentRoleSolver.resolve(entries: eSpacer, participating: [true, true, true])
        #expect(rolesSpacer[0] == .solo)
        #expect(rolesSpacer[1] == .solo)
        #expect(rolesSpacer[2] == .solo)

        // 5. Run broken by participating = false
        let eNonPart = [
            BarWidgetEntry(id: "w1"),
            BarWidgetEntry(id: "w2"),
            BarWidgetEntry(id: "w3")
        ]
        let rolesNonPart = BarSegmentRoleSolver.resolve(entries: eNonPart, participating: [true, false, true])
        #expect(rolesNonPart[0] == .solo)
        #expect(rolesNonPart[1] == .solo)
        #expect(rolesNonPart[2] == .solo)
    }

    @Test("BarConfig Models and Layout Codable")
    func testBarConfigCodable() throws {
        let entry = BarWidgetEntry(
            id: "clockWidget",
            widgetId: "clock",
            enabled: true,
            options: ["format": AnyCodable("24h")]
        )
        #expect(entry.widgetId == "clock")
        #expect(entry.options["format"]?.stringValue == "24h")

        let barLayout = BarLayout(left: [entry], center: [], right: [])
        let config = BarConfig(
            id: "test-bar",
            name: "Top Bar",
            screenPreferences: ["Built-in Display"],
            position: "top",
            autoHide: true,
            smartAutoHide: true,
            thickness: 50,
            margin: 12,
            spacing: 6,
            transparency: 0.85,
            gothCorners: false,
            layout: barLayout
        )

        #expect(config.isVertical == false)

        let verticalConfig = BarConfig(position: "left")
        #expect(verticalConfig.isVertical == true)

        let rightConfig = BarConfig(position: "right")
        #expect(rightConfig.isVertical == true)

        // Codable roundtrip
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(BarConfig.self, from: data)

        #expect(decoded.id == "test-bar")
        #expect(decoded.position == "top")
        #expect(decoded.thickness == 50)
        #expect(decoded.autoHide == true)
        #expect(decoded.smartAutoHide == true)
        #expect(decoded.gothCorners == false)
        #expect(decoded.layout.left.count == 1)
        #expect(decoded.layout.left.first?.options["format"]?.stringValue == "24h")
    }

    @Test("SmartAutoHideSolver Fullscreen Detection and Geometry Edge Cases")
    func testSmartAutoHideSolver() {
        let screenW = 1512.0
        let screenH = 982.0
        let screenVisH = 950.0

        // 1. Exact native fullscreen window
        let fsExact = SmartAutoHideSolver.isWindowFullscreen(
            windowX: 0,
            windowY: 0,
            windowWidth: screenW,
            windowHeight: screenH,
            screenWidth: screenW,
            screenHeight: screenH,
            screenVisibleHeight: screenVisH
        )
        #expect(fsExact == true)

        // 2. Maximized window under menu bar (touches bottom, starts at Y=32, full width)
        let fsMaximized = SmartAutoHideSolver.isWindowFullscreen(
            windowX: 0,
            windowY: 32,
            windowWidth: screenW,
            windowHeight: screenVisH,
            screenWidth: screenW,
            screenHeight: screenH,
            screenVisibleHeight: screenVisH
        )
        #expect(fsMaximized == true)

        // 3. Normal window in center (not full width/height)
        let normalWin = SmartAutoHideSolver.isWindowFullscreen(
            windowX: 100,
            windowY: 100,
            windowWidth: 800,
            windowHeight: 600,
            screenWidth: screenW,
            screenHeight: screenH,
            screenVisibleHeight: screenVisH
        )
        #expect(normalWin == false)

        // 4. Multi-monitor offset: window on secondary screen (X=1512, Y=0) matching screen 1
        let secondaryMatch = SmartAutoHideSolver.isWindowFullscreen(
            windowX: 1512,
            windowY: 0,
            windowWidth: 1920,
            windowHeight: 1080,
            screenWidth: 1920,
            screenHeight: 1080,
            screenVisibleHeight: 1080,
            screenCGX: 1512,
            screenCGY: 0
        )
        #expect(secondaryMatch == true)

        // 5. Multi-monitor mismatch: window on primary screen (X=0) checked against screen 1 (X=1512)
        let secondaryMismatch = SmartAutoHideSolver.isWindowFullscreen(
            windowX: 0,
            windowY: 0,
            windowWidth: screenW,
            windowHeight: screenH,
            screenWidth: 1920,
            screenHeight: 1080,
            screenVisibleHeight: 1080,
            screenCGX: 1512,
            screenCGY: 0
        )
        #expect(secondaryMismatch == false)
    }

    @Test("barSmartAutoHide Convenience and Dynamic Setting Getter/Setter")
    func testBarSmartAutoHideSettings() {
        var config = DMSConfig.default
        #expect(config.barSmartAutoHide == false)

        config.barSmartAutoHide = true
        #expect(config.barSmartAutoHide == true)
        #expect(config.barConfigs.first?.smartAutoHide == true)

        #expect(config.getSetting("barSmartAutoHide")?.boolValue == true)

        config.setSetting("barSmartAutoHide", value: AnyCodable(false))
        #expect(config.barSmartAutoHide == false)
        #expect(config.barConfigs.first?.smartAutoHide == false)
    }
}
