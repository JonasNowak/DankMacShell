import Foundation
import AppKit
import DMSCore

/// Provides eyedropper color sampling, recent swatches, and format conversion.
@MainActor
public final class ColorPickerService: ObservableObject {
    public static let shared = ColorPickerService()

    @Published public private(set) var selectedColor: NSColor = .systemPurple
    @Published public private(set) var hexCode: String = "#7C4DFF"
    @Published public private(set) var rgbString: String = "rgb(124, 77, 255)"
    @Published public private(set) var hslString: String = "hsl(256, 100%, 65%)"
    @Published public private(set) var recentColors: [String] = [
        "#7C4DFF", "#2196F3", "#4CAF50", "#FF9800", "#F44336", "#E91E63",
        "#9C27B0", "#00BCD4", "#009688", "#8BC34A", "#FFEB3B", "#607D8B"
    ]

    private init() {}

    public func sampleColor() {
        let sampler = NSColorSampler()
        sampler.show { [weak self] color in
            guard let color = color else { return }
            Task { @MainActor [weak self] in
                self?.applyColor(color)
            }
        }
    }

    public func copyColorToClipboard(_ hex: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(hex, forType: .string)
        ToastCenter.shared.show(icon: "doc.on.clipboard", message: "Color Copied: \(hex)")
    }

    public func applyColor(_ color: NSColor) {
        let rgbColor = color.usingColorSpace(.sRGB) ?? color
        self.selectedColor = rgbColor

        let r = Double(rgbColor.redComponent)
        let g = Double(rgbColor.greenComponent)
        let b = Double(rgbColor.blueComponent)

        let hex = String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
        self.hexCode = hex
        self.rgbString = "rgb(\(Int(round(r * 255))), \(Int(round(g * 255))), \(Int(round(b * 255))))"

        let hsl = DynamicThemeGenerator.rgbToHSL(r: r, g: g, b: b)
        self.hslString = "hsl(\(Int(round(hsl.h))), \(Int(round(hsl.s * 100)))%, \(Int(round(hsl.l * 100)))%)"

        if !recentColors.contains(hex) {
            recentColors.insert(hex, at: 0)
            if recentColors.count > 12 {
                recentColors = Array(recentColors.prefix(12))
            }
        }

        // Copy hex to pasteboard
        copyColorToClipboard(hex)
    }
}
