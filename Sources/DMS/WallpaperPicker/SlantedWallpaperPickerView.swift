import SwiftUI
import AppKit
import DMSCore

/// A skwd-inspired slanted slice carousel wallpaper picker and changer for macOS.
/// Displays wallpapers as horizontal parallelogram slices with customizable skew,
/// fluid width expansion on selection, live desktop testing with cancel/reset,
/// dynamic Material 3 theme sync, and folder filtering.
public struct SlantedWallpaperPickerView: View {
    @ObservedObject var controller: SlantedWallpaperPickerController
    @ObservedObject var wallpaperService = WallpaperService.shared
    @ObservedObject var configStore = ConfigStore.shared
    @ObservedObject var themeStore = ThemeStore.shared

    public var onClose: (() -> Void)? = nil

    @State private var hoveredIndex: Int? = nil
    @State private var searchQuery: String = ""
    @State private var selectedSource: WallpaperSource = .all
    @State private var onlyFolder: Bool = false
    @FocusState private var isViewFocused: Bool

    public init(controller: SlantedWallpaperPickerController? = nil, onClose: (() -> Void)? = nil) {
        self.controller = controller ?? SlantedWallpaperPickerController.shared
        self.onClose = onClose
    }

    private var availableWallpapers: [WallpaperItem] {
        let baseList = onlyFolder ? wallpaperService.pickerWallpapers() : wallpaperService.wallpapers
        return WallpaperItem.filterWallpapers(
            items: baseList,
            source: selectedSource,
            query: searchQuery
        )
    }

    private var currentFolderDisplay: String {
        let folder = configStore.config.wallpaperPickerFolder
        if folder.isEmpty {
            return "All Folders"
        }
        return (folder as NSString).lastPathComponent
    }

    public var body: some View {
        let p = themeStore.palette
        let skew = CGFloat(configStore.config.wallpaperPickerSkew)
        let items = availableWallpapers

        VStack(spacing: 0) {
            // MARK: - Header HUD Bar
            headerBar(palette: p, count: items.count)

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.35))

            // MARK: - Slices Carousel Area
            ZStack {
                Color(hex: p.surfaceContainerLowest.hex).opacity(0.85)

                if items.isEmpty {
                    emptyStateView(palette: p)
                } else {
                    carouselView(items: items, skew: skew, palette: p)
                }
            }
            .frame(height: 420)

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.35))

            // MARK: - Footer Control Bar
            footerBar(items: items, palette: p)
        }
        .frame(width: 1120)
        .background(GlassSurfaceBackground())
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(themeStore.panelBorderColor, lineWidth: 1)
        )
        .shadow(color: themeStore.adaptiveShadowColor(baseOpacity: 0.42), radius: 30, x: 0, y: 12)
        .focusable()
        .focused($isViewFocused)
        .onAppear {
            isViewFocused = true
            onlyFolder = configStore.config.wallpaperPickerOnlyFolder
        }
        .onKeyPress(.leftArrow) {
            controller.cyclePrevious()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            controller.cycleNext()
            return .handled
        }
        .onKeyPress(.return) {
            controller.commitSelection()
            return .handled
        }
        .onKeyPress(.space) {
            controller.commitSelection()
            return .handled
        }
        .onKeyPress(KeyEquivalent("r")) {
            shuffleWallpaper(count: items.count)
            return .handled
        }
        .onKeyPress(KeyEquivalent("f")) {
            toggleFolderRestriction()
            return .handled
        }
        .onKeyPress(.escape) {
            handleCloseOrCancel()
            return .handled
        }
    }

    // MARK: - Header
    @ViewBuilder
    private func headerBar(palette: DMSPalette, count: Int) -> some View {
        HStack(spacing: 12) {
            // App / Feature Brand
            HStack(spacing: 8) {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: palette.primary.hex))

                Text("Wallpaper Switcher")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: palette.onSurface.hex))

                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: palette.surfaceContainerHigh.hex))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                    .clipShape(Capsule())
            }

            Spacer()

            // Folder Filter Pill Toggle
            Button(action: toggleFolderRestriction) {
                HStack(spacing: 6) {
                    Image(systemName: onlyFolder ? "folder.fill.badge.gearshape" : "folder.fill")
                        .font(.system(size: 11))
                    Text(onlyFolder ? "Folder: \(currentFolderDisplay)" : "All Folders")
                        .font(.system(size: 11, weight: .semibold))

                    if onlyFolder {
                        Text("Active")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(hex: palette.primary.hex))
                            .foregroundColor(Color(hex: palette.onPrimary.hex))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(onlyFolder ? Color(hex: palette.primaryContainer.hex) : Color(hex: palette.surfaceContainerHigh.hex))
                .foregroundColor(onlyFolder ? Color(hex: palette.onPrimaryContainer.hex) : Color(hex: palette.onSurfaceVariant.hex))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Toggle folder restriction (Shortcut: F)")

            // Category Filter Pills
            HStack(spacing: 4) {
                ForEach([WallpaperSource.all, .custom, .pictures, .system, .presets], id: \.self) { src in
                    let isSel = selectedSource == src
                    Button {
                        selectedSource = src
                        controller.selectedIndex = 0
                    } label: {
                        Text(src.rawValue)
                            .font(.system(size: 10, weight: isSel ? .bold : .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isSel ? Color(hex: palette.primary.hex) : Color(hex: palette.surfaceContainerLow.hex))
                            .foregroundColor(isSel ? Color(hex: palette.onPrimary.hex) : Color(hex: palette.onSurfaceVariant.hex))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Shuffle Button
            Button(action: { shuffleWallpaper(count: count) }) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: palette.surfaceContainerHigh.hex))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Shuffle / Randomize wallpaper (Shortcut: R)")

            // Close / Cancel Button
            Button(action: handleCloseOrCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: palette.surfaceContainerHigh.hex))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Reset and Close (Esc)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(themeStore.panelHeaderBackground)
    }

    // MARK: - Carousel View
    @ViewBuilder
    private func carouselView(items: [WallpaperItem], skew: CGFloat, palette: DMSPalette) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let isSelected = (index == controller.selectedIndex)
                        let isHovered = (hoveredIndex == index)

                        SlantedWallpaperSlice(
                            item: item,
                            index: index,
                            isSelected: isSelected,
                            isHovered: isHovered,
                            skew: skew,
                            palette: palette,
                            onSelect: {
                                if isSelected {
                                    controller.commitSelection()
                                } else {
                                    controller.select(index: index)
                                }
                            }
                        )
                        .id(index)
                        .onHover { hover in
                            hoveredIndex = hover ? index : nil
                        }
                    }
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 20)
            }
            .onChange(of: controller.selectedIndex) { _, newIndex in
                withAnimation(.spring(response: 0.20, dampingFraction: 0.85)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(controller.selectedIndex, anchor: .center)
            }
        }
    }

    // MARK: - Empty State
    @ViewBuilder
    private func emptyStateView(palette: DMSPalette) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: palette.outline.hex))

            Text("No Wallpapers Found")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: palette.onSurface.hex))

            if onlyFolder {
                Text("Folder restriction is active (\(currentFolderDisplay)). Disable folder filtering or add wallpaper images to this directory.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)

                Button("Disable Folder Filter") {
                    onlyFolder = false
                    configStore.update { $0.wallpaperPickerOnlyFolder = false }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 4)
            } else {
                Text("Add folders containing images in DMS Settings > Wallpaper.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
            }
        }
        .padding(24)
    }

    // MARK: - Footer Bar
    @ViewBuilder
    private func footerBar(items: [WallpaperItem], palette: DMSPalette) -> some View {
        let currentItem = items.indices.contains(controller.selectedIndex) ? items[controller.selectedIndex] : nil

        HStack(spacing: 14) {
            // Selected item details & Live Testing Tag
            if let item = currentItem {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: palette.onSurface.hex))
                            .lineLimit(1)

                        if controller.isTestingSession {
                            HStack(spacing: 3) {
                                Image(systemName: "eye.fill")
                                Text("Testing Live")
                            }
                            .font(.system(size: 10, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: palette.tertiaryContainer.hex))
                            .foregroundColor(Color(hex: palette.onTertiaryContainer.hex))
                            .clipShape(Capsule())
                        }

                        if item.isCurrentDesktop {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Current Desktop")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: palette.primary.hex))
                        }
                    }

                    Text(item.path ?? "Preset Gradient Wallpaper")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: palette.outline.hex))
                        .lineLimit(1)
                }
            } else {
                Text("Select a wallpaper to preview and apply")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: palette.outline.hex))
            }

            Spacer()

            // Folder Filter Checkbox
            Toggle("Restrict to folder", isOn: Binding(
                get: { onlyFolder },
                set: { val in
                    onlyFolder = val
                    configStore.update { $0.wallpaperPickerOnlyFolder = val }
                }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))

            // Navigation hints
            HStack(spacing: 8) {
                Text("Shortcut/Arrows Cycle")
                Text("•")
                Text("↵ Apply")
                Text("•")
                Text("Esc Reset")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(Color(hex: palette.outline.hex))

            // Reset / Cancel Button
            Button(action: handleCloseOrCancel) {
                Text("Reset")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: palette.surfaceContainerHigh.hex))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Primary Apply Button
            if currentItem != nil {
                Button {
                    controller.commitSelection()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                        Text("Apply & Keep")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: palette.primary.hex))
                    .foregroundColor(Color(hex: palette.onPrimary.hex))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(themeStore.panelHeaderBackground)
    }

    // MARK: - Actions
    private func handleCloseOrCancel() {
        if let onClose = onClose {
            onClose()
        } else {
            controller.cancelAndRevert()
        }
    }

    private func shuffleWallpaper(count: Int) {
        guard count > 0 else { return }
        var randomIdx = Int.random(in: 0..<count)
        if count > 1 && randomIdx == controller.selectedIndex {
            randomIdx = (randomIdx + 1) % count
        }
        controller.select(index: randomIdx)
    }

    private func toggleFolderRestriction() {
        onlyFolder.toggle()
        configStore.update { $0.wallpaperPickerOnlyFolder = onlyFolder }
    }
}

// MARK: - Individual Slanted Parallelogram Slice
private struct SlantedWallpaperSlice: View {
    let item: WallpaperItem
    let index: Int
    let isSelected: Bool
    let isHovered: Bool
    let skew: CGFloat
    let palette: DMSPalette
    let onSelect: () -> Void

    @State private var thumbnailImage: NSImage?

    public init(
        item: WallpaperItem,
        index: Int,
        isSelected: Bool,
        isHovered: Bool,
        skew: CGFloat,
        palette: DMSPalette,
        onSelect: @escaping () -> Void
    ) {
        self.item = item
        self.index = index
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.skew = skew
        self.palette = palette
        self.onSelect = onSelect
        // Fast synchronous memory cache lookup on initialization
        self._thumbnailImage = State(initialValue: WallpaperService.shared.cachedThumbnail(for: item))
    }

    private var cardWidth: CGFloat {
        isSelected ? 620 : 124
    }

    private let cardHeight: CGFloat = 360
    private let cornerRadius: CGFloat = 18

    var body: some View {
        let shape = SlantedParallelogramShape(skew: skew, cornerRadius: cornerRadius)

        ZStack(alignment: .bottom) {
            // 1. Wallpaper Image or Gradient Preset
            Group {
                if let thumb = thumbnailImage {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                } else if let hexes = item.gradientColorsHex, !hexes.isEmpty {
                    LinearGradient(
                        colors: hexes.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: cardWidth, height: cardHeight)
                } else {
                    Rectangle()
                        .fill(Color(hex: palette.surfaceContainerHigh.hex))
                        .frame(width: cardWidth, height: cardHeight)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                        )
                }
            }

            // 2. Vignette / Hover Darkening Overlay
            Rectangle()
                .fill(Color.black.opacity(isSelected ? 0 : (isHovered ? 0.15 : 0.42)))

            // 3. Metadata Pill Badge at Bottom
            if isSelected || isHovered {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color.white)
                            .lineLimit(1)

                        Text(item.source.rawValue.uppercased())
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(hex: palette.primary.hex))
                    }

                    if item.isCurrentDesktop {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.green)
                    }

                    Spacer()

                    if isSelected {
                        HStack(spacing: 4) {
                            Text("↵ Apply")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: palette.primary.hex))
                        .foregroundColor(Color(hex: palette.onPrimary.hex))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(shape)
        .overlay(
            shape.stroke(
                isSelected ? Color(hex: palette.primary.hex) : (isHovered ? Color(hex: palette.primary.hex).opacity(0.4) : Color.white.opacity(0.18)),
                lineWidth: isSelected ? 3.5 : 1.0
            )
        )
        .shadow(
            color: isSelected ? Color(hex: palette.primary.hex).opacity(0.55) : Color.black.opacity(0.25),
            radius: isSelected ? 14 : 6,
            x: isSelected ? 4 : 2,
            y: isSelected ? 8 : 4
        )
        .zIndex(isSelected ? 100 : (isHovered ? 50 : Double(10 - index % 10)))
        .contentShape(shape)
        .onTapGesture {
            onSelect()
        }
        .task {
            if item.path != nil, thumbnailImage == nil {
                thumbnailImage = await WallpaperService.shared.thumbnail(for: item)
            }
        }
    }
}
