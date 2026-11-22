import Foundation
import AppKit
import CoreGraphics
import Darwin
import DMSCore

@_silgen_name("proc_pidpath")
func dms_proc_pidpath(_ pid: Int32, _ buffer: UnsafeMutableRawPointer, _ buffersize: UInt32) -> Int32

/// Service that monitors and controls media playback across macOS universally:
/// Apple Music, Spotify, VLC, and all MediaRemote / Web sources (Safari, Google Chrome,
/// Arc, Brave, TIDAL, YouTube, SoundCloud, Firefox, Zen Browser).
@MainActor
public final class NowPlayingService: ObservableObject {
    public static let shared = NowPlayingService()

    @Published public private(set) var currentTrack: NowPlayingTrack = NowPlayingTrack()

    /// 1 Hz high-frequency poll for live elapsed timeline and lyrics sync.
    private var pollTimer: Timer?
    /// Universal 2.0s idle heartbeat ensuring non-notifying sources (YouTube, Firefox, VLC) are detected quickly.
    private var heartbeatTimer: Timer?
    private static let idleHeartbeatInterval: TimeInterval = 2.0

    /// Reference-counted position consumers (media UIs that are currently visible).
    private var positionRefs: [String: Int] = [:]

    private var cachedArtwork: [String: Data] = [:]
    private var artworkCacheOrder: [String] = []
    private static let artworkCacheCapacity = 32
    private var isFetchingArtwork: Bool = false
    private var itunesInFlight: Set<String> = []
    private var itunesMisses: Set<String> = []
    private static let itunesMissesCapacity = 200

    /// Private artwork cache directory (0700) — never the predictable /tmp paths.
    nonisolated static let artworkDirectory: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/DMS/artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        return dir
    }()
    nonisolated static let nowPlayingArtworkURL = artworkDirectory.appendingPathComponent("nowplaying_art.jpg")
    nonisolated static let musicArtworkURL = artworkDirectory.appendingPathComponent("music_art.jpg")

    /// True when `bundleID` is present in the current NSWorkspace running applications.
    private static func isAppRunning(_ bundleID: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    private func cacheArtwork(_ data: Data, forKey key: String) {
        cachedArtwork[key] = data
        artworkCacheOrder.removeAll { $0 == key }
        artworkCacheOrder.append(key)
        while artworkCacheOrder.count > Self.artworkCacheCapacity {
            let evicted = artworkCacheOrder.removeFirst()
            cachedArtwork.removeValue(forKey: evicted)
        }
    }

    private func noteITunesMiss(_ key: String) {
        itunesMisses.insert(key)
        while itunesMisses.count > Self.itunesMissesCapacity {
            if let oldest = itunesMisses.first {
                itunesMisses.remove(oldest)
            } else {
                break
            }
        }
    }

    private var bridge: MediaRemoteBridge?
    private var bridgeTrack: NowPlayingTrack?

    private init() {
        setupDistributedNotifications()
        setupMediaRemoteBridge()
        updatePlaybackState()

        // 2.0s universal heartbeat on RunLoop.main in .common modes ensures it fires regardless of UI tracking.
        let timer = Timer(timeInterval: Self.idleHeartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlaybackState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        heartbeatTimer = timer

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bridge?.terminate()
            }
        }
    }

    private func setupMediaRemoteBridge() {
        bridge = MediaRemoteBridge { [weak self] track in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.bridgeTrack = track
                self.updatePlaybackState()
            }
        }
    }

    // MARK: - Position consumer ref-counting

    /// True while at least one visible media UI needs live position updates.
    public var hasPositionConsumers: Bool { !positionRefs.isEmpty }

    /// Registers a position consumer (e.g. "bar.media", "dash.media", "lyrics").
    public func addPositionRef(_ consumer: String) {
        let wasIdle = positionRefs.isEmpty
        positionRefs[consumer, default: 0] += 1
        if wasIdle {
            startPositionPolling()
        }
    }

    /// Releases a position consumer.
    public func removePositionRef(_ consumer: String) {
        guard let count = positionRefs[consumer] else { return }
        if count <= 1 {
            positionRefs.removeValue(forKey: consumer)
        } else {
            positionRefs[consumer] = count - 1
        }
        if positionRefs.isEmpty && !currentTrack.isPlaying {
            stopPositionPolling()
        }
    }

    private func startPositionPolling() {
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlaybackState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPositionPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func setupDistributedNotifications() {
        let center = DistributedNotificationCenter.default()

        // Apple Music notification
        center.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlaybackState()
            }
        }

        // Spotify notification
        center.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlaybackState()
            }
        }
    }

    private var isUpdatingPlayback = false

    public func updatePlaybackState() {
        guard !isUpdatingPlayback else { return }
        isUpdatingPlayback = true
        // Skip AppleScript/browser fallback polling while the MediaRemote bridge is
        // actively reporting — it already covers every MediaRemote-registered source.
        let bridgeReporting = self.bridge?.isActivelyReporting ?? false

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer { self.isUpdatingPlayback = false }

            let music: NowPlayingTrack?
            let spotify: NowPlayingTrack?
            let vlc: NowPlayingTrack?
            if bridgeReporting {
                music = nil
                spotify = nil
                vlc = nil
            } else {
                async let m = self.checkAppleMusic()
                async let s = self.checkSpotify()
                async let v = self.checkVLC()
                music = await m
                spotify = await s
                vlc = await v
            }
            let browser = bridgeReporting ? nil : self.checkBrowserWindows()
            let bridge = self.bridgeTrack

            // Priority 1: Actively playing sources win
            if let s = spotify, s.isPlaying {
                self.applyTrack(s)
                return
            }
            if let m = music, m.isPlaying {
                self.applyTrack(m)
                return
            }
            if let v = vlc, v.isPlaying {
                self.applyTrack(v)
                return
            }
            if let b = bridge, b.isPlaying {
                self.applyTrack(b)
                return
            }
            if let w = browser, w.isPlaying {
                self.applyTrack(w)
                return
            }

            // Priority 2: When paused/idle, show newest recent metadata across sources
            if let b = bridge, !b.title.isEmpty {
                self.applyTrack(b)
            } else if let s = spotify, !s.title.isEmpty {
                self.applyTrack(s)
            } else if let m = music, !m.title.isEmpty {
                self.applyTrack(m)
            } else if let v = vlc, !v.title.isEmpty {
                self.applyTrack(v)
            } else if let w = browser, !w.title.isEmpty {
                self.applyTrack(w)
            } else {
                if self.currentTrack.isPlaying {
                    self.currentTrack.isPlaying = false
                }
                if self.positionRefs.isEmpty {
                    self.stopPositionPolling()
                }
            }
        }
    }

    private func applyTrack(_ track: NowPlayingTrack) {
        let enhanced = withFallbackArtwork(track)
        self.currentTrack = enhanced
        if enhanced.isPlaying {
            startPositionPolling()
        } else if positionRefs.isEmpty {
            stopPositionPolling()
        }
        // v0.7 IPC: broadcast media changes to `dms listen events.media` subscribers
        EventSubscriptionBroker.shared.broadcast(event: "events.media", payload: [
            "title": enhanced.title,
            "artist": enhanced.artist,
            "album": enhanced.album,
            "isPlaying": enhanced.isPlaying,
            "app": enhanced.appName,
            "duration": enhanced.durationSeconds,
            "elapsed": enhanced.elapsedSeconds,
            "hasArtwork": enhanced.hasArtwork
        ])
    }

    // MARK: - Process Path Resolver

    nonisolated private static func resolveAppName(for pid: Int32) -> String? {
        guard pid > 0 else { return nil }
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        let ret = dms_proc_pidpath(pid, &pathBuffer, 4096)
        guard ret > 0 else { return nil }
        let path = String(cString: pathBuffer)
        let binary = (path as NSString).lastPathComponent

        // Check for .app bundle (e.g. ".../TIDAL.app/Contents/MacOS/TIDAL" -> "TIDAL")
        if let appRange = path.range(of: ".app/", options: .backwards) {
            let prefix = String(path[..<appRange.lowerBound])
            let appName = (prefix as NSString).lastPathComponent
            if !appName.isEmpty { return appName }
        }

        if binary.lowercased() == "zen" { return "Zen" }
        return binary
    }

    // MARK: - Apple Music

    private func checkAppleMusic() async -> NowPlayingTrack? {
        guard Self.isAppRunning("com.apple.Music") else { return nil }

        let script = """
        tell application "Music"
            try
                if player state is playing or player state is paused then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set dur to duration of current track
                    set pos to player position
                    set isPl to (player state is playing)
                    set hasArt to (count of artworks of current track) > 0
                    return trackName & "||" & artistName & "||" & albumName & "||" & dur & "||" & pos & "||" & isPl & "||" & hasArt
                end if
            on error
                return ""
            end try
        end tell
        """

        guard let output = await Self.runAppleScriptAsync(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "||")
        guard parts.count >= 6 else { return nil }

        let rawTitle = parts[0]
        let rawArtist = parts[1]
        let album = parts[2]
        let duration = Double(parts[3]) ?? 0.0
        let position = Double(parts[4]) ?? 0.0
        let isPlaying = parts[5].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
        let hasArtwork = parts.count > 6 ? (parts[6].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true") : false

        let cleaned = MediaTitleCleaner.clean(rawTitle: rawTitle, rawArtist: rawArtist, rawAppName: "Apple Music")

        let cacheKey = "music_\(cleaned.title)_\(cleaned.artist)"
        var artData = cachedArtwork[cacheKey]

        if artData == nil && hasArtwork && !isFetchingArtwork {
            artData = await fetchAppleMusicArtwork(cacheKey: cacheKey)
        }

        return NowPlayingTrack(
            title: cleaned.title,
            artist: cleaned.artist,
            album: album,
            isPlaying: isPlaying,
            durationSeconds: duration,
            elapsedSeconds: position,
            appName: "Apple Music",
            artworkData: artData,
            playbackRate: isPlaying ? 1.0 : 0.0,
            timestamp: Date()
        )
    }

    private func fetchAppleMusicArtwork(cacheKey: String) async -> Data? {
        isFetchingArtwork = true
        defer { isFetchingArtwork = false }

        // AppleScript writes a unique temp file inside the private artwork dir; we then
        // atomically rename it to the final path so readers never see partial data.
        let tmpPath = Self.artworkDirectory
            .appendingPathComponent(".music_art.\(UUID().uuidString).tmp").path
        let finalURL = Self.musicArtworkURL

        let script = """
        tell application "Music"
            try
                if (count of artworks of current track) > 0 then
                    set artData to raw data of artwork 1 of current track
                    set fp to (POSIX file "\(tmpPath)")
                    set f to open for access fp with write permission
                    set eof f to 0
                    write artData to f
                    close access f
                    return "\(tmpPath)"
                end if
            on error
                try
                    close access f
                end try
                return ""
            end try
        end tell
        """

        guard let path = await Self.runAppleScriptAsync(script), !path.isEmpty else { return nil }
        let tmpURL = URL(fileURLWithPath: path.trimmingCharacters(in: .whitespacesAndNewlines))
        try? FileManager.default.removeItem(at: finalURL)
        try? FileManager.default.moveItem(at: tmpURL, to: finalURL)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: finalURL.path)
        guard let data = try? Data(contentsOf: finalURL), !data.isEmpty else { return nil }
        cacheArtwork(data, forKey: cacheKey)
        return data
    }

    // MARK: - Spotify

    private func checkSpotify() async -> NowPlayingTrack? {
        guard Self.isAppRunning("com.spotify.client") else { return nil }

        let script = """
        tell application "Spotify"
            try
                if player state is playing or player state is paused then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set dur to (duration of current track) / 1000
                    set pos to player position
                    set isPl to (player state is playing)
                    set artUrl to artwork url of current track
                    return trackName & "||" & artistName & "||" & albumName & "||" & dur & "||" & pos & "||" & isPl & "||" & artUrl
                end if
            on error
                return ""
            end try
        end tell
        """

        guard let output = await Self.runAppleScriptAsync(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "||")
        guard parts.count >= 6 else { return nil }

        let rawTitle = parts[0]
        let rawArtist = parts[1]
        let album = parts[2]
        let duration = Double(parts[3]) ?? 0.0
        let position = Double(parts[4]) ?? 0.0
        let isPlaying = parts[5].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
        let artUrl = parts.count > 6 ? parts[6].trimmingCharacters(in: .whitespacesAndNewlines) : ""

        let cleaned = MediaTitleCleaner.clean(rawTitle: rawTitle, rawArtist: rawArtist, rawAppName: "Spotify")

        let cacheKey = "spotify_\(cleaned.title)_\(cleaned.artist)"
        let artData = cachedArtwork[cacheKey]

        if artData == nil && !artUrl.isEmpty && !isFetchingArtwork {
            fetchSpotifyArtwork(urlStr: artUrl, cacheKey: cacheKey, title: cleaned.title, artist: cleaned.artist)
        }

        return NowPlayingTrack(
            title: cleaned.title,
            artist: cleaned.artist,
            album: album,
            isPlaying: isPlaying,
            durationSeconds: duration,
            elapsedSeconds: position,
            appName: "Spotify",
            artworkData: artData,
            playbackRate: isPlaying ? 1.0 : 0.0,
            timestamp: Date(),
            artworkURL: artUrl.isEmpty ? nil : artUrl
        )
    }

    private func fetchSpotifyArtwork(urlStr: String, cacheKey: String, title: String, artist: String) {
        guard let url = URL(string: urlStr) else { return }
        isFetchingArtwork = true
        Task { @MainActor [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url), !data.isEmpty else {
                self?.isFetchingArtwork = false
                return
            }
            guard let self = self else { return }
            self.cacheArtwork(data, forKey: cacheKey)
            self.isFetchingArtwork = false
            // Only attach the artwork if the current track is still the one we fetched for.
            if self.currentTrack.title == title, self.currentTrack.artist == artist {
                self.currentTrack.artworkData = data
            }
        }
    }

    // MARK: - VLC Media Player

    private func checkVLC() async -> NowPlayingTrack? {
        guard Self.isAppRunning("org.videolan.vlc") else { return nil }

        let script = """
        tell application "VLC"
            try
                set isPl to (player state is playing) or playing
                set trackName to name of current item
                set dur to duration of current item
                set pos to current time
                return trackName & "||" & dur & "||" & pos & "||" & isPl
            on error
                return ""
            end try
        end tell
        """

        guard let output = await Self.runAppleScriptAsync(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "||")
        guard parts.count >= 4 else { return nil }

        let rawTitle = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawTitle.isEmpty else { return nil }

        let duration = Double(parts[1]) ?? 0.0
        let position = Double(parts[2]) ?? 0.0
        let isPlaying = parts[3].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"

        let cleaned = MediaTitleCleaner.clean(rawTitle: rawTitle, rawArtist: "", rawAppName: "VLC")

        return NowPlayingTrack(
            title: cleaned.title,
            artist: cleaned.artist,
            album: "",
            isPlaying: isPlaying,
            durationSeconds: duration,
            elapsedSeconds: position,
            appName: "VLC",
            artworkData: nil,
            playbackRate: isPlaying ? 1.0 : 0.0,
            timestamp: Date()
        )
    }

    // MARK: - Browser Window Fallback (Firefox, Zen Browser, LibreWolf)

    private func checkBrowserWindows() -> NowPlayingTrack? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let browserNames = ["zen", "firefox", "librewolf", "waterfox", "safari", "google chrome", "chrome", "brave", "arc", "edge", "opera", "vivaldi"]
        let mediaKeywords = ["youtube", "youtu.be", "soundcloud", "bandcamp", "spotify", "music.apple", "deezer", "tidal", "twitch", "vimeo"]

        for win in windowList {
            guard let layer = win[kCGWindowLayer as String] as? Int, layer == 0,
                  let owner = win[kCGWindowOwnerName as String] as? String,
                  let name = win[kCGWindowName as String] as? String,
                  !name.isEmpty else {
                continue
            }

            let ownerLower = owner.lowercased()
            guard browserNames.contains(where: { ownerLower.contains($0) }) else { continue }

            let nameLower = name.lowercased()
            if mediaKeywords.contains(where: { nameLower.contains($0) }) {
                let cleaned = MediaTitleCleaner.clean(rawTitle: name, rawArtist: "", rawAppName: owner)
                guard !cleaned.title.isEmpty,
                      cleaned.title != "YouTube",
                      cleaned.title != "SoundCloud",
                      cleaned.title != "Spotify" else {
                    continue
                }

                return NowPlayingTrack(
                    title: cleaned.title,
                    artist: cleaned.artist,
                    album: "",
                    isPlaying: true,
                    durationSeconds: 0.0,
                    elapsedSeconds: 0.0,
                    appName: cleaned.appName,
                    artworkData: nil,
                    playbackRate: 1.0,
                    timestamp: Date()
                )
            }
        }
        return nil
    }

    // MARK: - Playback Controls

    public func playPause() {
        if currentTrack.appName == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to playpause")
        } else if currentTrack.appName == "Apple Music" || currentTrack.appName == "Music" {
            _ = runAppleScript("tell application \"Music\" to playpause")
        } else if currentTrack.appName == "VLC" {
            _ = runAppleScript("tell application \"VLC\" to play")
        } else {
            bridge?.send("toggle")
        }

        let now = Date()
        currentTrack.elapsedSeconds = currentTrack.interpolatedElapsed(at: now)
        currentTrack.timestamp = now
        currentTrack.isPlaying.toggle()
        currentTrack.playbackRate = currentTrack.isPlaying ? 1.0 : 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.bridge?.send("poll")
            self?.updatePlaybackState()
        }
    }

    public func next() {
        if currentTrack.appName == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to next track")
        } else if currentTrack.appName == "Apple Music" || currentTrack.appName == "Music" {
            _ = runAppleScript("tell application \"Music\" to next track")
        } else if currentTrack.appName == "VLC" {
            _ = runAppleScript("tell application \"VLC\" to next")
        } else {
            bridge?.send("next")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.bridge?.send("poll")
            self?.updatePlaybackState()
        }
    }

    public func previous() {
        if currentTrack.appName == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to previous track")
        } else if currentTrack.appName == "Apple Music" || currentTrack.appName == "Music" {
            _ = runAppleScript("tell application \"Music\" to previous track")
        } else if currentTrack.appName == "VLC" {
            _ = runAppleScript("tell application \"VLC\" to previous")
        } else {
            bridge?.send("prev")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.bridge?.send("poll")
            self?.updatePlaybackState()
        }
    }

    public func seek(to progress: Double) {
        let clamped = min(1.0, max(0.0, progress))
        seekToSeconds(currentTrack.durationSeconds * clamped)
    }

    public func seekToSeconds(_ seconds: Double) {
        guard seconds.isFinite else { return }
        var targetSec = max(0, seconds)
        if currentTrack.durationSeconds > 0 {
            targetSec = min(currentTrack.durationSeconds, targetSec)
        }
        if currentTrack.appName == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to set player position to \(targetSec)")
        } else if currentTrack.appName == "Apple Music" || currentTrack.appName == "Music" {
            _ = runAppleScript("tell application \"Music\" to set player position to \(targetSec)")
        } else if currentTrack.appName == "VLC" {
            _ = runAppleScript("tell application \"VLC\" to set current time to \(Int(targetSec))")
        } else {
            bridge?.send("seek \(targetSec)")
        }
        currentTrack.elapsedSeconds = targetSec
        currentTrack.timestamp = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.bridge?.send("poll")
            self?.updatePlaybackState()
        }
    }

    // MARK: - High-resolution artwork fallback (iTunes Search API)

    private func artworkKey(_ track: NowPlayingTrack) -> String {
        "itunes_\(track.title)_\(track.artist)"
    }

    private func withFallbackArtwork(_ track: NowPlayingTrack) -> NowPlayingTrack {
        guard !track.title.isEmpty, track.title != "No Track Playing" else { return track }
        var result = track
        let key = artworkKey(track)
        if result.artworkData == nil || result.artworkData?.isEmpty == true {
            if let cached = cachedArtwork[key] {
                result.artworkData = cached
            } else {
                requestITunesArtwork(title: track.title, artist: track.artist, key: key)
            }
        }
        return result
    }

    private struct ITunesSearchResponse: Decodable, Sendable {
        struct Result: Decodable, Sendable {
            let artworkUrl100: String?
        }
        let results: [Result]
    }

    private func requestITunesArtwork(title: String, artist: String, key: String) {
        guard !itunesInFlight.contains(key), !itunesMisses.contains(key) else { return }
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: "\(artist) \(title)".trimmingCharacters(in: .whitespaces)),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let searchURL = components?.url else { return }
        itunesInFlight.insert(key)

        Task { @MainActor [weak self] in
            let imageData = await Self.fetchITunesArtwork(searchURL: searchURL)
            guard let self = self else { return }
            self.itunesInFlight.remove(key)
            guard let imageData = imageData else {
                self.noteITunesMiss(key)
                return
            }
            self.cacheArtwork(imageData, forKey: key)
            if self.artworkKey(self.currentTrack) == key,
               self.currentTrack.artworkData == nil || self.currentTrack.artworkData?.isEmpty == true {
                self.currentTrack.artworkData = imageData
            }
        }
    }

    private nonisolated static func fetchITunesArtwork(searchURL: URL) async -> Data? {
        do {
            let (data, _) = try await URLSession.shared.data(from: searchURL)
            let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
            guard let small = decoded.results.first?.artworkUrl100 else { return nil }
            let large = small.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            guard let imageURL = URL(string: large) else { return nil }
            let (imageData, _) = try await URLSession.shared.data(from: imageURL)
            return imageData.isEmpty ? nil : imageData
        } catch {
            return nil
        }
    }

    private func runAppleScript(_ script: String) -> String? {
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if error == nil {
                return result.stringValue
            }
        }
        return nil
    }

    /// Runs an AppleScript off the main actor so periodic polling never blocks the UI.
    private nonisolated static func runAppleScriptAsync(_ script: String) async -> String? {
        await Task.detached(priority: .utility) { () -> String? in
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else { return nil }
            let result = appleScript.executeAndReturnError(&error)
            return error == nil ? result.stringValue : nil
        }.value
    }
}

// MARK: - MediaRemoteBridge Process Manager

final class MediaRemoteBridge: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var inPipe: Pipe?
    private var outPipe: Pipe?
    private var buffer = ""
    private var isTerminated = false
    private var lastReport: Date?
    /// Spawn/restart backoff for the bridge child (capped at 30s, healthy after 30s uptime).
    private var backoff = CappedBackoffPolicy.mediaBridge
    /// When the current child process was started, for healthy-reset accounting.
    private var lastStartDate: Date?
    private let onTrack: @Sendable (NowPlayingTrack?) -> Void

    init(onTrack: @escaping @Sendable (NowPlayingTrack?) -> Void) {
        self.onTrack = onTrack
        start()
    }

    /// True while the bridge child has reported state within the last few seconds.
    var isActivelyReporting: Bool {
        lock.withLock {
            guard let last = lastReport else { return false }
            return Date().timeIntervalSince(last) < 3.0
        }
    }

    func start() {
        let shouldProceed = lock.withLock { () -> Bool in
            guard !isTerminated else { return false }
            // Tear down any previous instance cleanly before (re)starting: clear the
            // readability handler, close both pipes and reap the old child process.
            outPipe?.fileHandleForReading.readabilityHandler = nil
            try? inPipe?.fileHandleForWriting.close()
            try? outPipe?.fileHandleForReading.close()
            if let old = process, old.isRunning {
                old.terminate()
                DispatchQueue.global(qos: .utility).async { old.waitUntilExit() }
            }
            process = nil
            inPipe = nil
            outPipe = nil
            return true
        }
        guard shouldProceed else { return }
        guard let scriptPath = resolveScriptPath() else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        task.arguments = [scriptPath]

        let inP = Pipe()
        let outP = Pipe()
        task.standardInput = inP
        task.standardOutput = outP
        task.standardError = FileHandle.nullDevice

        let outHandle = outP.fileHandleForReading
        outHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self = self else { return }
            guard let str = String(data: data, encoding: .utf8) else { return }
            self.processIncoming(str)
        }

        task.terminationHandler = { [weak self] _ in
            guard let self = self else { return }
            // Clear the readability handler before releasing the process so no late
            // callback fires on the dead pipe.
            outHandle.readabilityHandler = nil
            let restartDelay = self.lock.withLock { () -> TimeInterval? in
                self.process = nil
                guard !self.isTerminated else { return nil }
                if let start = self.lastStartDate {
                    // A bridge that stayed up >= 30s was healthy: reset the backoff.
                    self.backoff.resetIfHealthy(uptime: Date().timeIntervalSince(start))
                }
                self.lastStartDate = nil
                return self.backoff.nextDelay()
            }
            guard let delay = restartDelay else { return }
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.start()
            }
        }

        do {
            try task.run()
            lock.withLock {
                self.process = task
                self.inPipe = inP
                self.outPipe = outP
                self.lastStartDate = Date()
            }
        } catch {
            // Spawn failure: clean up pipes/readabilityHandler and schedule a backoff
            // retry (previously a spawn failure was never retried).
            outHandle.readabilityHandler = nil
            try? inP.fileHandleForWriting.close()
            try? outP.fileHandleForReading.close()
            let retryDelay = lock.withLock { () -> TimeInterval? in
                self.process = nil
                self.inPipe = nil
                self.outPipe = nil
                self.lastStartDate = nil
                guard !self.isTerminated else { return nil }
                return self.backoff.nextDelay()
            }
            if let delay = retryDelay {
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.start()
                }
            }
        }
    }

    func send(_ cmd: String) {
        let pipe = lock.withLock { inPipe }
        guard let pipe = pipe else { return }
        let line = "\(cmd)\n"
        if let data = line.data(using: .utf8) {
            try? pipe.fileHandleForWriting.write(contentsOf: data)
        }
    }

    func terminate() {
        var proc: Process?
        lock.withLock {
            isTerminated = true
            // Clear the readability handler cleanly before terminating the process.
            outPipe?.fileHandleForReading.readabilityHandler = nil
            try? inPipe?.fileHandleForWriting.close()
            try? outPipe?.fileHandleForReading.close()
            proc = process
            process = nil
            inPipe = nil
            outPipe = nil
            lastStartDate = nil
        }
        if let proc = proc, proc.isRunning {
            proc.terminate()
            // Reap the child so it never lingers as a zombie.
            DispatchQueue.global(qos: .utility).async { proc.waitUntilExit() }
        }
    }

    private func processIncoming(_ chunk: String) {
        let lines = lock.withLock { () -> [String] in
            buffer += chunk
            var lines: [String] = []
            while let range = buffer.range(of: "\n") {
                let line = String(buffer[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                buffer.removeSubrange(..<range.upperBound)
                if !line.isEmpty {
                    lines.append(line)
                }
            }
            return lines
        }
        for line in lines {
            parseLine(line)
        }
    }

    private func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        lock.withLock { lastReport = Date() }
        let title = json["title"] as? String ?? ""
        let isPlaying = json["isPlaying"] as? Bool ?? false

        if title.isEmpty && !isPlaying {
            onTrack(nil)
            return
        }

        let artist = json["artist"] as? String ?? ""
        let album = json["album"] as? String ?? ""
        let duration = json["duration"] as? Double ?? 0.0
        let elapsed = json["elapsed"] as? Double ?? 0.0
        let rate = json["rate"] as? Double ?? 0.0
        let app = json["app"] as? String ?? "Media Player"
        let hasArt = json["hasArtwork"] as? Bool ?? false

        var artData: Data? = nil
        if hasArt, let data = try? Data(contentsOf: NowPlayingService.nowPlayingArtworkURL) {
            artData = data
        }

        let cleaned = MediaTitleCleaner.clean(rawTitle: title, rawArtist: artist, rawAppName: app)
        let sampledAt = Date()

        let track = NowPlayingTrack(
            title: cleaned.title,
            artist: cleaned.artist,
            album: album,
            isPlaying: isPlaying,
            durationSeconds: duration,
            elapsedSeconds: elapsed,
            appName: cleaned.appName,
            artworkData: artData,
            playbackRate: isPlaying ? (rate > 0 ? rate : 1.0) : 0.0,
            timestamp: sampledAt
        )

        onTrack(track)
    }

    private func resolveScriptPath() -> String? {
        if let p = Bundle.main.path(forResource: "media-bridge", ofType: "swift"), FileManager.default.fileExists(atPath: p) {
            return p
        }
        let res = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/media-bridge.swift").path
        if FileManager.default.fileExists(atPath: res) { return res }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let installed = "\(home)/Applications/DankMacShell.app/Contents/Resources/media-bridge.swift"
        if FileManager.default.fileExists(atPath: installed) { return installed }

        let support = "\(home)/Library/Application Support/DMS/media-bridge.swift"
        if FileManager.default.fileExists(atPath: support),
           (try? String(contentsOfFile: support, encoding: .utf8)) == Self.embeddedScript {
            return support
        }

        // Self-heal: ensure Support directory exists and keep script synchronized with embeddedScript
        let dir = "\(home)/Library/Application Support/DMS"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if (try? Self.embeddedScript.write(toFile: support, atomically: true, encoding: .utf8)) != nil {
            return support
        }
        return nil
    }

    private static let embeddedScript = #"""
import Foundation


let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
guard let handle = handle else {
    fputs("{\"error\":\"dlopen failed\"}\n", stderr)
    exit(1)
}

typealias MRRegister = @convention(c) (DispatchQueue) -> Void
typealias MRGetInfo = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
typealias MRGetClient = @convention(c) (DispatchQueue, @escaping (AnyObject?) -> Void) -> Void
typealias MRClientGetName = @convention(c) (AnyObject) -> CFString?
typealias MRClientGetBundle = @convention(c) (AnyObject) -> CFString?
typealias MRGetPID = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
typealias MRGetIsPlaying = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
typealias MRSendCommand = @convention(c) (Int32, AnyObject?) -> Bool
typealias MRSetElapsed = @convention(c) (Double) -> Void

guard let symReg = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications"),
      let symInfo = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else {
    fputs("{\"error\":\"symbols missing\"}\n", stderr)
    exit(1)
}

let mrReg = unsafeBitCast(symReg, to: MRRegister.self)
let mrGetInfo = unsafeBitCast(symInfo, to: MRGetInfo.self)
let mrGetClient = dlsym(handle, "MRMediaRemoteGetNowPlayingClient").map { unsafeBitCast($0, to: MRGetClient.self) }
let mrClientGetName = dlsym(handle, "MRNowPlayingClientGetDisplayName").map { unsafeBitCast($0, to: MRClientGetName.self) }
let mrClientGetBundle = dlsym(handle, "MRNowPlayingClientGetBundleIdentifier").map { unsafeBitCast($0, to: MRClientGetBundle.self) }
let mrGetPID = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID").map { unsafeBitCast($0, to: MRGetPID.self) }
let mrGetIsPlaying = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying").map { unsafeBitCast($0, to: MRGetIsPlaying.self) }
let mrSendCommand = dlsym(handle, "MRMediaRemoteSendCommand").map { unsafeBitCast($0, to: MRSendCommand.self) }
let mrSetElapsed = dlsym(handle, "MRMediaRemoteSetElapsedTime").map { unsafeBitCast($0, to: MRSetElapsed.self) }

let artDir = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Caches/DMS/artwork", isDirectory: true)
try? FileManager.default.createDirectory(at: artDir, withIntermediateDirectories: true)
try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: artDir.path)
let artURL = artDir.appendingPathComponent("nowplaying_art.jpg")
var lastEmittedJSON = ""
var lastIsPlaying = false
let appNameLock = NSLock()

@Sendable func finite(_ d: Double) -> Double { d.isFinite ? d : 0.0 }

@Sendable func emitJSON(_ payload: [String: Any]) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
          let json = String(data: data, encoding: .utf8) else { return nil }
    return json
}

func emitState(force: Bool = false) {
    mrGetInfo(DispatchQueue.main) { info in
        guard let dict = info as? [String: Any],
              let title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String,
              !title.isEmpty else {
            if let empty = emitJSON(["title": "", "artist": "", "album": "", "isPlaying": false, "duration": 0.0, "elapsed": 0.0, "rate": 0.0, "app": ""]) {
                if force || empty != lastEmittedJSON {
                    lastEmittedJSON = empty
                    lastIsPlaying = false
                    print(empty)
                    fflush(stdout)
                }
            }
            return
        }

        let artist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        let album = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
        let dur = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0.0
        let elapsed = dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0.0
        let rate = dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0.0

        var hasArt = false
        if let artData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, !artData.isEmpty {
            let tmp = artDir.appendingPathComponent(".nowplaying_art.\(UUID().uuidString).tmp")
            if (try? artData.write(to: tmp)) != nil {
                try? FileManager.default.removeItem(at: artURL)
                try? FileManager.default.moveItem(at: tmp, to: artURL)
            }
            hasArt = true
        }

        var appName = "Media Player"
        if let getClient = mrGetClient {
            let sema = DispatchSemaphore(value: 0)
            getClient(DispatchQueue.global()) { client in
                var resolved = "Media Player"
                if let client = client {
                    if let getName = mrClientGetName, let n = getName(client) as String?, !n.isEmpty {
                        resolved = n
                    } else if let getBundle = mrClientGetBundle, let b = getBundle(client) as String?, !b.isEmpty {
                        resolved = b
                    }
                }
                appNameLock.lock()
                appName = resolved
                appNameLock.unlock()
                sema.signal()
            }
            _ = sema.wait(timeout: .now() + 0.1)
        }
        appNameLock.lock()
        let resolvedAppName = appName
        appNameLock.unlock()

        let isPlaying = rate > 0.0
        lastIsPlaying = isPlaying

        if let json = emitJSON([
            "title": title,
            "artist": artist,
            "album": album,
            "duration": finite(dur),
            "elapsed": finite(elapsed),
            "rate": finite(rate),
            "isPlaying": isPlaying,
            "hasArtwork": hasArt,
            "app": resolvedAppName
        ]) {
            if force || json != lastEmittedJSON {
                lastEmittedJSON = json
                print(json)
                fflush(stdout)
            }
        }
    }
}

if CommandLine.arguments.contains("--once") {
    emitState(force: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        exit(0)
    }
    dispatchMain()
}

mrReg(DispatchQueue.main)

let notifs = [
    "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
    "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
    "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
]
for n in notifs {
    NotificationCenter.default.addObserver(forName: NSNotification.Name(n), object: nil, queue: .main) { _ in
        emitState()
    }
}

let timer = DispatchSource.makeTimerSource(queue: .main)
timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
timer.setEventHandler {
    if lastIsPlaying {
        emitState()
    }
}
timer.resume()

func handleCommand(_ trimmed: String) {
    if trimmed == "poll" {
        emitState(force: true)
    } else if trimmed == "play" {
        _ = mrSendCommand?(0, nil)
    } else if trimmed == "pause" {
        _ = mrSendCommand?(1, nil)
    } else if trimmed == "toggle" {
        _ = mrSendCommand?(2, nil)
    } else if trimmed == "next" {
        _ = mrSendCommand?(4, nil)
    } else if trimmed == "prev" {
        _ = mrSendCommand?(5, nil)
    } else if trimmed.starts(with: "seek ") {
        let secStr = String(trimmed.dropFirst(5))
        if let sec = Double(secStr) {
            mrSetElapsed?(sec)
        }
    } else if trimmed == "exit" || trimmed == "quit" {
        exit(0)
    }
}

func drainCommandLines(from buffer: inout Data) -> [String] {
    var commands: [String] = []
    while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
        let lineData = buffer[..<newlineIndex]
        buffer.removeSubrange(...newlineIndex)
        guard let rawLine = String(data: lineData, encoding: .utf8) else { continue }
        let cmd = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cmd.isEmpty {
            commands.append(cmd)
        }
    }
    if buffer.count > 65_536 {
        buffer.removeAll(keepingCapacity: false)
    }
    return commands
}

DispatchQueue.global(qos: .userInitiated).async {
    let stdinHandle = FileHandle.standardInput
    var stdinBuffer = Data()
    while true {
        let data = stdinHandle.availableData
        if data.isEmpty {
            exit(0)
        }
        stdinBuffer.append(data)
        for cmd in drainCommandLines(from: &stdinBuffer) {
            DispatchQueue.main.async {
                handleCommand(cmd)
            }
        }
    }
}

emitState()

dispatchMain()
"""#
}

