import SwiftUI
import DMSCore

/// Overview tab: two-column compact layout — hero device card on the left,
/// storage overview with numeric breakdown and content counts on the right.
public struct NokiaDeviceHeroView: View {
    public let palette: DMSPalette
    public let device: SymbianDevice?
    public let breakdown: SymbianStorageBreakdown?
    public let onSyncMusic: () -> Void
    public let onInstallApp: () -> Void

    @ObservedObject var syncService = SymbianSyncService.shared

    public init(
        palette: DMSPalette,
        device: SymbianDevice?,
        breakdown: SymbianStorageBreakdown?,
        onSyncMusic: @escaping () -> Void,
        onInstallApp: @escaping () -> Void
    ) {
        self.palette = palette
        self.device = device
        self.breakdown = breakdown
        self.onSyncMusic = onSyncMusic
        self.onInstallApp = onInstallApp
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            heroCard
                .frame(width: 232)
                .frame(maxHeight: .infinity, alignment: .top)

            storageSection(device: device)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Hero Device Card (left column)

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Nokia C7 product photo (bundled real image, CC BY-SA 3.0 — see Resources/NokiaC7-Photo-Attribution.txt)
            HStack {
                Spacer()
                ZStack {
                    if let img = NokiaDeviceAssets.c7Image {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 54, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(Color(hex: palette.outlineVariant.hex), lineWidth: 1.5)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color(hex: palette.surfaceContainerHighest.hex))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(Color(hex: palette.outlineVariant.hex), lineWidth: 1.5)
                            )
                            .frame(width: 54, height: 88)
                    }
                }
                .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 2)
                Spacer()
            }

            HStack(spacing: 6) {
                Text(device?.name ?? "Nokia C7-00")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                    .lineLimit(1)

                if device != nil {
                    Text("USB")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Color(hex: palette.primary.hex))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: palette.primaryContainer.hex))
                        .cornerRadius(4)
                }
            }

            Text(device?.osVersion ?? "Nokia Belle Refresh (Symbian OS v9.5)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                .lineLimit(2)

            // Hardware Specs pills (2x2 grid)
            let pillColumns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
            LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 4) {
                specPill(label: "Drive \(device?.driveLetter ?? "E:")", icon: "internaldrive")
                specPill(label: "8GB Mass Memory", icon: "memorychip")
                specPill(label: "3.5\" AMOLED", icon: "display")
                specPill(label: "USB 2.0 High Speed", icon: "cable.connector")
            }

            Spacer(minLength: 2)

            // Quick Action Buttons (stacked, full width)
            VStack(spacing: 5) {
                Button(action: onSyncMusic) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                        Text("Sync MP3s")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Color(hex: palette.onPrimary.hex))
                    .padding(.vertical, 5)
                    .background(Color(hex: palette.primary.hex))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: onInstallApp) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Install SISX")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Color(hex: palette.onSecondaryContainer.hex))
                    .padding(.vertical, 5)
                    .background(Color(hex: palette.secondaryContainer.hex))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(hex: palette.surfaceContainerLow.hex))
        .cornerRadius(10)
    }

    private func specPill(label: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color(hex: palette.surfaceContainerHighest.hex))
        .foregroundColor(Color(hex: palette.outline.hex))
        .cornerRadius(4)
    }

    // MARK: - Storage Overview (right column)

    private func storageSection(device: SymbianDevice?) -> some View {
        let bd = breakdown ?? (device.map { SymbianStorageBreakdown(freeBytes: $0.freeBytes, totalBytes: max(1, $0.totalBytes)) })
        let total = max(1.0, Double(bd?.totalBytes ?? 1))
        let usedPct = device.map { Int($0.usedPercentage * 100) } ?? 0
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("STORAGE OVERVIEW")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: palette.outline.hex))

                Spacer()

                if let dev = device {
                    Text("\(usedPct)% used — \(dev.formattedFreeSpace) free of \(dev.formattedTotalSpace)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                } else {
                    Text("No device connected")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color.orange)
                }
            }

            // Segmented Storage Bar
            GeometryReader { geo in
                let w = max(10.0, geo.size.width)
                let musicW: Double = bd.map { max(0.0, min(w * 0.45, w * Double($0.musicBytes) / total)) } ?? 0.0
                let appsW: Double = bd.map { max(0.0, min(w * 0.3, w * Double($0.appsBytes) / total)) } ?? 0.0
                let mediaW: Double = bd.map { max(0.0, min(w * 0.3, w * Double($0.mediaBytes) / total)) } ?? 0.0
                let sysW: Double = bd.map { max(0.0, min(w * 0.25, w * Double($0.systemBytes) / total)) } ?? 0.0
                let otherW: Double = bd.map { max(0.0, min(w * 0.2, w * Double($0.otherBytes) / total)) } ?? 0.0

                HStack(spacing: 2) {
                    if musicW > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.purple)
                            .frame(width: musicW)
                    }
                    if appsW > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue)
                            .frame(width: appsW)
                    }
                    if mediaW > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange)
                            .frame(width: mediaW)
                    }
                    if sysW > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray)
                            .frame(width: sysW)
                    }
                    if otherW > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.teal)
                            .frame(width: otherW)
                    }
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: palette.surfaceContainerHighest.hex))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 8)
            .cornerRadius(4)

            // Numeric Storage Legend (label + formatted size per category)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 3) {
                legendItem(label: "Music", bytes: bd?.musicBytes, color: Color.purple)
                legendItem(label: "Apps (SISX)", bytes: bd?.appsBytes, color: Color.blue)
                legendItem(label: "Photos & Video", bytes: bd?.mediaBytes, color: Color.orange)
                legendItem(label: "System", bytes: bd?.systemBytes, color: Color.gray)
                legendItem(label: "Other", bytes: bd?.otherBytes, color: Color.teal)
                legendItem(label: "Free", bytes: bd?.freeBytes, color: Color(hex: palette.surfaceContainerHighest.hex))
            }

            Spacer(minLength: 2)

            // Content counts (real device info: tracks on phone, apps staged)
            HStack(spacing: 12) {
                countItem(icon: "music.note", text: "\(syncService.deviceTracks.count) tracks on phone")
                countItem(icon: "shippingbox.fill", text: "\(syncService.stagedPackages.count) apps staged")
                Spacer()
            }
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
        }
        .padding(9)
        .background(Color(hex: palette.surfaceContainerLow.hex))
        .cornerRadius(10)
    }

    private func countItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(Color(hex: palette.primary.hex))
            Text(text)
        }
    }

    private func legendItem(label: String, bytes: Int64?, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Color(hex: palette.outline.hex))
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(bytes.map { Self.formatBytes($0) } ?? "—")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
