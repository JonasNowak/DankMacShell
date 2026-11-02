import SwiftUI
import AppKit
import DMSCore

/// Wallpaper gallery tab allowing live local browsing, thumbnail caching, folder additions, and desktop wallpaper application.
public struct WallpapersTab: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var wallpaperService = WallpaperService.shared

    @State private var selectedWallpaper: WallpaperItem?
    @State private var selectedSource: WallpaperSource = .all
    @State private var searchQuery: String = ""

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let filtered = WallpaperItem.filterWallpapers(
            items: wallpaperService.wallpapers,
            source: selectedSource,
            query: searchQuery
        )
        let currentSelection = selectedWallpaper ?? filtered.first ?? WallpaperItem.defaultPresets[0]

        VStack(spacing: 12) {
            // Category Filter Pills & Actions
            HStack(spacing: 8) {
                // Source Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(WallpaperSource.allCases) { src in
                            Button(action: { selectedSource = src }) {
                                Text(src.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(selectedSource == src ? Color(hex: p.primary.hex) : Color(hex: p.surfaceContainerHigh.hex))
                                    .foregroundColor(selectedSource == src ? Color(hex: p.onPrimary.hex) : Color(hex: p.onSurface.hex))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()

                // Add Folder Button
                Button(action: pickFolder) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                        Text("Add Folder…")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: p.surfaceContainerHighest.hex))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Apply Wallpaper Button
                Button(action: {
                    wallpaperService.applyWallpaper(currentSelection)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Apply Wallpaper")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color(hex: p.primary.hex))
                    .foregroundColor(Color(hex: p.onPrimary.hex))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Search Bar & Scan Indicator
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: p.outline.hex))
                    TextField("Search wallpapers…", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(hex: p.surfaceContainerLow.hex))
                .cornerRadius(8)

                if wallpaperService.isScanning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                }

                Text("\(filtered.count) wallpapers")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
            }

            // Wallpaper Grid
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(filtered) { wp in
                        let isSelected = (wp.id == currentSelection.id)
                        let isActiveDesktop = wp.isCurrentDesktop || (!wallpaperService.currentDesktopPath.isEmpty && wp.path == wallpaperService.currentDesktopPath)

                        Button(action: { selectedWallpaper = wp }) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    // Wallpaper Thumbnail or Gradient
                                    WallpaperCardPreview(item: wp, palette: p)
                                        .frame(height: 84)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                    // Active Desktop or Selected Checkmark
                                    if isActiveDesktop {
                                        HStack(spacing: 3) {
                                            Image(systemName: "desktopcomputer")
                                                .font(.system(size: 8, weight: .bold))
                                            Text("Active")
                                                .font(.system(size: 8, weight: .bold))
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2.5)
                                        .background(Color.black.opacity(0.65))
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                        .padding(5)
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isSelected ? Color(hex: p.primary.hex) : Color.clear, lineWidth: 2.5)
                                )

                                HStack {
                                    Text(wp.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color(hex: p.onSurface.hex))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(wp.source.rawValue)
                                        .font(.system(size: 9))
                                        .foregroundColor(Color(hex: p.outline.hex))
                                }
                                .padding(.horizontal, 2)
                            }
                            .padding(6)
                            .background(Color(hex: p.surfaceContainerHigh.hex))
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Select a folder containing wallpaper images"

        if panel.runModal() == .OK, let url = panel.url {
            wallpaperService.addFolder(path: url.path)
        }
    }
}

/// Preview component for a single wallpaper tile (downsampled image or gradient).
private struct WallpaperCardPreview: View {
    let item: WallpaperItem
    let palette: DMSPalette

    @State private var thumbnailImage: NSImage?
    @State private var isLoading: Bool = false

    var body: some View {
        ZStack {
            if let img = thumbnailImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let hexes = item.gradientColorsHex, !hexes.isEmpty {
                LinearGradient(
                    colors: hexes.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color(hex: palette.surfaceContainerHighest.hex)
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    Image(systemName: "photo")
                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                }
            }
        }
        .task(id: item.id) {
            guard item.path != nil else { return }
            isLoading = true
            let img = await WallpaperService.shared.thumbnail(for: item)
            self.thumbnailImage = img
            self.isLoading = false
        }
    }
}
