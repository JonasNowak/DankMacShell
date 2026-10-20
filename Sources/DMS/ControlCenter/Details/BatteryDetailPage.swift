import SwiftUI
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
                        .trim(from: 0, to: CGFloat(detailedInfo.capacity) / 100.0)
                        .stroke(
                            detailedInfo.capacity <= 20 ? theme.error : (detailedInfo.isCharging ? theme.primary : theme.secondary),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 72, height: 72)

                    VStack(spacing: 0) {
                        Text("\(detailedInfo.capacity)%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(theme.onSurface)
                        if detailedInfo.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                                .foregroundColor(theme.primary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(detailedInfo.isCharging ? "Charging" : (detailedInfo.onACPower ? "Power Adapter Connected" : "On Battery Power"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(theme.onSurface)

                    if detailedInfo.timeToEmptyMinutes > 0 {
                        Text("\(detailedInfo.timeToEmptyMinutes / 60)h \(detailedInfo.timeToEmptyMinutes % 60)m remaining")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.onSurfaceVariant)
                    } else if detailedInfo.timeToFullMinutes > 0 {
                        Text("\(detailedInfo.timeToFullMinutes / 60)h \(detailedInfo.timeToFullMinutes % 60)m until full")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.onSurfaceVariant)
                    } else {
                        Text(detailedInfo.isCharged ? "Fully Charged" : "Calculating time...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.onSurfaceVariant)
                    }

                    // Wattage draw
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.badge.clock.fill")
                            .font(.system(size: 11))
                        Text(String(format: "%.1f W Draw", detailedInfo.powerWatts))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(theme.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.primaryContainer)
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
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.outline)

                HStack(spacing: 10) {
                    metricTile(label: "Maximum Health", value: "\(detailedInfo.healthPercent)%")
                    metricTile(label: "Cycle Count", value: "\(detailedInfo.cycleCount)")
                    metricTile(label: "Voltage", value: String(format: "%.2f V", detailedInfo.voltageVolts))
                }
            }

            // MARK: - Power Mode Profiles
            VStack(alignment: .leading, spacing: 8) {
                Text("POWER MODE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.outline)

                HStack(spacing: 8) {
                    profileButton(name: "power-saver", label: "Power Saver", icon: "leaf.fill")
                    profileButton(name: "balanced", label: "Balanced", icon: "scale.3d")
                    profileButton(name: "performance", label: "Performance", icon: "flame.fill")
                }
            }

            // MARK: - 24-Hour Discharge Curve
            VStack(alignment: .leading, spacing: 8) {
                Text("24-HOUR DISCHARGE HISTORY")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.outline)

                DischargeCurveChart()
                    .frame(height: 80)
                    .padding(10)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .onAppear {
            detailedInfo = battery.getDetailedInfo()
        }
    }

    private func metricTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(theme.onSurface)
            Text(label)
                .font(.system(size: 10, weight: .medium))
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
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
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
