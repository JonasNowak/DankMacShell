import SwiftUI
import DMSCore

/// Main application view for the Nokia Belle USB Sync companion application.
public struct SymbianSyncView: View {
    @ObservedObject var themeStore = SymbianThemeStore.shared
    @ObservedObject var syncService = SymbianSyncService.shared
    public let onClose: () -> Void

    @State private var currentTab: SyncTab = .overview

    public enum SyncTab: String, CaseIterable {
        case overview = "Device Overview"
        case music = "MP3 Sync"
        case apps = "App Installer"
        case storage = "Storage & Tools"

        public var icon: String {
            switch self {
            case .overview: return "phone.fill"
            case .music: return "music.note.list"
            case .apps: return "shippingbox.fill"
            case .storage: return "internaldrive.fill"
            }
        }
    }

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        let palette = themeStore.palette

        VStack(spacing: 0) {
            // App Header Bar
            headerBar(palette: palette)

            Divider().opacity(0.3)

            // Segmented Tab Picker
            tabPicker(palette: palette)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // Feedback Banner (if any)
            if let feedback = syncService.userToastMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.green)
                    Text(feedback)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .cornerRadius(6)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }

            // Tab Content
            VStack {
                switch currentTab {
                case .overview:
                    NokiaDeviceHeroView(
                        palette: palette,
                        device: syncService.activeDevice,
                        breakdown: syncService.storageBreakdown,
                        onSyncMusic: { currentTab = .music },
                        onInstallApp: { currentTab = .apps }
                    )
                case .music:
                    SymbianMusicSyncTab(palette: palette)
                case .apps:
                    SymbianAppInstallTab(palette: palette)
                case .storage:
                    SymbianStorageExplorerTab(palette: palette)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.3)

            // Footer
            footerBar(palette: palette)
        }
        .frame(width: 720, height: 560)
        .background(Color(hex: palette.surface.hex))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: palette.outlineVariant.hex).opacity(0.5), lineWidth: 1)
        )
    }

    private func headerBar(palette: DMSPalette) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "phone.and.waveform")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: palette.primary.hex))

            VStack(alignment: .leading, spacing: 1) {
                Text("Nokia Belle USB Sync")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: palette.onSurface.hex))

                Text("Symbian Belle • Nokia C7 Companion")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: palette.outline.hex))
            }

            Spacer()

            // Device Selector (if multiple drives/devices connected)
            if !syncService.connectedDevices.isEmpty {
                Menu {
                    ForEach(syncService.connectedDevices) { dev in
                        Button(action: { syncService.activeDevice = dev }) {
                            Text("\(dev.name) (\(dev.driveLetter) \(dev.volumeName))")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text(syncService.activeDevice?.name ?? "Nokia Device")
                            .font(.system(size: 10, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: palette.surfaceContainerLow.hex))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
            } else {
                HStack(spacing: 4) {
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                    Text("No Device Detected")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }

            // Safely Eject button
            if syncService.activeDevice != nil {
                Button(action: { syncService.ejectActiveDevice() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "eject.fill")
                        Text("Eject")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: palette.surfaceContainerLow.hex))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                    .frame(width: 24, height: 24)
                    .background(Color(hex: palette.surfaceContainerLow.hex))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func tabPicker(palette: DMSPalette) -> some View {
        HStack(spacing: 6) {
            ForEach(SyncTab.allCases, id: \.self) { tab in
                let isSelected = currentTab == tab
                Button(action: { currentTab = tab }) {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    }
                    .foregroundColor(isSelected ? Color(hex: palette.onPrimary.hex) : Color(hex: palette.onSurfaceVariant.hex))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color(hex: palette.primary.hex) : Color(hex: palette.surfaceContainerLow.hex))
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func footerBar(palette: DMSPalette) -> some View {
        HStack {
            Text("Nokia C7-00 • Belle Refresh (Delight 6.4) • USB Mass Storage Mode • DankMacShell Plugin")
                .font(.system(size: 9))
                .foregroundColor(Color(hex: palette.outline.hex))

            Spacer()

            if let dev = syncService.activeDevice {
                Text("\(dev.formattedFreeSpace) / \(dev.formattedTotalSpace)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: palette.surfaceContainerLowest.hex))
    }
}
