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
    case vpn
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
    @ObservedObject private var tailscale = TailscaleService.shared
    @ObservedObject private var vpn = VPNService.shared
    private let nightShift = NightShiftService.shared

    @State private var navigationStack: [ControlCenterPage] = [.root]
    @State private var isEditingLayout: Bool = false
    @State private var showTileLibrary: Bool = false
    @State private var uptimeText: String = ""
    @State private var timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // Cached disk I/O results — loaded off the body so 60fps drags never hit the disk.
    @State private var avatarImage: NSImage? = nil
    @State private var diskUsage: (usedGB: Double, totalGB: Double, percent: Double, formatted: String)? = nil
    // Height update deferred while a tile drag is in progress (applied when the drag ends).
    @State private var pendingSheetHeight: CGFloat? = nil

    // Drag-and-drop state
    @State private var draggingWidgetID: String? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var previewWidgets: [ControlCenterWidgetConfig]? = nil
    @State private var dragStartSlot: GridPackingSolver.GridSlot? = nil
    @State private var dragStartWidgets: [ControlCenterWidgetConfig]? = nil
    @State private var dragStartLayout: GridPackingSolver.LayoutResult? = nil

    // Undo Stack
    @State private var undoStack: ControlCenterUndoStack = ControlCenterUndoStack(
        initialWidgets: ControlCenterUtils.normalizedGridTiles(
            from: ConfigStore.shared.config.controlCenterGridTiles,
            columns: CcMetrics.clampColumns(ConfigStore.shared.config.controlCenterColumns)
        ),
        initialColumns: CcMetrics.clampColumns(ConfigStore.shared.config.controlCenterColumns)
    )

    private var currentColumns: Int {
        CcMetrics.clampColumns(configStore.config.controlCenterColumns)
    }

    private var sheetWidth: CGFloat {
        currentColumns == CcMetrics.defaultColumns ? CcMetrics.defaultSheetWidth : CcMetrics.sheetWidthFor(columns: currentColumns)
    }

    private var gridWidth: Double {
        Double(sheetWidth - (CcMetrics.sheetPadding * 2.0))
    }

    private var gridWidgets: [ControlCenterWidgetConfig] {
        let raw = previewWidgets ?? configStore.config.controlCenterGridTiles
        return ControlCenterUtils.normalizedGridTiles(from: raw, columns: currentColumns)
    }

    private var currentLayout: GridPackingSolver.LayoutResult {
        ControlCenterGridPlanner.layoutResult(
            for: gridWidgets,
            columns: currentColumns,
            width: gridWidth
        )
    }

    private var sheetHeight: CGFloat {
        if activePage != .root {
            return CcMetrics.preferredDetailHeight(section: pageSectionName(activePage))
        }
        let headerH: CGFloat = 36.0
        let slidersH: CGFloat = 40.0
        let gridOmitted = gridWidgets.isEmpty && !isEditingLayout
        let gridH: CGFloat = gridOmitted ? 0.0 : (gridWidgets.isEmpty ? 44.0 : currentLayout.totalHeight)
        let bottomH: CGFloat = isEditingLayout ? 50.0 : 44.0
        let spacing: CGFloat = gridOmitted ? 8.0 * 2.0 : 8.0 * 3.0
        let padding: CGFloat = CcMetrics.sheetPadding * 2.0
        return max(showTileLibrary ? 316.0 : 180.0, headerH + slidersH + gridH + bottomH + spacing + padding)
    }

    /// Root background opacity for this floating panel: `floatingWindowTransparency`
    /// (clamped `0.2...1.0`) multiplied into the usual popup/surface opacity.
    private var floatingWindowOpacity: Double {
        let clamped = max(0.2, min(1.0, theme.surfaceTokens.floatingWindowTransparency))
        return clamped * min(theme.surfaceTokens.popupTransparency, theme.surfaceTokens.surfaceOpacity)
    }

    public init() {}

    private var activePage: ControlCenterPage {
        navigationStack.last ?? .root
    }

    /// Spring animation honoring `theme.motionTokens.reducedMotion` (nil disables animation).
    private func ccSpring(_ response: Double = 0.3, _ dampingFraction: Double = 0.85) -> Animation? {
        theme.motionTokens.reducedMotion ? nil : .spring(response: response, dampingFraction: dampingFraction)
    }

    public var body: some View {
        PopoutSurfaceContainer(bodyWidth: sheetWidth, bodyHeight: sheetHeight, backgroundOpacity: floatingWindowOpacity) {
            ZStack {
                if activePage == .root {
                    rootDashboardView
                        .transition(theme.motionTokens.reducedMotion ? .opacity : .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity.combined(with: .scale(scale: 0.96))
                        ))
                } else {
                    detailPageView
                        .transition(theme.motionTokens.reducedMotion ? .opacity : .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }

                // Tile Library Overlay Sheet
                if showTileLibrary {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation(ccSpring(0.25, 0.8)) {
                                showTileLibrary = false
                            }
                        }

                    TileLibrarySheet(
                        activeWidgetIDs: Set(gridWidgets.map(\.id)),
                        onAddWidget: { tile in
                            addWidget(tile)
                            withAnimation(ccSpring(0.25, 0.8)) {
                                showTileLibrary = false
                            }
                        },
                        onClose: {
                            withAnimation(ccSpring(0.25, 0.8)) {
                                showTileLibrary = false
                            }
                        }
                    )
                    .transition(theme.motionTokens.reducedMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
                    .zIndex(100)
                }
            }
        }
        .onAppear {
            updateUptime()
            refreshCachedDiskIO()
            if !isEditingLayout {
                undoStack.reset(widgets: gridWidgets, columns: currentColumns)
            }
            ControlCenterController.shared.updateHeight(to: sheetHeight)
        }
        .onChange(of: sheetHeight) { _, newH in
            // Defer the window resize while a tile drag is active so the panel doesn't
            // animate out from under the cursor mid-drag; applied once the drag ends.
            if draggingWidgetID != nil {
                pendingSheetHeight = newH
            } else {
                ControlCenterController.shared.updateHeight(to: newH)
            }
        }
        .onChange(of: isEditingLayout) { _, newValue in
            if newValue {
                undoStack.reset(widgets: gridWidgets, columns: currentColumns)
            } else {
                resetDragState()
            }
            ControlCenterController.shared.updateHeight(to: sheetHeight)
        }
        .onChange(of: showTileLibrary) { _, _ in
            ControlCenterController.shared.updateHeight(to: sheetHeight)
        }
        .onChange(of: activePage) { _, _ in
            ControlCenterController.shared.updateHeight(to: sheetHeight)
        }
        .onReceive(timer) { _ in
            updateUptime()
            refreshCachedDiskIO()
        }
    }

    /// Loads avatar image and disk usage off the view body (disk I/O), cached in @State.
    private func refreshCachedDiskIO() {
        avatarImage = loadAvatarImage()
        diskUsage = readDiskUsage()
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
            if gridWidgets.isEmpty {
                if isEditingLayout {
                    // Empty-grid placeholder keeps the drop zone visible while editing
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(theme.primary.opacity(0.08))
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.primary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        Text("No tiles — click + Add Tile")
                            .font(ThemeStore.shared.font(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                    .frame(height: 44)
                }
            } else {
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .frame(width: CGFloat(layout.width), height: CGFloat(layout.totalHeight))

                    // Drop-target placeholder under the actively dragged tile
                    if let activeId = draggingWidgetID,
                       let targetSlot = layout.slots.first(where: { $0.id == activeId }) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(theme.primary.opacity(0.12))
                            .stroke(theme.primary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .frame(width: CGFloat(targetSlot.w), height: CGFloat(targetSlot.h))
                            .offset(x: CGFloat(targetSlot.x), y: CGFloat(targetSlot.y))
                            .zIndex(0)
                    }

                    ForEach(layout.slots.sorted(by: { $0.id < $1.id })) { slot in
                        if let widget = gridWidgets.first(where: { $0.id == slot.id }) {
                            let isDragging = (draggingWidgetID == widget.id)
                            let xPos = (isDragging && dragStartSlot != nil) ? (dragStartSlot!.x + Double(dragOffset.width)) : slot.x
                            let yPos = (isDragging && dragStartSlot != nil) ? (dragStartSlot!.y + Double(dragOffset.height)) : slot.y

                            ZStack(alignment: .topLeading) {
                                tileView(for: widget, slot: slot)
                                    .allowsHitTesting(!isEditingLayout)
                                    .frame(width: CGFloat(slot.w), height: CGFloat(slot.h))

                                if isEditingLayout {
                                    // Guaranteed interior hit-target behind corner edit buttons
                                    Color.black.opacity(0.001)
                                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .gesture(tileDragGesture(for: widget))

                                    editControlsOverlay(for: widget, slot: slot)
                                }
                            }
                            .frame(width: CGFloat(slot.w), height: CGFloat(slot.h))
                            .scaleEffect(isDragging ? 1.02 : 1.0)
                            .shadow(color: isDragging ? Color.black.opacity(0.25) : .clear, radius: isDragging ? 8 : 0, y: isDragging ? 4 : 0)
                            .offset(x: CGFloat(xPos), y: CGFloat(yPos))
                            .zIndex(isDragging ? 50 : 1)
                            .animation(isDragging ? nil : ccSpring(0.22, 0.85), value: slot)
                        }
                    }
                }
                .coordinateSpace(name: "ccGrid")
                .frame(width: CGFloat(layout.width), height: CGFloat(layout.totalHeight), alignment: .topLeading)
            }

            // 4. Bottom Row / Edit Chrome
            if isEditingLayout {
                CcEditChrome(
                    canUndo: undoStack.canUndo,
                    canRedo: undoStack.canRedo,
                    onAddTile: {
                        withAnimation(ccSpring(0.25, 0.8)) {
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
                        withAnimation(ccSpring(0.3, 0.8)) {
                            isEditingLayout = false
                        }
                    }
                )
                .transition(theme.motionTokens.reducedMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
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

                    if let avatarImg = avatarImage {
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
                            .font(ThemeStore.shared.font(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // User Name & System Uptime
            VStack(alignment: .leading, spacing: 2) {
                Text(NSUserName().isEmpty ? "User" : NSUserName())
                    .font(ThemeStore.shared.font(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)

                Text(uptimeText.isEmpty ? "--" : uptimeText)
                    .font(ThemeStore.shared.font(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.onSurfaceVariant)
                    .lineLimit(1)
            }

            Spacer()

            // Header Action Buttons: Lock, Power, Settings, Edit
            HStack(spacing: 8) {
                HeaderActionButton(icon: "lock", label: "Lock Screen") {
                    lockScreen()
                    ControlCenterController.shared.hide()
                }

                HeaderActionButton(icon: "power", label: "Power Menu") {
                    PowerPopoutController.shared.toggle(anchorToControlCenter: true)
                }

                HeaderActionButton(icon: "gearshape", label: "Settings") {
                    ControlCenterController.shared.hide()
                    SettingsController.shared.show()
                }

                HeaderActionButton(icon: isEditingLayout ? "checkmark" : "pencil", label: isEditingLayout ? "Done Editing" : "Edit Layout") {
                    withAnimation(ccSpring(0.3, 0.8)) {
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
                accessibilityLabel: "Volume",
                onIconTap: { audio.toggleMute() },
                onValueChanged: { audio.setVolume($0) }
            )

            // Brightness Slider
            ControlCenterPillSlider(
                icon: "sun.max",
                value: brightness.isAvailable ? brightness.value : 0.5,
                accessibilityLabel: "Brightness",
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
                        .font(ThemeStore.shared.font(size: 14, weight: .semibold))
                        .foregroundColor(dnd.isEnabled ? theme.primary : theme.onSurface)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Do Not Disturb")
                            .font(ThemeStore.shared.font(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(theme.onSurface)
                        if dnd.isEnabled {
                            Text(dnd.remainingSeconds != nil ? WellbeingFormatter.formatDuration(seconds: dnd.remainingSeconds!) : "Active")
                                .font(ThemeStore.shared.font(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(theme.primary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(ThemeStore.shared.font(size: 10, weight: .semibold))
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
                        .font(ThemeStore.shared.font(size: 14, weight: .semibold))
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
                        .font(ThemeStore.shared.font(size: 14, weight: .semibold))
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
            HeaderActionButton(icon: "lock", label: "Lock Screen") {
                lockScreen()
                ControlCenterController.shared.hide()
            }

        case "power":
            HeaderActionButton(icon: "power", label: "Power Menu") {
                PowerPopoutController.shared.toggle(anchorToControlCenter: true)
            }

        case "settings":
            HeaderActionButton(icon: "gearshape", label: "Settings") {
                ControlCenterController.shared.hide()
                SettingsController.shared.show()
            }

        case "edit":
            HeaderActionButton(icon: isEditingLayout ? "checkmark" : "pencil", label: isEditingLayout ? "Done Editing" : "Edit Layout") {
                withAnimation(ccSpring(0.3, 0.8)) {
                    isEditingLayout.toggle()
                }
            }

        case "volumeSlider":
            ControlCenterPillSlider(
                icon: audio.currentOutputIcon,
                value: audio.isMuted ? 0.0 : audio.volume,
                accessibilityLabel: "Volume",
                onIconTap: { audio.toggleMute() },
                onValueChanged: { audio.setVolume($0) }
            )

        case "brightnessSlider":
            ControlCenterPillSlider(
                icon: "sun.max",
                value: brightness.isAvailable ? brightness.value : 0.5,
                accessibilityLabel: "Brightness",
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
                tileWidthCols: widget.w,
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
                tileWidthCols: widget.w,
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
                tileWidthCols: widget.w,
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
                tileWidthCols: widget.w,
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
                tileWidthCols: widget.w,
                onTap: { pushPage(.battery) },
                onDetailTap: { pushPage(.battery) }
            )

        case "diskUsage":
            ControlCenterTile(
                icon: "internaldrive",
                title: "/",
                subtitle: widget.w > 1 ? (diskUsage?.formatted ?? "--") : "",
                isActive: true,
                hasDetail: false,
                isPillIcon: true,
                tileWidthCols: widget.w,
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
                tileWidthCols: widget.w,
                onTap: {
                    ControlCenterController.shared.hide()
                    ColorPickerService.shared.sampleColor()
                }
            )

        case "idleInhibitor", "caffeine":
            ControlCenterTile(
                icon: inhibit.isInhibited ? "cup.and.saucer.fill" : "cup.and.saucer",
                title: "Keep Awake",
                subtitle: widget.w > 1 ? (inhibit.isInhibited ? (inhibit.remainingSeconds != nil ? IdleInhibitCountdown.formatRemainingShort(seconds: inhibit.remainingSeconds!) : "Indefinite") : "Off") : "",
                isActive: inhibit.isInhibited,
                hasDetail: widget.w > 1,
                isPillIcon: inhibit.isInhibited,
                tileWidthCols: widget.w,
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
                tileWidthCols: widget.w,
                onTap: { dnd.toggle() },
                onDetailTap: { pushPage(.doNotDisturb) }
            )

        case "vpn":
            ControlCenterTile(
                icon: "network.badge.shield.half.filled",
                title: vpnTileTitle,
                subtitle: widget.w > 1 ? vpnTileSubtitle : "",
                isActive: tailscale.isConnected || vpn.isConnected,
                hasDetail: widget.w > 1,
                isPillIcon: true,
                tileWidthCols: widget.w,
                onTap: {
                    if tailscale.isInstalled {
                        tailscale.toggleConnection()
                    } else {
                        pushPage(.vpn)
                    }
                },
                onDetailTap: { pushPage(.vpn) }
            )

        case "quickTiles":
            QuickTilesGroup(cols: widget.w)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case "media":
            mediaTileView(widget: widget)

        case "nightMode":
            ControlCenterTile(
                icon: "sun.and.horizon.fill",
                title: "Night Shift",
                subtitle: widget.w > 1 ? (nightShift.isOn ? "On" : "Off") : "",
                isActive: nightShift.isOn,
                hasDetail: false,
                isPillIcon: true,
                tileWidthCols: widget.w,
                onTap: { nightShift.toggle() }
            )

        case "darkMode":
            ControlCenterTile(
                icon: theme.isLightMode ? "sun.max.fill" : "moon.fill",
                title: theme.isLightMode ? "Light Mode" : "Dark Mode",
                subtitle: widget.w > 1 ? (theme.isLightMode ? "Light" : "Dark") : "",
                isActive: !theme.isLightMode,
                hasDetail: false,
                isPillIcon: true,
                tileWidthCols: widget.w,
                onTap: {
                    theme.toggleLightMode()
                    ConfigStore.shared.update { $0.isLightMode = theme.isLightMode }
                }
            )

        case "theme":
            ControlCenterTile(
                icon: "circle.lefthalf.filled",
                title: "Theme",
                subtitle: widget.w > 1 ? theme.themeName.capitalized : "",
                isActive: true,
                hasDetail: false,
                isPillIcon: true,
                tileWidthCols: widget.w,
                onTap: { cycleTheme() }
            )

        default:
            ControlCenterTile(
                icon: ControlCenterUtils.icon(for: widget.id),
                title: ControlCenterUtils.title(for: widget.id),
                subtitle: widget.w > 1 ? ControlCenterUtils.subtitle(for: widget.id) : "",
                isActive: widget.enabled,
                hasDetail: false,
                isPillIcon: true,
                tileWidthCols: widget.w,
                onTap: {}
            )
        }
    }

    // MARK: - VPN Tile Helpers
    private var vpnTileTitle: String {
        if tailscale.isConnected {
            return tailscale.exitNodeActive ? "Exit Node" : "Tailscale"
        }
        if vpn.isConnected {
            return "VPN"
        }
        return "VPN & Tailscale"
    }

    private var vpnTileSubtitle: String {
        if !tailscale.tailnetName.isEmpty {
            return tailscale.tailnetName
        }
        if let iface = vpn.activeInterface {
            return iface
        }
        return "Off"
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

                    if let avatarImg = avatarImage {
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
                            .font(ThemeStore.shared.font(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // User Name & System Uptime
            VStack(alignment: .leading, spacing: 2) {
                Text(NSUserName().isEmpty ? "User" : NSUserName())
                    .font(ThemeStore.shared.font(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)

                Text(uptimeText.isEmpty ? "--" : uptimeText)
                    .font(ThemeStore.shared.font(size: 11, weight: .medium, design: .rounded))
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

        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.primary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .allowsHitTesting(false)

            if slot.w < 60 {
                // 1×1 tiles: pin badges to opposite corners so they never collide or overflow
                HStack {
                    if canShrink {
                        Button {
                            resizeWidget(widget)
                        } label: {
                            Image(systemName: "arrow.left.and.right")
                                .font(ThemeStore.shared.font(size: 7, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 14, height: 14)
                                .background(theme.primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    if isRemovable {
                        Button {
                            removeWidget(widget)
                        } label: {
                            Image(systemName: "xmark")
                                .font(ThemeStore.shared.font(size: 6, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 14, height: 14)
                                .background(Color(hex: theme.palette.error.hex))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                HStack(spacing: 3) {
                    // Resize Span Button
                    if canShrink {
                        Button {
                            resizeWidget(widget)
                        } label: {
                            Image(systemName: "arrow.left.and.right")
                                .font(ThemeStore.shared.font(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 18, height: 18)
                                .background(theme.primary)
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
                                .font(ThemeStore.shared.font(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 18, height: 18)
                                .background(Color(hex: theme.palette.error.hex))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
    }

    // MARK: - Drag-and-Drop Gesture
    private func tileDragGesture(for widget: ControlCenterWidgetConfig) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("ccGrid"))
            .onChanged { value in
                if draggingWidgetID == nil {
                    draggingWidgetID = widget.id
                    dragStartSlot = currentLayout.slots.first(where: { $0.id == widget.id })
                    dragStartWidgets = gridWidgets
                    dragStartLayout = currentLayout
                }
                dragOffset = value.translation

                guard let startSlot = dragStartSlot,
                      let baseLayout = dragStartLayout,
                      let baseWidgets = dragStartWidgets else { return }

                let destX = startSlot.x + Double(value.translation.width)
                let destY = startSlot.y + Double(value.translation.height)
                let rawCell = GridPackingSolver.cellAt(
                    layout: baseLayout,
                    x: destX,
                    y: destY,
                    cols: Double(widget.w),
                    rows: Double(widget.h)
                )
                let targetCol = Int(rawCell.col.rounded())
                let targetRow = Int(rawCell.row.rounded())

                previewWidgets = ControlCenterGridPlanner.move(
                    widgetID: widget.id,
                    toCol: targetCol,
                    toRow: targetRow,
                    in: baseWidgets,
                    columns: currentColumns,
                    width: gridWidth
                )
            }
            .onEnded { _ in
                if let finalWidgets = previewWidgets {
                    recordAndSaveWidgets(finalWidgets)
                }
                resetDragState()
            }
    }

    private func resetDragState() {
        draggingWidgetID = nil
        dragOffset = .zero
        previewWidgets = nil
        dragStartSlot = nil
        dragStartWidgets = nil
        dragStartLayout = nil
        // Drag ended: apply the height update that was deferred mid-drag.
        if let pending = pendingSheetHeight {
            pendingSheetHeight = nil
            ControlCenterController.shared.updateHeight(to: pending)
        }
    }

    // MARK: - Grid Modification Actions
    private func resizeWidget(_ widget: ControlCenterWidgetConfig) {
        let updated = ControlCenterGridPlanner.cycleSpan(
            widgetID: widget.id,
            in: gridWidgets,
            columns: currentColumns,
            width: gridWidth
        )
        recordAndSaveWidgets(updated)
    }

    private func removeWidget(_ widget: ControlCenterWidgetConfig) {
        guard ControlCenterUtils.isRemovable(widget) else { return }
        let remaining = gridWidgets.filter { $0.id != widget.id }
        let updated = ControlCenterGridPlanner.normalizeLayout(
            remaining,
            columns: currentColumns,
            width: gridWidth
        )
        recordAndSaveWidgets(updated)
        ToastCenter.shared.show(icon: "trash", message: "Removed \(ControlCenterUtils.title(for: widget.id))")
    }

    private func addWidget(_ tile: ControlCenterWidgetConfig) {
        let updated = ControlCenterGridPlanner.insert(
            tile,
            into: gridWidgets,
            columns: currentColumns,
            width: gridWidth
        )
        recordAndSaveWidgets(updated)
        ToastCenter.shared.show(icon: "plus.circle.fill", message: "Added \(ControlCenterUtils.title(for: tile.id))")
    }

    private func resetToDefaults() {
        recordAndSaveWidgets(ControlCenterWidgetConfig.defaultGridTiles)
        ToastCenter.shared.show(icon: "arrow.counterclockwise", message: "Reset Control Center to defaults")
    }

    private func recordAndSaveWidgets(_ widgets: [ControlCenterWidgetConfig]) {
        undoStack.record(widgets: widgets, columns: currentColumns)
        configStore.update { $0.controlCenterGridTiles = widgets }
        previewWidgets = nil
    }

    private func applySnapshot(_ snapshot: ControlCenterUndoStack.Snapshot) {
        configStore.update {
            $0.controlCenterGridTiles = snapshot.widgets
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
    @ViewBuilder
    private func mediaTileView(widget: ControlCenterWidgetConfig) -> some View {
        let track = nowPlaying.currentTrack

        if widget.w == 1 {
            // 1×1: centered play/pause button filling the tile
            Button {
                nowPlaying.playPause()
            } label: {
                Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                    .font(ThemeStore.shared.font(size: 16, weight: .bold))
                    .foregroundColor(track.isPlaying ? theme.onPrimary : theme.onSurfaceVariant)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(track.isPlaying ? theme.primary : theme.surfaceContainerHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.outlineVariant.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(track.title.isEmpty ? "Now Playing" : track.title)
        } else if widget.w == 2 {
            // 2-col: compact 28×28 squircle + single-line title
            HStack(spacing: 8) {
                Button {
                    nowPlaying.playPause()
                } label: {
                    Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                        .font(ThemeStore.shared.font(size: 12, weight: .bold))
                        .foregroundColor(track.isPlaying ? theme.onPrimary : theme.onSurfaceVariant)
                        .frame(width: 28, height: 28)
                        .background(track.isPlaying ? theme.primary : theme.surfaceContainerHighest)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Text(track.title.isEmpty ? "Media" : track.title)
                    .font(ThemeStore.shared.font(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
            .background(theme.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.outlineVariant.opacity(0.15), lineWidth: 1)
            )
        } else {
            // 3+ cols: 58×32 pill + title + artist
            mediaTileWideView(track: track)
        }
    }

    private func mediaTileWideView(track: NowPlayingTrack) -> some View {
        HStack(spacing: 8) {
            Button {
                nowPlaying.playPause()
            } label: {
                ZStack {
                    if track.isPlaying {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(theme.primary)
                            .frame(width: 58, height: 32)
                        Image(systemName: "pause.fill")
                            .font(ThemeStore.shared.font(size: 14, weight: .bold))
                            .foregroundColor(theme.onPrimary)
                    } else {
                        Color.clear
                            .frame(width: 58, height: 32)
                        Image(systemName: "play.fill")
                            .font(ThemeStore.shared.font(size: 15, weight: .semibold))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title.isEmpty ? "No Media Playing" : track.title)
                    .font(ThemeStore.shared.font(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)
                if !track.artist.isEmpty {
                    Text(track.artist)
                        .font(ThemeStore.shared.font(size: 10, weight: .medium, design: .rounded))
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
        case .vpn: return "vpn"
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
        case .vpn:
            CcDetailPage(
                title: "VPN & Tailscale",
                onBack: { popPage() },
                onClose: { ControlCenterController.shared.hide(); popToRoot() }
            ) {
                VPNDetailPage()
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

    /// Locks the screen via `SACLockScreenImmediate` from the private login.framework,
    /// falling back to `pmset displaysleepnow` when the symbol cannot be resolved.
    private func lockScreen() {
        typealias LockScreenFn = @convention(c) () -> Void
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
           let sym = dlsym(handle, "SACLockScreenImmediate") {
            let lockFn = unsafeBitCast(sym, to: LockScreenFn.self)
            lockFn()
        } else {
            let task = Process()
            task.launchPath = "/usr/bin/pmset"
            task.arguments = ["displaysleepnow"]
            try? task.run()
        }
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

    private func readDiskUsage() -> (usedGB: Double, totalGB: Double, percent: Double, formatted: String)? {
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
        return nil
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
        withAnimation(ccSpring(0.3, 0.85)) {
            navigationStack.append(page)
        }
    }

    private func popPage() {
        withAnimation(ccSpring(0.3, 0.85)) {
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
    public let label: String
    public let action: () -> Void

    @ObservedObject private var theme = ThemeStore.shared

    public init(icon: String, label: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label ?? icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(ThemeStore.shared.font(size: 13, weight: .semibold))
                .foregroundColor(theme.onSurfaceVariant)
                .frame(width: 28, height: 28)
                .background(Color.clear)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Dual Pill Slider (Pill Track + Fill + Thumb, matches cc.png 1:1)
public struct ControlCenterPillSlider: View {
    public let icon: String
    public let value: Double
    public let accessibilityLabel: String
    public let onIconTap: () -> Void
    public let onValueChanged: (Double) -> Void

    @ObservedObject private var theme = ThemeStore.shared

    public init(
        icon: String,
        value: Double,
        accessibilityLabel: String? = nil,
        onIconTap: @escaping () -> Void,
        onValueChanged: @escaping (Double) -> Void
    ) {
        self.icon = icon
        self.value = value
        self.accessibilityLabel = accessibilityLabel ?? "Slider"
        self.onIconTap = onIconTap
        self.onValueChanged = onValueChanged
    }

    public var body: some View {
        HStack(spacing: 8) {
            Button(action: onIconTap) {
                Image(systemName: icon)
                    .font(ThemeStore.shared.font(size: 13, weight: .semibold))
                    .foregroundColor(theme.onSurfaceVariant)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)

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
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue("\(Int(round(clampedVal * 100))) percent")
                .accessibilityAdjustableAction { direction in
                    let step = 0.05
                    let next = max(0.0, min(1.0, value + (direction == .increment ? step : -step)))
                    onValueChanged(next)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard width > 0 else { return }
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
    public let tileWidthCols: Int
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
        tileWidthCols: Int = 4,
        onTap: @escaping () -> Void,
        onDetailTap: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isActive = isActive
        self.hasDetail = hasDetail
        self.isPillIcon = isPillIcon
        self.tileWidthCols = tileWidthCols
        self.onTap = onTap
        self.onDetailTap = onDetailTap
    }

    public var body: some View {
        if tileWidthCols == 1 {
            // 1×1: centered icon button filling the tile
            Button {
                onTap()
            } label: {
                Image(systemName: icon)
                    .font(ThemeStore.shared.font(size: 16, weight: .bold))
                    .foregroundColor((isPillIcon && isActive) ? theme.onPrimary : theme.onSurfaceVariant)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background((isPillIcon && isActive) ? theme.primary : theme.surfaceContainerHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.outlineVariant.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(title)
            .accessibilityLabel(title)
        } else if tileWidthCols == 2 {
            // 2-col: compact 28×28 icon pill + single-line title, split tap vs detail tap
            HStack(spacing: 8) {
                Button {
                    onTap()
                } label: {
                    Image(systemName: icon)
                        .font(ThemeStore.shared.font(size: 12, weight: .bold))
                        .foregroundColor((isPillIcon && isActive) ? theme.onPrimary : theme.onSurfaceVariant)
                        .frame(width: 28, height: 28)
                        .background((isPillIcon && isActive) ? theme.primary : theme.surfaceContainerHighest)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)

                Button {
                    if hasDetail {
                        onDetailTap()
                    } else {
                        onTap()
                    }
                } label: {
                    Text(title)
                        .font(ThemeStore.shared.font(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(theme.onSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
            .background(theme.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.outlineVariant.opacity(0.15), lineWidth: 1)
            )
        } else {
            // 3+ cols: 58×32 pill + title + subtitle
            wideTileContent
        }
    }

    private var wideTileContent: some View {
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
                            .font(ThemeStore.shared.font(size: 14, weight: .bold))
                            .foregroundColor(theme.onPrimary)
                    } else {
                        Color.clear
                            .frame(width: 58, height: 32)

                        Image(systemName: icon)
                            .font(ThemeStore.shared.font(size: 15, weight: .semibold))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)

            Button {
                if hasDetail {
                    onDetailTap()
                } else {
                    onTap()
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ThemeStore.shared.font(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(theme.onSurface)
                        .lineLimit(1)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(ThemeStore.shared.font(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(theme.onSurfaceVariant)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
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
