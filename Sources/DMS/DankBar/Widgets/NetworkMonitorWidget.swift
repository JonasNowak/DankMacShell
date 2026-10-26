import SwiftUI
import AppKit
import DMSCore

/// Real-time aggregate network throughput indicator (upload and download rates).
/// Matches M3 widget styling (`CpuMonitorWidget.swift`, `RamMonitorWidget.swift`) with compact/detailed modes.
/// Complies with `docs/spec/20-bar-widgets.md` `networkMonitor`.
public struct NetworkMonitorWidget: View {
    public var isVertical: Bool
    public var options: [String: AnyCodable]
    public var style: BarWidgetStyleOptions

    @ObservedObject private var theme = ThemeStore.shared
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

    private var isCompact: Bool {
        style.compactMode || (options["compactMode"]?.boolValue ?? false)
    }

    private var downRate: Double {
        telemetry.telemetry.networkDownBytesPerSec
    }

    private var upRate: Double {
        telemetry.telemetry.networkUpBytesPerSec
    }

    private var tintColor: Color {
        if let hex = style.customTintHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return theme.onSurface
    }

    private var backgroundColor: Color {
        if let hex = style.customBackgroundHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return theme.surfaceContainerHigh
    }

    public var body: some View {
        Button {
            // Open Activity Monitor Network or Process Manager
            ProcessListController.shared.toggle(sortByMemory: false, anchorX: NSEvent.mouseLocation.x)
        } label: {
            if isVertical {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(tintColor)

                    Text(SystemTelemetry.formatCompactByteRate(downRate))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(tintColor)
                        .lineLimit(1)
                }
                .frame(width: 28, height: 32)
                .background(backgroundColor)
                .clipShape(Capsule())
            } else {
                HStack(spacing: 5) {
                    if style.showIcon {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.primary)
                    }

                    if style.showLabel {
                        if isCompact {
                            Text("↓\(SystemTelemetry.formatCompactByteRate(downRate)) ↑\(SystemTelemetry.formatCompactByteRate(upRate))")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(tintColor)
                        } else {
                            HStack(spacing: 4) {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(theme.primary)
                                    Text(SystemTelemetry.formatByteRate(downRate))
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(tintColor)
                                }

                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(theme.secondary)
                                    Text(SystemTelemetry.formatByteRate(upRate))
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(tintColor)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 7)
                .frame(height: 26)
                .background(backgroundColor)
                .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .help("Network: ↓ \(SystemTelemetry.formatByteRate(downRate))  ↑ \(SystemTelemetry.formatByteRate(upRate))")
    }
}
