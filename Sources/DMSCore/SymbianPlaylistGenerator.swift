import Foundation

/// Generates Nokia Symbian Belle compatible M3U / M3U8 playlist files.
public enum SymbianPlaylistGenerator {

    /// Generates extended M3U file content for Symbian Belle Music Player.
    public static func generateContent(tracks: [SymbianTrack], relativeToPlaylistDirectory: Bool = true) -> String {
        var lines: [String] = ["#EXTM3U"]

        for track in tracks {
            let durationSeconds = Int(track.duration)
            let extinf = "#EXTINF:\(durationSeconds),\(track.artist) - \(track.title)"
            lines.append(extinf)

            // Nokia Symbian file system uses backslashes or forward slashes;
            // standard DOS/Symbian format: Artist\Album\Track.mp3
            var relPath = track.relativeDevicePath
            if relPath.hasPrefix("Music/") {
                relPath = String(relPath.dropFirst("Music/".count))
            }

            if relativeToPlaylistDirectory {
                // If playlist is stored in E:\Music\Playlists\, reference files as ..\Artist\Album\Song.mp3
                let dosPath = "..\\" + relPath.replacingOccurrences(of: "/", with: "\\")
                lines.append(dosPath)
            } else {
                let dosPath = relPath.replacingOccurrences(of: "/", with: "\\")
                lines.append(dosPath)
            }
        }

        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Writes an M3U playlist file into the target device's Music/Playlists directory.
    @discardableResult
    public static func writePlaylist(
        tracks: [SymbianTrack],
        playlistName: String,
        deviceMountURL: URL
    ) throws -> URL {
        let musicURL = deviceMountURL.appendingPathComponent("Music")
        let playlistsURL = musicURL.appendingPathComponent("Playlists")

        let fm = FileManager.default
        if !fm.fileExists(atPath: playlistsURL.path) {
            try fm.createDirectory(at: playlistsURL, withIntermediateDirectories: true)
        }

        let safeName = playlistName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = safeName.isEmpty ? "All_Tracks" : safeName
        let fileURL = playlistsURL.appendingPathComponent("\(finalName).m3u")

        let content = generateContent(tracks: tracks, relativeToPlaylistDirectory: true)
        guard let data = content.data(using: .utf8) else {
            throw NSError(domain: "SymbianPlaylist", code: -1, userInfo: [NSLocalizedDescriptionKey: "Encoding error"])
        }

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
