import Testing
import Foundation
@testable import DMSCore

@Suite("Theme and HCT Math Tests")
struct ThemeAndHCTTests {

    @Test("M3Color Hex Parsing and Extraction")
    func testM3ColorParsing() {
        // Standard 6-digit hex with hash
        let red = M3Color("#FF0000")
        #expect(abs(red.red - 1.0) < 0.001)
        #expect(abs(red.green - 0.0) < 0.001)
        #expect(abs(red.blue - 0.0) < 0.001)

        // Without leading hash
        let green = M3Color("00FF00")
        #expect(abs(green.red - 0.0) < 0.001)
        #expect(abs(green.green - 1.0) < 0.001)
        #expect(abs(green.blue - 0.0) < 0.001)

        // 3-digit shorthand
        let blue = M3Color("#00F") // expands to #0000FF
        #expect(abs(blue.red - 0.0) < 0.001)
        #expect(abs(blue.green - 0.0) < 0.001)
        #expect(abs(blue.blue - 1.0) < 0.001)

        let white = M3Color("FFF")
        #expect(abs(white.red - 1.0) < 0.001)
        #expect(abs(white.green - 1.0) < 0.001)
        #expect(abs(white.blue - 1.0) < 0.001)

        // Invalid hex string defaults gracefully to black (0, 0, 0)
        let invalid = M3Color("invalid")
        #expect(invalid.red == 0.0)
        #expect(invalid.green == 0.0)
        #expect(invalid.blue == 0.0)

        // M3Color.from(r:g:b:)
        let custom = M3Color.from(r: 0.5, g: 1.0, b: 0.0)
        #expect(custom.hex.hasPrefix("#"))

        // Out-of-bounds clamping
        let clamped = M3Color.from(r: -1.0, g: 2.0, b: 0.5)
        #expect(clamped.red == 0.0)
        #expect(clamped.green == 1.0)
    }

    @Test("StockThemes All Variants and Fallbacks")
    func testStockThemesAll() {
        let expectedThemes = ["purple", "blue", "green", "orange", "red", "yellow", "neutral"]
        #expect(StockThemes.allThemeNames == expectedThemes)

        for name in expectedThemes {
            let dark = StockThemes.theme(named: name, isDark: true)
            #expect(dark.isDark == true)
            #expect(dark.name.lowercased() == name)
            #expect(dark.primary.hex.hasPrefix("#"))
            #expect(dark.surface.hex.hasPrefix("#"))

            let light = StockThemes.theme(named: name, isDark: false)
            #expect(light.isDark == false)
            #expect(light.name.lowercased() == name)
            #expect(light.primary.hex.hasPrefix("#"))
            #expect(light.surface.hex.hasPrefix("#"))
        }

        // Case insensitivity and whitespace handling
        let mixed = StockThemes.theme(named: "  OrAnGe  ", isDark: true)
        #expect(mixed.name == "Orange")

        // Unknown theme defaults to Purple
        let unknown = StockThemes.theme(named: "cyberpunk", isDark: true)
        #expect(unknown.name == "Purple")
    }

    @Test("ThemePalette Serialization Roundtrip")
    func testThemePaletteCodable() throws {
        let original = StockThemes.purpleDark
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThemePalette.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.isDark == original.isDark)
        #expect(decoded.primary.hex == original.primary.hex)
        #expect(decoded.surface.hex == original.surface.hex)
        #expect(decoded.error.hex == original.error.hex)
        #expect(decoded.warning.hex == original.warning.hex)
    }

    @Test("DynamicThemeGenerator HSL Conversions")
    func testHSLConversions() {
        // Pure red
        let hslRed = DynamicThemeGenerator.rgbToHSL(r: 1.0, g: 0.0, b: 0.0)
        #expect(abs(hslRed.h - 0.0) < 0.1 || abs(hslRed.h - 360.0) < 0.1)
        #expect(abs(hslRed.s - 1.0) < 0.01)
        #expect(abs(hslRed.l - 0.5) < 0.01)

        // HSL to RGB roundtrip
        let rgbBack = hslRed.toRGB()
        #expect(abs(rgbBack.r - 1.0) < 0.01)
        #expect(abs(rgbBack.g - 0.0) < 0.01)
        #expect(abs(rgbBack.b - 0.0) < 0.01)

        // HSL degree wrapping and clamping
        let wrapped = DynamicThemeGenerator.HSL(h: 400.0, s: 1.5, l: -0.2)
        #expect(abs(wrapped.h - 40.0) < 0.01)
        #expect(wrapped.s == 1.0)
        #expect(wrapped.l == 0.0)
    }

    @Test("DynamicThemeGenerator Contrast Mode Generation")
    func testContrastLevels() {
        let seed = M3Color("#007AFF") // Apple blue

        let (stdDark, stdLight) = DynamicThemeGenerator.generate(from: seed, contrast: .standard)
        let (highDark, highLight) = DynamicThemeGenerator.generate(from: seed, contrast: .high)

        #expect(stdDark.isDark == true)
        #expect(stdLight.isDark == false)
        #expect(highDark.isDark == true)
        #expect(highLight.isDark == false)

        // High contrast should produce different surface or primary hex values
        #expect(stdDark.surface.hex != highDark.surface.hex || stdDark.primary.hex != highDark.primary.hex)
    }

    @Test("HCT Math Utilities and Rotation")
    func testHCTMathUtils() {
        // Signum
        #expect(HCTMath.signum(-42) == -1.0)
        #expect(HCTMath.signum(0) == 0.0)
        #expect(HCTMath.signum(100) == 1.0)

        // Sanitize degrees
        #expect(HCTMath.sanitizeDegrees(-30) == 330.0)
        #expect(HCTMath.sanitizeDegrees(390) == 30.0)
        #expect(HCTMath.sanitizeDegrees(0) == 0.0)

        // Rotation direction
        #expect(HCTMath.rotationDirection(from: 10, to: 100) == 1.0)
        #expect(HCTMath.rotationDirection(from: 10, to: 250) == -1.0)

        // Difference degrees (shortest distance <= 180)
        #expect(HCTMath.differenceDegrees(10, 350) == 20.0)
        #expect(HCTMath.differenceDegrees(0, 180) == 180.0)

        // Relative luminance
        let blackLum = HCTMath.relativeLuminance(M3Color("#000000"))
        let whiteLum = HCTMath.relativeLuminance(M3Color("#FFFFFF"))
        #expect(abs(blackLum - 0.0) < 0.001)
        #expect(abs(whiteLum - 1.0) < 0.001)

        // Mix
        let mixedHalf = HCTMath.mix(M3Color("#000000"), M3Color("#FFFFFF"), amount: 0.5)
        #expect(abs(mixedHalf.red - 0.5) < 0.01)
        #expect(abs(mixedHalf.green - 0.5) < 0.01)
        #expect(abs(mixedHalf.blue - 0.5) < 0.01)
    }

    @Test("HCT Coordinate Roundtrip")
    func testHCTCoordinateRoundtrip() {
        let colors = [
            M3Color("#FF0000"), // Red
            M3Color("#00FF00"), // Green
            M3Color("#0000FF"), // Blue
            M3Color("#FFFF00"), // Yellow
            M3Color("#9C27B0")  // Purple
        ]

        for original in colors {
            let hct = HCT.from(color: original)
            let reconstituted = hct.toColor()
            #expect(abs(reconstituted.red - original.red) < 0.05)
            #expect(abs(reconstituted.green - original.green) < 0.05)
            #expect(abs(reconstituted.blue - original.blue) < 0.05)
        }
    }
}
