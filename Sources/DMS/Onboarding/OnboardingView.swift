import SwiftUI
import AppKit
import CoreGraphics
import CoreLocation
import EventKit
import ApplicationServices
import DMSCore

/// Material 3 Expressive 5-step first-run onboarding wizard for DankMacShell.
/// Hosted by `OnboardingController` in a 680x540 window.
///
/// Steps: Welcome → Permissions → Bar Layout → Theme & Sync → Startup.
@MainActor
public struct OnboardingView: View {
    @ObservedObject private var themeStore = ThemeStore.shared
    @ObservedObject private var configStore = ConfigStore.shared
    @ObservedObject private var terminalThemeExporter = TerminalThemeExporter.shared
    @ObservedObject private var calendarService = CalendarService.shared
    @Bindable private var wifiService = WiFiService.shared
    @Bindable private var mediaKeyInterceptor = MediaKeyInterceptor.shared

    @State private var step: Int = 0
    @State private var launchAtLogin: Bool = LaunchAtLoginManager.isEnabled

    // Live-polled permission states stored in @State so SwiftUI reliably re-renders every row.
    @State private var hasDeviceControl: Bool = false
    @State private var hasInputMonitoring: Bool = false
    @State private var hasScreenRecording: Bool = false
    @State private var hasCalendar: Bool = false
    @State private var hasLocation: Bool = false

    let onFinish: () -> Void

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    private let stepTitles = ["Welcome", "Permissions", "Bar Layout", "Theme & Sync", "Startup"]

    public var body: some View {
        let p = themeStore.palette

        VStack(spacing: 0) {
            header(p)

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.4))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    stepContent(p)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.18), value: step)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.4))

            footer(p)
        }
        .frame(width: 680, height: 540)
        .background(
            GlassSurfaceBackground(
                baseColor: Color(hex: p.surface.hex),
                opacity: configStore.config.surfaceOpacity
            )
        )
        .onAppear {
            launchAtLogin = LaunchAtLoginManager.isEnabled
            terminalThemeExporter.refreshDetectedTargets()
            refreshPermissions()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                refreshPermissions()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            refreshPermissions()
        }
    }

    // MARK: - Live Permission Refresh

    private func refreshPermissions() {
        _ = mediaKeyInterceptor.checkPermissionsAndRetryTaps()
        let axTrusted = AXIsProcessTrusted() || mediaKeyInterceptor.mode == .active
        hasDeviceControl = axTrusted

        // Input Monitoring is granted if CGPreflightListenEventAccess() is true, if Device Control
        // is granted, or if MediaKeyInterceptor's passive/active CGEventTap is live.
        hasInputMonitoring = axTrusted
            || CGPreflightListenEventAccess()
            || mediaKeyInterceptor.mode == .passive
            || mediaKeyInterceptor.mode == .active

        // CGPreflightScreenCaptureAccess() caches false per-process until restart, so also probe
        // whether WindowServer unredacts foreign window titles in CGWindowListCopyWindowInfo.
        hasScreenRecording = CGPreflightScreenCaptureAccess() || Self.hasLiveScreenRecordingAccess()

        calendarService.checkAuthorization()
        let calStatus = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            hasCalendar = (calStatus == .fullAccess)
        } else {
            hasCalendar = (calStatus == .authorized)
        }

        let locStatus = CLLocationManager().authorizationStatus
        let ssidAvailable = (wifiService.ssid != nil && !(wifiService.ssid?.isEmpty ?? true))
        hasLocation = (locStatus == .authorizedAlways || locStatus == .authorized || wifiService.locationAuthorized || ssidAvailable)
    }

    /// Detects Screen Recording permission live without requiring an app restart by checking
    /// whether `CGWindowListCopyWindowInfo` includes `kCGWindowName` for other processes.
    private static func hasLiveScreenRecordingAccess() -> Bool {
        let myPid = ProcessInfo.processInfo.processIdentifier
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for entry in list {
            guard let pid = entry[kCGWindowOwnerPID as String] as? Int32, pid != myPid else { continue }
            let owner = (entry[kCGWindowOwnerName as String] as? String) ?? ""
            if owner == "WindowServer" { continue }
            if let name = entry[kCGWindowName as String] as? String, !name.isEmpty {
                return true
            }
        }
        return false
    }

    // MARK: - Header & Footer Chrome

    private func header(_ p: DMSPalette) -> some View {
        HStack(spacing: 10) {
            // Room for the macOS traffic lights (titled window, fullSizeContentView).
            Spacer().frame(width: 68)

            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: p.primary.hex))

            VStack(alignment: .leading, spacing: 1) {
                Text("DankMacShell Setup")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                Text("Step \(step + 1) of \(stepTitles.count) · \(stepTitles[step])")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(Array(stepTitles.indices), id: \.self) { i in
                    Button(action: { withAnimation(.easeInOut(duration: 0.18)) { step = i } }) {
                        Circle()
                            .fill(i == step ? Color(hex: p.primary.hex) : Color(hex: p.outlineVariant.hex))
                            .frame(width: 7, height: 7)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeStore.panelHeaderBackground)
    }

    private func footer(_ p: DMSPalette) -> some View {
        HStack(spacing: 10) {
            Text("Changes apply live")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: p.outline.hex))

            Spacer()

            if step > 0 {
                Button(action: { withAnimation(.easeInOut(duration: 0.18)) { step -= 1 } }) {
                    Text("Back")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(hex: p.surfaceContainerHigh.hex))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                        .cornerRadius(9)
                }
                .buttonStyle(.plain)
            }

            if step < stepTitles.count - 1 {
                Button(action: { withAnimation(.easeInOut(duration: 0.18)) { step += 1 } }) {
                    Text("Next")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color(hex: p.primary.hex))
                        .foregroundColor(Color(hex: p.onPrimary.hex))
                        .cornerRadius(9)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(themeStore.panelHeaderBackground)
    }

    // MARK: - Step Router

    @ViewBuilder
    private func stepContent(_ p: DMSPalette) -> some View {
        switch step {
        case 0: welcomeStep(p: p)
        case 1: permissionsStep(p: p)
        case 2: layoutStep(p: p)
        case 3: themeStep(p: p)
        default: startupStep(p: p)
        }
    }

    // MARK: - Step 1: Welcome

    private struct OverviewItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
        let hotkey: String?
    }

    private static let overviewItems: [OverviewItem] = [
        OverviewItem(icon: "menubar.rectangle", title: "DankBar", description: "Configurable status bar with OmniWM workspaces, system telemetry, media controls, and anchored popouts.", hotkey: nil),
        OverviewItem(icon: "iphone", title: "Dynamic Island", description: "Notch companion for Now Playing media, volume/brightness OSD, quick controls, weather, and clipboard.", hotkey: nil),
        OverviewItem(icon: "magnifyingglass", title: "DLauncherV2", description: "App launcher, math evaluator, file search, and dmenu selector.", hotkey: "⌥Space"),
        OverviewItem(icon: "square.grid.2x2", title: "DankDash", description: "Dashboard for calendar events, media player with synced LRC lyrics, weather forecast, and wallpapers.", hotkey: "⌥D"),
        OverviewItem(icon: "slider.horizontal.3", title: "Control Center", description: "Interactive quick-tile grid with Wi-Fi, Bluetooth, Audio, Battery, Focus, and Caffeine detail pages.", hotkey: nil),
        OverviewItem(icon: "gearshape.fill", title: "Settings", description: "Configure themes, multi-bar layouts, widgets, keybinds, and CLI/editor theme sync.", hotkey: nil)
    ]

    private func welcomeStep(p: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to the Material Mac experience")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: p.onSurface.hex))

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(Self.overviewItems) { item in
                    overviewCard(item, p)
                }
            }

            Text("Click Next to configure permissions and appearance.")
                .font(.system(size: 10.5))
                .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
        }
    }

    private func overviewCard(_ item: OverviewItem, _ p: DMSPalette) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: p.onPrimaryContainer.hex))
                .frame(width: 30, height: 30)
                .background(Color(hex: p.primaryContainer.hex))
                .cornerRadius(9)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                    if let hotkey = item.hotkey {
                        Text(hotkey)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: p.primary.hex))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: p.primaryContainer.hex))
                            .cornerRadius(4)
                    }
                    Spacer(minLength: 0)
                }
                Text(item.description)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .background(Color(hex: p.surfaceContainerLow.hex))
        .cornerRadius(12)
    }

    // MARK: - Step 2: Permissions Checklist

    private func permissionsStep(p: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Optional macOS permissions used by specific shell features in System Settings → Privacy & Security.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                Spacer()
                Button(action: { refreshPermissions() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Refresh")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: p.surfaceContainerHigh.hex))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                permissionRow(
                    icon: "hand.raised.fill",
                    title: "Device Control and Data Access",
                    subtitle: "Swallow hardware media, volume, and brightness keys directly and allow clipboard auto-paste",
                    granted: hasDeviceControl,
                    actionTitle: "Open Device Control",
                    p: p
                ) {
                    mediaKeyInterceptor.requestAccessibilityPermission()
                    refreshPermissions()
                }

                permissionRow(
                    icon: "keyboard.fill",
                    title: "Input Monitoring",
                    subtitle: "Monitor hardware media keys passively when Device Control is not enabled",
                    granted: hasInputMonitoring,
                    actionTitle: "Open Input Monitoring",
                    p: p
                ) {
                    mediaKeyInterceptor.requestInputMonitoringPermission()
                    refreshPermissions()
                }

                permissionRow(
                    icon: "record.circle.fill",
                    title: "Screen & System Audio Recording",
                    subtitle: "Sample on-screen colors with the eyedropper",
                    granted: hasScreenRecording,
                    actionTitle: "Grant Screen Recording",
                    p: p
                ) {
                    _ = CGRequestScreenCaptureAccess()
                    Self.openPrivacyPane(anchor: "Privacy_ScreenCapture")
                    refreshPermissions()
                }

                permissionRow(
                    icon: "calendar",
                    title: "Calendars",
                    subtitle: "Display upcoming events in DankDash",
                    granted: hasCalendar,
                    actionTitle: "Connect Calendar",
                    p: p
                ) {
                    let status = EKEventStore.authorizationStatus(for: .event)
                    if status == .notDetermined {
                        calendarService.requestAccess()
                    } else {
                        calendarService.openCalendarPrivacySettings()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        refreshPermissions()
                    }
                }

                permissionRow(
                    icon: "location.fill",
                    title: "Location Services",
                    subtitle: "Read the current Wi-Fi network name (SSID)",
                    granted: hasLocation,
                    actionTitle: "Open Location Settings",
                    p: p
                ) {
                    wifiService.requestLocationAuthorizationIfNeeded()
                    wifiService.openLocationSettings()
                    refreshPermissions()
                }
            }
        }
    }

    private static func openPrivacyPane(anchor: String) {
        let modernURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)")
        let legacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")
        if let modernURL, NSWorkspace.shared.open(modernURL) {
            return
        }
        if let legacyURL {
            NSWorkspace.shared.open(legacyURL)
        }
    }

    private func permissionRow(
        icon: String,
        title: String,
        subtitle: String,
        granted: Bool,
        actionTitle: String,
        p: DMSPalette,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: p.primary.hex))
                .frame(width: 28, height: 28)
                .background(Color(hex: p.primaryContainer.hex).opacity(0.45))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                Text(subtitle)
                    .font(.system(size: 9.5))
                    .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Fixed-width status column so all 5 status badges align vertically.
            HStack(spacing: 5) {
                Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(granted ? Color(hex: p.success.hex) : Color(hex: p.error.hex))
                Text(granted ? "Granted" : "Not granted")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(granted ? Color(hex: p.success.hex) : Color(hex: p.error.hex))
            }
            .frame(width: 92, alignment: .leading)

            // Fixed-width action column so buttons align uniformly on the right edge.
            Button(action: action) {
                Text(granted ? "Open Settings" : actionTitle)
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 148)
                    .padding(.vertical, 6)
                    .background(granted ? Color(hex: p.surfaceContainerHighest.hex) : Color(hex: p.primary.hex))
                    .foregroundColor(granted ? Color(hex: p.onSurface.hex) : Color(hex: p.onPrimary.hex))
                    .cornerRadius(7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color(hex: p.surfaceContainerLow.hex))
        .cornerRadius(12)
    }

    // MARK: - Step 3: Layout & Bar Style

    private var currentBar: BarConfig {
        configStore.config.barConfigs.indices.contains(0) ? configStore.config.barConfigs[0] : .default
    }

    private func layoutStep(p: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(icon: "menubar.rectangle", title: "Bar Position", subtitle: "Attach DankBar to a screen edge — applies live", palette: p) {
                HStack {
                    Text("Screen Edge")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                    Spacer()
                    SettingsSegmentedControl(
                        options: [
                            ("Bottom", "bottom"),
                            ("Top", "top"),
                            ("Left", "left"),
                            ("Right", "right")
                        ],
                        selection: Binding(
                            get: { currentBar.position.lowercased() },
                            set: { val in
                                configStore.update {
                                    if !$0.barConfigs.isEmpty { $0.barConfigs[0].position = val }
                                }
                                DankBarController.shared.reposition()
                            }
                        ),
                        palette: p
                    )
                }
            }

            SettingsCard(icon: "paintbrush.pointed.fill", title: "Bar Background Style", subtitle: "Solid surface, frosted glass, or floating island pills", palette: p) {
                HStack {
                    Text("Surface Style")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                    Spacer()
                    SettingsSegmentedControl(
                        options: [
                            ("Solid", "solid"),
                            ("Glass", "glass"),
                            ("Island", "island")
                        ],
                        selection: Binding(
                            get: {
                                let style = currentBar.backgroundStyle.lowercased()
                                return style == "surface" ? "solid" : style
                            },
                            set: { val in
                                configStore.update {
                                    if !$0.barConfigs.isEmpty { $0.barConfigs[0].backgroundStyle = val }
                                }
                                DankBarController.shared.reposition()
                            }
                        ),
                        palette: p
                    )
                }
            }
        }
    }

    // MARK: - Step 4: Theme & App Sync

    private func themeStep(p: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(icon: "paintpalette.fill", title: "Theme", subtitle: "Stock & community Material 3 palettes — applies live", palette: p) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stock")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    themeGrid(names: StockThemes.allThemeNames, p: p)

                    Text("Community")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    themeGrid(names: StockThemes.communityThemeNames, p: p)
                }
            }

            SettingsCard(icon: "sparkles", title: "Auto-Wallpaper Dynamic Palette", subtitle: "Derive the M3 palette from your desktop wallpaper automatically", palette: p) {
                SettingsToggleRow(
                    title: "Auto-Generate Colors on Wallpaper Switch",
                    subtitle: "Switch to the dynamic wallpaper palette whenever the desktop wallpaper changes",
                    isOn: Binding(
                        get: { configStore.config.autoGenerateWallpaperColors },
                        set: { val in configStore.update { $0.autoGenerateWallpaperColors = val } }
                    ),
                    palette: p
                )
            }

            SettingsCard(icon: "macwindow.on.rectangle", title: "App & CLI Theme Sync", subtitle: "Live-export the active palette to terminals, editors & CLI tools", palette: p) {
                SettingsToggleRow(
                    title: "Sync App & CLI Themes",
                    subtitle: "\(terminalThemeExporter.detectedTargetIds.count) apps detected on this Mac",
                    isOn: Binding(
                        get: { configStore.config.terminalThemeSync },
                        set: { val in
                            configStore.update { $0.terminalThemeSync = val }
                            if val {
                                terminalThemeExporter.exportIfEnabled(
                                    palette: themeStore.palette,
                                    themeName: themeStore.themeName,
                                    isDark: themeStore.palette.isDark
                                )
                            }
                        }
                    ),
                    palette: p
                )
            }
        }
    }

    private func themeGrid(names: [String], p: DMSPalette) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(names, id: \.self) { name in
                Button(action: {
                    themeStore.apply(theme: name)
                    configStore.update { $0.theme = name }
                }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(themeColor(for: name))
                            .frame(width: 11, height: 11)
                        Text(name.replacingOccurrences(of: "-", with: " ").capitalized)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: p.onSurface.hex))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if themeStore.themeName.lowercased() == name {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(Color(hex: p.primary.hex))
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: p.surfaceContainerLow.hex))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func themeColor(for name: String) -> Color {
        Color(hex: StockThemes.theme(named: name, isDark: !themeStore.isLightMode).primary.hex)
    }

    // MARK: - Step 5: Startup & Finish

    private func startupStep(p: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(icon: "power", title: "Startup", subtitle: "What happens when you log in to your Mac", palette: p) {
                SettingsToggleRow(
                    title: "Start DankMacShell at Login",
                    subtitle: "Launch DMS automatically when you sign in",
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: { val in
                            launchAtLogin = val
                            LaunchAtLoginManager.setEnabled(val)
                        }
                    ),
                    palette: p
                )

                Divider().opacity(0.3)

                SettingsToggleRow(
                    title: "Check for Updates Automatically",
                    subtitle: "Periodically check GitHub for new DankMacShell releases",
                    isOn: Binding(
                        get: { configStore.config.rawSettings["checkForUpdatesAutomatically"]?.boolValue ?? true },
                        set: { val in configStore.update { $0.rawSettings["checkForUpdatesAutomatically"] = AnyCodable(val) } }
                    ),
                    palette: p
                )
            }

            Button(action: finish) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Finish Setup")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color(hex: p.primary.hex))
                .foregroundColor(Color(hex: p.onPrimary.hex))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Text("You can change all of this later in Settings.")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
        }
    }

    private func finish() {
        configStore.update { $0.rawSettings["onboardingCompleted"] = AnyCodable(true) }
        onFinish()
    }
}

// MARK: - Service Convenience Extensions (onboarding entry points)

@MainActor
extension MediaKeyInterceptor {
    /// Requests Input Monitoring permission (TCC prompt) and opens the Privacy & Security pane.
    public func requestInputMonitoringPermission() {
        openInputMonitoringSettings()
    }
}

@MainActor
extension WiFiService {
    /// Opens System Settings → Privacy & Security → Location Services, which CoreWLAN
    /// needs on macOS 14.4+ to report Wi-Fi SSIDs.
    public func openLocationSettings() {
        let modernURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices")
        let legacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
        if let modernURL, NSWorkspace.shared.open(modernURL) {
            return
        }
        if let legacyURL {
            NSWorkspace.shared.open(legacyURL)
        }
    }
}
