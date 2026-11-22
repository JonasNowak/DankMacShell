import Foundation
import Combine
import AppKit
import DMSCore

/// Live Tailscale mesh status backing the `tailscale-status` plugin bar widget.
/// Polls `tailscale status --json` every 15s only while `start()` is active;
/// `stop()` cancels the timer immediately.
@MainActor
public final class TailscaleService: ObservableObject {
    public static let shared = TailscaleService()

    @Published public private(set) var isInstalled: Bool = false
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var tailnetName: String = ""
    @Published public private(set) var selfIP: String = ""
    @Published public private(set) var exitNodeActive: Bool = false
    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var selfHostName: String = ""
    @Published public private(set) var selfDNSName: String = ""
    @Published public private(set) var peers: [TailscalePeer] = []
    @Published public private(set) var exitNodeCandidates: [TailscalePeer] = []
    @Published public private(set) var activeExitNodeName: String? = nil
    @Published public private(set) var activeExitNodeID: String? = nil
    @Published public private(set) var isBusy: Bool = false

    public var barLabel: String {
        if !isInstalled {
            return "No Tailscale"
        }
        if isConnected {
            var label = tailnetName.isEmpty ? "Tailscale" : tailnetName
            if exitNodeActive {
                label += " • Exit"
            }
            return label
        }
        return "Tailscale Off"
    }

    private static let candidateBinaryPaths = [
        "/opt/homebrew/bin/tailscale",
        "/usr/local/bin/tailscale",
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    ]

    private static let pollInterval: TimeInterval = 15.0

    private var timer: Timer?

    private var binaryPath: String? {
        Self.candidateBinaryPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private init() {}

    public func start() {
        isEnabled = true
        refresh()
        startTimer()
    }

    public func stop() {
        isEnabled = false
        timer?.invalidate()
        timer = nil
    }

    public func refresh() {
        guard let path = binaryPath else {
            isInstalled = false
            isConnected = false
            tailnetName = ""
            selfIP = ""
            exitNodeActive = false
            selfHostName = ""
            selfDNSName = ""
            peers = []
            exitNodeCandidates = []
            activeExitNodeName = nil
            activeExitNodeID = nil
            return
        }
        isInstalled = true
        Task.detached(priority: .utility) { [weak self] in
            let result = SafeProcessRunner.run(
                executablePath: path,
                arguments: ["status", "--json"],
                timeout: 4.0
            )
            guard let output = try? result.get(), !output.timedOut,
                  let json = String(data: output.stdout, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.applyStatusJSON(json)
            }
        }
    }

    public func toggleConnection() {
        guard let path = binaryPath else { return }
        let command = isConnected ? "down" : "up"
        isBusy = true
        ToastCenter.shared.show(
            icon: command == "up" ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
            message: command == "up" ? "Connecting Tailscale..." : "Disconnecting Tailscale..."
        )
        Task.detached(priority: .utility) { [weak self] in
            _ = SafeProcessRunner.run(executablePath: path, arguments: [command], timeout: 4.0)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            Task { @MainActor [weak self] in
                self?.isBusy = false
                self?.refresh()
            }
        }
    }

    /// Sets the exit node to `target` (an IP or host name); pass an empty string to clear
    /// (`tailscale set --exit-node=`). Shows toast feedback and refreshes status after 1s.
    public func setExitNode(_ target: String) {
        guard let path = binaryPath else { return }
        isBusy = true
        let clearing = target.isEmpty
        ToastCenter.shared.show(
            icon: "network.badge.shield.half.filled",
            message: clearing ? "Clearing exit node..." : "Setting exit node to \(target)..."
        )
        Task.detached(priority: .utility) { [weak self] in
            _ = SafeProcessRunner.run(
                executablePath: path,
                arguments: ["set", "--exit-node=\(target)"],
                timeout: 6.0
            )
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            Task { @MainActor [weak self] in
                self?.isBusy = false
                self?.refresh()
            }
        }
    }

    public func copyIP() {
        guard !selfIP.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selfIP, forType: .string)
        ToastCenter.shared.show(icon: "doc.on.doc.fill", message: "Copied \(selfIP)")
    }

    /// Copies a peer's IP to the pasteboard and confirms with a toast.
    public func copyPeerIP(_ ip: String, hostName: String) {
        guard !ip.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ip, forType: .string)
        ToastCenter.shared.show(icon: "doc.on.doc.fill", message: "Copied \(ip) (\(hostName))")
    }

    /// Opens the Tailscale admin console (machine list) in the default browser.
    public func openAdminConsole() {
        if let url = URL(string: "https://login.tailscale.com/admin/machines") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    // MARK: - Status JSON

    private func applyStatusJSON(_ json: String) {
        guard let snapshot = TailscaleStatusParser.parse(json: json) else {
            return
        }
        isConnected = snapshot.isConnected
        selfIP = snapshot.selfIP
        tailnetName = snapshot.tailnetName
        selfHostName = snapshot.selfHostName
        selfDNSName = snapshot.selfDNSName
        peers = snapshot.peers
        exitNodeCandidates = snapshot.exitNodeCandidates
        activeExitNodeID = snapshot.activeExitNodeID
        activeExitNodeName = snapshot.activeExitNodeName
        exitNodeActive = snapshot.activeExitNodeID != nil
    }
}
