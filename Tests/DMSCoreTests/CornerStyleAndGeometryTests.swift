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
}
