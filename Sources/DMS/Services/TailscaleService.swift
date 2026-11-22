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
        Task.detached(priority: .utility) { [weak self] in
            _ = SafeProcessRunner.run(executablePath: path, arguments: [command], timeout: 4.0)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            Task { @MainActor [weak self] in
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

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    // MARK: - Status JSON

    private struct TailscaleStatusJSON: Decodable {
        let BackendState: String?
        let selfNode: SelfNode?
        let CurrentTailnet: TailnetInfo?
        let ExitNodeStatus: ExitNodeStatus?

        enum CodingKeys: String, CodingKey {
            case BackendState
            case selfNode = "Self"
            case CurrentTailnet
            case ExitNodeStatus
        }

        struct SelfNode: Decodable {
            let TailscaleIPs: [String]?
        }

        struct TailnetInfo: Decodable {
            let Name: String?
        }

        struct ExitNodeStatus: Decodable {
            let Online: Bool?
        }
    }

    private func applyStatusJSON(_ json: String) {
        guard let data = json.data(using: .utf8),
              let status = try? JSONDecoder().decode(TailscaleStatusJSON.self, from: data) else {
            return
        }
        isConnected = status.BackendState == "Running"
        selfIP = status.selfNode?.TailscaleIPs?.first ?? ""
        tailnetName = status.CurrentTailnet?.Name ?? ""
        exitNodeActive = status.ExitNodeStatus != nil
    }
}
