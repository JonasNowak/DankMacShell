import Foundation
import Combine
import DMSCore

/// Fetches, caches and tracks synchronized (LRC) lyrics for the currently playing track.
///
/// - Lyrics are fetched from LRCLIB (`/api/get`, falling back to `/api/search`) and cached
///   in memory (LRU) and on disk (`~/Library/Application Support/DMS/lyrics_cache/`).
/// - The 10 Hz sync loop runs ONLY while the track is playing, synced lyrics are loaded
///   and at least one lyric UI consumer is visible.
@MainActor
public final class LyricsService: ObservableObject {
    public static let shared = LyricsService()

    @Published public private(set) var currentLyrics: ParsedLyrics?
    @Published public private(set) var activeLineIndex: Int?
    @Published public private(set) var activeWordIndex: Int?
    @Published public private(set) var activeLineText: String = ""
    @Published public private(set) var isLoading: Bool = false
    /// Whether the interactive lyrics view is requested/visible (set by DankDash and the bar widget).
    @Published public var isLyricsOverlayVisible: Bool = false

    // MARK: - Private state

    private static let lruCapacity = 32
    private static let syncIntervalNs: UInt64 = 100_000_000 // 100 ms (10 Hz)
    private nonisolated static let userAgent = "DankMacShell/0.6.0 (https://github.com/jonasnowak/DankMacShell)"

    private var consumers: [String: Int] = [:]
    private var syncTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    private var currentKey: String?
    private var holdsPositionRef = false

    private var memoryCache: [String: ParsedLyrics] = [:]
    private var lruOrder: [String] = []
    private var notFoundKeys: Set<String> = []

    private var cancellables = Set<AnyCancellable>()
    private var lastIdentity: TrackIdentity?

    private struct TrackIdentity: Equatable {
        let title: String
        let artist: String
        let album: String
        let duration: Int
    }

    private init() {
        // `@Published` emits in willSet; hop to the next main-queue turn so reads of the
        // services' state observe the committed value.
        NowPlayingService.shared.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.handleTrackUpdate(track)
            }
            .store(in: &cancellables)

        ConfigStore.shared.$config
            .map { $0.enableLyrics }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self = self else { return }
                if enabled {
                    self.ensureLoaded()
                } else {
                    self.cancelFetch()
                    self.apply(nil)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    public var isEnabled: Bool { ConfigStore.shared.config.enableLyrics }

    /// Registers a visible lyric UI (e.g. "bar.lyric", "island.media", "dash.media").
    public func addConsumer(_ id: String) {
        let wasEmpty = consumers.isEmpty
        consumers[id, default: 0] += 1
        if wasEmpty {
            NowPlayingService.shared.addPositionRef("lyrics")
            holdsPositionRef = true
        }
        ensureLoaded()
        reevaluateTimer()
    }

    /// Releases a lyric UI consumer. The last release stops the sync loop and the position ref.
    public func removeConsumer(_ id: String) {
        guard let count = consumers[id] else { return }
        if count <= 1 { consumers.removeValue(forKey: id) } else { consumers[id] = count - 1 }
        if consumers.isEmpty, holdsPositionRef {
            NowPlayingService.shared.removePositionRef("lyrics")
            holdsPositionRef = false
        }
        reevaluateTimer()
    }

    /// Loads lyrics for the current track if none are loaded yet (respects `enableLyrics`).
    public func ensureLoaded() {
        let track = NowPlayingService.shared.currentTrack
        guard let key = Self.key(for: track), isEnabled else { return }
        if currentKey == key, (currentLyrics != nil || isLoading || notFoundKeys.contains(key)) { return }
        load(track: track, key: key, force: false)
    }

    /// Re-fetches lyrics for the current track, bypassing memory and disk caches.
    public func refresh() {
        let track = NowPlayingService.shared.currentTrack
        guard let key = Self.key(for: track) else { return }
        notFoundKeys.remove(key)
        memoryCache.removeValue(forKey: key)
        lruOrder.removeAll { $0 == key }
        load(track: track, key: key, force: true)
    }

    /// Clears the in-memory LRU and every file in the disk cache.
    public func clearCache() {
        memoryCache.removeAll()
        lruOrder.removeAll()
        notFoundKeys.removeAll()
        let dir = Self.cacheDirectory
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for f in files { try? fm.removeItem(at: f) }
            }
        }
    }

    /// Persists the global timing offset (ms; positive = lyrics appear earlier).
    public func setOffset(ms: Int) {
        let clamped = min(10_000, max(-10_000, ms))
        ConfigStore.shared.update { $0.lyricsOffsetMs = clamped }
        updateActive(elapsed: NowPlayingService.shared.currentTrack.interpolatedElapsed())
    }

    /// Human-readable status for `dms lyrics status`.
    public func statusSummary() -> String {
        let track = NowPlayingService.shared.currentTrack
        var parts: [String] = []
        parts.append("Enabled: \(isEnabled)")
        parts.append("Track: \(track.title.isEmpty ? "-" : track.title) - \(track.artist)")
        if isLoading {
            parts.append("State: loading")
        } else if let l = currentLyrics {
            if l.instrumental { parts.append("State: instrumental") }
            else if l.isSynced { parts.append("State: synced (\(l.lines.count) lines)") }
            else if !l.plainLyrics.isEmpty { parts.append("State: plain (unsynced)") }
            else { parts.append("State: empty") }
        } else {
            parts.append("State: none")
        }
        parts.append("Offset: \(ConfigStore.shared.config.lyricsOffsetMs) ms")
        parts.append("Sync loop: \(syncTask != nil ? "running (10 Hz)" : "idle")")
        parts.append("Active line: \(activeLineText.isEmpty ? "-" : activeLineText)")
        return parts.joined(separator: "\n")
    }

    // MARK: - Track tracking

    private static func key(for track: NowPlayingTrack) -> String? {
        guard !track.title.isEmpty, track.title != "No Track Playing" else { return nil }
        return LRCLyricsParser.cacheKey(title: track.title, artist: track.artist, album: track.album, duration: track.durationSeconds)
    }

    private func identity(of track: NowPlayingTrack) -> TrackIdentity? {
        guard !track.title.isEmpty, track.title != "No Track Playing" else { return nil }
        return TrackIdentity(title: track.title, artist: track.artist, album: track.album, duration: Int(track.durationSeconds.rounded()))
    }

    private func handleTrackUpdate(_ track: NowPlayingTrack) {
        let ident = identity(of: track)
        if ident != lastIdentity {
            lastIdentity = ident
            cancelFetch()
            currentKey = nil
            apply(nil)
            if ident != nil, !consumers.isEmpty { ensureLoaded() }
        }
        updateActive(elapsed: track.interpolatedElapsed())
        reevaluateTimer()
    }

    // MARK: - Loading

    private func cancelFetch() {
        fetchTask?.cancel()
        fetchTask = nil
        isLoading = false
    }

    private func load(track: NowPlayingTrack, key: String, force: Bool) {
        cancelFetch()
        currentKey = key

        if !force {
            if let cached = memoryCache[key] {
                touch(key)
                apply(cached)
                return
            }
            if notFoundKeys.contains(key) {
                apply(nil)
                return
            }
        }

        let title = track.title
        let artist = track.artist
        let album = track.album
        let duration = track.durationSeconds
        isLoading = true
        apply(nil)

        fetchTask = Task { @MainActor [weak self] in
            if !force, let disk = await Self.readDisk(key: key) {
                guard let self = self, !Task.isCancelled, self.currentKey == key else { return }
                self.finish(key: key, result: .found(disk), persist: false)
                return
            }
            let result = await Self.fetchFromLRCLIB(title: title, artist: artist, album: album, duration: duration)
            guard let self = self, !Task.isCancelled, self.currentKey == key else { return }
            self.finish(key: key, result: result, persist: true)
        }
    }

    private enum FetchResult: Sendable {
        case found(ParsedLyrics)
        case notFound
        case failed
    }

    private func finish(key: String, result: FetchResult, persist: Bool) {
        isLoading = false
        fetchTask = nil
        switch result {
        case .found(let lyrics):
            remember(key: key, lyrics: lyrics)
            if persist { Self.writeDisk(key: key, lyrics: lyrics) }
            apply(lyrics)
        case .notFound:
            notFoundKeys.insert(key)
            apply(nil)
        case .failed:
            apply(nil) // transient (offline etc.): not cached, retried on refresh / next track change
        }
    }

    private func apply(_ lyrics: ParsedLyrics?) {
        if currentLyrics != lyrics { currentLyrics = lyrics }
        updateActive(elapsed: NowPlayingService.shared.currentTrack.interpolatedElapsed())
        reevaluateTimer()
    }

    // MARK: - LRU

    private func touch(_ key: String) {
        lruOrder.removeAll { $0 == key }
        lruOrder.append(key)
    }

    private func remember(key: String, lyrics: ParsedLyrics) {
        memoryCache[key] = lyrics
        touch(key)
        while lruOrder.count > Self.lruCapacity {
            let evicted = lruOrder.removeFirst()
            memoryCache.removeValue(forKey: evicted)
        }
    }

    // MARK: - Sync loop (10 Hz, only while needed)

    private var shouldRunTimer: Bool {
        guard isEnabled, !consumers.isEmpty, let lyrics = currentLyrics, lyrics.isSynced else { return false }
        return NowPlayingService.shared.currentTrack.isPlaying
    }

    private func reevaluateTimer() {
        if shouldRunTimer {
            guard syncTask == nil else { return }
            syncTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    guard let self = self else { return }
                    self.tick()
                    try? await Task.sleep(nanoseconds: Self.syncIntervalNs)
                }
            }
        } else {
            syncTask?.cancel()
            syncTask = nil
        }
    }

    private func tick() {
        updateActive(elapsed: NowPlayingService.shared.currentTrack.interpolatedElapsed())
    }

    /// Updates published indices only when they change, so 10 Hz ticks don't re-render observers needlessly.
    private func updateActive(elapsed: Double) {
        guard let lyrics = currentLyrics, lyrics.isSynced else {
            if activeLineIndex != nil { activeLineIndex = nil }
            if activeWordIndex != nil { activeWordIndex = nil }
            if !activeLineText.isEmpty { activeLineText = "" }
            return
        }
        let offset = ConfigStore.shared.config.lyricsOffsetMs
        let line = LRCLyricsParser.activeLineIndex(at: elapsed, in: lyrics, additionalOffsetMs: offset)
        let word = LRCLyricsParser.activeWordIndex(at: elapsed, in: lyrics, additionalOffsetMs: offset)
        let text = line.map { lyrics.lines[$0].text } ?? ""
        if activeLineIndex != line { activeLineIndex = line }
        if activeWordIndex != word { activeWordIndex = word }
        if activeLineText != text { activeLineText = text }
    }

    // MARK: - Disk cache

    private nonisolated static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("DMS/lyrics_cache", isDirectory: true)
    }

    private nonisolated static func readDisk(key: String) async -> ParsedLyrics? {
        let file = cacheDirectory.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(ParsedLyrics.self, from: data)
    }

    private static func writeDisk(key: String, lyrics: ParsedLyrics) {
        let dir = cacheDirectory
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            guard let data = try? JSONEncoder().encode(lyrics) else { return }
            try? data.write(to: dir.appendingPathComponent("\(key).json"), options: .atomic)
        }
    }

    // MARK: - LRCLIB client

    private nonisolated static func request(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    private nonisolated static func fetchFromLRCLIB(title: String, artist: String, album: String, duration: Double) async -> FetchResult {
        // 1. Exact match: /api/get
        var get = URLComponents(string: "https://lrclib.net/api/get")
        var items = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        if !album.isEmpty { items.append(URLQueryItem(name: "album_name", value: album)) }
        if duration > 0 { items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded())))) }
        get?.queryItems = items
        guard let getURL = get?.url else { return .failed }

        do {
            let (data, response) = try await URLSession.shared.data(for: request(getURL))
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200, let decoded = try? JSONDecoder().decode(LRCLIBResponse.self, from: data) {
                let parsed = LRCLyricsParser.parsed(from: decoded)
                if parsed.hasContent { return .found(parsed) }
            } else if status != 404 && status != 200 {
                return .failed
            }
        } catch {
            return .failed
        }

        // 2. Fallback: /api/search
        var search = URLComponents(string: "https://lrclib.net/api/search")
        search?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        guard let searchURL = search?.url else { return .failed }
        do {
            let (data, response) = try await URLSession.shared.data(for: request(searchURL))
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { return status == 404 ? .notFound : .failed }
            let results = (try? JSONDecoder().decode([LRCLIBResponse].self, from: data)) ?? []
            if let best = bestMatch(in: results, duration: duration) {
                let parsed = LRCLyricsParser.parsed(from: best)
                if parsed.hasContent { return .found(parsed) }
            }
            return .notFound
        } catch {
            return .failed
        }
    }

    /// Prefers synced results, then the closest duration match when duration is known.
    nonisolated static func bestMatch(in results: [LRCLIBResponse], duration: Double) -> LRCLIBResponse? {
        let usable = results.filter { r in
            !(r.syncedLyrics ?? "").isEmpty || !(r.plainLyrics ?? "").isEmpty || (r.instrumental ?? false)
        }
        guard !usable.isEmpty else { return nil }
        return usable.min { a, b in
            let aSynced = !(a.syncedLyrics ?? "").isEmpty
            let bSynced = !(b.syncedLyrics ?? "").isEmpty
            if aSynced != bSynced { return aSynced }
            let aDelta = (duration > 0 && a.duration != nil) ? abs(a.duration! - duration) : Double.greatestFiniteMagnitude
            let bDelta = (duration > 0 && b.duration != nil) ? abs(b.duration! - duration) : Double.greatestFiniteMagnitude
            return aDelta < bDelta
        }
    }
}
