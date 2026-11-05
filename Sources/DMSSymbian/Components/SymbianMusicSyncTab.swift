import SwiftUI
import AppKit
import DMSCore

/// Dedicated view for managing, previewing, and synchronizing MP3 audio files to the Nokia C7 / Symbian Belle device.
public struct SymbianMusicSyncTab: View {
    public let palette: DMSPalette
    @ObservedObject var syncService = SymbianSyncService.shared

    @State private var searchQuery: String = ""
    @State private var selectedTrackIDs: Set<String> = []
    @State private var autoOrganize: Bool = true
    @State private var generatePlaylist: Bool = true
    @State private var cleanDotfiles: Bool = true
    @State private var viewMode: MusicViewMode = .macLibrary

    private enum MusicViewMode: String, CaseIterable {
        case macLibrary = "Mac Music"
        case phoneLibrary = "On Nokia C7"
    }

    public init(palette: DMSPalette) {
        self.palette = palette
    }

    private var filteredLocalTracks: [SymbianTrack] {
        if searchQuery.isEmpty { return syncService.localTracks }
        return syncService.localTracks.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery) ||
            $0.artist.localizedCaseInsensitiveContains(searchQuery) ||
            $0.album.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private var filteredDeviceTracks: [SymbianTrack] {
        if searchQuery.isEmpty { return syncService.deviceTracks }
        return syncService.deviceTracks.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery) ||
            $0.artist.localizedCaseInsensitiveContains(searchQuery) ||
            $0.album.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Control Header
            HStack(spacing: 8) {
                // View Mode Picker (Mac vs Phone)
                Picker("", selection: $viewMode) {
                    ForEach(MusicViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)

                // Search Bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: palette.outline.hex))
                    TextField("Search title, artist, or album...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: palette.outline.hex))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(hex: palette.surfaceContainerLow.hex))
                .cornerRadius(7)

                // Pick folder button
                Button(action: pickLocalMusicFolder) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                        Text("Choose Folder")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: palette.primary.hex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(hex: palette.surfaceContainerLow.hex))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // Refresh button
                Button(action: {
                    syncService.scanLocalMusic()
                    if let dev = syncService.activeDevice {
                        syncService.refreshActiveDeviceData(dev)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                        .frame(width: 26, height: 26)
                        .background(Color(hex: palette.surfaceContainerLow.hex))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Sync Options Toolbar
            if viewMode == .macLibrary {
                HStack(spacing: 12) {
                    Button(action: selectAllTracks) {
                        Text("Select All (\(filteredLocalTracks.count))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: palette.primary.hex))
                    }
                    .buttonStyle(.plain)

                    Button(action: { selectedTrackIDs.removeAll() }) {
                        Text("Deselect All")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: palette.outline.hex))
                    }
                    .buttonStyle(.plain)

                    Button(action: selectUnsyncedTracks) {
                        Text("Select Unsynced")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: palette.secondary.hex))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Toggle("Organize Folders", isOn: $autoOrganize)
                        .font(.system(size: 9))
                        .toggleStyle(.checkbox)

                    Toggle("M3U Playlist", isOn: $generatePlaylist)
                        .font(.system(size: 9))
                        .toggleStyle(.checkbox)

                    Toggle("Clean Dotfiles", isOn: $cleanDotfiles)
                        .font(.system(size: 9))
                        .toggleStyle(.checkbox)
                }
                .padding(.horizontal, 4)
            }

            // Sync Progress Banner (when active)
            if syncService.isSyncing {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                        Text(syncService.syncStatusMessage)
                            .font(.system(size: 10, weight: .semibold))
                        Spacer()
                        Text("\(Int(syncService.syncProgress * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(Color(hex: palette.onPrimaryContainer.hex))

                    ProgressView(value: syncService.syncProgress)
                        .progressViewStyle(.linear)
                }
                .padding(8)
                .background(Color(hex: palette.primaryContainer.hex))
                .cornerRadius(8)
            }

            // Track List Table
            ScrollView {
                LazyVStack(spacing: 4) {
                    if viewMode == .macLibrary {
                        if filteredLocalTracks.isEmpty {
                            emptyState(message: syncService.isScanningLocal ? "Scanning local music..." : "No local tracks found in ~/Music. Click 'Choose Folder' to pick your MP3 collection.")
                        } else {
                            ForEach(filteredLocalTracks) { track in
                                trackRow(track: track, isDeviceTrack: false)
                            }
                        }
                    } else {
                        if filteredDeviceTracks.isEmpty {
                            emptyState(message: "No music tracks detected on Nokia C7 (Drive \(syncService.activeDevice?.driveLetter ?? "E:")/Music).")
                        } else {
                            ForEach(filteredDeviceTracks) { track in
                                trackRow(track: track, isDeviceTrack: true)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .background(Color(hex: palette.surfaceContainerLowest.hex))
            .cornerRadius(8)

            // Bottom Sync Action Bar (Mac mode)
            if viewMode == .macLibrary {
                HStack {
                    Text("\(selectedTrackIDs.count) tracks selected")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))

                    Spacer()

                    Button(action: startSync) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Sync to Nokia C7 (\(selectedTrackIDs.count))")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: palette.onPrimary.hex))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selectedTrackIDs.isEmpty || syncService.activeDevice == nil ? Color(hex: palette.outline.hex) : Color(hex: palette.primary.hex))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedTrackIDs.isEmpty || syncService.activeDevice == nil || syncService.isSyncing)
                }
                .padding(.top, 4)
            }
        }
    }

    private func trackRow(track: SymbianTrack, isDeviceTrack: Bool) -> some View {
        let isSelected = selectedTrackIDs.contains(track.id)

        return HStack(spacing: 8) {
            if !isDeviceTrack {
                Button(action: {
                    if isSelected {
                        selectedTrackIDs.remove(track.id)
                    } else {
                        selectedTrackIDs.insert(track.id)
                    }
                }) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 13))
                        .foregroundColor(isSelected ? Color(hex: palette.primary.hex) : Color(hex: palette.outline.hex))
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "music.note")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: palette.primary.hex))
                .frame(width: 22, height: 22)
                .background(Color(hex: palette.surfaceContainerLow.hex))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(track.artist)
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: palette.outline.hex))
                    Text(track.album)
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: palette.outline.hex))
                        .lineLimit(1)
                }
            }

            Spacer()

            if !isDeviceTrack {
                if track.isSyncedToDevice {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("On Phone")
                    }
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Color.green)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(4)
                }
            }

            Text(track.formattedDuration)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: palette.outline.hex))

            Text(track.formattedSize)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(hex: palette.outline.hex))
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isSelected ? Color(hex: palette.primaryContainer.hex).opacity(0.3) : Color(hex: palette.surfaceContainerLow.hex))
        .cornerRadius(6)
    }

    private func emptyState(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.tv")
                .font(.system(size: 24))
                .foregroundColor(Color(hex: palette.outline.hex))
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }

    private func selectAllTracks() {
        for t in filteredLocalTracks {
            selectedTrackIDs.insert(t.id)
        }
    }

    private func selectUnsyncedTracks() {
        selectedTrackIDs.removeAll()
        for t in filteredLocalTracks where !t.isSyncedToDevice {
            selectedTrackIDs.insert(t.id)
        }
    }

    private func pickLocalMusicFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Music Folder"

        if panel.runModal() == .OK, let url = panel.url {
            syncService.scanLocalMusic(from: url)
        }
    }

    private func startSync() {
        let tracksToSync = syncService.localTracks.filter { selectedTrackIDs.contains($0.id) }
        Task {
            _ = await syncService.syncTracks(
                tracks: tracksToSync,
                autoOrganize: autoOrganize,
                generatePlaylist: generatePlaylist,
                cleanDotfiles: cleanDotfiles
            )
        }
    }
}
