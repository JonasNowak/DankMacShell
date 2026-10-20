import SwiftUI
import DMSCore

/// Real-time aggregate CPU load percentage with M3 threshold colors.
/// Complies with `docs/spec/20-bar-widgets.md` `cpuMonitor`.
public struct CpuMonitorWidget: View {
    public var isVertical: Bool
    @ObservedObject private var theme = ThemeStore.shared
    private let telemetry = TelemetryService.shared

    public init(isVertical: Bool = false) {
        self.isVertical = isVertical
    }

    private var cpuColor: Color {
        let percent = telemetry.telemetry.cpuPercent
        if percent > 85.0 {
            return theme.error
        } else if percent >= 70.0 {
            return theme.warning
        } else {
            return theme.onSurface
        }
    }

    public var body: some View {
        Button {
            ProcessListController.shared.toggle(sortByMemory: false, anchorX: NSEvent.mouseLocation.x)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(cpuColor)

                if !isVertical {
                    Text("\(Int(round(telemetry.telemetry.cpuPercent)))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(cpuColor)
                }
            }
            .padding(.horizontal, isVertical ? 0 : 6)
            .frame(width: isVertical ? 28 : nil, height: isVertical ? 28 : 26)
            .background(theme.surfaceContainerHigh)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("CPU Load: \(String(format: "%.1f", telemetry.telemetry.cpuPercent))%")
    }
}
