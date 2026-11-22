import SwiftUI
import DMSCore

/// Wallpaper-level widget card: live digital clock/date plus CPU/RAM telemetry gauges.
/// Rendered inside the non-activating desktop panel owned by `DesktopWidgetsController`.
public struct DesktopWidgetsView: View {
    @ObservedObject private var clock = ClockService.shared
    @ObservedObject private var themeStore = ThemeStore.shared

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let t = TelemetryService.shared.telemetry
        let reducedMotion = themeStore.motionTokens.reducedMotion

        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(clock.currentDate, format: .dateTime.hour().minute().second())
                    .font(ThemeStore.shared.font(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                    .monospacedDigit()
                Text(clock.currentDate, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(ThemeStore.shared.font(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
            }

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            gaugeRow(
                label: "CPU",
                percent: t.cpuPercent,
                detail: "\(Int(t.cpuPercent.rounded()))%",
                palette: p,
                reducedMotion: reducedMotion
            )
            gaugeRow(
                label: "RAM",
                percent: t.ramPercent,
                detail: "\(String(format: "%.1f", t.ramUsedGB)) / \(String(format: "%.0f", t.ramTotalGB)) GB",
                palette: p,
                reducedMotion: reducedMotion
            )
        }
        .padding(14)
        .frame(width: 248)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: p.surfaceContainerHigh.hex).opacity(0.55))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(hex: p.outlineVariant.hex).opacity(0.6), lineWidth: 1)
            }
        )
        .accessibilityLabel("Desktop widgets: clock and system telemetry")
    }

    private func gaugeRow(label: String, percent: Double, detail: String, palette: DMSPalette, reducedMotion: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(ThemeStore.shared.font(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                Spacer()
                Text(detail)
                    .font(ThemeStore.shared.font(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
            }
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: palette.surfaceContainerHighest.hex).opacity(0.7))
                    Capsule()
                        .fill(Color(hex: palette.primary.hex))
                        .frame(width: max(0, min(w, w * CGFloat(percent / 100))))
                        .animation(reducedMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: percent)
                }
                .frame(height: 6)
            }
            .frame(height: 6)
        }
    }
}
