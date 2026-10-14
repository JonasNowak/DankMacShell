import SwiftUI
import DMSCore

/// Material 3 Screen Color Picker modal view.
public struct ColorPickerView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var colorPicker = ColorPickerService.shared

    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        let p = themeStore.palette

        VStack(spacing: 20) {
            // Header
            HStack {
                Label("Color Picker", systemImage: "eyedropper.halffull")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: p.surfaceVariant.hex))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Swatch Preview & Eyedropper Button
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(nsColor: colorPicker.selectedColor))
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color(nsColor: colorPicker.selectedColor).opacity(0.4), radius: 10, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text(colorPicker.hexCode)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: p.onSurface.hex))

                    Button(action: { colorPicker.sampleColor() }) {
                        Label("Pick from Screen", systemImage: "eyedropper")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: p.onPrimary.hex))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(hex: p.primary.hex))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(16)
            .background(Color(hex: p.surfaceContainerHigh.hex))
            .cornerRadius(20)

            // Format Rows (Hex, RGB, HSL)
            VStack(spacing: 10) {
                ColorFormatRow(label: "HEX", value: colorPicker.hexCode, palette: p)
                ColorFormatRow(label: "RGB", value: colorPicker.rgbString, palette: p)
                ColorFormatRow(label: "HSL", value: colorPicker.hslString, palette: p)
            }

            // Recent Swatches
            if !colorPicker.recentColors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RECENT COLORS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: p.outline.hex))

                    HStack(spacing: 8) {
                        ForEach(colorPicker.recentColors, id: \.self) { hex in
                            Button(action: {
                                if let c = NSColor(hex: hex) {
                                    colorPicker.applyColor(c)
                                }
                            }) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(Color(hex: p.surface.hex))
        .cornerRadius(26)
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color(hex: p.outlineVariant.hex).opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 12)
    }
}

private struct ColorFormatRow: View {
    let label: String
    let value: String
    let palette: DMSPalette

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: palette.outline.hex))
                .frame(width: 40, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: palette.onSurface.hex))

            Spacer()

            Button(action: {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(value, forType: .string)
                ToastCenter.shared.show(icon: "doc.on.doc.fill", message: "Copied \(value)")
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: palette.primary.hex))
                    .frame(width: 26, height: 26)
                    .background(Color(hex: palette.primaryContainer.hex))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(hex: palette.surfaceContainerHigh.hex))
        .cornerRadius(12)
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }
        guard clean.count == 6, let num = UInt64(clean, radix: 16) else { return nil }
        let r = CGFloat((num >> 16) & 0xFF) / 255.0
        let g = CGFloat((num >> 8) & 0xFF) / 255.0
        let b = CGFloat(num & 0xFF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
