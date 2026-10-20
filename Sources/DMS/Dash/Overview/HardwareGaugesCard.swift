import SwiftUI
import DMSCore

/// Hardware telemetry resource meters card with 3 vertical sliders and icons.
public struct HardwareGaugesCard: View {
    @ObservedObject var themeStore = ThemeStore.shared
    let telemetryService = TelemetryService.shared

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let telemetry = telemetryService.telemetry

        let cpuFraction = min(1.0, max(0.05, telemetry.cpuPercent / 100.0))
        let tempFraction = 0.49 // Approx 49°C / nominal thermal fraction
        let ramFraction = min(1.0, max(0.1, telemetry.ramPercent / 100.0))

        HStack(spacing: 0) {
            Spacer()
            VerticalMeterColumn(
                fraction: cpuFraction,
                icon: "cpu",
                primaryColor: Color(hex: p.primary.hex),
                trackColor: Color.white.opacity(0.1)
            )
            Spacer()
            VerticalMeterColumn(
                fraction: tempFraction,
                icon: "thermometer.medium",
                primaryColor: Color(hex: p.primary.hex),
                trackColor: Color.white.opacity(0.1)
            )
            Spacer()
            VerticalMeterColumn(
                fraction: ramFraction,
                icon: "memorychip",
                primaryColor: Color(hex: p.primary.hex),
                trackColor: Color.white.opacity(0.1)
            )
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: p.surfaceContainerHigh.hex))
        .cornerRadius(12)
    }
}

private struct VerticalMeterColumn: View {
    let fraction: Double
    let icon: String
    let primaryColor: Color
    let trackColor: Color

    var body: some View {
        VStack(spacing: 6) {
            // Vertical capsule track
            GeometryReader { geo in
                let totalHeight = geo.size.height
                let fillHeight = max(7.5, min(totalHeight, totalHeight * CGFloat(fraction)))

                ZStack(alignment: .bottom) {
                    // Track background
                    Capsule()
                        .fill(trackColor)
                        .frame(width: 7.5, height: totalHeight)

                    // Filled level
                    Capsule()
                        .fill(primaryColor)
                        .frame(width: 7.5, height: fillHeight)
                }
                .frame(width: 7.5, height: totalHeight)
                .clipShape(Capsule())
            }
            .frame(width: 7.5)

            // Icon below
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(primaryColor)
                .frame(width: 16, height: 16)
        }
    }
}

