import SwiftUI
import DMSCore

/// Visual presentation card showing the Nokia C7 product photo, Symbian Belle specifications, and storage breakdown.
public struct NokiaDeviceHeroView: View {
    public let palette: DMSPalette
    public let device: SymbianDevice?
    public let breakdown: SymbianStorageBreakdown?
    public let onSyncMusic: () -> Void
    public let onInstallApp: () -> Void

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
        VStack(spacing: 12) {
            // Hero Device Card
            HStack(spacing: 16) {
                // Nokia C7 product photo (bundled real image, CC BY-SA 3.0 — see Resources/NokiaC7-Photo-Attribution.txt)
                ZStack {
                    if let img = NokiaDeviceAssets.c7Image {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: palette.outlineVariant.hex), lineWidth: 1.5)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(hex: palette.surfaceContainerHighest.hex))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: palette.outlineVariant.hex), lineWidth: 1.5)
                            )
                            .frame(width: 80, height: 130)
                    }
                }
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)

                // Device Specifications & Details
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(device?.name ?? "Nokia C7-00")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: palette.onSurface.hex))

                        if device != nil {
                            Text("USB MASS STORAGE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color(hex: palette.primary.hex))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: palette.primaryContainer.hex))
                                .cornerRadius(4)
                        }
                    }

                    Text(device?.osVersion ?? "Nokia Belle Refresh (Symbian OS v9.5)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))

                    // Hardware Specs pills
                    HStack(spacing: 5) {
                        specPill(label: "Drive \(device?.driveLetter ?? "E:")", icon: "internaldrive")
                        specPill(label: "8GB Mass Memory", icon: "memorychip")
                        specPill(label: "3.5\" AMOLED", icon: "display")
                        specPill(label: "USB 2.0 High Speed", icon: "cable.connector")
                    }
                    .padding(.top, 2)

                    // Quick Action Buttons
                    HStack(spacing: 8) {
                        Button(action: onSyncMusic) {
                            HStack(spacing: 4) {
                                Image(systemName: "music.note.list")
                                Text("Sync MP3s")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: palette.onPrimary.hex))
                            .padding(.horizontal, 10)
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
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: palette.onSecondaryContainer.hex))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: palette.secondaryContainer.hex))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
            .padding(12)
            .background(Color(hex: palette.surfaceContainerLow.hex))
            .cornerRadius(12)

            // Storage Breakdown Bar
            if let dev = device {
                storageSection(device: dev)
            }
        }
    }

    private func specPill(label: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(label)
                .font(.system(size: 8, weight: .medium))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color(hex: palette.surfaceContainerHighest.hex))
        .foregroundColor(Color(hex: palette.outline.hex))
        .cornerRadius(4)
    }

    private func storageSection(device: SymbianDevice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("STORAGE BREAKDOWN")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: palette.outline.hex))

                Spacer()

                Text("\(device.formattedFreeSpace) / \(device.formattedTotalSpace)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
            }

            // Segmented Storage Bar
            GeometryReader { geo in
                let w = max(10.0, geo.size.width)
                let bd = breakdown ?? SymbianStorageBreakdown(
                    freeBytes: device.freeBytes,
                    totalBytes: max(1, device.totalBytes)
                )
                let total = max(1.0, Double(bd.totalBytes))
                let musicW = max(0.0, min(w * 0.45, w * Double(bd.musicBytes) / total))
                let appsW = max(0.0, min(w * 0.3, w * Double(bd.appsBytes) / total))
                let mediaW = max(0.0, min(w * 0.3, w * Double(bd.mediaBytes) / total))
                let sysW = max(0.0, min(w * 0.25, w * Double(bd.systemBytes) / total))

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
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: palette.surfaceContainerHighest.hex))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 8)
            .cornerRadius(4)

            // Storage Legend
            HStack(spacing: 12) {
                legendItem(label: "Music", color: Color.purple)
                legendItem(label: "Apps (SISX)", color: Color.blue)
                legendItem(label: "Photos & Video", color: Color.orange)
                legendItem(label: "System", color: Color.gray)
                legendItem(label: "Free Space", color: Color(hex: palette.surfaceContainerHighest.hex))
            }
            .font(.system(size: 9))
            .foregroundColor(Color(hex: palette.outline.hex))
        }
        .padding(10)
        .background(Color(hex: palette.surfaceContainerLow.hex))
        .cornerRadius(10)
    }

    private func legendItem(label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
    }
}
