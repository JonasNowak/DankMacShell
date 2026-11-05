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
    private var isFetchingArtwork: Bool = false
    private var itunesInFlight: Set<String> = []
    private var itunesMisses: Set<String> = []

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

    public func updatePlaybackState() {
        let music = checkAppleMusic()
        let spotify = checkSpotify()
        let vlc = checkVLC()
        let browser = checkBrowserWindows()
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

    private func applyTrack(_ track: NowPlayingTrack) {
        let enhanced = withFallbackArtwork(track)
        self.currentTrack = enhanced
        if enhanced.isPlaying {
            startPositionPolling()
        } else if positionRefs.isEmpty {
            stopPositionPolling()
        }
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

    private func checkAppleMusic() -> NowPlayingTrack? {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
        guard !running.isEmpty else { return nil }

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

        guard let output = runAppleScript(script), !output.isEmpty else { return nil }
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
            artData = fetchAppleMusicArtwork(cacheKey: cacheKey)
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

    private func fetchAppleMusicArtwork(cacheKey: String) -> Data? {
        isFetchingArtwork = true
        defer { isFetchingArtwork = false }

        let script = """
        tell application "Music"
            try
                if (count of artworks of current track) > 0 then
                    set artData to raw data of artwork 1 of current track
                    set fp to (POSIX file "/tmp/dms_music_art.jpg")
                    set f to open for access fp with write permission
                    set eof f to 0
                    write artData to f
                    close access f
                    return "/tmp/dms_music_art.jpg"
                end if
            on error
                return ""
            end try
        end tell
        """

        guard let path = runAppleScript(script), !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path.trimmingCharacters(in: .whitespacesAndNewlines))
        if let data = try? Data(contentsOf: url), !data.isEmpty {
            self.cachedArtwork[cacheKey] = data
            return data
        }
        return nil
    }

    // MARK: - Spotify

    private func checkSpotify() -> NowPlayingTrack? {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")
        guard !running.isEmpty else { return nil }

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

        guard let output = runAppleScript(script), !output.isEmpty else { return nil }
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
            fetchSpotifyArtwork(urlStr: artUrl, cacheKey: cacheKey)
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

    private func fetchSpotifyArtwork(urlStr: String, cacheKey: String) {
        guard let url = URL(string: urlStr) else { return }
        isFetchingArtwork = true
        Task { @MainActor [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url), !data.isEmpty else {
                self?.isFetchingArtwork = false
                return
            }
            guard let self = self else { return }
            self.cachedArtwork[cacheKey] = data
            self.isFetchingArtwork = false
            if !self.currentTrack.title.isEmpty {
                self.currentTrack.artworkData = data
            }
        }
    }

    // MARK: - VLC Media Player

    private func checkVLC() -> NowPlayingTrack? {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "org.videolan.vlc")
        guard !running.isEmpty else { return nil }

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

        guard let output = runAppleScript(script), !output.isEmpty else { return nil }
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
                self.itunesMisses.insert(key)
                return
            }
            self.cachedArtwork[key] = imageData
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
}

// MARK: - MediaRemoteBridge Process Manager

final class MediaRemoteBridge: @unchecked Sendable {
    private var process: Process?
    private var inPipe: Pipe?
    private var outPipe: Pipe?
    private var buffer = ""
    private var isTerminated = false
    private let onTrack: @Sendable (NowPlayingTrack?) -> Void

    init(onTrack: @escaping @Sendable (NowPlayingTrack?) -> Void) {
        self.onTrack = onTrack
        start()
    }

    func start() {
        guard !isTerminated else { return }
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
            guard let self = self, !self.isTerminated else { return }
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.start()
            }
        }

        do {
            try task.run()
            self.process = task
            self.inPipe = inP
            self.outPipe = outP
        } catch {
            // Process start failed
        }
    }

    func send(_ cmd: String) {
        guard let inPipe = inPipe else { return }
        let line = "\(cmd)\n"
        if let data = line.data(using: .utf8) {
            try? inPipe.fileHandleForWriting.write(contentsOf: data)
        }
    }

    func terminate() {
        isTerminated = true
        outPipe?.fileHandleForReading.readabilityHandler = nil
        try? inPipe?.fileHandleForWriting.close()
        process?.terminate()
        process = nil
        inPipe = nil
        outPipe = nil
    }

    private func processIncoming(_ chunk: String) {
        buffer += chunk
        while let range = buffer.range(of: "\n") {
            let line = String(buffer[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            buffer.removeSubrange(..<range.upperBound)
            if !line.isEmpty {
                parseLine(line)
            }
        }
    }

    private func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
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
        if hasArt, let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/dms_nowplaying_art.jpg")) {
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

        let repo = "/Users/jonasnowak/Documents/repos/DankMacShell/Support/media-bridge.swift"
        if FileManager.default.fileExists(atPath: repo) { return repo }

        let support = "\(home)/Library/Application Support/DMS/media-bridge.swift"
        if FileManager.default.fileExists(atPath: support) { return support }

        // Self-heal: ensure Support directory exists and write script
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

let artURL = URL(fileURLWithPath: "/tmp/dms_nowplaying_art.jpg")
var lastEmittedJSON = ""
var lastIsPlaying = false

func escape(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "\"", with: "\\\"")
     .replacingOccurrences(of: "\n", with: "\\n")
     .replacingOccurrences(of: "\r", with: "\\r")
}

func emitState(force: Bool = false) {
    mrGetInfo(DispatchQueue.main) { info in
        guard let dict = info as? [String: Any],
              let title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String,
              !title.isEmpty else {
            let empty = "{\"title\":\"\",\"artist\":\"\",\"album\":\"\",\"isPlaying\":false,\"duration\":0,\"elapsed\":0,\"rate\":0,\"app\":\"\"}"
            if force || empty != lastEmittedJSON {
                lastEmittedJSON = empty
                lastIsPlaying = false
                print(empty)
                fflush(stdout)
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
            try? artData.write(to: artURL)
            hasArt = true
        }

        var appName = "Media Player"
        if let getClient = mrGetClient {
            let sema = DispatchSemaphore(value: 0)
            getClient(DispatchQueue.global()) { client in
                if let client = client {
                    if let getName = mrClientGetName, let n = getName(client) as String?, !n.isEmpty {
                        appName = n
                    } else if let getBundle = mrClientGetBundle, let b = getBundle(client) as String?, !b.isEmpty {
                        appName = b
                    }
                }
                sema.signal()
            }
            _ = sema.wait(timeout: .now() + 0.1)
        }

        let isPlaying = rate > 0.0
        lastIsPlaying = isPlaying

        let json = "{\"title\":\"\(escape(title))\",\"artist\":\"\(escape(artist))\",\"album\":\"\(escape(album))\",\"duration\":\(dur),\"elapsed\":\(elapsed),\"rate\":\(rate),\"isPlaying\":\(isPlaying),\"hasArtwork\":\(hasArt),\"app\":\"\(escape(appName))\"}"
        if force || json != lastEmittedJSON {
            lastEmittedJSON = json
            print(json)
            fflush(stdout)
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

DispatchQueue.global(qos: .userInitiated).async {
    let stdinHandle = FileHandle.standardInput
    while true {
        let data = stdinHandle.availableData
        if data.isEmpty {
            exit(0)
        }
        guard let line = String(data: data, encoding: .utf8) else { continue }
        for cmd in line.components(separatedBy: "\n") {
            let trimmed = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            DispatchQueue.main.async {
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
        }
    }
}

emitState()
dispatchMain()
"""#
}

