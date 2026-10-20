import Foundation

/// Represents media playback information for currently playing music or audio.
public struct NowPlayingTrack: Sendable, Codable, Equatable {
    public var title: String
    public var artist: String
    public var album: String
    public var isPlaying: Bool
    public var durationSeconds: Double
    public var elapsedSeconds: Double
    public var appName: String
    public var artworkData: Data?

    public var hasArtwork: Bool {
        guard let data = artworkData else { return false }
        return !data.isEmpty
    }

    public var formattedElapsed: String {
        formatTime(elapsedSeconds)
    }

    public var formattedDuration: String {
        formatTime(durationSeconds)
    }

    public var progress: Double {
        guard durationSeconds > 0 else { return 0.0 }
        return min(1.0, max(0.0, elapsedSeconds / durationSeconds))
    }

    public init(
        title: String = "No Track Playing",
        artist: String = "DMS Media Player",
        album: String = "",
        isPlaying: Bool = false,
        durationSeconds: Double = 0.0,
        elapsedSeconds: Double = 0.0,
        appName: String = "",
        artworkData: Data? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.durationSeconds = durationSeconds
        self.elapsedSeconds = elapsedSeconds
        self.appName = appName
        self.artworkData = artworkData
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
