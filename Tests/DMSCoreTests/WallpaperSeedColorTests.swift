import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import DMSCore

@Suite("WallpaperSeedColor Tests")
struct WallpaperSeedColorTests {

    private func solidColorImageURL(r: UInt8, g: UInt8, b: UInt8) throws -> URL {
        let size = 64
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var raw = [UInt8](repeating: 0, count: size * size * 4)
        for i in stride(from: 0, to: raw.count, by: 4) {
            raw[i] = r
            raw[i + 1] = g
            raw[i + 2] = b
            raw[i + 3] = 255
        }
        guard let ctx = CGContext(
            data: &raw,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = ctx.makeImage() else {
            throw NSError(domain: "test", code: -1)
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("seed-test-\(UUID().uuidString).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "test", code: -2)
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)
        return url
    }

    @Test("Dominant color of a solid image matches the fill color")
    func dominantColorOfSolidImage() throws {
        let url = try solidColorImageURL(r: 30, g: 100, b: 200)
        defer { try? FileManager.default.removeItem(at: url) }

        let seed = WallpaperSeedColor.dominantColor(from: url)
        #expect(seed != nil)
        #expect(abs(seed!.red - 30.0 / 255.0) < 0.05)
        #expect(abs(seed!.green - 100.0 / 255.0) < 0.05)
        #expect(abs(seed!.blue - 200.0 / 255.0) < 0.05)
    }

    @Test("Dominant color of a missing file returns nil")
    func dominantColorOfMissingFile() {
        let url = URL(fileURLWithPath: "/tmp/definitely-not-there-\(UUID().uuidString).png")
        #expect(WallpaperSeedColor.dominantColor(from: url) == nil)
    }
}
