import SwiftUI
import AppKit
import Combine
import DMSCore

public struct DankBarView: View {
    @ObservedObject private var theme = ThemeStore.shared
    private let runningApps = RunningAppsService.shared
    private let telemetry = TelemetryService.shared
    private let wifi = WiFiService.shared
    private let audio = AudioService.shared
    private let battery = BatteryService.shared
    @ObservedObject private var nowPlaying = NowPlayingService.shared
    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var inhibit = IdleInhibitService.shared
    @ObservedObject private var configStore = ConfigStore.shared

    @State private var currentTime = Date()
    @State private var activeSpace: Int = 1
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            // MARK: - Left: Launcher + Spaces + Active App + Dock
            HStack(spacing: 6) {
                // DMS Launcher Button
                Button {
                    LauncherController.shared.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.grid.3x3.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.onPrimary)
                        Text("DMS")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(theme.onPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(theme.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Workspaces / Spaces Indicator
                if configStore.config.showSpaces {
                    HStack(spacing: 3) {
                        ForEach(1...4, id: \.self) { spaceNum in
                            Button(action: {
                                activeSpace = spaceNum
                                // Send Ctrl+Number key event to switch spaces
                                switchSpace(spaceNum)
                            }) {
                                Text("\(spaceNum)")
                                    .font(.system(size: 11, weight: activeSpace == spaceNum ? .bold : .medium, design: .rounded))
                                    .foregroundColor(activeSpace == spaceNum ? theme.onPrimary : theme.onSurface)
                                    .frame(width: 20, height: 20)
                                    .background(activeSpace == spaceNum ? theme.primary : Color.clear)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Capsule())
                }

                // Active App Pill
                if let active = runningApps.activeApp {
                    HStack(spacing: 6) {
                        AppIconImage(path: active.path, size: 16)
                        Text(active.name)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.onSurface)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(theme.outlineVariant.opacity(0.3), lineWidth: 1)
                    )
                }

                // Dock Apps
                if configStore.config.showDock {
                    HStack(spacing: 4) {
                        ForEach(runningApps.dockApps) { app in
                            DockAppItemView(app: app)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(theme.surfaceContainerLow)
                    .clipShape(Capsule())
                }
            }

            Spacer()

            // MARK: - Center: Dynamic Island / Clock & Media Pill
            HStack(spacing: 8) {
                Button(action: {
                    DashController.shared.toggle()
                }) {
                    HStack(spacing: 8) {
                        // Clock
                        HStack(spacing: 5) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(theme.primary)
                            Text(timeFormatter.string(from: currentTime))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(theme.onSurface)
                            Text("•")
                                .foregroundColor(theme.outline)
                            Text(dateFormatter.string(from: currentTime))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(theme.onSurfaceVariant)
                        }

                        // Media playback snippet inside Dynamic Island if playing
                        if configStore.config.showMedia, nowPlaying.currentTrack.isPlaying {
                            HStack(spacing: 6) {
                                Text("|")
                                    .foregroundColor(theme.outline)

                                Image(systemName: "music.note")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(theme.primary)

                                Text("\(nowPlaying.currentTrack.title)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(theme.onSurface)
                                    .lineLimit(1)

                                Button(action: { nowPlaying.playPause() }) {
                                    Image(systemName: "pause.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(theme.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(theme.outlineVariant.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .onReceive(timer) { input in
                currentTime = input
            }

            Spacer()

            // MARK: - Right: Telemetry, Weather, Quick Toggles & Controls
            HStack(spacing: 6) {
                // Weather Pill
                if configStore.config.showWeather {
                    Button(action: { DashController.shared.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: weather.currentWeather.sfSymbol)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(theme.primary)
                            Text("\(Int(round(weather.currentWeather.temperatureC)))°")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(theme.onSurface)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Hardware Telemetry
                if configStore.config.showTelemetry {
                    // CPU Pill
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.primary)
                        Text("\(Int(telemetry.telemetry.cpuPercent))%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.onSurface)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Capsule())

                    // RAM Pill
                    HStack(spacing: 4) {
                        Image(systemName: "memorychip")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.secondary)
                        Text("\(Int(telemetry.telemetry.ramPercent))%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.onSurface)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Capsule())

                    // Battery Pill
                    if let bat = battery.status {
                        HStack(spacing: 4) {
                            Image(systemName: bat.isCharging ? "battery.100.bolt" : "battery.75")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(bat.isCharging ? theme.success : theme.onSurface)
                            Text("\(bat.capacity)%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.onSurface)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Capsule())
                    }
                }

                // Sleep Inhibit (Caffeinate) Pill
                Button(action: { inhibit.toggle() }) {
                    Image(systemName: inhibit.isInhibited ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(inhibit.isInhibited ? theme.onPrimary : theme.onSurface)
                        .padding(6)
                        .background(inhibit.isInhibited ? theme.primary : theme.surfaceContainerHigh)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Mic Mute Toggle Pill
                Button(action: { audio.isMicMuted.toggle() }) {
                    Image(systemName: audio.isMicMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(audio.isMicMuted ? theme.error : theme.primary)
                        .padding(6)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Wi-Fi Pill
                HStack(spacing: 4) {
                    Image(systemName: wifi.symbolName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(wifi.isConnected ? theme.primary : theme.outline)
                }
                .padding(6)
                .background(theme.surfaceContainerHigh)
                .clipShape(Circle())

                // Audio Output Volume Pill
                HStack(spacing: 4) {
                    Image(systemName: audio.isMuted ? "speaker.slash.fill" : (audio.volume > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(audio.isMuted ? theme.outline : theme.primary)
                }
                .padding(6)
                .background(theme.surfaceContainerHigh)
                .clipShape(Circle())

                // Control Center Trigger
                Button {
                    ControlCenterController.shared.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ControlCenterController.shared.isVisible ? theme.onPrimary : theme.onSurface)
                        .padding(7)
                        .background(ControlCenterController.shared.isVisible ? theme.primary : theme.surfaceContainerHigh)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Power Menu Trigger
                Button {
                    PowerMenuController.shared.toggle()
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.onSurface)
                        .padding(7)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 48)
        .background(
            ZStack {
                if configStore.config.barTransparent {
                    VisualEffectBlur(material: .headerView, blendingMode: .withinWindow)
                        .background(theme.surface.opacity(0.85))
                } else {
                    theme.surface
                }
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(theme.outlineVariant.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 14, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func switchSpace(_ number: Int) {
        let src = CGEventSource(stateID: .hidSystemState)
        let keyCodes: [Int: CGKeyCode] = [1: 18, 2: 19, 3: 20, 4: 21] // 1, 2, 3, 4
        guard let code = keyCodes[number] else { return }

        let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)
        down?.flags = .maskControl
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)
        up?.flags = .maskControl
        up?.post(tap: .cghidEventTap)
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return f
    }
}

/// Dock item button with running status dot and context menu.
public struct DockAppItemView: View {
    public let app: AppItem
    @ObservedObject private var theme = ThemeStore.shared

    public var body: some View {
        Button {
            RunningAppsService.shared.activate(app: app)
        } label: {
            VStack(spacing: 2) {
                AppIconImage(path: app.path, size: 22)

                Circle()
                    .fill(app.isRunning ? theme.primary : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 30, height: 32)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Text(app.name).font(.headline)
            Divider()

            Button(app.isPinned ? "Unpin from Dock" : "Pin to Dock") {
                RunningAppsService.shared.togglePinned(bundleID: app.bundleID)
            }

            if app.isRunning {
                Button("Hide") {
                    RunningAppsService.shared.hide(app: app)
                }

                Button("Quit") {
                    RunningAppsService.shared.quit(app: app)
                }
            }
        }
    }
}

/// Async App Icon image using NSWorkspace.
public struct AppIconImage: View {
    public let path: String
    public let size: CGFloat

    public var body: some View {
        if let img = iconImage {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(.secondary)
        }
    }

    private var iconImage: NSImage? {
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: size * 2, height: size * 2)
        return icon
    }
}

/// AppKit VisualEffectView wrapper for native liquid blur backgrounds.
public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode

    public init(material: NSVisualEffectView.Material = .headerView, blendingMode: NSVisualEffectView.BlendingMode = .withinWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
