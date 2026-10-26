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
}

/// Control Center master dashboard implementing 1:1 visual fidelity with DMS reference design (`cc.png`),
/// responsive hardware toggles, deep navigation stack, dual sliders, and zero-overflow compact layout.
public struct ControlCenterView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var configStore = ConfigStore.shared
    private let wifi = WiFiService.shared
    private let bluetooth = BluetoothService.shared
    private let audio = AudioService.shared
    private let brightness = BrightnessService.shared
    private let battery = BatteryService.shared
    @ObservedObject private var inhibit = IdleInhibitService.shared
    @ObservedObject private var nowPlaying = NowPlayingService.shared

    @State private var navigationStack: [ControlCenterPage] = [.root]
    @State private var isEditingLayout: Bool = false
    @State private var avatarShapeIndex: Int = 0
    @State private var uptimeText: String = ""
    @State private var timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var currentColumns: Int {
        CcMetrics.clampColumns(configStore.config.controlCenterColumns)
    }

    private var sheetWidth: CGFloat {
        currentColumns == CcMetrics.defaultColumns ? CcMetrics.defaultSheetWidth : CcMetrics.sheetWidthFor(columns: currentColumns)
    }

    public init() {}

    private var activePage: ControlCenterPage {
        navigationStack.last ?? .root
    }

    public var body: some View {
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
        }
        .frame(width: sheetWidth, height: 348)
        .background(theme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.outlineVariant.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
        .onAppear {
            updateUptime()
        }
        .onReceive(timer) { _ in
            updateUptime()
        }
    }

    // MARK: - Root Dashboard View (Matches cc.png 1:1)
    private var rootDashboardView: some View {
        VStack(spacing: 8) {
            // 1. Header Row: User Avatar, Name, Uptime, Quick Action Buttons (Lock, Power, Settings, Edit)
            headerBar

            // 2. Dual Sliders: Master Volume & Display Brightness
            dualSlidersRow

            // 3. 2-Column Hardware Tiles Grid (4 Rows: Wi-Fi, BT, Audio Out, Audio In, Battery, Disk, Color Picker, Keep Awake)
            hardwareGrid

            // 4. Bottom Row: Do Not Disturb pill + Night Shift/Dark Mode circle + Theme/Contrast circle
            bottomActionsRow
        }
        .padding(CcMetrics.sheetPadding)
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 10) {
            // User Avatar
            Button {
                if isEditingLayout {
                    cycleAvatarShape()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(theme.surfaceContainerHighest)
                        .frame(width: 36, height: 36)

                    if let avatarImg = loadAvatarImage() {
                        Image(nsImage: avatarImg)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(theme.primary)
                            .frame(width: 34, height: 34)
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

    // MARK: - 2-Column Hardware Grid (Matches cc.png 1:1)
    private var hardwareGrid: some View {
        VStack(spacing: CcMetrics.gridGap) {
            // Row 1: Wi-Fi & Bluetooth
            HStack(spacing: CcMetrics.gridGap) {
                ControlCenterTile(
                    icon: wifi.symbolName,
                    title: wifi.ssid ?? (wifi.isConnected ? "Wi-Fi" : "Disconnected"),
                    subtitle: wifi.isConnected ? "\(wifi.currentRssiPercent)%" : "Off",
                    isActive: wifi.isPowerOn && wifi.isConnected,
                    hasDetail: true,
                    isPillIcon: true,
                    onTap: { wifi.togglePower() },
                    onDetailTap: { pushPage(.network) }
                )

                ControlCenterTile(
                    icon: "antenna.radiowaves.left.and.right",
                    title: bluetooth.isOn ? "Enabled" : "Disabled",
                    subtitle: bluetooth.connectedDevicesSummary,
                    isActive: bluetooth.isOn,
                    hasDetail: true,
                    isPillIcon: true,
                    onTap: { bluetooth.toggle() },
                    onDetailTap: { pushPage(.bluetooth) }
                )
            }

            // Row 2: Audio Output & Audio Input
            HStack(spacing: CcMetrics.gridGap) {
                ControlCenterTile(
                    icon: "speaker.wave.2.fill",
                    title: audio.currentOutputName,
                    subtitle: "\(Int(audio.volume * 100))%",
                    isActive: !audio.isMuted && audio.volume > 0,
                    hasDetail: true,
                    isPillIcon: true,
                    onTap: { audio.toggleMute() },
                    onDetailTap: { pushPage(.audio) }
                )

                ControlCenterTile(
                    icon: "mic.fill",
                    title: audio.currentInputName,
                    subtitle: "\(Int(audio.inputVolume * 100))%",
                    isActive: audio.inputVolume > 0,
                    hasDetail: true,
                    isPillIcon: true,
                    onTap: { audio.setInputVolume(audio.inputVolume > 0 ? 0 : 0.75) },
                    onDetailTap: { pushPage(.audio) }
                )
            }

            // Row 3: Battery & Storage (Disk Usage)
            HStack(spacing: CcMetrics.gridGap) {
                ControlCenterTile(
                    icon: (battery.status?.isCharging ?? false) ? "bolt.batteryblock.fill" : "battery.100",
                    title: "Battery",
                    subtitle: "\(battery.status?.capacity ?? 100)%\(battery.status?.isCharging == true ? " • Charging" : "")",
                    isActive: (battery.status?.isCharging ?? false) || (battery.status?.onACPower ?? false),
                    hasDetail: true,
                    isPillIcon: true,
                    onTap: { pushPage(.battery) },
                    onDetailTap: { pushPage(.battery) }
                )

                let diskInfo = readDiskUsage()
                ControlCenterTile(
                    icon: "internaldrive",
                    title: "/",
                    subtitle: diskInfo.formatted,
                    isActive: true,
                    hasDetail: false,
                    isPillIcon: true,
                    onTap: {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.DiskUtility") {
                            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                        }
                    }
                )
            }

            // Row 4: Color Picker & Keep Awake
            HStack(spacing: CcMetrics.gridGap) {
                ControlCenterTile(
                    icon: "paintpalette.fill",
                    title: "Color Picker",
                    subtitle: "Choose a color",
                    isActive: true,
                    hasDetail: false,
                    isPillIcon: true,
                    onTap: {
                        ColorPickerController.shared.show()
                    }
                )

                ControlCenterTile(
                    icon: inhibit.isInhibited ? "cup.and.saucer.fill" : "cup.and.saucer",
                    title: "Keep Awake",
                    subtitle: "",
                    isActive: inhibit.isInhibited,
                    hasDetail: false,
                    isPillIcon: inhibit.isInhibited,
                    onTap: {
                        inhibit.toggle()
                    }
                )
            }
        }
    }

    // MARK: - Bottom Actions Row (Matches cc.png 1:1)
    // Column 1: Do Not Disturb squircle (length = Column 1)
    // Column 2: Light Mode squircle + Theme/Contrast squircle (split Column 2 equally)
    private var bottomActionsRow: some View {
        HStack(spacing: CcMetrics.gridGap) {
            // Column 1: Do Not Disturb Button (matches Column 1 width)
            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.onSurface)

                    Text("Do Not Disturb")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(theme.onSurface)

                    Spacer()
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

            // Column 2: Two squircle buttons (Light Mode & Theme/Contrast)
            HStack(spacing: CcMetrics.gridGap) {
                // Dark Mode / Light Mode Squircle Button
                Button {
                    theme.toggleLightMode()
                    ConfigStore.shared.update { $0.isLightMode = theme.isLightMode }
                } label: {
                    Image(systemName: "moon")
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
            .frame(maxWidth: .infinity)
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
        case .root:
            EmptyView()
        }
    }

    // MARK: - Helpers
    private func updateUptime() {
        let seconds = ProcessInfo.processInfo.systemUptime
        uptimeText = UptimeFormatter.format(seconds: seconds)
    }

    private func cycleAvatarShape() {
        avatarShapeIndex = (avatarShapeIndex + 1) % ControlCenterUtils.userShapes.count
        let shape = ControlCenterUtils.userShapes[avatarShapeIndex]
        ToastCenter.shared.show(icon: "shuffle", message: "Avatar Shape: \(shape)")
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
                    // Dark track capsule
                    Capsule()
                        .fill(theme.surfaceContainerHighest.opacity(0.85))
                        .frame(height: 10)

                    // Filled lavender progress
                    Capsule()
                        .fill(theme.primary.opacity(0.85))
                        .frame(width: max(0, fillWidth), height: 10)

                    // Pill thumb indicator at the end of progress
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
            // Icon Container (Lavender squircle when active, transparent when inactive)
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

            // Tile Label Stack (Title and Subtitle)
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

// MARK: - Compatibility Structs
public struct ThemeChip: View {
    public let name: String
    public let label: String
    public var icon: String? = nil
    public var colorHex: String? = nil
    public let isSelected: Bool

    @ObservedObject private var theme = ThemeStore.shared

    public init(name: String, label: String, icon: String? = nil, colorHex: String? = nil, isSelected: Bool) {
        self.name = name
        self.label = label
        self.icon = icon
        self.colorHex = colorHex
        self.isSelected = isSelected
    }

    public var body: some View {
        Button {
            theme.apply(theme: name, lightMode: theme.isLightMode)
            ConfigStore.shared.update { $0.theme = name }
        } label: {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                } else if let colorHex {
                    Circle().fill(Color(hex: colorHex)).frame(width: 8, height: 8)
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? theme.onPrimary : theme.onSurface)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? theme.primary : theme.surfaceContainer)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

public struct PowerActionButton: View {
    public let icon: String
    public let label: String
    public let action: () -> Void

    @ObservedObject private var theme = ThemeStore.shared

    public init(icon: String, label: String, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(theme.onSurface)
                .frame(width: 32, height: 32)
                .background(theme.surfaceContainerHigh)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
