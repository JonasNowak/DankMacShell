import SwiftUI
import DMSCore

/// GPU utilization and thermal status indicator.
/// Complies with `docs/spec/20-bar-widgets.md` `gpuTemperature`.
public struct GpuMonitorWidget: View {
    public var isVertical: Bool
    @ObservedObject private var theme = ThemeStore.shared
    private let telemetry = TelemetryService.shared

    public init(isVertical: Bool = false) {
        self.isVertical = isVertical
    }

    private var gpuPercent: Double {
        telemetry.telemetry.gpuPercent ?? 0.0
    }

    private var gpuColor: Color {
        if gpuPercent > 85.0 {
            return theme.error
        } else if gpuPercent >= 70.0 {
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
                Image(systemName: "display")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(gpuColor)

                if !isVertical {
                    Text("\(Int(round(gpuPercent)))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(gpuColor)
                }
            }
            .padding(.horizontal, isVertical ? 0 : 6)
            .frame(width: isVertical ? 28 : nil, height: isVertical ? 28 : 26)
            .background(theme.surfaceContainerHigh)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("GPU Utilization: \(Int(round(gpuPercent)))%")
    }
}
