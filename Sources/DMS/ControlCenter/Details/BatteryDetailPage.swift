import SwiftUI
import AppKit
import DMSCore

/// Battery diagnostics, real-time power draw (Watts), health %, and 24h discharge curve subpage.
/// Implements upstream DMS `quickshell/Modules/ControlCenter/Details/BatteryDetail.qml`.
public struct BatteryDetailPage: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var configStore = ConfigStore.shared
    private let battery = BatteryService.shared

    @State private var detailedInfo: BatteryDetailedInfo = BatteryDetailedInfo.fallback
    private var selectedProfile: String {
        configStore.config.getSetting("batteryProfile")?.stringValue ?? "balanced"
    }

    /// True on laptops with a real AppleSmartBattery; false on desktop Macs / VMs.
    private var hasBattery: Bool {
        detailedInfo.hasHardwareTelemetry || battery.status != nil
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // MARK: - Big State Header Card
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(theme.outlineVariant.opacity(0.3), lineWidth: 8)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: hasBattery ? CGFloat(detailedInfo.capacity) / 100.0 : 0)
                        .stroke(
                            detailedInfo.capacity <= 20 ? theme.error : (detailedInfo.isCharging ? theme.primary : theme.secondary),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 72, height: 72)

                    VStack(spacing: 0) {
                        Text(hasBattery ? "\(detailedInfo.capacity)%" : "--")
                            .font(ThemeStore.shared.font(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(theme.onSurface)
                        if hasBattery && detailedInfo.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(ThemeStore.shared.font(size: 10))
                                .foregroundColor(theme.primary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if hasBattery {
                        Text(detailedInfo.isCharging ? "Charging" : (detailedInfo.onACPower ? "Power Adapter Connected" : "On Battery Power"))
                            .font(ThemeStore.shared.font(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(theme.onSurface)

                        if detailedInfo.timeToEmptyMinutes > 0 {
                            Text("\(detailedInfo.timeToEmptyMinutes / 60)h \(detailedInfo.timeToEmptyMinutes % 60)m remaining")
                                .font(ThemeStore.shared.font(size: 12, weight: .medium))
                                .foregroundColor(theme.onSurfaceVariant)
                        } else if detailedInfo.timeToFullMinutes > 0 {
                            Text("\(detailedInfo.timeToFullMinutes / 60)h \(detailedInfo.timeToFullMinutes % 60)m until full")
                                .font(ThemeStore.shared.font(size: 12, weight: .medium))
                                .foregroundColor(theme.onSurfaceVariant)
                        } else {
                            Text(detailedInfo.isCharged ? "Fully Charged" : "Calculating time...")
                                .font(ThemeStore.shared.font(size: 12, weight: .medium))
                                .foregroundColor(theme.onSurfaceVariant)
                        }

                        // Wattage draw
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.badge.clock.fill")
                                .font(ThemeStore.shared.font(size: 11))
                            Text(String(format: "%.1f W Draw", detailedInfo.powerWatts))
                                .font(ThemeStore.shared.font(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(theme.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.primaryContainer)
                        .clipShape(Capsule())
                    } else {
                        Text("No internal battery")
                            .font(ThemeStore.shared.font(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(theme.onSurface)
                        Text("This Mac has no smart battery (desktop or VM)")
                            .font(ThemeStore.shared.font(size: 12, weight: .medium))
                            .foregroundColor(theme.onSurfaceVariant)
                    }

                    // Live macOS Low Power Mode state
                    HStack(spacing: 4) {
                        Image(systemName: battery.isLowPowerModeEnabled ? "leaf.fill" : "gauge.open")
                            .font(ThemeStore.shared.font(size: 11))
                        Text(battery.isLowPowerModeEnabled ? "Low Power Mode Active" : "Standard Power Mode")
                            .font(ThemeStore.shared.font(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(battery.isLowPowerModeEnabled ? theme.secondary : theme.onSurfaceVariant)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.surfaceContainerHighest)
                    .clipShape(Capsule())
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // MARK: - Hardware Health & Cycle Metrics
            VStack(alignment: .leading, spacing: 8) {
                Text("BATTERY HEALTH & SPECS")
                    .font(ThemeStore.shared.font(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.outline)

                HStack(spacing: 10) {
                    metricTile(label: "Maximum Health", value: hasBattery ? "\(detailedInfo.healthPercent)%" : "--")
                    metricTile(label: "Cycle Count", value: hasBattery ? "\(detailedInfo.cycleCount)" : "--")
                    metricTile(label: "Voltage", value: hasBattery ? String(format: "%.2f V", detailedInfo.voltageVolts) : "--")
                }
            }

            // MARK: - Power Mode Profiles
            VStack(alignment: .leading, spacing: 8) {
                Text("POWER MODE")
                    .font(ThemeStore.shared.font(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.outline)

                HStack(spacing: 8) {
                    profileButton(name: "power-saver", label: "Power Saver", icon: "leaf.fill")
                    profileButton(name: "balanced", label: "Balanced", icon: "scale.3d")
                    profileButton(name: "performance", label: "Performance", icon: "flame.fill")
                }

                // Live macOS Low Power Mode state + shortcut into macOS Battery Settings
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: battery.isLowPowerModeEnabled ? "leaf.fill" : "gauge.open")
                            .font(ThemeStore.shared.font(size: 11))
                            .foregroundColor(battery.isLowPowerModeEnabled ? theme.secondary : theme.onSurfaceVariant)
                        Text(battery.isLowPowerModeEnabled ? "Low Power Mode Active" : "Standard Power Mode")
                            .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                            .foregroundColor(theme.onSurface)
                    }
                    Spacer()
                    Button {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(ThemeStore.shared.font(size: 10))
                            Text("Battery Settings…")
                                .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(theme.surfaceContainerHighest)
                        .foregroundColor(theme.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open macOS Battery Settings")
                }
            }

            // MARK: - 24-Hour Discharge Curve
            VStack(alignment: .leading, spacing: 8) {
                Text("24-HOUR DISCHARGE HISTORY")
                    .font(ThemeStore.shared.font(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.outline)

                if hasBattery {
                    DischargeCurveChart()
                        .frame(height: 80)
                        .padding(10)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Text("No battery telemetry available on this Mac")
                        .font(ThemeStore.shared.font(size: 11, weight: .medium))
                        .foregroundColor(theme.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 80)
                        .padding(10)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .onAppear {
            detailedInfo = battery.getDetailedInfo()
        }
        .onChange(of: battery.status) { _, _ in
            detailedInfo = battery.getDetailedInfo()
        }
    }

    private func metricTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(ThemeStore.shared.font(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(theme.onSurface)
            Text(label)
                .font(ThemeStore.shared.font(size: 10, weight: .medium))
                .foregroundColor(theme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(theme.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func profileButton(name: String, label: String, icon: String) -> some View {
        Button {
            ConfigStore.shared.update { $0.setSetting("batteryProfile", value: AnyCodable(name)) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(ThemeStore.shared.font(size: 11))
                Text(label)
                    .font(ThemeStore.shared.font(size: 11, weight: .semibold))
            }
            .foregroundColor(selectedProfile == name ? theme.onPrimary : theme.onSurface)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(selectedProfile == name ? theme.primary : theme.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

/// 24-hour discharge history canvas curve chart.
private struct DischargeCurveChart: View {
    @ObservedObject private var theme = ThemeStore.shared

    // Simulated 24-hour points (0-100% capacity)
    private let dataPoints: [CGFloat] = [1.0, 0.95, 0.90, 0.85, 0.78, 0.72, 0.65, 0.58, 0.50, 0.80, 0.98, 0.92, 0.84, 0.76, 0.70, 0.62]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let step = w / CGFloat(max(1, dataPoints.count - 1))

            Path { path in
                guard !dataPoints.isEmpty else { return }
                path.move(to: CGPoint(x: 0, y: h * (1.0 - dataPoints[0])))
                for i in 1..<dataPoints.count {
                    let pt = CGPoint(x: CGFloat(i) * step, y: h * (1.0 - dataPoints[i]))
                    path.addLine(to: pt)
                }
            }
            .stroke(theme.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            // Gradient fill under the curve
            Path { path in
                guard !dataPoints.isEmpty else { return }
                path.move(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: 0, y: h * (1.0 - dataPoints[0])))
                for i in 1..<dataPoints.count {
                    let pt = CGPoint(x: CGFloat(i) * step, y: h * (1.0 - dataPoints[i]))
                    path.addLine(to: pt)
                }
                path.addLine(to: CGPoint(x: w, y: h))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [theme.primary.opacity(0.3), theme.primary.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}
