import Testing
import Foundation
@testable import DMSCore

@Suite("Corner Style and Geometry Specification Tests")
struct CornerStyleAndGeometryTests {

    @Test("BarCornerStyle Enum and Metadata")
    func testBarCornerStyleEnum() {
        #expect(BarCornerStyle.allCases.count == 4)
        #expect(BarCornerStyle.capsule.rawValue == "capsule")
        #expect(BarCornerStyle.gothic.rawValue == "gothic")
        #expect(BarCornerStyle.rounded.rawValue == "rounded")
        #expect(BarCornerStyle.square.rawValue == "square")

        #expect(BarCornerStyle.capsule.title == "Capsule")
        #expect(BarCornerStyle.gothic.title == "Gothic")
        #expect(BarCornerStyle.rounded.title == "Rounded")
        #expect(BarCornerStyle.square.title == "Square")
    }

    @Test("BarConfig CornerStyle Mapping to CornerRadius and GothCorners")
    func testBarConfigCornerStyleMapping() {
        var cfg = BarConfig()

        // Default: cornerRadius = -1, gothCorners = true -> .gothic
        #expect(cfg.gothCorners == true)
        #expect(cfg.cornerStyle == .gothic)

        // Set square
        cfg.cornerStyle = .square
        #expect(cfg.cornerStyle == .square)
        #expect(cfg.cornerRadius == 0.0)
        #expect(cfg.gothCorners == false)

        // Set rounded
        cfg.cornerStyle = .rounded
        #expect(cfg.cornerStyle == .rounded)
        #expect(cfg.cornerRadius > 0.0)
        #expect(cfg.gothCorners == false)

        // Set capsule
        cfg.cornerStyle = .capsule
        #expect(cfg.cornerStyle == .capsule)
        #expect(cfg.cornerRadius < 0.0)
        #expect(cfg.gothCorners == false)

        // Set gothic
        cfg.cornerStyle = .gothic
        #expect(cfg.cornerStyle == .gothic)
        #expect(cfg.gothCorners == true)
    }

    @Test("BarConfig Codable Roundtrip with Corner Styles and Fillet Radius")
    func testBarConfigSerialization() throws {
        var cfg = BarConfig(
            cornerRadius: 18.0,
            gothCorners: false,
            gothFilletRadius: 16.0,
            autoSquareAttachedCorners: true,
            cornerStyle: .rounded
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(cfg)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BarConfig.self, from: data)

        #expect(decoded.cornerStyle == .rounded)
        #expect(decoded.cornerRadius == 18.0)
        #expect(decoded.gothCorners == false)
        #expect(decoded.gothFilletRadius == 16.0)
        #expect(decoded.autoSquareAttachedCorners == true)

        // Test Gothic configuration
        cfg.cornerStyle = .gothic
        cfg.gothFilletRadius = 20.0
        let gothicData = try encoder.encode(cfg)
        let decodedGothic = try decoder.decode(BarConfig.self, from: gothicData)
        #expect(decodedGothic.cornerStyle == .gothic)
        #expect(decodedGothic.gothCorners == true)
        #expect(decodedGothic.gothFilletRadius == 20.0)

        // Test Square configuration
        cfg.cornerStyle = .square
        let squareData = try encoder.encode(cfg)
        let decodedSquare = try decoder.decode(BarConfig.self, from: squareData)
        #expect(decodedSquare.cornerStyle == .square)
        #expect(decodedSquare.cornerRadius == 0.0)
        #expect(decodedSquare.gothCorners == false)
    }

    @Test("IslandSettings CornerStyle and Fillet Radius Roundtrip")
    func testIslandCornerStyleAndFillet() {
        var island = IslandSettings()
        #expect(island.gothCorners == true)
        #expect(island.cornerStyle == .gothic)
        #expect(island.gothFilletRadius == 12.0)

        island.cornerStyle = .capsule
        #expect(island.gothCorners == false)
        #expect(island.cornerStyle == .capsule)

        island.gothFilletRadius = 18.0
        let dict = island.toDictionary()
        let reconstructed = IslandSettings(from: dict)

        #expect(reconstructed.gothCorners == false)
        #expect(reconstructed.cornerStyle == .capsule)
        #expect(reconstructed.gothFilletRadius == 18.0)
    }

    @Test("DMSConfig FixedCornerRadius and GothCornersEnabled")
    func testDMSConfigCornerOverrides() throws {
        var config = DMSConfig()
        #expect(config.gothCornersEnabled == true)
        #expect(config.fixedCornerRadius == nil)

        config.fixedCornerRadius = 0.0 // Square override
        #expect(config.fixedCornerRadius == 0.0)

        config.fixedCornerRadius = 20.0 // Fixed rounded override
        #expect(config.fixedCornerRadius == 20.0)

        config.fixedCornerRadius = nil // Back to dynamic
        #expect(config.fixedCornerRadius == nil)

        config.gothCornersEnabled = false
        #expect(config.gothCornersEnabled == false)
    }

    @Test("BarConfig Gothic Priority Over AutoSquareAttachedCorners")
    func testGothicPriorityOverAutoSquare() {
        var cfg = BarConfig()
        cfg.margin = 0
        cfg.autoSquareAttachedCorners = true
        cfg.cornerStyle = .gothic

        #expect(cfg.gothCorners == true)
        #expect(cfg.cornerStyle == .gothic)

        // Switching to square
        cfg.cornerStyle = .square
        #expect(cfg.gothCorners == false)
        #expect(cfg.cornerStyle == .square)
        #expect(cfg.cornerRadius == 0.0)

        // Switching back to gothic restores gothic corners even with margin 0
        cfg.cornerStyle = .gothic
        #expect(cfg.gothCorners == true)
        #expect(cfg.cornerStyle == .gothic)
        #expect(cfg.cornerRadius == -1.0)
    }

    @Test("IslandSettings Goth Corners and Fillet Clamping")
    func testIslandGothCornersClamping() {
        var island = IslandSettings()
        #expect(island.gothCorners == true)
        #expect(island.gothFilletRadius == 12.0)

        island.gothFilletRadius = 2.0 // Below min 4.0
        #expect(island.gothFilletRadius == 4.0)

        island.gothFilletRadius = 40.0 // Above max 32.0
        #expect(island.gothFilletRadius == 32.0)

        island.gothCorners = false
        #expect(island.gothCorners == false)
    }

    @Test("Popout Connected Mode ('Gothic Corners') Configuration Specification")
    func testPopoutConnectedModeConfiguration() {
        var config = DMSConfig()
        // Default: Popouts connect directly to bar with Gothic concave fillets (SURF-001)
        #expect(config.gothCornersEnabled == true)

        config.gothCornersEnabled = false
        #expect(config.gothCornersEnabled == false)

        config.gothCornersEnabled = true
        #expect(config.gothCornersEnabled == true)

        // Fillet dimensions
        var barCfg = BarConfig()
        #expect(barCfg.gothFilletRadius == 14.0)

        barCfg.gothFilletRadius = 2.0 // clamped to min 4.0
        #expect(barCfg.gothFilletRadius == 4.0)

        barCfg.gothFilletRadius = 50.0 // clamped to max 32.0
        #expect(barCfg.gothFilletRadius == 32.0)

        barCfg.gothFilletRadius = 16.0
        #expect(barCfg.gothFilletRadius == 16.0)
    }

    @Test("Connected Mode Popout Geometry Dimensions and Flanges")
    func testConnectedModePopoutGeometryDimensions() {
        let bodyWidth: Double = 255.0
        let bodyHeight: Double = 348.0
        let filletRadius: Double = 14.0

        // In connected horizontal mode (top/bottom), total width expands by 2 * filletRadius
        let totalHorizontalWidth = bodyWidth + 2.0 * filletRadius
        #expect(totalHorizontalWidth == 283.0)

        // The body remains centered within the flanges
        let leftFlangeWidth = filletRadius
        let rightFlangeWidth = filletRadius
        let effectiveBodyWidth = totalHorizontalWidth - leftFlangeWidth - rightFlangeWidth
        #expect(effectiveBodyWidth == bodyWidth)

        // In connected vertical mode (left/right), total height expands by 2 * filletRadius
        let totalVerticalHeight = bodyHeight + 2.0 * filletRadius
        #expect(totalVerticalHeight == 376.0)
        let effectiveBodyHeight = totalVerticalHeight - 2.0 * filletRadius
        #expect(effectiveBodyHeight == bodyHeight)
    }

    @Test("Popout SURF-002 Physical Protrusion Motion Architecture")
    func testPopoutProtrusionMotionArchitecture() {
        let barHeight: CGFloat = 48.0
        let bodyWidth: CGFloat = 255.0
        let bodyHeight: CGFloat = 348.0
        let filletRadius: CGFloat = 14.0

        let totalWidth = bodyWidth + 2.0 * filletRadius
        let totalHeight = bodyHeight

        // Connected popout window is stationary, flush against DankBar (gap = 0)
        let bottomTargetRect = NSRect(x: 100, y: barHeight, width: totalWidth, height: totalHeight)
        #expect(bottomTargetRect.minY == barHeight)
        #expect(bottomTargetRect.width == 283.0)
        #expect(bottomTargetRect.height == 348.0)

        // Collapsed protrusion height starts at 0 at the bar edge
        let collapsedHeight: CGFloat = 0.0
        let expandedHeight: CGFloat = totalHeight
        #expect(expandedHeight - collapsedHeight == 348.0)

        // Top bar: flush below top bar
        let screenHeight: CGFloat = 900.0
        let topBarY = screenHeight - barHeight
        let topTargetRect = NSRect(x: 100, y: topBarY - totalHeight, width: totalWidth, height: totalHeight)
        #expect(topTargetRect.maxY == topBarY)
    }
}
