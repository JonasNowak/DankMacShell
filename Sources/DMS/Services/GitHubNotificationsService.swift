import Foundation
import Combine
import AppKit
import DMSCore

/// Live GitHub unread-notification counter backing the `github-notifications` plugin
/// bar widget. Polls `gh api notifications --jq length` every 60s only while
/// `start()` is active; `stop()` cancels the timer immediately.
@MainActor
public final class GitHubNotificationsService: ObservableObject {
    public static let shared = GitHubNotificationsService()

    @Published public private(set) var isAvailable: Bool = false
    @Published public private(set) var unreadCount: Int = 0
    @Published public private(set) var isEnabled: Bool = false

    private static let candidateBinaryPaths = [
        "/opt/homebrew/bin/gh",
        "/usr/local/bin/gh",
        "/usr/bin/gh"
    ]

    private static let pollInterval: TimeInterval = 60.0

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
            isAvailable = false
            unreadCount = 0
            return
        }
        isAvailable = true
        Task.detached(priority: .utility) { [weak self] in
            let result = SafeProcessRunner.run(
                executablePath: path,
                arguments: ["api", "notifications", "--jq", "length"],
                timeout: 6.0
            )
            guard let output = try? result.get(), !output.timedOut,
                  let stdout = String(data: output.stdout, encoding: .utf8),
                  let count = Int(stdout.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return
            }
            Task { @MainActor [weak self] in
                self?.unreadCount = count
            }
        }
    }

    public func openNotifications() {
        guard let url = URL(string: "https://github.com/notifications") else { return }
        NSWorkspace.shared.open(url)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }
}
