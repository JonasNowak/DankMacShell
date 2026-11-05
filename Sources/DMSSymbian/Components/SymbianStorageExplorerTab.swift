import SwiftUI
import AppKit
import DMSCore

/// View providing storage diagnostics, directory navigation, and macOS dotfile cleanup for Symbian Belle volumes.
public struct SymbianStorageExplorerTab: View {
    public let palette: DMSPalette
    @ObservedObject var syncService = SymbianSyncService.shared

    @State private var showSystemFolders: Bool = false

    public init(palette: DMSPalette) {
        self.palette = palette
    }

    private var directoryItems: [(name: String, icon: String, isSystem: Bool)] {
        [
            ("Music", "music.note", false),
            ("Installs", "shippingbox.fill", false),
            ("Images", "photo.on.rectangle", false),
            ("Videos", "film", false),
            ("cities", "map.fill", false),
            ("Data", "folder.fill", false),
            ("Others", "folder", false),
            ("private", "lock.shield", true),
            ("sys", "gearshape.2.fill", true),
            ("resource", "puzzlepiece", true),
            ("system", "wrench.and.screwdriver", true)
        ]
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Maintenance Toolbar
            HStack(spacing: 8) {
                Button(action: { syncService.cleanDeviceDotfiles() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Clean macOS Dotfiles (._*)")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: palette.primary.hex))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: palette.primaryContainer.hex))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: openDriveInFinder) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app")
                        Text("Open Drive in Finder")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(hex: palette.surfaceContainerLow.hex))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                Toggle("Show System Folders", isOn: $showSystemFolders)
                    .font(.system(size: 9))
                    .toggleStyle(.checkbox)
            }

            // Directory Table
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(directoryItems.filter { !($0.isSystem && !showSystemFolders) }, id: \.name) { item in
                        folderRow(name: item.name, icon: item.icon, isSystem: item.isSystem)
                    }
                }
                .padding(.vertical, 2)
            }
            .background(Color(hex: palette.surfaceContainerLowest.hex))
            .cornerRadius(8)

            // Explanatory note
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: palette.outline.hex))

                Text("Symbian OS uses FAT32 formatting. macOS automatically writes hidden AppleDouble '._*' files which can cause corrupt entries in Symbian's Music Player and Photo Gallery. The 'Clean' tool removes them instantly.")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: palette.outline.hex))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
        }
    }

    private func folderRow(name: String, icon: String, isSystem: Bool) -> some View {
        let mountPath = syncService.activeDevice?.mountPath ?? ""
        let folderURL = URL(fileURLWithPath: mountPath).appendingPathComponent(name)
        let exists = !mountPath.isEmpty && FileManager.default.fileExists(atPath: folderURL.path)

        return HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(isSystem ? Color(hex: palette.outline.hex) : Color(hex: palette.primary.hex))
                .frame(width: 22, height: 22)
                .background(Color(hex: palette.surfaceContainerLow.hex))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: palette.onSurface.hex))

                    if isSystem {
                        Text("SYSTEM")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Color(hex: palette.error.hex))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color(hex: palette.errorContainer.hex))
                            .cornerRadius(2)
                    }
                }

                Text(exists ? "Present on Drive \(syncService.activeDevice?.driveLetter ?? "E:")" : "Not created")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: palette.outline.hex))
            }

            Spacer()

            if exists {
                Text("Ready")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.green)
            } else {
                Text("Empty")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: palette.outline.hex))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(hex: palette.surfaceContainerLow.hex))
        .cornerRadius(6)
    }

    private func openDriveInFinder() {
        guard let path = syncService.activeDevice?.mountPath else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
