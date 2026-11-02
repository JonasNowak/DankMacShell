import SwiftUI
import AppKit
import Combine
import DMSCore

/// Navigation state for Control Center detail subpages.
public enum ControlCenterPage: Equatable {
    case root
    case network
    case bluetooth
    case audio
    case battery
    case doNotDisturb
    case idleInhibitor
}

/// Control Center master dashboard implementing dynamic 2D grid bin-packing (`GridPackingSolver`),
/// interactive drag-and-drop customization, tile library sheet, 50-step undo/redo stack, 12 geometric
/// avatar shapes, and deep hardware detail subpages.
public struct ControlCenterView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var configStore = ConfigStore.shared
    private let wifi = WiFiService.shared
    private let bluetooth = BluetoothService.shared
    private let audio = AudioService.shared
    private let brightness = BrightnessService.shared
    private let battery = BatteryService.shared
    @ObservedObject private var inhibit = IdleInhibitService.shared
    @ObservedObject private var dnd = DoNotDisturbService.shared
    @ObservedObject private var nowPlaying = NowPlayingService.shared

    @State private var navigationStack: [ControlCenterPage] = [.root]
    @State private var isEditingLayout: Bool = false
    @State private var showTileLibrary: Bool = false
    @State private var uptimeText: String = ""
    @State private var timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // Drag-and-drop state
    @State private var draggingWidgetID: String? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var previewWidgets: [ControlCenterWidgetConfig]? = nil

    // Undo Stack
    @State private var undoStack: ControlCenterUndoStack = ControlCenterUndoStack(
        initialWidgets: ConfigStore.shared.config.controlCenterWidgets,
        initialColumns: ConfigStore.shared.config.controlCenterColumns
    )

    private var currentColumns: Int {
        CcMetrics.clampColumns(configStore.config.controlCenterColumns)
    }

    private var sheetWidth: CGFloat {
        currentColumns == CcMetrics.defaultColumns ? CcMetrics.defaultSheetWidth : CcMetrics.sheetWidthFor(columns: currentColumns)
    }

    private var gridWidgets: [ControlCenterWidgetConfig] {
        let raw = previewWidgets ?? configStore.config.controlCenterWidgets
        return ControlCenterUtils.hardwareTiles(from: raw)
    }

    private var currentLayout: GridPackingSolver.LayoutResult {
        let minRow = gridWidgets.map(\.row).min() ?? 0
        let cards = gridWidgets.map { w in
            GridPackingSolver.CardItem(
                id: w.id,
                col: Double(w.col),
                row: Double(max(0, w.row - minRow)),
                w: Double(w.w),
                h: Double(w.h),
                small: w.small,
                isAvailable: w.enabled
            )
        }
        let gridWidth = Double(sheetWidth - (CcMetrics.sheetPadding * 2.0))
        return GridPackingSolver.packCards(
            cards: cards,
            columns: currentColumns,
            width: gridWidth,
            gap: Double(CcMetrics.gridGap),
            rowUnit: Double(CcMetrics.tileHeight),
            gravity: true
        )
    }

    private var sheetHeight: CGFloat {
        if activePage != .root {
            return CcMetrics.preferredDetailHeight(section: pageSectionName(activePage))
        }
        let headerH: CGFloat = 36.0
        let slidersH: CGFloat = 40.0
        let gridH: CGFloat = currentLayout.totalHeight
        let bottomH: CGFloat = isEditingLayout ? 50.0 : 44.0
        let spacing: CGFloat = 8.0 * 3.0
        let padding: CGFloat = CcMetrics.sheetPadding * 2.0
        return max(ControlCenterController.standardSheetHeight, headerH + slidersH + gridH + bottomH + spacing + padding)
    }

    public init() {}

    private var activePage: ControlCenterPage {
        navigationStack.last ?? .root
    }

    public var body: some View {
        PopoutSurfaceContainer(bodyWidth: sheetWidth, bodyHeight: sheetHeight) {
            ZStack {
                if activePage == .root {
                    rootDashboardView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity.combined(with: .scale(scale: 0.96))
                        ))
                } else {
                    detailPageView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }

                // Tile Library Overlay Sheet
                if showTileLibrary {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                showTileLibrary = false
                            }
                        }

                    TileLibrarySheet(
                        activeWidgetIDs: Set(gridWidgets.map(\.id)),
                        onAddWidget: { tile in
                            addWidget(tile)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                showTileLibrary = false
                            }
                        },
                        onClose: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                showTileLibrary = false
                            }
                        }
                    )
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .zIndex(100)
                }
            }
        }
        .onAppear {
            updateUptime()
            undoStack.reset(widgets: gridWidgets, columns: currentColumns)
            ControlCenterController.shared.updateHeight(to: sheetHeight)
        }
        .onChange(of: sheetHeight) { _, newH in
            ControlCenterController.shared.updateHeight(to: newH)
        }
        .onChange(of: isEditingLayout) { _, _ in
            ControlCenterController.shared.updateHeight(to: sheetHeight)
        }
        .onChange(of: activePage) { _, _ in
            ControlCenterController.shared.updateHeight(to: sheetHeight)
        }
        .onReceive(timer) { _ in
            updateUptime()
        }
    }

    // MARK: - Root Dashboard View (Matches cc.png 1:1 and M3 Expressive)
    private var rootDashboardView: some View {
        let layout = currentLayout

        return VStack(spacing: 8) {
            // 1. Header Row: User Avatar (12 shapes), Name, Uptime, Quick Action Buttons (Lock, Power, Settings, Edit)
            headerBar

            // 2. Dual Sliders: Master Volume & Display Brightness
            dualSlidersRow

            // 3. Dynamic Interactive Hardware Grid (Wi-Fi, Bluetooth, Audio Out, Audio In, Battery, Storage, Color Picker, Keep Awake)
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: CGFloat(layout.width), height: CGFloat(layout.totalHeight))

                ForEach(layout.slots) { slot in
                    if let widget = gridWidgets.first(where: { $0.id == slot.id }) {
                        let isDragging = (draggingWidgetID == widget.id)
                        let xPos = slot.x + (isDragging ? dragOffset.width : 0)
                        let yPos = slot.y + (isDragging ? dragOffset.height : 0)

                        tileView(for: widget, slot: slot)
                            .frame(width: CGFloat(slot.w), height: CGFloat(slot.h))
                            .offset(x: CGFloat(xPos), y: CGFloat(yPos))
                            .zIndex(isDragging ? 50 : 1)
                            .overlay(
                                isEditingLayout ? editControlsOverlay(for: widget, slot: slot) : nil
                            )
                            .gesture(
                                isEditingLayout ? tileDragGesture(for: widget, layout: layout) : nil
                            )
                    }
                }
            }
            .frame(width: CGFloat(layout.width), height: CGFloat(layout.totalHeight), alignment: .topLeading)

            // 4. Bottom Row / Edit Chrome
            if isEditingLayout {
                CcEditChrome(
                    canUndo: undoStack.canUndo,
                    canRedo: undoStack.canRedo,
                    onAddTile: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            showTileLibrary = true
                        }
                    },
                    onUndo: {
                        if let snap = undoStack.undo() {
                            applySnapshot(snap)
                        }
                    },
                    onRedo: {
                        if let snap = undoStack.redo() {
                            applySnapshot(snap)
                        }
                    },
                    onReset: {
                        resetToDefaults()
                    },
                    onDone: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isEditingLayout = false
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                bottomActionsRow
            }
        }
        .padding(CcMetrics.sheetPadding)
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 10) {
            // User Avatar (Clipped by Geometric Avatar Mask)
            Button {
                if isEditingLayout {
                    cycleAvatarShape()
                }
            } label: {
                ZStack {
                    GeometricAvatarShape(shapeName: configStore.config.controlCenterAvatarShape)
                        .fill(theme.surfaceContainerHighest)
                        .frame(width: 36, height: 36)

                    if let avatarImg = loadAvatarImage() {
                        Image(nsImage: avatarImg)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(GeometricAvatarShape(shapeName: configStore.config.controlCenterAvatarShape))
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(theme.primary)
                            .frame(width: 34, height: 34)
                            .clipShape(GeometricAvatarShape(shapeName: configStore.config.controlCenterAvatarShape))
                    }

                    if isEditingLayout {
                        Circle()
                            .fill(Color.black.opacity(0.45))
                            .frame(width: 36, height: 36)
                        Image(systemName: "shuffle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // User Name & System Uptime
            VStack(alignment: .leading, spacing: 2) {
                Text(NSUserName().isEmpty ? "User" : NSUserName())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)

                Text(uptimeText.isEmpty ? "up 7 hours, 47 minutes" : uptimeText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.onSurfaceVariant)
                    .lineLimit(1)
            }

            Spacer()

            // Header Action Buttons: Lock, Power, Settings, Edit
            HStack(spacing: 8) {
                HeaderActionButton(icon: "lock") {
                    Process.launchedProcess(launchPath: "/usr/bin/pmset", arguments: ["displaysleepnow"])
                    ControlCenterController.shared.hide()
                }

                HeaderActionButton(icon: "power") {
                    PowerPopoutController.shared.toggle(anchorToControlCenter: true)
                }

                HeaderActionButton(icon: "gearshape") {
                    ControlCenterController.shared.hide()
                    SettingsController.shared.show()
                }

                HeaderActionButton(icon: isEditingLayout ? "checkmark" : "pencil") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isEditingLayout.toggle()
                    }
                }
            }
        }
    }

    // MARK: - Dual Sliders Row (Volume on left, Brightness on right)
    private var dualSlidersRow: some View {
        HStack(spacing: 12) {
            // Volume Slider
            ControlCenterPillSlider(
                icon: audio.currentOutputIcon,
                value: audio.isMuted ? 0.0 : audio.volume,
                onIconTap: { audio.toggleMute() },
                onValueChanged: { audio.setVolume($0) }
            )

            // Brightness Slider
            ControlCenterPillSlider(
                icon: "sun.max",
                value: brightness.isAvailable ? brightness.value : 0.5,
                onIconTap: {
                    if brightness.isAvailable {
                        brightness.set(brightness.value > 0.05 ? 0.0 : 0.8)
                    }
                },
                onValueChanged: {
                    if brightness.isAvailable {
                        brightness.set($0)
                    }
                }
            )
        }
        .padding(.vertical, 2)
    }

    // MARK: - Bottom Actions Row (Matches cc.png 1:1)
    private var bottomActionsRow: some View {
        HStack(spacing: CcMetrics.gridGap) {
            // Column 1: Do Not Disturb Button (matches Column 1 width)
            Button {
                pushPage(.doNotDisturb)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: dnd.isEnabled ? "bell.slash.fill" : "bell.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(dnd.isEnabled ? theme.primary : theme.onSurface)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Do Not Disturb")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(theme.onSurface)
                        if dnd.isEnabled {
                            Text(dnd.remainingSeconds != nil ? WellbeingFormatter.formatDuration(seconds: dnd.remainingSeconds!) : "Active")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(theme.primary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.onSurfaceVariant)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                .background(theme.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.outlineVariant.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Column 2: Two squircle buttons (Dark Mode & Theme/Contrast)
            HStack(spacing: CcMetrics.gridGap) {
                // Dark Mode / Light Mode Squircle Button
                Button {
                    theme.toggleLightMode()
                    ConfigStore.shared.update { $0.isLightMode = theme.isLightMode }
                } label: {
                    Image(systemName: theme.isLightMode ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.isLightMode ? theme.primary : theme.onSurface)
                        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(theme.outlineVariant.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                // Theme Palette / Contrast Squircle Button
                Button {
                    cycleTheme()
                } label: {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.onSurface)
                        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(theme.outlineVariant.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Tile Content Dispatcher
    @ViewBuilder
    private func tileView(for widget: ControlCenterWidgetConfig, slot: GridPackingSolver.GridSlot) -> some View {
        switch widget.id {
        case "user":
            userHeaderCard

        case "lock":
            HeaderActionButton(icon: "lock") {
                Process.launchedProcess(launchPath: "/usr/bin/pmset", arguments: ["displaysleepnow"])
                ControlCenterController.shared.hide()
            }

        case "power":
            HeaderActionButton(icon: "power") {
                PowerPopoutController.shared.toggle(anchorToControlCenter: true)
            }

        case "settings":
            HeaderActionButton(icon: "gearshape") {
                ControlCenterController.shared.hide()
                SettingsController.shared.show()
            }

        case "edit":
            HeaderActionButton(icon: isEditingLayout ? "checkmark" : "pencil") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isEditingLayout.toggle()
                }
            }

        case "volumeSlider":
            ControlCenterPillSlider(
                icon: audio.currentOutputIcon,
                value: audio.isMuted ? 0.0 : audio.volume,
                onIconTap: { audio.toggleMute() },
                onValueChanged: { audio.setVolume($0) }
            )

        case "brightnessSlider":
            ControlCenterPillSlider(
                icon: "sun.max",
                value: brightness.isAvailable ? brightness.value : 0.5,
                onIconTap: {
                    if brightness.isAvailable {
                        brightness.set(brightness.value > 0.05 ? 0.0 : 0.8)
                    }
                },
                onValueChanged: {
                    if brightness.isAvailable {
                        brightness.set($0)
                    }
                }
            )

        case "wifi", "network":
            ControlCenterTile(
                icon: wifi.symbolName,
                title: wifi.ssid ?? (wifi.isConnected ? "Wi-Fi" : "Disconnected"),
                subtitle: widget.w > 1 ? (wifi.isConnected ? "\(wifi.currentRssiPercent)%" : "Off") : "",
                isActive: wifi.isPowerOn && wifi.isConnected,
                hasDetail: widget.w > 1,
                isPillIcon: true,
                onTap: { wifi.togglePower() },
                onDetailTap: { pushPage(.network) }
            )

        case "bluetooth":
            ControlCenterTile(
                icon: "antenna.radiowaves.left.and.right",
                title: bluetooth.isOn ? "Enabled" : "Disabled",
                subtitle: widget.w > 1 ? bluetooth.connectedDevicesSummary : "",
                isActive: bluetooth.isOn,
                hasDetail: widget.w > 1,
                isPillIcon: true,
                onTap: { bluetooth.toggle() },
                onDetailTap: { pushPage(.bluetooth) }
            )

        case "audioOutput", "audioDevice":
            ControlCenterTile(
                icon: "speaker.wave.2.fill",
                title: audio.currentOutputName,
                subtitle: widget.w > 1 ? "\(Int(audio.volume * 100))%" : "",
                isActive: !audio.isMuted && audio.volume > 0,
                hasDetail: widget.w > 1,
                isPillIcon: true,
                onTap: { audio.toggleMute() },
                onDetailTap: { pushPage(.audio) }
            )

        case "audioInput":
            ControlCenterTile(
                icon: "mic.fill",
                title: audio.currentInputName,
                subtitle: widget.w > 1 ? "\(Int(audio.inputVolume * 100))%" : "",
                isActive: audio.inputVolume > 0,
                hasDetail: widget.w > 1,
                isPillIcon: true,
                onTap: { audio.setInputVolume(audio.inputVolume > 0 ? 0 : 0.75) },
                onDetailTap: { pushPage(.audio) }
            )

        case "battery":
            ControlCenterTile(
                icon: (battery.status?.isCharging ?? false) ? "bolt.batteryblock.fill" : "battery.100",
                title: "Battery",
                subtitle: widget.w > 1 ? "\(battery.status?.capacity ?? 100)%\(battery.status?.isCharging == true ? " • Charging" : "")" : "",
                isActive: (battery.status?.isCharging ?? false) || (battery.status?.onACPower ?? false),
                hasDetail: widget.w > 1,
                isPillIcon: true,
                onTap: { pushPage(.battery) },
                onDetailTap: { pushPage(.battery) }
            )

        case "diskUsage":
            let diskInfo = readDiskUsage()
            ControlCenterTile(
                icon: "internaldrive",
                title: "/",
                subtitle: widget.w > 1 ? diskInfo.formatted : "",
                isActive: true,
                hasDetail: false,
                isPillIcon: true,
                onTap: {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.DiskUtility") {
                        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                    }
                }
            )

        case "colorPicker":
            ControlCenterTile(
                icon: "paintpalette.fill",
                title: "Color Picker",
                subtitle: widget.w > 1 ? "Choose a color" : "",
                isActive: true,
                hasDetail: false,
                isPillIcon: true,
                onTap: { ColorPickerController.shared.show() }
            )

        case "idleInhibitor", "caffeine":
            ControlCenterTile(
                icon: inhibit.isInhibited ? "cup.and.saucer.fill" : "cup.and.saucer",
                title: "Keep Awake",
                subtitle: widget.w > 1 ? (inhibit.isInhibited ? (inhibit.remainingSeconds != nil ? IdleInhibitCountdown.formatRemainingShort(seconds: inhibit.remainingSeconds!) : "Indefinite") : "Off") : "",
                isActive: inhibit.isInhibited,
                hasDetail: widget.w > 1,
                isPillIcon: inhibit.isInhibited,
                onTap: { inhibit.toggle() },
                onDetailTap: { pushPage(.idleInhibitor) }
            )

        case "doNotDisturb", "dnd":
            ControlCenterTile(
                icon: dnd.isEnabled ? "bell.slash.fill" : "bell.slash",
                title: "Do Not Disturb",
                subtitle: widget.w > 1 ? (dnd.isEnabled ? (dnd.remainingSeconds != nil ? WellbeingFormatter.formatDuration(seconds: dnd.remainingSeconds!) : "On") : "Off") : "",
                isActive: dnd.isEnabled,
                hasDetail: widget.w > 1,
                isPillIcon: dnd.isEnabled,
                onTap: { dnd.toggle() },
                onDetailTap: { pushPage(.doNotDisturb) }
            )

        case "quickTiles":
            QuickTilesGroup()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case "media":
            mediaTileView(widget: widget)

        case "nightMode":
            Button {
                NightShiftService.shared.toggle()
            } label: {
                Image(systemName: "sun.max.trianglebadge.exclamationmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.onSurface)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.outlineVariant.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

        case "darkMode":
            Button {
                theme.toggleLightMode()
                ConfigStore.shared.update { $0.isLightMode = theme.isLightMode }
            } label: {
                Image(systemName: "moon")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.onSurface)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.outlineVariant.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

        case "theme":
            Button {
                cycleTheme()
            } label: {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.onSurface)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.outlineVariant.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

        default:
            ControlCenterTile(
                icon: ControlCenterUtils.icon(for: widget.id),
                title: ControlCenterUtils.title(for: widget.id),
                subtitle: widget.w > 1 ? ControlCenterUtils.subtitle(for: widget.id) : "",
                isActive: widget.enabled,
                hasDetail: false,
                isPillIcon: true,
                onTap: {}
            )
        }
    }

    // MARK: - User Header Card with 12 Geometric Avatar Shapes
    private var userHeaderCard: some View {
        let shapeName = configStore.config.controlCenterAvatarShape

        return HStack(spacing: 10) {
            // User Avatar (Clipped by Geometric Avatar Mask)
            Button {
                if isEditingLayout {
                    cycleAvatarShape()
                }
            } label: {
                ZStack {
                    GeometricAvatarShape(shapeName: shapeName)
                        .fill(theme.surfaceContainerHighest)
                        .frame(width: 36, height: 36)

                    if let avatarImg = loadAvatarImage() {
                        Image(nsImage: avatarImg)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(GeometricAvatarShape(shapeName: shapeName))
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(theme.primary)
                            .frame(width: 34, height: 34)
                            .clipShape(GeometricAvatarShape(shapeName: shapeName))
                    }

                    if isEditingLayout {
                        Circle()
                            .fill(Color.black.opacity(0.45))
                            .frame(width: 36, height: 36)
                        Image(systemName: "shuffle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // User Name & System Uptime
            VStack(alignment: .leading, spacing: 2) {
                Text(NSUserName().isEmpty ? "User" : NSUserName())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)

                Text(uptimeText.isEmpty ? "up 7 hours, 47 minutes" : uptimeText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.onSurfaceVariant)
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Edit Controls Overlay
    private func editControlsOverlay(for widget: ControlCenterWidgetConfig, slot: GridPackingSolver.GridSlot) -> some View {
        let isRemovable = ControlCenterUtils.isRemovable(widget)
        let canShrink = ControlCenterUtils.canShrink(widget.id)

        return ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: theme.palette.primary.hex), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

            HStack(spacing: 3) {
                // Resize Span Button
                if canShrink {
                    Button {
                        resizeWidget(widget)
                    } label: {
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Color(hex: theme.palette.primary.hex))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // Delete Button
                if isRemovable {
                    Button {
                        removeWidget(widget)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Color(hex: theme.palette.error.hex))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
    }

    // MARK: - Drag-and-Drop Gesture
    private func tileDragGesture(for widget: ControlCenterWidgetConfig, layout: GridPackingSolver.LayoutResult) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if draggingWidgetID == nil {
                    draggingWidgetID = widget.id
                }
                dragOffset = value.translation

                if let currentSlot = layout.slots.first(where: { $0.id == widget.id }) {
                    let destX = currentSlot.x + Double(value.translation.width)
                    let destY = currentSlot.y + Double(value.translation.height)
                    let (targetCol, targetRow) = GridPackingSolver.cellAt(
                        layout: layout,
                        x: destX,
                        y: destY,
                        cols: Double(widget.w),
                        rows: Double(widget.h)
                    )

                    var updated = gridWidgets
                    if let idx = updated.firstIndex(where: { $0.id == widget.id }) {
                        updated[idx].col = Int(targetCol)
                        updated[idx].row = Int(targetRow)
                        previewWidgets = updated
                    }
                }
            }
            .onEnded { _ in
                if let finalWidgets = previewWidgets {
                    recordAndSaveWidgets(finalWidgets)
                }
                draggingWidgetID = nil
                dragOffset = .zero
                previewWidgets = nil
            }
    }

    // MARK: - Grid Modification Actions
    private func resizeWidget(_ widget: ControlCenterWidgetConfig) {
        let (newW, newH) = ControlCenterUtils.nextSpan(for: widget, columns: currentColumns)
        var updated = gridWidgets
        if let idx = updated.firstIndex(where: { $0.id == widget.id }) {
            updated[idx].w = newW
            updated[idx].h = newH
            updated[idx].small = (newW == 1)
            recordAndSaveWidgets(updated)
        }
    }

    private func removeWidget(_ widget: ControlCenterWidgetConfig) {
        guard ControlCenterUtils.isRemovable(widget) else { return }
        let updated = gridWidgets.filter { $0.id != widget.id }
        recordAndSaveWidgets(updated)
        ToastCenter.shared.show(icon: "trash", message: "Removed \(ControlCenterUtils.title(for: widget.id))")
    }

    private func addWidget(_ tile: ControlCenterWidgetConfig) {
        var updated = gridWidgets
        var toAdd = tile
        toAdd.col = 0
        toAdd.row = 100 // Gravity will pack it to first fit
        toAdd.enabled = true
        updated.append(toAdd)
        recordAndSaveWidgets(updated)
        ToastCenter.shared.show(icon: "plus.circle.fill", message: "Added \(ControlCenterUtils.title(for: tile.id))")
    }

    private func resetToDefaults() {
        let defaults = ControlCenterUtils.canonicalHardwareTiles
        recordAndSaveWidgets(defaults)
        ToastCenter.shared.show(icon: "arrow.counterclockwise", message: "Reset Control Center to defaults")
    }

    private func recordAndSaveWidgets(_ widgets: [ControlCenterWidgetConfig]) {
        undoStack.record(widgets: widgets, columns: currentColumns)
        configStore.update { $0.controlCenterWidgets = widgets }
        previewWidgets = nil
    }

    private func applySnapshot(_ snapshot: ControlCenterUndoStack.Snapshot) {
        configStore.update {
            $0.controlCenterWidgets = snapshot.widgets
            $0.controlCenterColumns = snapshot.columns
        }
        previewWidgets = nil
    }

    private func cycleAvatarShape() {
        let current = configStore.config.controlCenterAvatarShape
        let nextShape = ControlCenterUtils.nextUserShape(current)
        configStore.update { $0.controlCenterAvatarShape = nextShape }
        ToastCenter.shared.show(icon: "shuffle", message: "Avatar Shape: \(nextShape)")
    }

    // MARK: - Media Tile View
    private func mediaTileView(widget: ControlCenterWidgetConfig) -> some View {
        let track = nowPlaying.currentTrack
        return HStack(spacing: 8) {
            Button {
                nowPlaying.playPause()
            } label: {
                ZStack {
                    if track.isPlaying {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(theme.primary)
                            .frame(width: 58, height: 32)
                        Image(systemName: "pause.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.onPrimary)
                    } else {
                        Color.clear
                            .frame(width: 58, height: 32)
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title.isEmpty ? "No Media Playing" : track.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)
                if !track.artist.isEmpty {
                    Text(track.artist)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(theme.onSurfaceVariant)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
        .background(theme.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.outlineVariant.opacity(0.15), lineWidth: 1)
        )
    }

    private func pageSectionName(_ page: ControlCenterPage) -> String {
        switch page {
        case .network: return "wifi"
        case .bluetooth: return "bluetooth"
        case .audio: return "audioOutput"
        case .battery: return "battery"
        case .doNotDisturb: return "doNotDisturb"
        case .idleInhibitor: return "idleInhibitor"
        case .root: return ""
        }
    }

    // MARK: - Detail Page Layer
    @ViewBuilder
    private var detailPageView: some View {
        switch activePage {
        case .network:
            CcDetailPage(
                title: "Wi-Fi Networks",
                onBack: { popPage() },
                onClose: { ControlCenterController.shared.hide(); popToRoot() }
            ) {
                NetworkDetailPage()
            }
        case .bluetooth:
            CcDetailPage(
                title: "Bluetooth Devices",
                onBack: { popPage() },
                onClose: { ControlCenterController.shared.hide(); popToRoot() }
            ) {
                BluetoothDetailPage()
            }
        case .audio:
            CcDetailPage(
                title: "Audio Mixer",
                onBack: { popPage() },
                onClose: { ControlCenterController.shared.hide(); popToRoot() }
            ) {
                AudioDetailPage()
            }
        case .battery:
            CcDetailPage(
                title: "Battery & Power",
                onBack: { popPage() },
                onClose: { ControlCenterController.shared.hide(); popToRoot() }
            ) {
                BatteryDetailPage()
            }
        case .doNotDisturb:
            CcDetailPage(
                title: "Do Not Disturb",
                onBack: { popPage() },
                onClose: { ControlCenterController.shared.hide(); popToRoot() }
            ) {
                DoNotDisturbDetailPage()
            }
        case .idleInhibitor:
            CcDetailPage(
                title: "Keep Awake",
                onBack: { popPage() },
                onClose: { ControlCenterController.shared.hide(); popToRoot() }
            ) {
                IdleInhibitorDetailPage()
            }
        case .root:
            EmptyView()
        }
    }

    // MARK: - Helpers
    private func updateUptime() {
        let seconds = ProcessInfo.processInfo.systemUptime
        uptimeText = UptimeFormatter.format(seconds: seconds)
    }

    private func cycleTheme() {
        let themes = ["dynamic", "purple", "blue", "green", "orange", "red", "yellow", "neutral"]
        let current = theme.themeName.lowercased()
        let nextIdx = ((themes.firstIndex(of: current) ?? 0) + 1) % themes.count
        let next = themes[nextIdx]
        theme.apply(theme: next, lightMode: theme.isLightMode)
        ConfigStore.shared.update { $0.theme = next }
        ToastCenter.shared.show(icon: "paintpalette.fill", message: "Theme: \(next.capitalized)")
    }

    private func readDiskUsage() -> (usedGB: Double, totalGB: Double, percent: Double, formatted: String) {
        let url = URL(fileURLWithPath: "/")
        if let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
           let total = values.volumeTotalCapacity,
           let free = values.volumeAvailableCapacity {
            let used = total - free
            let res = ControlCenterUtils.formatStorage(usedBytes: Int64(used), totalBytes: Int64(total))
            let usedGB = Double(used) / (1024.0 * 1024.0 * 1024.0)
            let totalGB = Double(total) / (1024.0 * 1024.0 * 1024.0)
            return (usedGB, totalGB, res.rawPercent, res.summary)
        }
        return (80.0, 186.7, 0.43, "80.0G / 186.7G (43%)")
    }

    private func loadAvatarImage() -> NSImage? {
        let facePath = ("~/.face" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: facePath),
           let img = NSImage(contentsOfFile: facePath) {
            return img
        }
        let avatarPng = ("~/.avatar.png" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: avatarPng),
           let img = NSImage(contentsOfFile: avatarPng) {
            return img
        }
        return nil
    }

    private func pushPage(_ page: ControlCenterPage) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            navigationStack.append(page)
        }
    }

    private func popPage() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if navigationStack.count > 1 {
                navigationStack.removeLast()
            }
        }
    }

    private func popToRoot() {
        navigationStack = [.root]
    }
}

// MARK: - Header Action Button
public struct HeaderActionButton: View {
    public let icon: String
    public let action: () -> Void

    @ObservedObject private var theme = ThemeStore.shared

    public init(icon: String, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.onSurfaceVariant)
                .frame(width: 28, height: 28)
                .background(Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dual Pill Slider (Pill Track + Fill + Thumb, matches cc.png 1:1)
public struct ControlCenterPillSlider: View {
    public let icon: String
    public let value: Double
    public let onIconTap: () -> Void
    public let onValueChanged: (Double) -> Void

    @ObservedObject private var theme = ThemeStore.shared

    public init(
        icon: String,
        value: Double,
        onIconTap: @escaping () -> Void,
        onValueChanged: @escaping (Double) -> Void
    ) {
        self.icon = icon
        self.value = value
        self.onIconTap = onIconTap
        self.onValueChanged = onValueChanged
    }

    public var body: some View {
        HStack(spacing: 8) {
            Button(action: onIconTap) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.onSurfaceVariant)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                let width = geo.size.width
                let clampedVal = max(0.0, min(1.0, value))
                let fillWidth = width * CGFloat(clampedVal)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.surfaceContainerHighest.opacity(0.85))
                        .frame(height: 10)

                    Capsule()
                        .fill(theme.primary.opacity(0.85))
                        .frame(width: max(0, fillWidth), height: 10)

                    Capsule()
                        .fill(theme.onPrimary)
                        .frame(width: 4, height: 16)
                        .offset(x: max(0, min(width - 4, fillWidth - 2)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let fraction = max(0.0, min(1.0, Double(gesture.location.x / width)))
                            onValueChanged(fraction)
                        }
                )
            }
            .frame(height: 18)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - M3 Control Center Tile (Matches cc.png 1:1 with pill icon & clean labels)
public struct ControlCenterTile: View {
    public let icon: String
    public let title: String
    public let subtitle: String
    public let isActive: Bool
    public let hasDetail: Bool
    public let isPillIcon: Bool
    public let onTap: () -> Void
    public let onDetailTap: () -> Void

    @ObservedObject private var theme = ThemeStore.shared

    public init(
        icon: String,
        title: String,
        subtitle: String = "",
        isActive: Bool,
        hasDetail: Bool = false,
        isPillIcon: Bool = true,
        onTap: @escaping () -> Void,
        onDetailTap: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isActive = isActive
        self.hasDetail = hasDetail
        self.isPillIcon = isPillIcon
        self.onTap = onTap
        self.onDetailTap = onDetailTap
    }

    public var body: some View {
        HStack(spacing: 8) {
            Button {
                onTap()
            } label: {
                ZStack {
                    if isPillIcon && isActive {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(theme.primary)
                            .frame(width: 58, height: 32)

                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.onPrimary)
                    } else {
                        Color.clear
                            .frame(width: 58, height: 32)

                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                if hasDetail {
                    onDetailTap()
                } else {
                    onTap()
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(theme.onSurface)
                        .lineLimit(1)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(theme.onSurfaceVariant)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
        .background(theme.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.outlineVariant.opacity(0.15), lineWidth: 1)
        )
    }
}
