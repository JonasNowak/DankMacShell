import Foundation

/// Entry storing launch count and last launch date for a specific application or item.
public struct FrecencyEntry: Sendable, Codable, Equatable {
    public var launchCount: Int
    public var lastLaunchedAt: Date

    public init(launchCount: Int = 1, lastLaunchedAt: Date = Date()) {
        self.launchCount = launchCount
        self.lastLaunchedAt = lastLaunchedAt
    }
}

/// Persistent frecency store for DLauncherV2.
/// Tracks application launches, persists them to disk asynchronously, and calculates
/// frecency scores based on `docs/spec/18-launcher.md`.
public final class LauncherFrecencyStore: @unchecked Sendable {
    public static let shared = LauncherFrecencyStore()

    private let lock = NSLock()
    private var entries: [String: FrecencyEntry] = [:]
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let url = fileURL {
            self.fileURL = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
            let dmsDir = appSupport.appendingPathComponent("DMS", isDirectory: true)
            self.fileURL = dmsDir.appendingPathComponent("frecency.json")
        }
        loadFromDisk()
    }

    /// Records an application launch, incrementing its launch count and updating the last launch timestamp.
    public func recordLaunch(id: String, date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }

        if var existing = entries[id] {
            existing.launchCount += 1
            existing.lastLaunchedAt = date
            entries[id] = existing
        } else {
            entries[id] = FrecencyEntry(launchCount: 1, lastLaunchedAt: date)
        }

        saveToDiskAsync()
    }

    /// Retrieves the launch count and last launch date for an identifier.
    public func launchInfo(for id: String) -> (count: Int, lastLaunch: Date?) {
        lock.lock()
        defer { lock.unlock() }
        if let entry = entries[id] {
            return (entry.launchCount, entry.lastLaunchedAt)
        }
        return (0, nil)
    }

    /// Calculates the frecency score for an application ID at the current moment.
    public func frecencyScore(for id: String, now: Date = Date()) -> Int {
        let (count, lastLaunch) = launchInfo(for: id)
        return LauncherScorer.calculateFrecency(launchCount: count, lastLaunch: lastLaunch, now: now)
    }

    /// Clears all frecency records (useful for testing or cache reset).
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
        saveToDiskAsync()
    }

    // MARK: - Persistence
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([String: FrecencyEntry].self, from: data)
            lock.lock()
            self.entries = decoded
            lock.unlock()
        } catch {
            // Silently fallback if corrupted
        }
    }

    private func saveToDiskAsync() {
        let snapshot = entries
        let target = fileURL
        Task.detached(priority: .utility) {
            do {
                let dir = target.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: dir.path) {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                }
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: target, options: .atomic)
            } catch {
                // Ignore background write failures
            }
        }
    }
}
