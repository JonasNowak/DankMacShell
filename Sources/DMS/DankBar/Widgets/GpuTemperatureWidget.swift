import SwiftUI
import AppKit
import DMSCore

/// GPU thermal core temperature indicator supporting °C and °F with M3 severity thresholds.
/// Complies with `docs/spec/20-bar-widgets.md` `gpuTemperature`.
public struct GpuTemperatureWidget: View {
    public var isVertical: Bool
    public var options: [String: AnyCodable]
    public var style: BarWidgetStyleOptions

    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var configStore = ConfigStore.shared
    private let telemetry = TelemetryService.shared

    public init(
        isVertical: Bool = false,
        options: [String: AnyCodable] = [:],
        style: BarWidgetStyleOptions = BarWidgetStyleOptions()
    ) {
        self.isVertical = isVertical
        self.options = options
        self.style = style
    }

    private var unit: TemperatureUnit {
        if let optUnit = options["temperatureUnit"]?.stringValue?.lowercased() {
            if optUnit == "fahrenheit" || optUnit == "f" { return .fahrenheit }
            if optUnit == "celsius" || optUnit == "c" { return .celsius }
        }
        return configStore.config.weatherUnits.lowercased() == "fahrenheit" ? .fahrenheit : .celsius
    }

    private var gpuCelsius: Double {
        telemetry.telemetry.gpuTemperature ?? 42.0
    }

    private var severity: ThermalSeverity {
        SystemTelemetry.thermalSeverity(forCelsius: gpuCelsius)
    }

    private var tempColor: Color {
        if let hex = style.customTintHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        switch severity {
        case .critical:
            return theme.error
        case .warning:
            return theme.warning
        case .normal:
            return theme.onSurface
        }
    }

    private var backgroundColor: Color {
        if let hex = style.customBackgroundHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return theme.surfaceContainerHigh
    }

    private var formattedTemperature: String {
        SystemTelemetry.formatTemperature(gpuCelsius, unit: unit)
    }

    public var body: some View {
        Button {
            ProcessListController.shared.toggle(sortByMemory: false, anchorX: NSEvent.mouseLocation.x)
        } label: {
            HStack(spacing: 4) {
                if style.showIcon {
                    Image(systemName: "display")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(tempColor)
                }

                if !isVertical && style.showLabel {
                    Text(formattedTemperature)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(tempColor)
                }
            }
            .padding(.horizontal, isVertical ? 0 : 7)
            .frame(width: isVertical ? 28 : nil, height: isVertical ? 28 : 26)
            .background(backgroundColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("GPU Temperature: \(formattedTemperature) (\(String(format: "%.1f", gpuCelsius))°C)")
    }
}
