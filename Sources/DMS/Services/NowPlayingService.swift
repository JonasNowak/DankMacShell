import Foundation
import AppKit
import DMSCore

/// Service that monitors and controls media playback across macOS (Apple Music, Spotify).
@MainActor
public final class NowPlayingService: ObservableObject {
    public static let shared = NowPlayingService()

    @Published public private(set) var currentTrack: NowPlayingTrack = NowPlayingTrack()

    private var pollTimer: Timer?

    private init() {
        setupDistributedNotifications()
        updatePlaybackState()

        // Slow poll (every 5 seconds) to keep track elapsed time in sync
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlaybackState()
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
    }

    public func updatePlaybackState() {
        // First check Apple Music
        if let track = checkAppleMusic() {
            self.currentTrack = track
            return
        }

        // Then check Spotify
        if let track = checkSpotify() {
            self.currentTrack = track
            return
        }

        // Default idle track if neither running
        if self.currentTrack.isPlaying {
            self.currentTrack.isPlaying = false
        }
    }

    private func checkAppleMusic() -> NowPlayingTrack? {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
        guard !running.isEmpty else { return nil }

        let script = """
        tell application "Music"
            if player state is playing or player state is paused then
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set dur to duration of current track
                set pos to player position
                set isPl to (player state is playing)
                return trackName & "||" & artistName & "||" & albumName & "||" & dur & "||" & pos & "||" & isPl
            end if
        end tell
        """

        guard let output = runAppleScript(script) else { return nil }
        let parts = output.components(separatedBy: "||")
        guard parts.count >= 6 else { return nil }

        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let duration = Double(parts[3]) ?? 0.0
        let position = Double(parts[4]) ?? 0.0
        let isPlaying = parts[5].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            durationSeconds: duration,
            elapsedSeconds: position,
            appName: "Apple Music"
        )
    }

    private func checkSpotify() -> NowPlayingTrack? {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")
        guard !running.isEmpty else { return nil }

        let script = """
        tell application "Spotify"
            if player state is playing or player state is paused then
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set dur to (duration of current track) / 1000
                set pos to player position
                set isPl to (player state is playing)
                return trackName & "||" & artistName & "||" & albumName & "||" & dur & "||" & pos & "||" & isPl
            end if
        end tell
        """

        guard let output = runAppleScript(script) else { return nil }
        let parts = output.components(separatedBy: "||")
        guard parts.count >= 6 else { return nil }

        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let duration = Double(parts[3]) ?? 0.0
        let position = Double(parts[4]) ?? 0.0
        let isPlaying = parts[5].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            durationSeconds: duration,
            elapsedSeconds: position,
            appName: "Spotify"
        )
    }

    public func playPause() {
        if currentTrack.appName == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to playpause")
        } else {
            _ = runAppleScript("tell application \"Music\" to playpause")
        }
        currentTrack.isPlaying.toggle()
    }

    public func next() {
        if currentTrack.appName == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to next track")
        } else {
            _ = runAppleScript("tell application \"Music\" to next track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updatePlaybackState()
        }
    }

    public func previous() {
        if currentTrack.appName == "Spotify" {
            _ = runAppleScript("tell application \"Spotify\" to previous track")
        } else {
            _ = runAppleScript("tell application \"Music\" to previous track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updatePlaybackState()
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
