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
    /// Playback rate (1.0 = normal speed, 0.0 = paused).
    public var playbackRate: Double
    /// Wall-clock time at which `elapsedSeconds` was sampled.
    public var timestamp: Date
    /// Remote artwork URL, when the source provides one.
    public var artworkURL: String?

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
        artworkData: Data? = nil,
        playbackRate: Double? = nil,
        timestamp: Date = Date(),
        artworkURL: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.durationSeconds = durationSeconds
        self.elapsedSeconds = elapsedSeconds
        self.appName = appName
        self.artworkData = artworkData
        self.playbackRate = playbackRate ?? (isPlaying ? 1.0 : 0.0)
        self.timestamp = timestamp
        self.artworkURL = artworkURL
    }

    /// Sub-second playback position extrapolated from the last sample (`timestamp`).
    public func interpolatedElapsed(at date: Date = Date()) -> Double {
        guard isPlaying else { return elapsedSeconds }
        let rate = playbackRate > 0 ? playbackRate : 1.0
        let delta = max(0, date.timeIntervalSince(timestamp))
        let value = elapsedSeconds + delta * rate
        if durationSeconds > 0 { return min(durationSeconds, value) }
        return value
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}


/// Layout style of the DankDash media hub.
public enum MediaPlayerLayout: String, Codable, CaseIterable, Sendable {
    case bento
    case material

    public var displayName: String {
        switch self {
        case .bento: return "Bento"
        case .material: return "Material"
        }
    }
}
