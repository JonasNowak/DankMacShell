import SwiftUI
import AppKit
import DMSCore

/// View for inspecting, preparing, and staging Symbian SIS, SISX, JAR, and WGZ applications onto the Nokia C7.
public struct SymbianAppInstallTab: View {
    public let palette: DMSPalette
    @ObservedObject var syncService = SymbianSyncService.shared

    @State private var stagedPreview: SymbianAppPackage?
    @State private var isTargetedForDrop: Bool = false
    @State private var isCopying: Bool = false

    public init(palette: DMSPalette) {
        self.palette = palette
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Drag and Drop Zone
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isTargetedForDrop ? Color(hex: palette.primary.hex) : Color(hex: palette.outlineVariant.hex),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                    .background(isTargetedForDrop ? Color(hex: palette.primaryContainer.hex).opacity(0.15) : Color(hex: palette.surfaceContainerLow.hex))

                VStack(spacing: 6) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: palette.primary.hex))

                    Text("Drag & Drop Symbian Packages Here")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: palette.onSurface.hex))

                    Text("Supports .sisx (Belle Native), .sis (Symbian), .jar (Java ME), .wgz (Widgets)")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: palette.outline.hex))

                    Button(action: pickPackageFile) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.badge.plus")
                            Text("Choose Package...")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: palette.onPrimary.hex))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: palette.primary.hex))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(14)
            }
            .frame(height: 92)
            .onDrop(of: ["public.file-url"], isTargeted: $isTargetedForDrop) { providers in
                handleDrop(providers: providers)
            }

            // Staging Preview Card (if file was dropped or selected)
            if let preview = stagedPreview {
                packagePreviewCard(package: preview)
            }

            // Staged Packages on Nokia C7
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("PACKAGES READY FOR INSTALL ON NOKIA C7 (DRIVE \(syncService.activeDevice?.driveLetter ?? "E:")\\INSTALLS)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: palette.outline.hex))

                    Spacer()

                    Text("\(syncService.stagedPackages.count) staged")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                }

                if syncService.stagedPackages.isEmpty {
                    VStack(spacing: 4) {
                        Text("No packages currently waiting in Drive \(syncService.activeDevice?.driveLetter ?? "E:")\\Installs.")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: palette.outline.hex))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color(hex: palette.surfaceContainerLow.hex))
                    .cornerRadius(8)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(syncService.stagedPackages) { pkg in
                                stagedRow(package: pkg)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                    .background(Color(hex: palette.surfaceContainerLowest.hex))
                    .cornerRadius(8)
                }
            }

            // How-to-Install Instruction Banner
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: palette.primary.hex))

                VStack(alignment: .leading, spacing: 2) {
                    Text("How to Install on Symbian Belle:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: palette.onSurface.hex))

                    Text("After staging, unplug the USB cable or toggle mode. On your Nokia C7 screen, open Menu > Applications > Office > File Manager > Drive E: > Installs and tap the app to start Nokia Belle's installer.")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(8)
            .background(Color(hex: palette.surfaceContainerLow.hex))
            .cornerRadius(8)
        }
    }

    private func packagePreviewCard(package: SymbianAppPackage) -> some View {
        HStack(spacing: 12) {
            Image(systemName: package.packageType.icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: palette.primary.hex))
                .frame(width: 32, height: 32)
                .background(Color(hex: palette.primaryContainer.hex))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(package.appName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: palette.onSurface.hex))

                    Text(package.version)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(hex: palette.surfaceContainerHighest.hex))
                        .cornerRadius(3)

                    Text(package.packageType.rawValue.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(hex: palette.secondary.hex))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(hex: palette.secondaryContainer.hex))
                        .cornerRadius(3)
                }

                HStack(spacing: 6) {
                    Text(package.targetPlatform)
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: palette.outline.hex))

                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: palette.outline.hex))

                    Text("UID: \(package.uid)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: palette.outline.hex))

                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: palette.outline.hex))

                    Text(package.formattedSize)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: palette.outline.hex))
                }
            }

            Spacer()

            Button(action: stageCurrentPreview) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line")
                    Text("Stage onto Nokia C7")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: palette.onPrimary.hex))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(syncService.activeDevice == nil ? Color(hex: palette.outline.hex) : Color(hex: palette.primary.hex))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(syncService.activeDevice == nil || isCopying)
        }
        .padding(10)
        .background(Color(hex: palette.surfaceContainerHighest.hex).opacity(0.35))
        .cornerRadius(8)
    }

    private func stagedRow(package: SymbianAppPackage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: package.packageType.icon)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: palette.primary.hex))
                .frame(width: 22, height: 22)
                .background(Color(hex: palette.surfaceContainerLow.hex))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(package.appName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                        .lineLimit(1)

                    Text(package.version)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Color(hex: palette.outline.hex))
                }

                Text("\(package.fileName) · UID \(package.uid) · \(package.formattedSize)")
                    .font(.system(size: 8))
                    .foregroundColor(Color(hex: palette.outline.hex))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { syncService.removeStagedPackage(package) }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(Color.red.opacity(0.8))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(hex: palette.surfaceContainerLow.hex))
        .cornerRadius(6)
    }

    private func pickPackageFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Package"

        if panel.runModal() == .OK, let url = panel.url {
            let parsed = SymbianSISParser.parse(url: url)
            self.stagedPreview = parsed
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in
                let parsed = SymbianSISParser.parse(url: url)
                self.stagedPreview = parsed
            }
        }
        return true
    }

    private func stageCurrentPreview() {
        guard let preview = stagedPreview else { return }
        isCopying = true
        let url = URL(fileURLWithPath: preview.filePath)
        Task {
            _ = try? await syncService.stagePackage(from: url)
            await MainActor.run {
                self.isCopying = false
                self.stagedPreview = nil
            }
        }
    }
}
