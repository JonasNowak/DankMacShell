import SwiftUI
import AppKit
import DMSCore

public struct ControlCenterView: View {
    @ObservedObject private var theme = ThemeStore.shared
    private let wifi = WiFiService.shared
    private let bluetooth = BluetoothService.shared
    private let audio = AudioService.shared
    private let brightness = BrightnessService.shared
    private let nightShift = NightShiftService.shared
    private let battery = BatteryService.shared
    @ObservedObject private var inhibit = IdleInhibitService.shared
    @ObservedObject private var nowPlaying = NowPlayingService.shared

    public init() {}

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
            // MARK: - Header: User Info & Shortcuts
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(theme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSFullUserName().isEmpty ? NSUserName() : NSFullUserName())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(theme.onSurface)

                    Text(ProcessInfo.processInfo.hostName)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.onSurfaceVariant)
                }

                Spacer()

                // DMS Settings Button
                Button {
                    ControlCenterController.shared.hide()
                    SettingsController.shared.show()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.onSurfaceVariant)
                        .frame(width: 32, height: 32)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // macOS System Settings Button
                Button {
                    openSystemSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.onSurfaceVariant)
                        .frame(width: 32, height: 32)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // MARK: - Media Player Card
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(theme.primary)
                        .frame(width: 36, height: 36)
                        .background(theme.primaryContainer)
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(nowPlaying.currentTrack.title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(theme.onSurface)
                            .lineLimit(1)

                        Text(nowPlaying.currentTrack.artist)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.onSurfaceVariant)
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Button { nowPlaying.previous() } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 12))
                                .foregroundColor(theme.onSurface)
                        }
                        .buttonStyle(.plain)

                        Button { nowPlaying.playPause() } label: {
                            Image(systemName: nowPlaying.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(theme.onPrimary)
                                .frame(width: 30, height: 30)
                                .background(theme.primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button { nowPlaying.next() } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12))
                                .foregroundColor(theme.onSurface)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if nowPlaying.currentTrack.durationSeconds > 0 {
                    ProgressView(value: nowPlaying.currentTrack.progress)
                        .accentColor(theme.primary)
                }
            }
            .padding(12)
            .background(theme.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // MARK: - Action Tiles (2 Columns Grid)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                // Wi-Fi Tile
                M3ActionTile(
                    icon: wifi.symbolName,
                    title: "Wi-Fi",
                    subtitle: wifi.subtitle,
                    isActive: wifi.isPowerOn && wifi.isConnected,
                    onTap: { wifi.togglePower() }
                )

                // Bluetooth Tile
                M3ActionTile(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Bluetooth",
                    subtitle: bluetooth.isOn ? "On" : "Off",
                    isActive: bluetooth.isOn,
                    onTap: { bluetooth.toggle() }
                )

                // Theme Mode Tile (Dark / Light)
                M3ActionTile(
                    icon: theme.isLightMode ? "sun.max.fill" : "moon.fill",
                    title: "Mode",
                    subtitle: theme.isLightMode ? "Light" : "Dark",
                    isActive: theme.isLightMode,
                    onTap: {
                        theme.toggleLightMode()
                        ConfigStore.shared.update { $0.isLightMode = theme.isLightMode }
                        ToastCenter.shared.show(
                            icon: theme.isLightMode ? "sun.max.fill" : "moon.fill",
                            message: "Switched to \(theme.isLightMode ? "Light" : "Dark") Mode"
                        )
                    }
                )

                // Night Shift Tile
                M3ActionTile(
                    icon: "sun.and.horizon.fill",
                    title: "Night Shift",
                    subtitle: nightShift.isOn ? "On" : "Off",
                    isActive: nightShift.isOn,
                    onTap: {
                        nightShift.toggle()
                        ToastCenter.shared.show(
                            icon: "sun.and.horizon.fill",
                            message: "Night Shift \(nightShift.isOn ? "Enabled" : "Disabled")"
                        )
                    }
                )

                // Sleep Inhibit / Caffeinate Tile
                M3ActionTile(
                    icon: inhibit.isInhibited ? "cup.and.saucer.fill" : "cup.and.saucer",
                    title: "Inhibit Sleep",
                    subtitle: inhibit.isInhibited ? "Active" : "Off",
                    isActive: inhibit.isInhibited,
                    onTap: { inhibit.toggle() }
                )

                // Microphone Mute Tile
                M3ActionTile(
                    icon: audio.isMicMuted ? "mic.slash.fill" : "mic.fill",
                    title: "Microphone",
                    subtitle: audio.isMicMuted ? "Muted" : "Active",
                    isActive: !audio.isMicMuted,
                    onTap: { audio.isMicMuted.toggle() }
                )

                // Screen Capture Tile
                M3ActionTile(
                    icon: "camera.viewfinder",
                    title: "Capture",
                    subtitle: "Area / Window",
                    isActive: false,
                    onTap: { takeScreenshot() }
                )

                // Do Not Disturb / Focus Tile
                M3ActionTile(
                    icon: "moon.circle.fill",
                    title: "Focus",
                    subtitle: "Do Not Disturb",
                    isActive: false,
                    onTap: { openFocusSettings() }
                )
            }

            // MARK: - Sliders: Volume & Brightness
            VStack(spacing: 8) {
                // Volume Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.primary)
                        Text("Volume")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.onSurface)
                        Spacer()
                        Text("\(Int(audio.volume * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.onSurfaceVariant)
                    }

                    Slider(value: Binding(
                        get: { audio.volume },
                        set: { audio.setVolume($0) }
                    ), in: 0...1)
                    .tint(theme.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Brightness Slider
                if brightness.isAvailable {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.secondary)
                            Text("Brightness")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.onSurface)
                            Spacer()
                            Text("\(Int(brightness.value * 100))%")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.onSurfaceVariant)
                        }

                        Slider(value: Binding(
                            get: { brightness.value },
                            set: { brightness.set($0) }
                        ), in: 0...1)
                        .tint(theme.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            // MARK: - Themes Row
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("THEME PALETTES")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(theme.outline)
                    Spacer()
                    Text(theme.themeName.capitalized)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.primary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ThemeChip(name: "dynamic", label: "Dynamic", icon: "sparkles", isSelected: theme.themeName.lowercased() == "dynamic")
                        ThemeChip(name: "purple", label: "Purple", colorHex: "#D0BCFF", isSelected: theme.themeName.lowercased() == "purple")
                        ThemeChip(name: "blue", label: "Blue", colorHex: "#A8C7FA", isSelected: theme.themeName.lowercased() == "blue")
                        ThemeChip(name: "green", label: "Green", colorHex: "#81C995", isSelected: theme.themeName.lowercased() == "green")
                        ThemeChip(name: "orange", label: "Orange", colorHex: "#FFB77C", isSelected: theme.themeName.lowercased() == "orange")
                        ThemeChip(name: "red", label: "Red", colorHex: "#FFB3AC", isSelected: theme.themeName.lowercased() == "red")
                        ThemeChip(name: "yellow", label: "Yellow", colorHex: "#E2C553", isSelected: theme.themeName.lowercased() == "yellow")
                        ThemeChip(name: "neutral", label: "Neutral", colorHex: "#C7C6CA", isSelected: theme.themeName.lowercased() == "neutral")
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(12)
            .background(theme.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // MARK: - Power & Session Quick Actions
            HStack(spacing: 8) {
                PowerActionButton(icon: "lock.fill", label: "Lock") {
                    Process.launchedProcess(launchPath: "/usr/bin/pmset", arguments: ["displaysleepnow"])
                    ControlCenterController.shared.hide()
                }
                PowerActionButton(icon: "moon.zzz.fill", label: "Sleep") {
                    Process.launchedProcess(launchPath: "/usr/bin/pmset", arguments: ["sleepnow"])
                    ControlCenterController.shared.hide()
                }
                PowerActionButton(icon: "arrow.counterclockwise", label: "Restart") {
                    PowerMenuController.shared.show()
                }
                PowerActionButton(icon: "power", label: "Shut Down") {
                    PowerMenuController.shared.show()
                }
            }
        }
        .padding(16)
        }
        .frame(width: 360)
        .background(theme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.outlineVariant.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 8)
    }

    private func takeScreenshot() {
        ControlCenterController.shared.hide()
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-i", "-c"]
            task.launch()
            task.waitUntilExit()

            ToastCenter.shared.show(
                icon: "camera.viewfinder",
                message: "Screenshot copied to clipboard!"
            )
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(url)
        }
        ControlCenterController.shared.hide()
    }

    private func openFocusSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
        ControlCenterController.shared.hide()
    }
}

/// Material 3 rounded action tile chip with active accent fill.
public struct M3ActionTile: View {
    public let icon: String
    public let title: String
    public let subtitle: String
    public let isActive: Bool
    public let onTap: () -> Void

    @ObservedObject private var theme = ThemeStore.shared

    public var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isActive ? theme.onPrimary : theme.primary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(isActive ? theme.onPrimary : theme.onSurface)

                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(isActive ? theme.onPrimary.opacity(0.8) : theme.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(isActive ? theme.primary : theme.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? theme.primary : theme.outlineVariant.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Horizontal theme selection pill.
public struct ThemeChip: View {
    public let name: String
    public let label: String
    public var icon: String? = nil
    public var colorHex: String? = nil
    public let isSelected: Bool

    @ObservedObject private var theme = ThemeStore.shared

    public var body: some View {
        Button {
            theme.apply(theme: name, lightMode: theme.isLightMode)
            ConfigStore.shared.update { $0.theme = name }
            ToastCenter.shared.show(
                icon: icon ?? "paintpalette.fill",
                message: "Theme set to \(label)"
            )
        } label: {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                } else if let colorHex {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 10, height: 10)
                }

                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? theme.onPrimary : theme.onSurface)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? theme.primary : theme.surfaceContainer)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? theme.primary : theme.outlineVariant.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Power action circular button.
public struct PowerActionButton: View {
    public let icon: String
    public let label: String
    public let action: () -> Void

    @ObservedObject private var theme = ThemeStore.shared

    public var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.onSurface)
                    .frame(width: 32, height: 32)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Circle())

                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(theme.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
