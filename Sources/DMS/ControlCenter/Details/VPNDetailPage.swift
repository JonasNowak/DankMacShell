import SwiftUI
import AppKit
import DMSCore

/// Tailscale mesh VPN detail subpage: mesh status header, exit node selector,
/// full peer list with copy-to-clipboard IPs, and system VPN tunnel status.
public struct VPNDetailPage: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var tailscale = TailscaleService.shared
    @ObservedObject private var vpn = VPNService.shared

    @State private var peerSearch: String = ""

    public init() {}

    private var statusBadge: (text: String, color: Color) {
        if !tailscale.isInstalled {
            return ("Not Installed", Color(hex: theme.palette.error.hex))
        }
        if tailscale.isConnected {
            return ("Connected", theme.primary)
        }
        return ("Disconnected", theme.onSurfaceVariant)
    }

    private var filteredPeers: [TailscalePeer] {
        let query = peerSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return tailscale.peers }
        return tailscale.peers.filter {
            $0.hostName.lowercased().contains(query)
                || $0.dnsName.lowercased().contains(query)
                || $0.ips.contains { $0.contains(query) }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            meshHeaderCard

            if tailscale.isInstalled && tailscale.isConnected {
                exitNodeCard
            }

            peersCard

            systemVPNCcard
        }
        .onAppear {
            tailscale.refresh()
            vpn.refresh()
        }
    }

    // MARK: - Tailscale Mesh Header Card
    private var meshHeaderCard: some View {
        let badge = statusBadge

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "network.badge.shield.half.filled")
                        .font(ThemeStore.shared.font(size: 16, weight: .bold))
                        .foregroundColor(tailscale.isConnected ? theme.onPrimary : theme.onSurface)
                        .frame(width: 32, height: 32)
                        .background(tailscale.isConnected ? theme.primary : theme.surfaceContainerHigh)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tailscale Mesh")
                            .font(ThemeStore.shared.font(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(theme.onSurface)
                        Text(tailscale.isInstalled
                             ? (tailscale.tailnetName.isEmpty ? "Tailnet" : tailscale.tailnetName)
                             : "tailscale CLI not found")
                            .font(ThemeStore.shared.font(size: 11, weight: .medium))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                }

                Spacer()

                // Status badge
                Text(badge.text)
                    .font(ThemeStore.shared.font(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(badge.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badge.color.opacity(0.15))
                    .clipShape(Capsule())
            }

            if tailscale.isInstalled {
                // Self identity row: host name + clickable self IP pill
                HStack(spacing: 8) {
                    if !tailscale.selfHostName.isEmpty {
                        Text(tailscale.selfHostName)
                            .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                            .foregroundColor(theme.onSurfaceVariant)
                            .lineLimit(1)
                    }

                    if !tailscale.selfIP.isEmpty {
                        Button {
                            tailscale.copyIP()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(ThemeStore.shared.font(size: 9, weight: .bold))
                                Text(tailscale.selfIP)
                                    .font(ThemeStore.shared.font(size: 10, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(theme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.primaryContainer)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Copy my Tailscale IP")
                    }

                    Spacer()
                }

                // Primary actions: Connect/Disconnect toggle, Admin Console, Refresh
                HStack(spacing: 8) {
                    Button {
                        tailscale.toggleConnection()
                    } label: {
                        HStack(spacing: 6) {
                            if tailscale.isBusy {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: tailscale.isConnected ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                    .font(ThemeStore.shared.font(size: 12, weight: .bold))
                            }
                            Text(tailscale.isConnected ? "Disconnect" : "Connect")
                        }
                        .font(ThemeStore.shared.font(size: 12, weight: .semibold))
                        .foregroundColor(theme.onPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(theme.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(tailscale.isBusy)
                    .accessibilityLabel(tailscale.isConnected ? "Disconnect Tailscale" : "Connect Tailscale")

                    Button {
                        tailscale.openAdminConsole()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "safari")
                                .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                            Text("Admin Console")
                        }
                        .font(ThemeStore.shared.font(size: 12, weight: .semibold))
                        .foregroundColor(theme.onSurface)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        tailscale.refresh()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                            Text("Refresh")
                        }
                        .font(ThemeStore.shared.font(size: 12, weight: .semibold))
                        .foregroundColor(theme.onSurface)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
        .padding(12)
        .background(theme.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Exit Node Card
    private var exitNodeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXIT NODE")
                .font(ThemeStore.shared.font(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(theme.outline)

            VStack(spacing: 6) {
                exitNodeRow(
                    title: "None (Direct)",
                    subtitle: "Route traffic directly",
                    isActive: tailscale.activeExitNodeID == nil,
                    online: true
                ) {
                    tailscale.setExitNode("")
                }

                ForEach(tailscale.exitNodeCandidates) { peer in
                    exitNodeRow(
                        title: peer.hostName,
                        subtitle: "\(osBadgeLabel(peer.os)) • \(peer.primaryIPv4 ?? peer.ips.first ?? "")",
                        isActive: tailscale.activeExitNodeID == peer.id
                            || (tailscale.activeExitNodeName == peer.hostName && tailscale.activeExitNodeID == nil),
                        online: peer.online
                    ) {
                        tailscale.setExitNode(peer.primaryIPv4 ?? peer.ips.first ?? peer.hostName)
                    }
                }
            }
        }
        .padding(12)
        .background(theme.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func exitNodeRow(title: String, subtitle: String, isActive: Bool, online: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Radio indicator
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(ThemeStore.shared.font(size: 15, weight: .bold))
                    .foregroundColor(isActive ? theme.primary : theme.outlineVariant)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(ThemeStore.shared.font(size: 13, weight: isActive ? .bold : .medium))
                        .foregroundColor(theme.onSurface)
                    Text(subtitle)
                        .font(ThemeStore.shared.font(size: 10, weight: .medium))
                        .foregroundColor(theme.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer()

                Circle()
                    .fill(online ? Color.green : theme.outlineVariant)
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? theme.surfaceContainerHighest : theme.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isActive ? theme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(tailscale.isBusy)
    }

    // MARK: - Mesh Peers Card
    private var peersCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MESH PEERS (\(tailscale.peers.count))")
                    .font(ThemeStore.shared.font(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.outline)

                Spacer()

                // Search filter
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(ThemeStore.shared.font(size: 10))
                        .foregroundColor(theme.outline)
                    TextField("Filter peers…", text: $peerSearch)
                        .textFieldStyle(.plain)
                        .font(ThemeStore.shared.font(size: 11))
                        .frame(width: 140)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(theme.surfaceContainer)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if tailscale.peers.isEmpty {
                HStack {
                    Spacer()
                    Text(tailscale.isConnected ? "No peers in this tailnet" : "Connect to see mesh peers")
                        .font(ThemeStore.shared.font(size: 12))
                        .foregroundColor(theme.onSurfaceVariant)
                        .padding(24)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 6) {
                        ForEach(filteredPeers) { peer in
                            peerRow(peer)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(12)
        .background(theme.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func peerRow(_ peer: TailscalePeer) -> some View {
        HStack(spacing: 12) {
            // Online indicator dot
            Circle()
                .fill(peer.online ? Color.green : theme.outlineVariant)
                .frame(width: 8, height: 8)

            // OS icon
            Image(systemName: osSymbol(for: peer.os))
                .font(ThemeStore.shared.font(size: 14))
                .foregroundColor(peer.online ? theme.primary : theme.onSurfaceVariant)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(peer.hostName)
                        .font(ThemeStore.shared.font(size: 13, weight: peer.online ? .bold : .medium))
                        .foregroundColor(peer.online ? theme.onSurface : theme.onSurfaceVariant)
                        .lineLimit(1)

                    if peer.isExitNode || tailscale.activeExitNodeID == peer.id {
                        Text("EXIT")
                            .font(ThemeStore.shared.font(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(theme.onPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(theme.primary)
                            .clipShape(Capsule())
                    }
                }

                Text(peer.primaryIPv4 ?? peer.ips.first ?? peer.dnsName)
                    .font(ThemeStore.shared.font(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.onSurfaceVariant)
                    .lineLimit(1)
            }

            Spacer()

            // Click-to-copy IP button
            if let ip = peer.primaryIPv4 ?? peer.ips.first, !ip.isEmpty {
                Button {
                    tailscale.copyPeerIP(ip, hostName: peer.hostName)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(ThemeStore.shared.font(size: 10, weight: .bold))
                        Text(ip)
                            .font(ThemeStore.shared.font(size: 10, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(theme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.primaryContainer)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Copy \(ip)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(peer.online ? 1.0 : 0.55)
    }

    // MARK: - System VPN Tunnels Card
    private var systemVPNCcard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SYSTEM VPN TUNNELS")
                .font(ThemeStore.shared.font(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(theme.outline)

            HStack(spacing: 12) {
                Image(systemName: vpn.isConnected ? "lock.shield.fill" : "lock.shield")
                    .font(ThemeStore.shared.font(size: 15, weight: .bold))
                    .foregroundColor(vpn.isConnected ? theme.primary : theme.onSurfaceVariant)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(vpn.isConnected ? "VPN tunnel active" : "No system VPN active")
                        .font(ThemeStore.shared.font(size: 13, weight: .semibold))
                        .foregroundColor(theme.onSurface)
                    if let iface = vpn.activeInterface {
                        Text("Interface: \(iface)")
                            .font(ThemeStore.shared.font(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                }

                Spacer()

                Button {
                    vpn.openVPNSettings()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                        Text("Open macOS VPN Settings")
                    }
                    .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                    .foregroundColor(theme.onSurface)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.surfaceContainer)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(theme.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Helpers
    private func osSymbol(for os: String) -> String {
        switch os.lowercased() {
        case "macos", "darwin", "ios":
            return os.lowercased() == "ios" ? "iphone" : "laptopcomputer"
        case "linux":
            return "server.rack"
        case "windows":
            return "desktopcomputer"
        case "android":
            return "smartphone"
        default:
            return "desktopcomputer"
        }
    }

    private func osBadgeLabel(_ os: String) -> String {
        let lower = os.lowercased()
        if lower.isEmpty { return "unknown" }
        return lower.capitalized
    }
}
