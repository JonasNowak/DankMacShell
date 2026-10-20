import SwiftUI
import CoreWLAN
import DMSCore

/// Wi-Fi Network scanner and connection manager subpage.
/// Implements upstream DMS `quickshell/Modules/ControlCenter/Details/NetworkDetail.qml`.
public struct NetworkDetailPage: View {
    @ObservedObject private var theme = ThemeStore.shared
    private let wifi = WiFiService.shared

    @State private var networks: [ScannedNetwork] = []
    @State private var isScanning = false
    @State private var selectedNetwork: ScannedNetwork? = nil
    @State private var passwordInput: String = ""
    @State private var isShowingPasswordModal: Bool = false
    @State private var isShowingQRModal: Bool = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Power switch row
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: wifi.symbolName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(wifi.isPowerOn ? theme.onPrimary : theme.onSurface)
                        .frame(width: 32, height: 32)
                        .background(wifi.isPowerOn ? theme.primary : theme.surfaceContainerHigh)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Wi-Fi")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(theme.onSurface)
                        Text(wifi.subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { wifi.isPowerOn },
                    set: { _ in wifi.togglePower(); refreshNetworks() }
                ))
                .toggleStyle(.switch)
            }
            .padding(12)
            .background(theme.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if wifi.isPowerOn {
                // Actions: Scan & Share
                HStack {
                    Button {
                        refreshNetworks()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(.degrees(isScanning ? 360 : 0))
                                .animation(isScanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isScanning)
                            Text("Scan Networks")
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

                    if let currentSSID = wifi.ssid, !currentSSID.isEmpty {
                        Button {
                            isShowingQRModal = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "qrcode")
                                Text("Share Wi-Fi")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(theme.primaryContainer)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Networks list
                VStack(alignment: .leading, spacing: 8) {
                    Text("AVAILABLE NETWORKS (\(networks.count))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(theme.outline)

                    if networks.isEmpty {
                        HStack {
                            Spacer()
                            Text(isScanning ? "Scanning for networks..." : "No networks found")
                                .font(.system(size: 12))
                                .foregroundColor(theme.onSurfaceVariant)
                                .padding(24)
                            Spacer()
                        }
                    } else {
                        ForEach(networks) { net in
                            networkRow(net)
                        }
                    }
                }
            }
        }
        .onAppear {
            refreshNetworks()
        }
        .sheet(isPresented: $isShowingPasswordModal) {
            passwordModalView
        }
        .sheet(isPresented: $isShowingQRModal) {
            qrModalView
        }
    }

    // MARK: - Network Row
    private func networkRow(_ net: ScannedNetwork) -> some View {
        Button {
            if net.isConnected {
                // already connected
            } else if net.isSecure {
                selectedNetwork = net
                passwordInput = ""
                isShowingPasswordModal = true
            } else {
                wifi.connect(to: net.ssid, password: nil)
            }
        } label: {
            HStack(spacing: 12) {
                // Signal strength bars
                signalIcon(bars: net.signalBars)
                    .foregroundColor(net.isConnected ? theme.primary : theme.onSurface)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(net.ssid)
                        .font(.system(size: 13, weight: net.isConnected ? .bold : .medium))
                        .foregroundColor(theme.onSurface)

                    if net.isConnected {
                        Text("Connected")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.primary)
                    }
                }

                Spacer()

                if net.isSecure {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(theme.onSurfaceVariant.opacity(0.8))
                }

                if net.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(net.isConnected ? theme.surfaceContainerHigh : theme.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(net.isConnected ? theme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func signalIcon(bars: Int) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i <= bars ? theme.primary : theme.outlineVariant.opacity(0.4))
                    .frame(width: 3, height: CGFloat(i * 3 + 2))
            }
        }
    }

    private func refreshNetworks() {
        isScanning = true
        Task {
            let scanned = wifi.scanNetworks()
            await MainActor.run {
                self.networks = scanned
                self.isScanning = false
            }
        }
    }

    // MARK: - Password Connection Modal
    private var passwordModalView: some View {
        VStack(spacing: 16) {
            Text("Connect to \(selectedNetwork?.ssid ?? "Network")")
                .font(.headline)
                .foregroundColor(theme.onSurface)

            SecureField("Enter Wi-Fi Password", text: $passwordInput)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            HStack {
                Button("Cancel") {
                    isShowingPasswordModal = false
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Connect") {
                    if let ssid = selectedNetwork?.ssid {
                        wifi.connect(to: ssid, password: passwordInput)
                    }
                    isShowingPasswordModal = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .padding(24)
        .frame(width: 300)
        .background(theme.surfaceContainer)
    }

    // MARK: - Wi-Fi QR Code Modal
    private var qrModalView: some View {
        VStack(spacing: 16) {
            Text("Wi-Fi Quick Share")
                .font(.headline)
                .foregroundColor(theme.onSurface)

            if let ssid = wifi.ssid {
                Text(ssid)
                    .font(.subheadline)
                    .foregroundColor(theme.primary)

                Image(systemName: "qrcode")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .foregroundColor(theme.onSurface)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)

                Text("Scan to connect to this Wi-Fi network")
                    .font(.caption)
                    .foregroundColor(theme.onSurfaceVariant)
            }

            Button("Done") {
                isShowingQRModal = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 280)
        .background(theme.surfaceContainer)
    }
}
