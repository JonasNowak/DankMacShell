import SwiftUI
import CoreImage.CIFilterBuiltins
import DMSCore

/// Material 3 QR Code Generator modal view.
public struct QRGeneratorView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    let wifi = WiFiService.shared
    @State private var inputText: String = "https://danklinux.com"
    @State private var qrImage: NSImage? = nil

    let onClose: () -> Void

    public init(initialText: String? = nil, onClose: @escaping () -> Void) {
        if let t = initialText, !t.isEmpty {
            _inputText = State(initialValue: t)
        }
        self.onClose = onClose
    }

    public var body: some View {
        let p = themeStore.palette

        VStack(spacing: 18) {
            // Header
            HStack {
                Label("QR Generator", systemImage: "qrcode")
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

            // Text Input Field
            HStack {
                TextField("Enter text, URL or message...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                    .onChange(of: inputText) {
                        generateQR()
                    }

                if let ssid = wifi.ssid, !ssid.isEmpty {
                    Button(action: {
                        inputText = "WIFI:S:\(ssid);T:WPA;P:;; "
                        generateQR()
                    }) {
                        Label("WiFi", systemImage: "wifi")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: p.primary.hex))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: p.primaryContainer.hex))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(hex: p.surfaceContainerHigh.hex))
            .cornerRadius(12)

            // QR Code Image Preview
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .frame(width: 200, height: 200)

                if let img = qrImage {
                    Image(nsImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                } else {
                    ProgressView()
                }
            }
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: copyImage) {
                    Label("Copy QR Image", systemImage: "doc.on.doc.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: p.onPrimary.hex))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: p.primary.hex))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button(action: saveImage) {
                    Label("Save PNG", systemImage: "square.and.arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: p.surfaceVariant.hex))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 380)
        .background(Color(hex: p.surface.hex))
        .cornerRadius(26)
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color(hex: p.outlineVariant.hex).opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 12)
        .onAppear {
            generateQR()
        }
    }

    private func generateQR() {
        guard !inputText.isEmpty else { return }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(inputText.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return }

        // Scale up sharp
        let rep = NSCIImageRep(ciImage: output)
        let nsImg = NSImage(size: NSSize(width: 200, height: 200))
        nsImg.addRepresentation(rep)
        self.qrImage = nsImg
    }

    private func copyImage() {
        guard let img = qrImage else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([img])
        ToastCenter.shared.show(icon: "qrcode", message: "QR Code copied to clipboard")
    }

    private func saveImage() {
        guard let img = qrImage,
              let tiff = img.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }

        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let dest = downloads.appendingPathComponent("dms-qr-\(Int(Date().timeIntervalSince1970)).png")
        try? png.write(to: dest)
        ToastCenter.shared.show(icon: "arrow.down.circle.fill", message: "Saved to Downloads")
    }
}
