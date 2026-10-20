import Testing
import Foundation
@testable import DMSCore

@Suite("Dock Config and Magnification Engine Tests")
struct DockConfigAndEngineTests {

    @Test("DockConfig Properties and Orientation")
    func testDockOrientationAndEdges() {
        let topDock = DockConfig(position: 0)
        #expect(topDock.isVertical == false)
        #expect(topDock.edgeString == "top")

        let bottomDock = DockConfig(position: 1)
        #expect(bottomDock.isVertical == false)
        #expect(bottomDock.edgeString == "bottom")

        let leftDock = DockConfig(position: 2)
        #expect(leftDock.isVertical == true)
        #expect(leftDock.edgeString == "left")

        let rightDock = DockConfig(position: 3)
        #expect(rightDock.isVertical == true)
        #expect(rightDock.edgeString == "right")

        let invalidDock = DockConfig(position: 99)
        #expect(invalidDock.isVertical == false)
        #expect(invalidDock.edgeString == "bottom")
    }

    @Test("Dock Edge Resolution for Multiple Screens")
    func testDockEdgeResolution() {
        let configs = [
            DockConfig(id: "main-bottom", enabled: true, screenPreferences: ["Built-in Display"], position: 1),
            DockConfig(id: "ext-bottom", enabled: true, screenPreferences: ["Dell U2720Q"], position: 1),
            DockConfig(id: "all-left", enabled: true, screenPreferences: ["all"], position: 2),
            DockConfig(id: "disabled-top", enabled: false, screenPreferences: ["all"], position: 0),
            DockConfig(id: "last-right", enabled: true, screenPreferences: ["any"], showOnLastDisplay: true, position: 3)
        ]

        // 1. Explicit screen match
        let winDell = DockConfig.resolveEdge(
            configs: configs,
            screenName: "Dell U2720Q",
            screenModel: nil,
            allScreens: ["Built-in Display", "Dell U2720Q"],
            edge: "bottom"
        )
        #expect(winDell?.id == "ext-bottom")

        // 2. Explicit screen model match
        let winModel = DockConfig.resolveEdge(
            configs: configs,
            screenName: "Display #2",
            screenModel: "Dell U2720Q",
            allScreens: ["Built-in Display", "Display #2"],
            edge: "bottom"
        )
        #expect(winModel?.id == "ext-bottom")

        // 3. Fallback to "all"
        let winAll = DockConfig.resolveEdge(
            configs: configs,
            screenName: "Some Screen",
            edge: "left"
        )
        #expect(winAll?.id == "all-left")

        // 4. Disabled dock is ignored
        let winDisabled = DockConfig.resolveEdge(
            configs: configs,
            screenName: "Built-in Display",
            edge: "top"
        )
        #expect(winDisabled == nil)

        // 5. Fallback to showOnLastDisplay when single screen
        let winLast = DockConfig.resolveEdge(
            configs: configs,
            screenName: "Sole Display",
            allScreens: ["Sole Display"],
            edge: "right"
        )
        #expect(winLast?.id == "last-right")

        // 6. Resolve all edges for Built-in Display
        let allResolved = DockConfig.resolveAll(
            configs: configs,
            screenName: "Built-in Display",
            allScreens: ["Built-in Display"]
        )
        // bottom (main-bottom), left (all-left), right (last-right)
        #expect(allResolved.count == 3)
        #expect(allResolved.contains(where: { $0.id == "main-bottom" }))
        #expect(allResolved.contains(where: { $0.id == "all-left" }))
        #expect(allResolved.contains(where: { $0.id == "last-right" }))
    }

    @Test("DockConfig Serialization Roundtrip")
    func testDockConfigCodable() throws {
        let dock = DockConfig(
            id: "dock-primary",
            name: "Primary Dock",
            enabled: true,
            screenPreferences: ["all"],
            position: 1,
            mode: "taskbar",
            taskbarAlign: "start",
            iconSize: 48,
            spacing: 10,
            itemSpacing: 6,
            transparency: 0.9,
            magnification: true,
            magnificationScale: 140.0,
            magnificationProfile: "gaussian",
            options: ["custom": AnyCodable("value")]
        )

        let data = try JSONEncoder().encode(dock)
        let decoded = try JSONDecoder().decode(DockConfig.self, from: data)

        #expect(decoded.id == "dock-primary")
        #expect(decoded.mode == "taskbar")
        #expect(decoded.taskbarAlign == "start")
        #expect(decoded.iconSize == 48)
        #expect(decoded.magnification == true)
        #expect(decoded.magnificationScale == 140.0)
        #expect(decoded.magnificationProfile == "gaussian")
        #expect(decoded.options["custom"]?.stringValue == "value")
    }

    @Test("Dock Magnification Physics Edge Cases")
    func testMagnificationPhysics() {
        // Zero or negative baseSize fallback
        let fallbackRadius = DockMagnificationEngine.magnificationRadius(baseSize: -10, profile: "parabolic")
        #expect(abs(fallbackRadius - (42.0 * 1.8)) < 0.001)

        // Invalid profile fallback to parabolic
        let unknownProfileRadius = DockMagnificationEngine.magnificationRadius(baseSize: 50, profile: "unknown")
        #expect(abs(unknownProfileRadius - (50.0 * 1.8)) < 0.001)

        // Factor at zero radius
        let zeroRadiusFactor = DockMagnificationEngine.magnificationFactor(dist: 10, radius: 0, profile: "parabolic")
        #expect(zeroRadiusFactor == 0.0)

        // Factor at exact boundary (dist == radius) must be 0.0
        let boundaryFactor = DockMagnificationEngine.magnificationFactor(dist: 100, radius: 100, profile: "parabolic")
        #expect(boundaryFactor == 0.0)

        // Gaussian and cosine profile factor decay
        let rGauss = 100.0
        let fGaussMid = DockMagnificationEngine.magnificationFactor(dist: 50, radius: rGauss, profile: "gaussian")
        #expect(fGaussMid > 0.0 && fGaussMid < 1.0)

        let rCos = 100.0
        let fCosMid = DockMagnificationEngine.magnificationFactor(dist: 50, radius: rCos, profile: "cosine")
        #expect(abs(fCosMid - 0.5) < 0.01) // cos(pi/2) = 0 -> 0.5 * (1 + 0) = 0.5

        // Drag backward unitTarget
        let spans: [(id: String, start: Double, end: Double)] = [
            (id: "app_1", start: 0, end: 50),
            (id: "app_2", start: 50, end: 100),
            (id: "app_3", start: 100, end: 150)
        ]
        // app_3 (start 100) dragging backwards past midpoint of app_2 (75)
        // start 100 - 30 = 70 < 75
        let swapBackward = DockMagnificationEngine.unitTarget(spans: spans, id: "app_3", offset: -30)
        #expect(swapBackward == "app_2")

        // app_3 dragging backwards past midpoint of app_1 (25)
        // start 100 - 80 = 20 < 25
        let swapMultiBackward = DockMagnificationEngine.unitTarget(spans: spans, id: "app_3", offset: -80)
        #expect(swapMultiBackward == "app_1")
    }
}
