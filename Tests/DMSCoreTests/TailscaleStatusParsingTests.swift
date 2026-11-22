import Testing
import Foundation
@testable import DMSCore

@Suite("Tailscale Status JSON Parsing Tests")
struct TailscaleStatusParsingTests {

    /// Full multi-peer `tailscale status --json` payload with an active exit node.
    private static let fullStatusJSON = #"""
    {
      "BackendState": "Running",
      "Self": {
        "ID": "nSelf123",
        "HostName": "jonas-macbook",
        "DNSName": "jonas-macbook.tailnet.ts.net.",
        "TailscaleIPs": ["100.64.0.1", "fd7a:115c:a1e0::1"]
      },
      "CurrentTailnet": { "Name": "tailnet" },
      "Peer": {
        "nOffline1": {
          "ID": "nOffline1",
          "HostName": "zeta-server",
          "DNSName": "zeta-server.tailnet.ts.net.",
          "TailscaleIPs": ["100.64.0.9"],
          "OS": "linux",
          "Online": false,
          "Active": false,
          "ExitNode": false,
          "ExitNodeOption": false,
          "Relay": ""
        },
        "nExit1": {
          "ID": "nExit1",
          "HostName": "exit-nyc",
          "DNSName": "exit-nyc.tailnet.ts.net.",
          "TailscaleIPs": ["100.64.0.2"],
          "OS": "linux",
          "Online": true,
          "Active": true,
          "ExitNode": true,
          "ExitNodeOption": true,
          "Relay": "nyc"
        },
        "nAlpha1": {
          "ID": "nAlpha1",
          "HostName": "alpha-phone",
          "DNSName": "alpha-phone.tailnet.ts.net.",
          "TailscaleIPs": ["100.64.0.3"],
          "OS": "ios",
          "Online": true,
          "Active": true,
          "ExitNodeOption": false
        },
        "nBeta1": {
          "ID": "nBeta1",
          "HostName": "beta-laptop",
          "DNSName": "beta-laptop.tailnet.ts.net.",
          "TailscaleIPs": ["100.64.0.4"],
          "OS": "macos",
          "Online": true,
          "Active": false,
          "ExitNodeOption": true,
          "Relay": "sea"
        }
      },
      "ExitNodeStatus": {
        "ID": "nExit1",
        "Online": true,
        "TailscaleIPs": ["100.64.0.2"]
      }
    }
    """#

    @Test("Full multi-peer payload parses self, tailnet, and backend state")
    func testFullPayloadCoreFields() {
        let snapshot = TailscaleStatusParser.parse(json: Self.fullStatusJSON)
        #expect(snapshot != nil)
        #expect(snapshot?.backendState == "Running")
        #expect(snapshot?.isConnected == true)
        #expect(snapshot?.tailnetName == "tailnet")
        #expect(snapshot?.selfHostName == "jonas-macbook")
        #expect(snapshot?.selfDNSName == "jonas-macbook.tailnet.ts.net.")
        // IPv4 preferred over the IPv6 address in TailscaleIPs
        #expect(snapshot?.selfIP == "100.64.0.1")
    }

    @Test("Peers parse with all fields and sort online-first then alphabetically")
    func testPeerParsingAndSorting() {
        let snapshot = TailscaleStatusParser.parse(json: Self.fullStatusJSON)
        #expect(snapshot?.peers.count == 4)

        let hostNames = snapshot?.peers.map { $0.hostName }
        #expect(hostNames == ["alpha-phone", "beta-laptop", "exit-nyc", "zeta-server"])

        let exitPeer = snapshot?.peers.first { $0.id == "nExit1" }
        #expect(exitPeer?.hostName == "exit-nyc")
        #expect(exitPeer?.dnsName == "exit-nyc.tailnet.ts.net.")
        #expect(exitPeer?.ips == ["100.64.0.2"])
        #expect(exitPeer?.os == "linux")
        #expect(exitPeer?.online == true)
        #expect(exitPeer?.active == true)
        #expect(exitPeer?.isExitNode == true)
        #expect(exitPeer?.offersExitNode == true)
        #expect(exitPeer?.relay == "nyc")
        #expect(exitPeer?.primaryIPv4 == "100.64.0.2")

        let offlinePeer = snapshot?.peers.first { $0.id == "nOffline1" }
        #expect(offlinePeer?.online == false)
        #expect(offlinePeer?.active == false)
        #expect(offlinePeer?.offersExitNode == false)
    }

    @Test("Computed helpers: onlinePeers, offlinePeers, exitNodeCandidates")
    func testComputedHelpers() {
        let snapshot = TailscaleStatusParser.parse(json: Self.fullStatusJSON)
        #expect(snapshot?.onlinePeers.count == 3)
        #expect(snapshot?.offlinePeers.count == 1)
        #expect(snapshot?.offlinePeers.first?.hostName == "zeta-server")

        let candidates = snapshot?.exitNodeCandidates.map { $0.hostName }
        #expect(candidates == ["beta-laptop", "exit-nyc"])
    }

    @Test("Exit node resolved by peer ID from ExitNodeStatus")
    func testExitNodeResolutionByID() {
        let snapshot = TailscaleStatusParser.parse(json: Self.fullStatusJSON)
        #expect(snapshot?.activeExitNodeID == "nExit1")
        #expect(snapshot?.activeExitNodeName == "exit-nyc")
    }

    @Test("Exit node resolved by Tailscale IP when ID does not match a peer")
    func testExitNodeResolutionByIPFallback() {
        let json = #"""
        {
          "BackendState": "Running",
          "Self": { "HostName": "mac", "TailscaleIPs": ["100.64.0.1"] },
          "Peer": {
            "nBeta1": {
              "ID": "nBeta1",
              "HostName": "beta-laptop",
              "TailscaleIPs": ["100.64.0.4"],
              "OS": "macos",
              "Online": true,
              "ExitNodeOption": true
            }
          },
          "ExitNodeStatus": { "ID": "stale-id", "Online": true, "TailscaleIPs": ["100.64.0.4"] }
        }
        """#
        let snapshot = TailscaleStatusParser.parse(json: json)
        #expect(snapshot?.activeExitNodeID == "stale-id")
        #expect(snapshot?.activeExitNodeName == "beta-laptop")
    }

    @Test("No exit node active yields nil ID and name")
    func testNoExitNode() {
        let json = #"""
        {
          "BackendState": "Running",
          "Self": { "HostName": "mac", "TailscaleIPs": ["100.64.0.1"] },
          "Peer": {}
        }
        """#
        let snapshot = TailscaleStatusParser.parse(json: json)
        #expect(snapshot?.activeExitNodeID == nil)
        #expect(snapshot?.activeExitNodeName == nil)
        #expect(snapshot?.peers.isEmpty == true)
        #expect(snapshot?.exitNodeCandidates.isEmpty == true)
    }

    @Test("Stopped backend state parses as disconnected")
    func testStoppedState() {
        let json = #"""
        {
          "BackendState": "Stopped",
          "Self": { "HostName": "mac", "DNSName": "mac.tailnet.ts.net.", "TailscaleIPs": ["100.64.0.1"] },
          "CurrentTailnet": { "Name": "tailnet" }
        }
        """#
        let snapshot = TailscaleStatusParser.parse(json: json)
        #expect(snapshot != nil)
        #expect(snapshot?.backendState == "Stopped")
        #expect(snapshot?.isConnected == false)
        #expect(snapshot?.tailnetName == "tailnet")
        #expect(snapshot?.peers.isEmpty == true)
    }

    @Test("Invalid JSON returns nil")
    func testInvalidJSON() {
        #expect(TailscaleStatusParser.parse(json: "not json at all") == nil)
        #expect(TailscaleStatusParser.parse(json: "") == nil)
        #expect(TailscaleStatusParser.parse(json: "{") == nil)
        #expect(TailscaleStatusParser.parse(json: "[1, 2, 3]") == nil)
    }

    @Test("Empty object decodes to a default snapshot, not nil")
    func testEmptyObjectDefaults() {
        let snapshot = TailscaleStatusParser.parse(json: "{}")
        #expect(snapshot != nil)
        #expect(snapshot?.backendState == "")
        #expect(snapshot?.isConnected == false)
        #expect(snapshot?.tailnetName == "")
        #expect(snapshot?.selfHostName == "")
        #expect(snapshot?.selfIP == "")
        #expect(snapshot?.peers == [])
        #expect(snapshot?.activeExitNodeID == nil)
    }

    @Test("Peer dictionary key used as ID when peer ID field is missing")
    func testPeerKeyFallbackID() {
        let json = #"""
        {
          "BackendState": "Running",
          "Peer": {
            "key-abc": { "HostName": "keyed-peer", "TailscaleIPs": ["100.64.0.7"], "Online": true }
          }
        }
        """#
        let snapshot = TailscaleStatusParser.parse(json: json)
        #expect(snapshot?.peers.count == 1)
        #expect(snapshot?.peers.first?.id == "key-abc")
        #expect(snapshot?.peers.first?.hostName == "keyed-peer")
        #expect(snapshot?.peers.first?.online == true)
        #expect(snapshot?.peers.first?.offersExitNode == false)
    }

    @Test("Snapshot Codable round-trip preserves equality")
    func testCodableRoundTrip() throws {
        guard let snapshot = TailscaleStatusParser.parse(json: Self.fullStatusJSON) else {
            Issue.record("expected snapshot to parse")
            return
        }
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(TailscaleStatusSnapshot.self, from: data)
        #expect(decoded == snapshot)
    }
}
