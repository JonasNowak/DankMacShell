import SwiftUI
import DMSCore

/// Real-time aggregate RAM utilization percentage with M3 threshold colors.
/// Complies with `docs/spec/20-bar-widgets.md` `ramMonitor`.
/// Left-click triggers Process Manager popout sorted by memory with services overview.
public struct RamMonitorWidget: View {
    public var isVertical: Bool
    @ObservedObject private var theme = ThemeStore.shared
    private let telemetry = TelemetryService.shared

    public init(isVertical: Bool = false) {
        self.isVertical = isVertical
    }

    private var ramColor: Color {
        let percent = telemetry.telemetry.ramPercent
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
            ProcessListController.shared.toggle(sortByMemory: true, anchorX: NSEvent.mouseLocation.x)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ramColor)

                if !isVertical {
                    Text("\(Int(round(telemetry.telemetry.ramPercent)))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(ramColor)
                }
            }
            .padding(.horizontal, isVertical ? 0 : 6)
            .frame(width: isVertical ? 28 : nil, height: isVertical ? 28 : 26)
            .background(theme.surfaceContainerHigh)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("RAM Utilization: \(String(format: "%.1f", telemetry.telemetry.ramUsedGB)) GB / \(String(format: "%.1f", telemetry.telemetry.ramTotalGB)) GB")
    }
}
