import Foundation

/// A single Tailscale mesh peer decoded from `tailscale status --json`.
public struct TailscalePeer: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var hostName: String
    public var dnsName: String
    public var ips: [String]
    public var os: String
    public var online: Bool
    public var active: Bool
    public var isExitNode: Bool
    public var offersExitNode: Bool
    public var relay: String

    public init(
        id: String,
        hostName: String,
        dnsName: String = "",
        ips: [String] = [],
        os: String = "",
        online: Bool = false,
        active: Bool = false,
        isExitNode: Bool = false,
        offersExitNode: Bool = false,
        relay: String = ""
    ) {
        self.id = id
        self.hostName = hostName
        self.dnsName = dnsName
        self.ips = ips
        self.os = os
        self.online = online
        self.active = active
        self.isExitNode = isExitNode
        self.offersExitNode = offersExitNode
        self.relay = relay
    }

    /// First IPv4 address (Tailscale lists the CGNAT IPv4 first, but be defensive).
    public var primaryIPv4: String? {
        ips.first { !$0.contains(":") } ?? ips.first
    }
}

/// Immutable snapshot of a full `tailscale status --json` payload.
public struct TailscaleStatusSnapshot: Codable, Sendable, Equatable {
    public var backendState: String
    public var isConnected: Bool
    public var tailnetName: String
    public var selfHostName: String
    public var selfDNSName: String
    public var selfIP: String
    public var activeExitNodeID: String?
    public var activeExitNodeName: String?
    public var peers: [TailscalePeer]

    public init(
        backendState: String = "",
        isConnected: Bool = false,
        tailnetName: String = "",
        selfHostName: String = "",
        selfDNSName: String = "",
        selfIP: String = "",
        activeExitNodeID: String? = nil,
        activeExitNodeName: String? = nil,
        peers: [TailscalePeer] = []
    ) {
        self.backendState = backendState
        self.isConnected = isConnected
        self.tailnetName = tailnetName
        self.selfHostName = selfHostName
        self.selfDNSName = selfDNSName
        self.selfIP = selfIP
        self.activeExitNodeID = activeExitNodeID
        self.activeExitNodeName = activeExitNodeName
        self.peers = peers
    }

    public var onlinePeers: [TailscalePeer] {
        peers.filter { $0.online }
    }

    public var offlinePeers: [TailscalePeer] {
        peers.filter { !$0.online }
    }

    /// Peers advertising exit-node capability (`ExitNodeOption` in the raw payload).
    public var exitNodeCandidates: [TailscalePeer] {
        peers.filter { $0.offersExitNode }
    }
}

/// Pure-logic decoder for `tailscale status --json` output.
public enum TailscaleStatusParser: Sendable {

    /// Parses a full `tailscale status --json` payload into a snapshot.
    /// Returns nil for invalid JSON; missing sections decode as empty defaults.
    /// Peers are sorted online-first, then alphabetically by host name.
    public static func parse(json: String) -> TailscaleStatusSnapshot? {
        guard let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        guard let raw = try? decoder.decode(StatusJSON.self, from: data) else { return nil }

        let selfNode = raw.selfNode
        let selfIPs = selfNode?.TailscaleIPs ?? []
        let selfIP = selfIPs.first { !$0.contains(":") } ?? selfIPs.first ?? ""

        var peers: [TailscalePeer] = []
        for (key, peerJSON) in raw.Peer ?? [:] {
            let id = peerJSON.ID?.isEmpty == false ? peerJSON.ID! : key
            peers.append(TailscalePeer(
                id: id,
                hostName: peerJSON.HostName ?? "",
                dnsName: peerJSON.DNSName ?? "",
                ips: peerJSON.TailscaleIPs ?? [],
                os: peerJSON.OS ?? "",
                online: peerJSON.Online ?? false,
                active: peerJSON.Active ?? false,
                isExitNode: peerJSON.ExitNode ?? false,
                offersExitNode: peerJSON.ExitNodeOption ?? false,
                relay: peerJSON.Relay ?? ""
            ))
        }
        peers.sort { lhs, rhs in
            if lhs.online != rhs.online { return lhs.online }
            return lhs.hostName.localizedCaseInsensitiveCompare(rhs.hostName) == .orderedAscending
        }

        let exitStatus = raw.ExitNodeStatus
        let exitNodeID = exitStatus?.ID?.isEmpty == false ? exitStatus!.ID : nil
        let exitNodeIPs = exitStatus?.TailscaleIPs ?? []
        let activeExitNodeName: String? = {
            if let exitNodeID {
                if let match = peers.first(where: { $0.id == exitNodeID }) {
                    return match.hostName
                }
            }
            if let ip = exitNodeIPs.first,
               let match = peers.first(where: { $0.ips.contains(ip) }) {
                return match.hostName
            }
            return nil
        }()

        return TailscaleStatusSnapshot(
            backendState: raw.BackendState ?? "",
            isConnected: raw.BackendState == "Running",
            tailnetName: raw.CurrentTailnet?.Name ?? "",
            selfHostName: selfNode?.HostName ?? "",
            selfDNSName: selfNode?.DNSName ?? "",
            selfIP: selfIP,
            activeExitNodeID: exitNodeID,
            activeExitNodeName: activeExitNodeName,
            peers: peers
        )
    }

    // MARK: - Raw JSON shapes

    private struct StatusJSON: Decodable {
        let BackendState: String?
        let selfNode: SelfJSON?
        let CurrentTailnet: TailnetJSON?
        let Peer: [String: PeerJSON]?
        let ExitNodeStatus: ExitNodeStatusJSON?

        enum CodingKeys: String, CodingKey {
            case BackendState
            case selfNode = "Self"
            case CurrentTailnet
            case Peer
            case ExitNodeStatus
        }
    }

    private struct SelfJSON: Decodable {
        let HostName: String?
        let DNSName: String?
        let TailscaleIPs: [String]?
    }

    private struct TailnetJSON: Decodable {
        let Name: String?
    }

    private struct PeerJSON: Decodable {
        let ID: String?
        let HostName: String?
        let DNSName: String?
        let TailscaleIPs: [String]?
        let OS: String?
        let Online: Bool?
        let Active: Bool?
        let ExitNode: Bool?
        let ExitNodeOption: Bool?
        let Relay: String?
    }

    private struct ExitNodeStatusJSON: Decodable {
        let ID: String?
        let Online: Bool?
        let TailscaleIPs: [String]?
    }
}
