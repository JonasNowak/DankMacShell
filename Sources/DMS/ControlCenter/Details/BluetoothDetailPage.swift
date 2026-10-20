import SwiftUI
import DMSCore

/// Bluetooth device manager and peripheral battery status subpage.
/// Implements upstream DMS `quickshell/Modules/ControlCenter/Details/BluetoothDetail.qml`.
public struct BluetoothDetailPage: View {
    @ObservedObject private var theme = ThemeStore.shared
    private let bluetooth = BluetoothService.shared

    @State private var devices: [BluetoothDeviceInfo] = []
    @State private var isScanning = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Power switch row
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(bluetooth.isOn ? theme.onPrimary : theme.onSurface)
                        .frame(width: 32, height: 32)
                        .background(bluetooth.isOn ? theme.primary : theme.surfaceContainerHigh)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Bluetooth")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(theme.onSurface)
                        Text(bluetooth.isOn ? "On" : "Off")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { bluetooth.isOn },
                    set: { _ in bluetooth.toggle(); refreshDevices() }
                ))
                .toggleStyle(.switch)
            }
            .padding(12)
            .background(theme.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if bluetooth.isOn {
                // Refresh devices button
                HStack {
                    Button {
                        refreshDevices()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Devices")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.onSurface)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                // Paired devices list
                VStack(alignment: .leading, spacing: 8) {
                    Text("PAIRED DEVICES (\(devices.count))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(theme.outline)

                    if devices.isEmpty {
                        HStack {
                            Spacer()
                            Text("No paired Bluetooth devices")
                                .font(.system(size: 12))
                                .foregroundColor(theme.onSurfaceVariant)
                                .padding(24)
                            Spacer()
                        }
                    } else {
                        ForEach(devices) { dev in
                            deviceRow(dev)
                        }
                    }
                }
            }
        }
        .onAppear {
            refreshDevices()
        }
    }

    private func deviceRow(_ dev: BluetoothDeviceInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForDevice(name: dev.name))
                .font(.system(size: 15))
                .foregroundColor(dev.isConnected ? theme.primary : theme.onSurface)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(dev.name)
                    .font(.system(size: 13, weight: dev.isConnected ? .bold : .medium))
                    .foregroundColor(theme.onSurface)

                Text(dev.isConnected ? "Connected" : "Not Connected")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(dev.isConnected ? theme.primary : theme.onSurfaceVariant)
            }

            Spacer()

            if let battery = dev.batteryLevel {
                HStack(spacing: 3) {
                    Image(systemName: "battery.100")
                        .font(.system(size: 11))
                    Text("\(battery)%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundColor(theme.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(theme.primaryContainer)
                .clipShape(Capsule())
            }

            Button(dev.isConnected ? "Disconnect" : "Connect") {
                if dev.isConnected {
                    bluetooth.disconnectDevice(address: dev.id)
                } else {
                    bluetooth.connectDevice(address: dev.id)
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    refreshDevices()
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(dev.isConnected ? theme.surfaceContainerHigh : theme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(dev.isConnected ? theme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func iconForDevice(name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpod") || lower.contains("headphone") || lower.contains("buds") {
            return "headphones"
        } else if lower.contains("keyboard") {
            return "keyboard"
        } else if lower.contains("mouse") || lower.contains("trackpad") {
            return "computermouse"
        } else if lower.contains("watch") {
            return "applewatch"
        } else if lower.contains("phone") {
            return "iphone"
        }
        return "wave.3.right"
    }

    private func refreshDevices() {
        devices = bluetooth.pairedDevices()
    }
}
