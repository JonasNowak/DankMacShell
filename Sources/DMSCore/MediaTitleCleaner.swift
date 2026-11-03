import Foundation

/// Result of normalizing raw media title, artist, and application name strings.
public struct CleanedMediaInfo: Sendable, Codable, Equatable {
    public let title: String
    public let artist: String
    public let appName: String

    public init(title: String, artist: String, appName: String) {
        self.title = title
        self.artist = artist
        self.appName = appName
    }
}

/// Normalizer for media track titles, artist names, and application identifiers.
/// Cleans browser tabs, YouTube suffixes, video junk, audio file extensions,
/// and extracts artist names when embedded in track titles.
public enum MediaTitleCleaner {

    /// Cleans raw title, artist, and app name into polished, standardized metadata.
    public static func clean(rawTitle: String, rawArtist: String = "", rawAppName: String = "") -> CleanedMediaInfo {
        var title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var artist = rawArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        var appName = rawAppName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty, title != "No Track Playing" else {
            return CleanedMediaInfo(title: title, artist: artist, appName: appName.isEmpty ? "Media Player" : appName)
        }

        // 1. Strip common media file extensions (e.g. from VLC, IINA, local players)
        let fileExtensions = [
            ".mp3", ".flac", ".m4a", ".wav", ".aac", ".ogg", ".opus",
            ".alac", ".aiff", ".mp4", ".mkv", ".avi", ".mov", ".webm"
        ]
        for ext in fileExtensions {
            if title.lowercased().hasSuffix(ext) {
                title = String(title.dropLast(ext.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // 2. Strip leading track number prefix (e.g. "01. ", "01 - ", "1. ", "01 ")
        if let match = title.range(of: #"^\d{1,3}[\.\s\-]+\s*"#, options: .regularExpression) {
            title = String(title[match.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        var isYouTube = false
        var isSoundCloud = false
        var isBandcamp = false

        // 3. Strip browser private mode and window title wrappers first
        let browserSuffixes = [
            " — Privater Modus", " - Privater Modus", " — Private Browsing", " - Private Browsing",
            " — Mozilla Firefox", " — Zen Browser", " - Google Chrome",
            " - Brave", " - Arc", " - Safari", " - Microsoft Edge",
            " - Opera", " - Vivaldi", " — LibreWolf", " — Waterfox",
            " — Zen", " - Zen"
        ]
        for suf in browserSuffixes {
            if title.hasSuffix(suf) {
                title = String(title.dropLast(suf.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        // 4. Strip media website suffixes
        let ytSuffixes = [
            " - YouTube Music", " – YouTube Music", " — YouTube Music", " | YouTube Music",
            " - YouTube", " – YouTube", " — YouTube", " | YouTube"
        ]
        for suf in ytSuffixes {
            if title.hasSuffix(suf) {
                title = String(title.dropLast(suf.count)).trimmingCharacters(in: .whitespaces)
                isYouTube = true
                break
            }
        }

        if title.hasSuffix(" | SoundCloud") || title.hasSuffix(" - SoundCloud") || title.hasSuffix(" on SoundCloud") {
            title = title.replacingOccurrences(of: " | SoundCloud", with: "")
                         .replacingOccurrences(of: " - SoundCloud", with: "")
                         .replacingOccurrences(of: " on SoundCloud", with: "")
                         .trimmingCharacters(in: .whitespaces)
            isSoundCloud = true
        }

        if title.hasSuffix(" | Bandcamp") || title.hasSuffix(" - Bandcamp") {
            title = title.replacingOccurrences(of: " | Bandcamp", with: "")
                         .replacingOccurrences(of: " - Bandcamp", with: "")
                         .trimmingCharacters(in: .whitespaces)
            isBandcamp = true
        }

        // 5. Resolve friendly app name
        if isYouTube || appName.lowercased().contains("youtube") {
            appName = "YouTube"
        } else if isSoundCloud || appName.lowercased().contains("soundcloud") {
            appName = "SoundCloud"
        } else if isBandcamp || appName.lowercased().contains("bandcamp") {
            appName = "Bandcamp"
        } else if appName.starts(with: "com.") || appName.starts(with: "org.") || appName.starts(with: "io.") || appName.starts(with: "app.") || appName.starts(with: "company.") {
            let bundleMap: [String: String] = [
                "com.tidal.desktop": "TIDAL",
                "com.spotify.client": "Spotify",
                "com.apple.Music": "Apple Music",
                "com.apple.Safari": "Safari",
                "com.google.Chrome": "Google Chrome",
                "org.videolan.vlc": "VLC",
                "io.iina.IINA": "IINA",
                "com.brave.Browser": "Brave",
                "company.thebrowser.Browser": "Arc",
                "org.mozilla.firefox": "Firefox",
                "app.zen-browser.zen": "Zen",
                "com.microsoft.edgemac": "Edge"
            ]
            appName = bundleMap[appName] ?? appName
        } else if appName.lowercased() == "zen" {
            appName = "Zen"
        } else if appName.lowercased() == "tidal" {
            appName = "TIDAL"
        } else if appName.isEmpty {
            appName = "Media Player"
        }

        // 6. Clean Topic suffix from artist (common on YouTube auto-generated music releases)
        if artist.lowercased().hasSuffix(" - topic") {
            artist = String(artist.dropLast(8)).trimmingCharacters(in: .whitespaces)
        } else if artist.lowercased().hasSuffix(" (topic)") {
            artist = String(artist.dropLast(8)).trimmingCharacters(in: .whitespaces)
        }

        // 7. Extract artist from title if artist is empty or generic
        let artistIsGeneric = artist.isEmpty ||
                              artist.lowercased() == "youtube" ||
                              artist.lowercased() == "youtube music" ||
                              artist.lowercased() == appName.lowercased() ||
                              artist.lowercased() == "media player"

        if artistIsGeneric {
            let splitters = [" - ", " – ", " — "]
            for sep in splitters {
                if let range = title.range(of: sep) {
                    let left = String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let right = String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !left.isEmpty && !right.isEmpty {
                        artist = left
                        title = right
                        break
                    }
                }
            }
        }

        // 8. Strip redundant artist prefix if title still begins with artist name
        if !artist.isEmpty {
            let prefixes = ["\(artist) - ", "\(artist) – ", "\(artist) — "]
            for p in prefixes {
                if title.lowercased().hasPrefix(p.lowercased()) {
                    title = String(title.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }

        // 9. Clean video/audio metadata clutter from title
        let videoPatterns = [
            #"\s*[\(\[](?:Official\s+)?(?:Music\s+)?Video(?:(?:\s+Remastered)?|\s+4K|\s+HD)?[\)\]]"#,
            #"\s*[\(\[](?:Official\s+)?Audio(?:[\s\w]+)?[\)\]]"#,
            #"\s*[\(\[](?:Official\s+)?Lyric\s+Video[\)\]]"#,
            #"\s*[\(\[]Visualizer[\)\]]"#,
            #"\s*[\(\[](?:4K|HD|HQ|UHD)[\)\]]"#,
            #"\s*[\(\[]Remastered(?:\s+\d{4})?[\)\]]"#,
            #"\s*[\(\[]\d{4}\s+Remaster[\)\]]"#
        ]
        for pat in videoPatterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) {
                title = regex.stringByReplacingMatches(
                    in: title,
                    range: NSRange(title.startIndex..., in: title),
                    withTemplate: ""
                ).trimmingCharacters(in: .whitespaces)
            }
        }

        return CleanedMediaInfo(title: title, artist: artist, appName: appName)
    }
}
