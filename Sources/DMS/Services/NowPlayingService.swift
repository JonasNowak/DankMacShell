import Foundation
import AppKit
import DMSCore

/// Service that monitors and controls media playback across macOS (Apple Music, Spotify, MediaRemote).
@MainActor
public final class NowPlayingService: ObservableObject {
    public static let shared = NowPlayingService()

    @Published public private(set) var currentTrack: NowPlayingTrack = NowPlayingTrack()

    private var pollTimer: Timer?
    private var cachedArtwork: [String: Data] = [:]
    private var isFetchingArtwork: Bool = false

    // MediaRemote function pointers
    private typealias MRGetInfo = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
    private typealias MRSendCommand = @convention(c) (Int32, AnyObject?) -> Bool
    private typealias MRRegisterForNotifications = @convention(c) (DispatchQueue) -> Void
    private var mrGetInfo: MRGetInfo?
    private var mrSendCommand: MRSendCommand?
    private var mrRegisterForNotifications: MRRegisterForNotifications?

    private init() {
        setupMediaRemote()
        setupDistributedNotifications()
        updatePlaybackState()

        // 1-second poll interval keeps track elapsed time and playback status responsive
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlaybackState()
            }
        }
    }

    private func setupMediaRemote() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) {
            if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
                self.mrGetInfo = unsafeBitCast(sym, to: MRGetInfo.self)
            }
            if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
                self.mrSendCommand = unsafeBitCast(sym, to: MRSendCommand.self)
            }
            if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
                self.mrRegisterForNotifications = unsafeBitCast(sym, to: MRRegisterForNotifications.self)
                self.mrRegisterForNotifications?(DispatchQueue.main)
            }
        }
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

        // MediaRemote notification (TIDAL, Web, YouTube, Safari, Chrome, etc.)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
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

        // 1. If Apple Music is actively playing
        if let m = music, m.isPlaying {
            self.currentTrack = m
            return
        }

        // 2. If Spotify is actively playing
        if let s = spotify, s.isPlaying {
            self.currentTrack = s
            return
        }

        // 3. Query MediaRemote (TIDAL, Safari, etc.)
        checkMediaRemote { [weak self] mrTrack in
            guard let self = self else { return }
            if let mr = mrTrack, mr.isPlaying {
                self.currentTrack = mr
                return
            }

            // If nothing is actively playing, show whichever has recent track metadata
            if let mr = mrTrack, !mr.title.isEmpty {
                self.currentTrack = mr
            } else if let s = spotify, !s.title.isEmpty {
                self.currentTrack = s
            } else if let m = music, !m.title.isEmpty {
                self.currentTrack = m
            } else {
                if self.currentTrack.isPlaying {
                    self.currentTrack.isPlaying = false
                }
            }
        }
    }


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

        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let duration = Double(parts[3]) ?? 0.0
        let position = Double(parts[4]) ?? 0.0
        let isPlaying = parts[5].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
        let hasArtwork = parts.count > 6 ? (parts[6].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true") : false

        let cacheKey = "music_\(title)_\(artist)"
        var artData = cachedArtwork[cacheKey]

        if artData == nil && hasArtwork && !isFetchingArtwork {
            artData = fetchAppleMusicArtwork(cacheKey: cacheKey)
        }

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            durationSeconds: duration,
            elapsedSeconds: position,
            appName: "Apple Music",
            artworkData: artData
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

        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let duration = Double(parts[3]) ?? 0.0
        let position = Double(parts[4]) ?? 0.0
        let isPlaying = parts[5].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
        let artUrl = parts.count > 6 ? parts[6].trimmingCharacters(in: .whitespacesAndNewlines) : ""

        let cacheKey = "spotify_\(title)_\(artist)"
        let artData = cachedArtwork[cacheKey]

        if artData == nil && !artUrl.isEmpty && !isFetchingArtwork {
            fetchSpotifyArtwork(urlStr: artUrl, cacheKey: cacheKey)
        }

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            durationSeconds: duration,
            elapsedSeconds: position,
            appName: "Spotify",
            artworkData: artData
        )
    }

    private func fetchSpotifyArtwork(urlStr: String, cacheKey: String) {
        guard let url = URL(string: urlStr) else { return }
        isFetchingArtwork = true
        Task.detached { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url), !data.isEmpty else {
                await MainActor.run { self?.isFetchingArtwork = false }
                return
            }
            await MainActor.run {
                self?.cachedArtwork[cacheKey] = data
                self?.isFetchingArtwork = false
                if self?.currentTrack.title.isEmpty == false {
                    self?.currentTrack.artworkData = data
                }
            }
        }
    }

    private func checkMediaRemote(completion: @escaping (NowPlayingTrack?) -> Void) {
        guard let getInfo = mrGetInfo else {
            completion(nil)
            return
        }

        getInfo(DispatchQueue.global()) { info in
            guard let dict = info as? [String: Any],
                  let title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String,
                  !title.isEmpty else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let artist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            let album = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
            let duration = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0.0
            let elapsed = dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0.0
            let rate = dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0.0
            let artwork = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data

            let isTidal = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.tidal.desktop").isEmpty
            let appName = isTidal ? "TIDAL" : "Media Player"

            var computedElapsed = elapsed
            if rate > 0, let timestamp = dict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date {
                let delta = Date().timeIntervalSince(timestamp)
                if delta > 0 {
                    computedElapsed = min(duration > 0 ? duration : Double.infinity, elapsed + delta * rate)
                }
            }

            let track = NowPlayingTrack(
                title: title,
                artist: artist,
                album: album,
                isPlaying: rate > 0.0,
                durationSeconds: duration,
                elapsedSeconds: computedElapsed,
                appName: appName,
                artworkData: artwork
            )

            DispatchQueue.main.async {
                completion(track)
            }
        }
    }

    public func playPause() {
        if currentTrack.appName == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to playpause")
        } else if currentTrack.appName == "Apple Music" || currentTrack.appName == "Music" {
            _ = runAppleScript("tell application \"Music\" to playpause")
        } else if let sendCmd = mrSendCommand {
            _ = sendCmd(2, nil) // kMRTogglePlayPause
        } else {
            let spotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
            let musicRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
            if spotifyRunning {
                _ = runAppleScript("tell application \"Spotify\" to playpause")
            } else if musicRunning {
                _ = runAppleScript("tell application \"Music\" to playpause")
            }
        }


        currentTrack.isPlaying.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.updatePlaybackState()
        }
    }

    public func next() {
        if currentTrack.appName == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to next track")
        } else if currentTrack.appName == "Apple Music" || currentTrack.appName == "Music" {
            _ = runAppleScript("tell application \"Music\" to next track")
        } else {
            if let sendCmd = mrSendCommand {
                _ = sendCmd(4, nil) // kMRNextTrack
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.updatePlaybackState()
        }
    }

    public func previous() {
        if currentTrack.appName == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to previous track")
        } else if currentTrack.appName == "Apple Music" || currentTrack.appName == "Music" {
            _ = runAppleScript("tell application \"Music\" to previous track")
        } else {
            if let sendCmd = mrSendCommand {
                _ = sendCmd(5, nil) // kMRPreviousTrack
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.updatePlaybackState()
        }
    }

    public func seek(to progress: Double) {
        let clamped = min(1.0, max(0.0, progress))
        let targetSec = currentTrack.durationSeconds * clamped
        if currentTrack.appName == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to set player position to \(targetSec)")
        } else if currentTrack.appName == "Apple Music" || currentTrack.appName == "Music" {
            _ = runAppleScript("tell application \"Music\" to set player position to \(targetSec)")
        }
        currentTrack.elapsedSeconds = targetSec
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
