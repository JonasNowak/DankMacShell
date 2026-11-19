import Foundation
import os
import DMSCore

/// Checks GitHub for a newer DankMacShell release and publishes the result.
/// Automatic checks run at most once every 6 hours; `checkNow(force:)` bypasses the interval.
@MainActor
public final class UpdateCheckService: ObservableObject {
    public static let shared = UpdateCheckService()

    private nonisolated static let log = Logger(subsystem: "com.dank.macshell", category: "UpdateCheckService")

    private static let releasesURL = URL(string: "https://api.github.com/repos/JonasNowak/DankMacShell/releases/latest")!
    private static let minCheckInterval: TimeInterval = 6 * 60 * 60 // 6 hours
    private static let lastCheckDefaultsKey = "com.dank.macshell.updateCheck.lastCheck"

    @Published public private(set) var hasUpdate: Bool = false
    @Published public private(set) var latestVersion: String? = nil
    @Published public private(set) var releaseURL: URL? = nil
    @Published public private(set) var isChecking: Bool = false

    private var checkTask: Task<Void, Never>?

    private init() {}

    /// Current app version from the bundle, falling back to `DMSVersion.current`.
    private static func currentVersion() -> String {
        DMSVersion.displayVersion
    }

    /// Compares two `vX.Y.Z`-style version strings; returns true when `latest` is newer than `current`.
    nonisolated private static func isNewer(latest: String, current: String) -> Bool {
        func components(_ v: String) -> [Int] {
            v.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                .split(separator: "-").first.map { $0.split(separator: ".").compactMap { Int($0) } } ?? []
        }
        let a = components(latest)
        let b = components(current)
        let count = max(a.count, b.count)
        for i in 0..<count {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }

    /// Runs an update check unless one ran within the last 6 hours (unless `force`).
    public func checkNow(force: Bool = false) {
        if !force {
            let last = UserDefaults.standard.double(forKey: Self.lastCheckDefaultsKey)
            if last > 0 && Date().timeIntervalSince1970 - last < Self.minCheckInterval {
                return
            }
        }
        checkTask?.cancel()
        checkTask = Task { @MainActor in
            await performCheck()
        }
    }

    private func performCheck() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckDefaultsKey)

        var request = URLRequest(url: Self.releasesURL)
        request.timeoutInterval = 15
        request.setValue("DankMacShell/0.9.0 (https://github.com/JonasNowak/DankMacShell)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                Self.log.error("Update check failed: HTTP \\( (response as? HTTPURLResponse)?.statusCode ?? -1 )")
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                Self.log.error("Update check failed: malformed release payload")
                return
            }
            let htmlURL = (json["html_url"] as? String).flatMap { URL(string: $0) }
            let current = Self.currentVersion()
            let newer = Self.isNewer(latest: tag, current: current)

            latestVersion = tag
            releaseURL = htmlURL
            hasUpdate = newer
            if newer {
                Self.log.info("Update available: \\(tag) (current \\(current))")
            }
        } catch {
            if !Task.isCancelled {
                Self.log.error("Update check failed: \\(error.localizedDescription)")
            }
        }
    }
}
