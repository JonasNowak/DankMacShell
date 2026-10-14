import SwiftUI
import AppKit
import Combine
import DMSCore

public struct DankBarView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var workspace = WorkspaceService.shared
    private let telemetry = TelemetryService.shared
    private let wifi = WiFiService.shared
    private let audio = AudioService.shared
    private let battery = BatteryService.shared
    @ObservedObject private var nowPlaying = NowPlayingService.shared
    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var inhibit = IdleInhibitService.shared
    @ObservedObject private var configStore = ConfigStore.shared

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            // MARK: - Left: Launcher + Spaces + Workspace Apps
            HStack(spacing: 6) {
                // DMS Launcher Button
                if configStore.config.showLauncher {
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
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(theme.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Workspaces / Spaces Indicator (Live updating)
                if configStore.config.showSpaces {
                    let total = max(4, workspace.spacesCount)
                    HStack(spacing: 3) {
                        ForEach(1...total, id: \.self) { spaceNum in
                            Button(action: {
                                workspace.switchSpace(spaceNum)
                            }) {
                                Text("\(spaceNum)")
                                    .font(.system(size: 11, weight: workspace.activeSpaceIndex == spaceNum ? .bold : .medium, design: .rounded))
                                    .foregroundColor(workspace.activeSpaceIndex == spaceNum ? theme.onPrimary : theme.onSurface)
                                    .frame(width: 20, height: 20)
                                    .background(workspace.activeSpaceIndex == spaceNum ? theme.primary : Color.clear)
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

                // Workspace Running Apps (Shows all apps open in said workspace)
                if configStore.config.showWorkspaceApps && !workspace.currentWorkspaceApps.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(workspace.currentWorkspaceApps) { app in
                            WorkspaceAppItemView(app: app)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(theme.surfaceContainerHigh.opacity(0.7))
                    .clipShape(Capsule())
                }
            }

            Spacer(minLength: 12)

            // MARK: - Center: Dynamic Island / Clock & Media Pill
            if configStore.config.showClock {
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
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                Text("•")
                                    .foregroundColor(theme.outline)
                                Text(dateFormatter.string(from: currentTime))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(theme.onSurfaceVariant)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
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
            }

            Spacer(minLength: 12)

            // MARK: - Right: Telemetry, Weather, Quick Toggles & Controls
            HStack(spacing: 6) {
                // Optional Applets: Notepad, Clipboard, ColorPicker shortcuts
                if configStore.config.showNotepadApplet {
                    Button(action: { NotepadController.shared.toggle() }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.onSurface)
                            .padding(6)
                            .background(theme.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Notepad Scratchpad")
                }

                if configStore.config.showClipboardApplet {
                    Button(action: { ClipboardController.shared.toggle() }) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.onSurface)
                            .padding(6)
                            .background(theme.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Clipboard History")
                }

                if configStore.config.showColorPickerApplet {
                    Button(action: { ColorPickerController.shared.show() }) {
                        Image(systemName: "eyedropper")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.onSurface)
                            .padding(6)
                            .background(theme.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Color Eyedropper")
                }

                // Weather Pill (Text cut-off fixed)
                if configStore.config.showWeather {
                    Button(action: { DashController.shared.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: weather.currentWeather.sfSymbol)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(theme.primary)
                            Text("\(Int(round(weather.currentWeather.temperatureC)))°")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.onSurface)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Live Weather: \(weather.currentWeather.conditionDescription)")
                }

                // Hardware Telemetry (CPU, RAM, Battery - Text cut-off fixed)
                if configStore.config.showTelemetry {
                    // CPU Pill
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.primary)
                        Text("\(Int(telemetry.telemetry.cpuPercent))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.onSurface)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Capsule())

                    // RAM Pill
                    HStack(spacing: 4) {
                        Image(systemName: "memorychip")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.secondary)
                        Text("\(Int(telemetry.telemetry.ramPercent))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.onSurface)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 9)
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
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(theme.onSurface)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Capsule())
                    }
                }

                // Sleep Inhibit (Caffeinate) Pill
                if configStore.config.showInhibit {
                    Button(action: { inhibit.toggle() }) {
                        Image(systemName: inhibit.isInhibited ? "cup.and.saucer.fill" : "cup.and.saucer")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(inhibit.isInhibited ? theme.onPrimary : theme.onSurface)
                            .padding(6)
                            .background(inhibit.isInhibited ? theme.primary : theme.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(inhibit.isInhibited ? "Sleep Inhibit Active" : "Sleep Inhibit Off")
                }

                // Mic Mute Toggle Pill
                if configStore.config.showMic {
                    Button(action: { audio.isMicMuted.toggle() }) {
                        Image(systemName: audio.isMicMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(audio.isMicMuted ? theme.error : theme.primary)
                            .padding(6)
                            .background(theme.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(audio.isMicMuted ? "Microphone Muted" : "Microphone Active")
                }

                // Wi-Fi Pill
                if configStore.config.showWifi {
                    HStack(spacing: 4) {
                        Image(systemName: wifi.symbolName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(wifi.isConnected ? theme.primary : theme.outline)
                    }
                    .padding(6)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Circle())
                    .help(wifi.subtitle)
                }

                // Audio Output Volume Pill
                if configStore.config.showVolume {
                    HStack(spacing: 4) {
                        Image(systemName: audio.isMuted ? "speaker.slash.fill" : (audio.volume > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(audio.isMuted ? theme.outline : theme.primary)
                    }
                    .padding(6)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Circle())
                    .help("Volume: \(Int(audio.volume * 100))%")
                }

                // Control Center Trigger
                if configStore.config.showControlCenter {
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
                    .help("Quick Settings & Control Center")
                }

                // Power Menu Trigger
                if configStore.config.showPowerMenu {
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
                    .help("Power & Session Menu")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        guard !path.isEmpty else { return nil }
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

/// Represents an interactive application pill open in the current workspace.
public struct WorkspaceAppItemView: View {
    public let app: WorkspaceAppItem
    @ObservedObject private var theme = ThemeStore.shared

    public init(app: WorkspaceAppItem) {
        self.app = app
    }

    public var body: some View {
        Button {
            WorkspaceService.shared.activate(app: app)
        } label: {
            HStack(spacing: 5) {
                AppIconImage(path: app.path, size: 16)
                if app.isActive {
                    Text(app.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.onSurface)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, app.isActive ? 8 : 6)
            .padding(.vertical, 4)
            .background(app.isActive ? theme.primaryContainer.opacity(0.6) : theme.surfaceContainerLow)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(app.isActive ? theme.primary.opacity(0.4) : theme.outlineVariant.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(app.name)
    }
}
