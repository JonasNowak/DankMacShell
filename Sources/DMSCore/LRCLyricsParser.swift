import Foundation

// MARK: - Models

/// A single word inside an enhanced (word-level) LRC line.
public struct LyricWord: Sendable, Codable, Equatable {
    public var startTime: Double
    public var endTime: Double?
    public var text: String

    public init(startTime: Double, endTime: Double? = nil, text: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

/// One synchronized lyric line.
public struct LyricLine: Sendable, Codable, Equatable, Identifiable {
    public var id: Int
    public var time: Double
    public var endTime: Double?
    public var text: String
    public var words: [LyricWord]

    public init(id: Int, time: Double, endTime: Double? = nil, text: String, words: [LyricWord] = []) {
        self.id = id
        self.time = time
        self.endTime = endTime
        self.text = text
        self.words = words
    }
}

/// Fully parsed lyrics for a track (synced, plain or instrumental).
public struct ParsedLyrics: Sendable, Codable, Equatable {
    public var trackName: String
    public var artistName: String
    public var albumName: String
    public var duration: Double
    public var isSynced: Bool
    public var instrumental: Bool
    /// LRC header `[offset:]` (seconds) that has already been applied to `lines`.
    public var offsetSeconds: Double
    public var lines: [LyricLine]
    public var plainLyrics: String

    public init(
        trackName: String = "",
        artistName: String = "",
        albumName: String = "",
        duration: Double = 0,
        isSynced: Bool = false,
        instrumental: Bool = false,
        offsetSeconds: Double = 0,
        lines: [LyricLine] = [],
        plainLyrics: String = ""
    ) {
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.duration = duration
        self.isSynced = isSynced
        self.instrumental = instrumental
        self.offsetSeconds = offsetSeconds
        self.lines = lines
        self.plainLyrics = plainLyrics
    }

    /// True when there is anything to display.
    public var hasContent: Bool {
        instrumental || !lines.isEmpty || !plainLyrics.isEmpty
    }
}

/// Response shape of `https://lrclib.net/api/get` and the elements of `/api/search`.
public struct LRCLIBResponse: Sendable, Codable, Equatable {
    public var id: Int?
    public var trackName: String?
    public var artistName: String?
    public var albumName: String?
    public var duration: Double?
    public var instrumental: Bool?
    public var plainLyrics: String?
    public var syncedLyrics: String?

    public init(
        id: Int? = nil,
        trackName: String? = nil,
        artistName: String? = nil,
        albumName: String? = nil,
        duration: Double? = nil,
        instrumental: Bool? = nil,
        plainLyrics: String? = nil,
        syncedLyrics: String? = nil
    ) {
        self.id = id
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.duration = duration
        self.instrumental = instrumental
        self.plainLyrics = plainLyrics
        self.syncedLyrics = syncedLyrics
    }
}

// MARK: - Parser

/// Pure-Foundation LRC / enhanced-LRC parser and playback-position solver.
public enum LRCLyricsParser {

    // MARK: Parsing

    /// Parses LRC text (standard and enhanced word-level) into `ParsedLyrics`.
    public static func parse(
        _ lrc: String,
        trackName: String = "",
        artistName: String = "",
        albumName: String = "",
        duration: Double = 0
    ) -> ParsedLyrics {
        var title = trackName
        var artist = artistName
        var album = albumName
        var offsetMs: Double = 0

        struct RawLine { var time: Double; var text: String; var words: [LyricWord]; var order: Int }
        var raws: [RawLine] = []
        var order = 0

        let normalized = lrc.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = Substring(rawLine.trimmingCharacters(in: .whitespaces))
            guard line.first == "[" else { continue }

            var times: [Double] = []
            var rest = line

            // Consume leading [..] tags.
            while rest.first == "[", let close = rest.firstIndex(of: "]") {
                let inner = rest[rest.index(after: rest.startIndex)..<close]
                if let t = parseTimestamp(inner) {
                    times.append(t)
                } else if let colon = inner.firstIndex(of: ":") {
                    let key = inner[inner.startIndex..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                    let value = inner[inner.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    switch key {
                    case "ti": if title.isEmpty { title = value }
                    case "ar": if artist.isEmpty { artist = value }
                    case "al": if album.isEmpty { album = value }
                    case "offset":
                        let cleaned = value.hasPrefix("+") ? String(value.dropFirst()) : value
                        offsetMs = Double(cleaned) ?? 0
                    default: break
                    }
                } else {
                }
                rest = rest[rest.index(after: close)...]
                if times.isEmpty { break }   // metadata line: stop after first tag
            }

            guard !times.isEmpty else { continue }

            let (text, words) = parseEnhancedText(String(rest))
            for t in times {
                raws.append(RawLine(time: t, text: text, words: words, order: order))
                order += 1
            }
        }

        let offsetSeconds = offsetMs / 1000.0
        // Apply offset (+N ms => lyrics appear earlier) and sort stably.
        var shifted = raws.map { r -> RawLine in
            var r = r
            let delta = r.time - offsetSeconds
            let applied = max(0, delta)
            let shift = applied - r.time
            r.time = applied
            r.words = r.words.map { w in
                var w = w
                w.startTime = max(0, w.startTime + shift)
                return w
            }
            return r
        }
        shifted.sort { $0.time == $1.time ? $0.order < $1.order : $0.time < $1.time }

        var lines: [LyricLine] = []
        lines.reserveCapacity(shifted.count)
        for (idx, r) in shifted.enumerated() {
            let end: Double?
            if idx + 1 < shifted.count {
                end = shifted[idx + 1].time
            } else if duration > r.time {
                end = duration
            } else {
                end = nil
            }
            var words = r.words
            for w in words.indices {
                if w + 1 < words.count {
                    words[w].endTime = words[w + 1].startTime
                } else {
                    words[w].endTime = end
                }
            }
            lines.append(LyricLine(id: idx, time: r.time, endTime: end, text: r.text, words: words))
        }

        return ParsedLyrics(
            trackName: title,
            artistName: artist,
            albumName: album,
            duration: duration,
            isSynced: !lines.isEmpty,
            instrumental: false,
            offsetSeconds: offsetSeconds,
            lines: lines,
            plainLyrics: lines.isEmpty ? "" : lines.map(\.text).joined(separator: "\n")
        )
    }

    /// Builds `ParsedLyrics` from an LRCLIB response: synced > plain > instrumental.
    public static func parsed(from response: LRCLIBResponse) -> ParsedLyrics {
        let name = response.trackName ?? ""
        let artist = response.artistName ?? ""
        let album = response.albumName ?? ""
        let duration = response.duration ?? 0

        if let synced = response.syncedLyrics, !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var parsed = parse(synced, trackName: name, artistName: artist, albumName: album, duration: duration)
            if parsed.isSynced {
                if let plain = response.plainLyrics, !plain.isEmpty { parsed.plainLyrics = plain }
                parsed.instrumental = response.instrumental ?? false
                return parsed
            }
        }
        let plain = (response.plainLyrics ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedLyrics(
            trackName: name,
            artistName: artist,
            albumName: album,
            duration: duration,
            isSynced: false,
            instrumental: (response.instrumental ?? false) && plain.isEmpty,
            offsetSeconds: 0,
            lines: [],
            plainLyrics: plain
        )
    }

    /// Parses `mm:ss`, `mm:ss.x`, `mm:ss.xx`, `mm:ss.xxx` (digits only). Returns nil for metadata tags.
    static func parseTimestamp(_ s: Substring) -> Double? {
        guard let first = s.first, first.isASCII, first.isNumber else { return nil }
        guard let colon = s.firstIndex(of: ":") else { return nil }
        let minPart = s[s.startIndex..<colon]
        guard !minPart.isEmpty, minPart.allSatisfy({ $0.isASCII && $0.isNumber }), let minutes = Double(minPart) else { return nil }
        let secPart = s[s.index(after: colon)...]
        var whole = secPart
        var frac: Substring = ""
        if let sep = secPart.firstIndex(where: { $0 == "." || $0 == ":" }) {
            whole = secPart[secPart.startIndex..<sep]
            frac = secPart[secPart.index(after: sep)...]
        }
        guard !whole.isEmpty, whole.allSatisfy({ $0.isASCII && $0.isNumber }), let seconds = Double(whole) else { return nil }
        var fraction = 0.0
        if !frac.isEmpty {
            guard frac.allSatisfy({ $0.isASCII && $0.isNumber }), let f = Double("0." + frac) else { return nil }
            fraction = f
        }
        return minutes * 60 + seconds + fraction
    }

    /// Splits text containing optional `<mm:ss.xx>word` markers into plain text + words.
    static func parseEnhancedText(_ text: String) -> (String, [LyricWord]) {
        guard text.contains("<") else {
            return (text.trimmingCharacters(in: .whitespaces), [])
        }
        var words: [LyricWord] = []
        var plain = ""
        var currentStart: Double?
        var buffer = ""

        func flush() {
            if let start = currentStart {
                let trimmed = buffer.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    words.append(LyricWord(startTime: start, endTime: nil, text: trimmed))
                }
            }
            plain += buffer
            buffer = ""
        }

        var idx = text.startIndex
        while idx < text.endIndex {
            let ch = text[idx]
            if ch == "<", let close = text[idx...].firstIndex(of: ">"),
               let t = parseTimestamp(text[text.index(after: idx)..<close]) {
                flush()
                currentStart = t
                idx = text.index(after: close)
                continue
            }
            buffer.append(ch)
            idx = text.index(after: idx)
        }
        flush()
        let collapsed = plain
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return (collapsed, words)
    }

    // MARK: Solver (O(log n))

    /// Index of the last line with `time <= elapsed + offset`, or nil.
    public static func activeLineIndex(at elapsedSeconds: Double, in lyrics: ParsedLyrics, additionalOffsetMs: Int = 0) -> Int? {
        guard lyrics.isSynced, !lyrics.lines.isEmpty else { return nil }
        let t = elapsedSeconds + Double(additionalOffsetMs) / 1000.0
        let lines = lyrics.lines
        var lo = 0
        var hi = lines.count   // first index whose time > t
        while lo < hi {
            let mid = (lo + hi) / 2
            if lines[mid].time <= t { lo = mid + 1 } else { hi = mid }
        }
        let idx = lo - 1
        return idx >= 0 ? idx : nil
    }

    /// Index of the active word within the active line (enhanced LRC), or nil.
    public static func activeWordIndex(at elapsedSeconds: Double, in lyrics: ParsedLyrics, additionalOffsetMs: Int = 0) -> Int? {
        guard let li = activeLineIndex(at: elapsedSeconds, in: lyrics, additionalOffsetMs: additionalOffsetMs) else { return nil }
        let words = lyrics.lines[li].words
        guard !words.isEmpty else { return nil }
        let t = elapsedSeconds + Double(additionalOffsetMs) / 1000.0
        var lo = 0
        var hi = words.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if words[mid].startTime <= t { lo = mid + 1 } else { hi = mid }
        }
        let idx = lo - 1
        return idx >= 0 ? idx : nil
    }

    /// Progress (0...1) through the active line.
    public static func lineProgress(at elapsedSeconds: Double, in lyrics: ParsedLyrics, trackDuration: Double, additionalOffsetMs: Int = 0) -> Double {
        guard let li = activeLineIndex(at: elapsedSeconds, in: lyrics, additionalOffsetMs: additionalOffsetMs) else { return 0 }
        let line = lyrics.lines[li]
        let t = elapsedSeconds + Double(additionalOffsetMs) / 1000.0
        let end = line.endTime ?? (trackDuration > line.time ? trackDuration : line.time)
        let span = end - line.time
        guard span > 0 else { return 0 }
        return min(1.0, max(0.0, (t - line.time) / span))
    }

    // MARK: Cache key

    /// Deterministic, filesystem-safe cache key: `<slug>-<fnv1a64 hex>`.
    public static func cacheKey(title: String, artist: String, album: String, duration: Double) -> String {
        func norm(_ s: String) -> String {
            s.lowercased()
                .split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " ")
        }
        let t = norm(title), a = norm(artist), al = norm(album)
        let d = Int(duration.rounded())
        let canonical = "\(t)|\(a)|\(al)|\(d)"

        var hash: UInt64 = 0xcbf29ce484222325
        for byte in canonical.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        let hex = String(hash, radix: 16)
        let paddedHex = String(repeating: "0", count: max(0, 16 - hex.count)) + hex

        var slug = ""
        for ch in "\(a)-\(t)" {
            if ch.isASCII && (ch.isLetter || ch.isNumber) { slug.append(ch) }
            else if !slug.hasSuffix("-") { slug.append("-") }
            if slug.count >= 48 { break }
        }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if slug.isEmpty { slug = "track" }
        return "\(slug)-\(paddedHex)"
    }
}
