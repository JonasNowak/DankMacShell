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

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            // MARK: - Left: Launcher + Active App + Dock
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
                if ConfigStore.shared.config.showDock {
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

            // MARK: - Center: Clock & Dynamic Island
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primary)
                    Text(timeFormatter.string(from: currentTime))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(theme.onSurface)
                    Text("•")
                        .foregroundColor(theme.outline)
                    Text(dateFormatter.string(from: currentTime))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(theme.onSurfaceVariant)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(theme.surfaceContainerHigh)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(theme.outlineVariant.opacity(0.25), lineWidth: 1)
                )
            }
            .onReceive(timer) { input in
                currentTime = input
            }

            Spacer()

            // MARK: - Right: Telemetry + Controls
            HStack(spacing: 6) {
                if ConfigStore.shared.config.showTelemetry {
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

                // Wi-Fi Pill
                HStack(spacing: 4) {
                    Image(systemName: wifi.symbolName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(wifi.isConnected ? theme.primary : theme.outline)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(theme.surfaceContainerHigh)
                .clipShape(Circle())

                // Audio Pill
                HStack(spacing: 4) {
                    Image(systemName: audio.isMuted ? "speaker.slash.fill" : (audio.volume > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(audio.isMuted ? theme.outline : theme.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(theme.surfaceContainerHigh)
                .clipShape(Circle())

                // Control Center Trigger
                Button {
                    ControlCenterController.shared.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ControlCenterController.shared.isVisible ? theme.onPrimary : theme.onSurface)
                        .padding(8)
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
                        .padding(8)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            ZStack {
                if ConfigStore.shared.config.barTransparent {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(theme.surfaceContainer)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.outlineVariant.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
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

/// Dock app button with active running indicator dot and context menu.
public struct DockAppItemView: View {
    public let app: AppItem
    @ObservedObject private var theme = ThemeStore.shared
    @State private var isHovered = false

    public var body: some View {
        Button {
            RunningAppsService.shared.activate(app: app)
        } label: {
            VStack(spacing: 2) {
                AppIconImage(path: app.path, size: 24)
                    .scaleEffect(isHovered ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)

                // Running indicator dot
                Circle()
                    .fill(app.isRunning ? theme.primary : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 34, height: 36)
            .background(isHovered ? theme.surfaceContainerHighest.opacity(0.6) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hover in
            isHovered = hover
        }
        .contextMenu {
            Button(app.isPinned ? "Unpin from Dock" : "Pin to Dock") {
                RunningAppsService.shared.togglePin(bundleID: app.bundleID)
            }
            if app.isRunning {
                Button("Hide") {
                    RunningAppsService.shared.hide(app: app)
                }
                Divider()
                Button("Quit", role: .destructive) {
                    RunningAppsService.shared.quit(app: app)
                }
            }
        }
    }
}

/// App icon loader from macOS workspace.
public struct AppIconImage: View {
    public let path: String
    public let size: CGFloat

    public var body: some View {
        if let img = iconImage() {
            Image(nsImage: img)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app.fill")
                .resizable()
                .frame(width: size, height: size)
                .foregroundColor(.secondary)
        }
    }

    private func iconImage() -> NSImage? {
        guard !path.isEmpty else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }
}
