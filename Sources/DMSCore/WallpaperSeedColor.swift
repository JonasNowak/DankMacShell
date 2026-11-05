import Foundation
import CoreGraphics
import ImageIO

/// Extracts a seed color from a wallpaper image by downsampling to 32x32 and
/// averaging the non-extreme, non-transparent pixels. Shared by the DMS shell
/// (via ThemeStore) and the dms-symbian companion so both resolve the same
/// "dynamic" theme palette.
public enum WallpaperSeedColor {
    /// Dominant average color of the image at `url`, as an M3 seed color.
    /// Returns nil when the image cannot be decoded; falls back to the M3 default seed.
    public static func dominantColor(from url: URL) -> M3Color? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        let width = 32
        let height = 32
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalR: Double = 0
        var totalG: Double = 0
        var totalB: Double = 0
        var count: Double = 0

        for i in stride(from: 0, to: rawData.count, by: 4) {
            let r = Double(rawData[i]) / 255.0
            let g = Double(rawData[i + 1]) / 255.0
            let b = Double(rawData[i + 2]) / 255.0
            let a = Double(rawData[i + 3]) / 255.0

            if a > 0.5 {
                let l = (r + g + b) / 3.0
                if l > 0.1 && l < 0.9 {
                    totalR += r
                    totalG += g
                    totalB += b
                    count += 1
                }
            }
        }

        guard count > 0 else {
            return M3Color("#6750A4")
        }

        return M3Color.from(r: totalR / count, g: totalG / count, b: totalB / count)
    }
}
