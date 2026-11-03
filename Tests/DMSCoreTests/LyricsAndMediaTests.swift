import Testing
import Foundation
@testable import DMSCore

@Suite("Synchronized LRC Lyrics & Media Hub Tests")
struct LyricsAndMediaTests {

    // MARK: - Timestamps

    @Test("Standard [mm:ss.xx], [mm:ss.xxx] and [mm:ss] timestamps")
    func testStandardTimestamps() {
        let lrc = """
        [00:01.50]centi
        [00:02.250]milli
        [01:05]whole
        [00:07.5]single digit fraction
        """
        let parsed = LRCLyricsParser.parse(lrc)
        #expect(parsed.isSynced)
        #expect(parsed.lines.count == 4)
        #expect(abs(parsed.lines[0].time - 1.5) < 1e-9)
        #expect(abs(parsed.lines[1].time - 2.25) < 1e-9)
        #expect(abs(parsed.lines[2].time - 7.5) < 1e-9)
        #expect(abs(parsed.lines[3].time - 65.0) < 1e-9)
        #expect(parsed.lines.map(\.text) == ["centi", "milli", "single digit fraction", "whole"])
        #expect(parsed.lines.map(\.id) == [0, 1, 2, 3])
    }

    @Test("Multi-timestamp compressed lines expand and sort")
    func testMultiTimestamps() {
        let lrc = "[00:12.00][00:24.00]Chorus\n[00:18.00]Verse"
        let parsed = LRCLyricsParser.parse(lrc)
        #expect(parsed.lines.count == 3)
        #expect(parsed.lines.map(\.text) == ["Chorus", "Verse", "Chorus"])
        #expect(parsed.lines.map(\.time) == [12.0, 18.0, 24.0])
        #expect(parsed.lines[0].endTime == 18.0)
        #expect(parsed.lines[1].endTime == 24.0)
        #expect(parsed.lines[2].endTime == nil)
    }

    @Test("Last line ends at the track duration when provided")
    func testLastLineEndTimeUsesDuration() {
        let parsed = LRCLyricsParser.parse("[00:05.00]a\n[00:10.00]b", duration: 20)
        #expect(parsed.lines[1].endTime == 20)
        #expect(parsed.duration == 20)
    }

    @Test("Empty-text timestamps are kept as gap lines; malformed lines are ignored")
    func testGapLinesAndMalformed() {
        let lrc = "garbage line\n[00:05.00]sing\n[00:09.00]\n[xx:yy]nope\n[00:12.00]again\r\n"
        let parsed = LRCLyricsParser.parse(lrc)
        #expect(parsed.lines.map(\.text) == ["sing", "", "again"])
        #expect(parsed.lines.map(\.time) == [5.0, 9.0, 12.0])
    }

    @Test("Text without timestamps is not synced")
    func testUnsyncedText() {
        let parsed = LRCLyricsParser.parse("just words\nno timing")
        #expect(!parsed.isSynced)
        #expect(parsed.lines.isEmpty)
        #expect(LRCLyricsParser.activeLineIndex(at: 5, in: parsed) == nil)
    }

    // MARK: - Metadata & offset

    @Test("Metadata headers and positive offset (+ms shows lyrics earlier)")
    func testMetadataAndPositiveOffset() {
        let lrc = """
        [ti:Song Title]
        [ar:The Artist]
        [al:The Album]
        [by:someone]
        [offset:+500]
        [00:12.00]Hello
        [00:15.50]World
        """
        let parsed = LRCLyricsParser.parse(lrc)
        #expect(parsed.trackName == "Song Title")
        #expect(parsed.artistName == "The Artist")
        #expect(parsed.albumName == "The Album")
        #expect(parsed.offsetSeconds == 0.5)
        #expect(parsed.lines.count == 2)
        #expect(abs(parsed.lines[0].time - 11.5) < 1e-9)
        #expect(abs(parsed.lines[1].time - 15.0) < 1e-9)
    }

    @Test("Negative offset delays lyrics; oversized positive offset clamps at zero")
    func testNegativeAndClampedOffset() {
        let delayed = LRCLyricsParser.parse("[offset:-500]\n[00:10.00]x")
        #expect(abs(delayed.lines[0].time - 10.5) < 1e-9)
        #expect(delayed.offsetSeconds == -0.5)

        let clamped = LRCLyricsParser.parse("[offset:+5000]\n[00:02.00]x")
        #expect(clamped.lines[0].time == 0)
    }

    @Test("Explicit arguments take precedence over header metadata")
    func testExplicitMetadataWins() {
        let parsed = LRCLyricsParser.parse("[ti:Header]\n[00:01.00]x", trackName: "Explicit")
        #expect(parsed.trackName == "Explicit")
    }

    // MARK: - Enhanced word-level

    @Test("Enhanced word timestamps compute word and line end times")
    func testEnhancedWordTimestamps() {
        let lrc = """
        [00:10.00]<00:10.00>Hello <00:10.50>big <00:11.00>world
        [00:12.00]plain next
        """
        let parsed = LRCLyricsParser.parse(lrc)
        #expect(parsed.lines.count == 2)
        let first = parsed.lines[0]
        #expect(first.text == "Hello big world")
        #expect(first.endTime == 12.0)
        #expect(first.words.count == 3)
        #expect(first.words.map(\.text) == ["Hello", "big", "world"])
        #expect(first.words.map(\.startTime) == [10.0, 10.5, 11.0])
        #expect(first.words[0].endTime == 10.5)
        #expect(first.words[1].endTime == 11.0)
        #expect(first.words[2].endTime == 12.0)
        #expect(parsed.lines[1].words.isEmpty)
    }

    @Test("Word timestamps follow the offset shift")
    func testWordTimesShiftWithOffset() {
        let parsed = LRCLyricsParser.parse("[offset:+1000]\n[00:10.00]<00:10.00>a <00:11.00>b")
        #expect(abs(parsed.lines[0].time - 9.0) < 1e-9)
        #expect(abs(parsed.lines[0].words[0].startTime - 9.0) < 1e-9)
        #expect(abs(parsed.lines[0].words[1].startTime - 10.0) < 1e-9)
    }

    // MARK: - Binary search solver

    private func threeLines() -> ParsedLyrics {
        LRCLyricsParser.parse("[00:05.00]a\n[00:10.00]b\n[00:15.00]c", duration: 20)
    }

    @Test("activeLineIndex binary search boundaries (MEDIA-002)")
    func testActiveLineIndex() {
        let l = threeLines()
        #expect(LRCLyricsParser.activeLineIndex(at: 0, in: l) == nil)
        #expect(LRCLyricsParser.activeLineIndex(at: 4.99, in: l) == nil)
        #expect(LRCLyricsParser.activeLineIndex(at: 5.0, in: l) == 0)
        #expect(LRCLyricsParser.activeLineIndex(at: 9.99, in: l) == 0)
        #expect(LRCLyricsParser.activeLineIndex(at: 10.0, in: l) == 1)
        #expect(LRCLyricsParser.activeLineIndex(at: 14.5, in: l) == 1)
        #expect(LRCLyricsParser.activeLineIndex(at: 100, in: l) == 2)
    }

    @Test("activeLineIndex applies the additional offset in ms")
    func testActiveLineIndexWithAdditionalOffset() {
        let l = threeLines()
        #expect(LRCLyricsParser.activeLineIndex(at: 8, in: l, additionalOffsetMs: 2000) == 1)
        #expect(LRCLyricsParser.activeLineIndex(at: 11, in: l, additionalOffsetMs: -2000) == 0)
        #expect(LRCLyricsParser.activeLineIndex(at: 3, in: l, additionalOffsetMs: 2000) == 0)
    }

    @Test("activeLineIndex on empty lyrics and large inputs")
    func testActiveLineIndexEmptyAndLarge() {
        #expect(LRCLyricsParser.activeLineIndex(at: 1, in: ParsedLyrics()) == nil)

        var big = ParsedLyrics(isSynced: true)
        big.lines = (0..<10_000).map { LyricLine(id: $0, time: Double($0), text: "l\($0)") }
        #expect(LRCLyricsParser.activeLineIndex(at: 4_321.5, in: big) == 4_321)
        #expect(LRCLyricsParser.activeLineIndex(at: 99_999, in: big) == 9_999)
    }

    @Test("activeWordIndex within the active enhanced line")
    func testActiveWordIndex() {
        let parsed = LRCLyricsParser.parse("[00:10.00]<00:10.00>Hello <00:10.50>big <00:11.00>world\n[00:12.00]plain")
        #expect(LRCLyricsParser.activeWordIndex(at: 9.9, in: parsed) == nil)
        #expect(LRCLyricsParser.activeWordIndex(at: 10.0, in: parsed) == 0)
        #expect(LRCLyricsParser.activeWordIndex(at: 10.7, in: parsed) == 1)
        #expect(LRCLyricsParser.activeWordIndex(at: 11.2, in: parsed) == 2)
        // Line without word timing
        #expect(LRCLyricsParser.activeWordIndex(at: 12.5, in: parsed) == nil)
        // Additional offset shifts the word window
        #expect(LRCLyricsParser.activeWordIndex(at: 9.6, in: parsed, additionalOffsetMs: 1000) == 1)
    }

    @Test("lineProgress fraction through the active line")
    func testLineProgress() {
        let l = threeLines()
        #expect(LRCLyricsParser.lineProgress(at: 2, in: l, trackDuration: 20) == 0)
        #expect(abs(LRCLyricsParser.lineProgress(at: 12.5, in: l, trackDuration: 20) - 0.5) < 1e-9)
        #expect(abs(LRCLyricsParser.lineProgress(at: 17.5, in: l, trackDuration: 20) - 0.5) < 1e-9)
        #expect(LRCLyricsParser.lineProgress(at: 10.0, in: l, trackDuration: 20) == 0)

        // Last line with unknown end falls back to the supplied track duration.
        let noEnd = LRCLyricsParser.parse("[00:10.00]only")
        #expect(abs(LRCLyricsParser.lineProgress(at: 15, in: noEnd, trackDuration: 20) - 0.5) < 1e-9)
        #expect(LRCLyricsParser.lineProgress(at: 15, in: noEnd, trackDuration: 0) == 0)
    }

    // MARK: - LRCLIB models

    @Test("LRCLIBResponse decoding for /api/get")
    func testLRCLIBResponseDecoding() throws {
        let json = """
        {"id":42,"trackName":"Track","artistName":"Artist","albumName":"Album","duration":210.0,
         "instrumental":false,"plainLyrics":"la la","syncedLyrics":"[00:01.00]la\\n[00:03.00]la"}
        """
        let r = try JSONDecoder().decode(LRCLIBResponse.self, from: Data(json.utf8))
        #expect(r.id == 42)
        #expect(r.trackName == "Track")
        #expect(r.artistName == "Artist")
        #expect(r.albumName == "Album")
        #expect(r.duration == 210.0)
        #expect(r.instrumental == false)
        #expect(r.plainLyrics == "la la")

        let parsed = LRCLyricsParser.parsed(from: r)
        #expect(parsed.isSynced)
        #expect(parsed.lines.count == 2)
        #expect(parsed.lines[1].endTime == 210.0)
        #expect(parsed.plainLyrics == "la la")
        #expect(parsed.trackName == "Track")
    }

    @Test("LRCLIBResponse decoding handles null lyrics and /api/search arrays")
    func testLRCLIBNullsAndSearchArray() throws {
        let json = """
        [{"id":1,"trackName":"A","artistName":"B","albumName":null,"duration":100,
          "instrumental":true,"plainLyrics":null,"syncedLyrics":null},
         {"id":2,"trackName":"A","artistName":"B","albumName":"C","duration":101,
          "instrumental":false,"plainLyrics":"plain only","syncedLyrics":null}]
        """
        let list = try JSONDecoder().decode([LRCLIBResponse].self, from: Data(json.utf8))
        #expect(list.count == 2)
        #expect(list[0].albumName == nil)

        let instrumental = LRCLyricsParser.parsed(from: list[0])
        #expect(instrumental.instrumental)
        #expect(!instrumental.isSynced)
        #expect(instrumental.hasContent)

        let plain = LRCLyricsParser.parsed(from: list[1])
        #expect(!plain.isSynced)
        #expect(!plain.instrumental)
        #expect(plain.plainLyrics == "plain only")
    }

    @Test("ParsedLyrics Codable round-trip")
    func testParsedLyricsRoundTrip() throws {
        let original = LRCLyricsParser.parse(
            "[ti:T]\n[00:01.00]<00:01.00>a <00:01.50>b\n[00:03.00]c",
            trackName: "T", artistName: "A", albumName: "B", duration: 30
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ParsedLyrics.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Cache key

    @Test("cacheKey is deterministic and normalized")
    func testCacheKey() {
        let a = LRCLyricsParser.cacheKey(title: "Hello World", artist: "Adele", album: "25", duration: 295.4)
        let b = LRCLyricsParser.cacheKey(title: "  hello   world", artist: "ADELE", album: "25 ", duration: 295.2)
        #expect(a == b)
        #expect(a.hasPrefix("adele-hello-world-"))
        let hash = a.components(separatedBy: "-").last ?? ""
        #expect(hash.count == 16)
        #expect(hash.allSatisfy { $0.isHexDigit })

        #expect(LRCLyricsParser.cacheKey(title: "Hello World", artist: "Adele", album: "25", duration: 300) != a)
        #expect(LRCLyricsParser.cacheKey(title: "Hello World", artist: "Other", album: "25", duration: 295) != a)
        #expect(LRCLyricsParser.cacheKey(title: "Hello World", artist: "Adele", album: "21", duration: 295) != a)
    }

    @Test("cacheKey is filesystem-safe even for unusual titles")
    func testCacheKeyFilesystemSafe() {
        let key = LRCLyricsParser.cacheKey(title: "../../etc/passwd 🎵", artist: "A/B", album: "", duration: 0)
        #expect(!key.contains("/"))
        #expect(!key.contains(" "))
        #expect(!key.isEmpty)
        let emptyKey = LRCLyricsParser.cacheKey(title: "", artist: "", album: "", duration: 0)
        #expect(emptyKey.hasPrefix("track-"))
    }

    // MARK: - NowPlayingTrack

    @Test("NowPlayingTrack.interpolatedElapsed extrapolates between polls")
    func testInterpolatedElapsed() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        var track = NowPlayingTrack(
            title: "T", artist: "A", isPlaying: true,
            durationSeconds: 200, elapsedSeconds: 10, timestamp: t0
        )
        #expect(track.playbackRate == 1.0)
        #expect(abs(track.interpolatedElapsed(at: t0.addingTimeInterval(2.5)) - 12.5) < 1e-9)
        // Clock skew: a date before the sample never goes backwards.
        #expect(track.interpolatedElapsed(at: t0.addingTimeInterval(-5)) == 10)

        track.playbackRate = 2.0
        #expect(abs(track.interpolatedElapsed(at: t0.addingTimeInterval(2.5)) - 15.0) < 1e-9)

        track.isPlaying = false
        #expect(track.interpolatedElapsed(at: t0.addingTimeInterval(50)) == 10)
    }

    @Test("interpolatedElapsed clamps to the duration and works for unknown durations")
    func testInterpolatedElapsedClamp() {
        let t0 = Date(timeIntervalSince1970: 0)
        let short = NowPlayingTrack(title: "T", isPlaying: true, durationSeconds: 12, elapsedSeconds: 10, timestamp: t0)
        #expect(short.interpolatedElapsed(at: t0.addingTimeInterval(5)) == 12)

        let live = NowPlayingTrack(title: "T", isPlaying: true, durationSeconds: 0, elapsedSeconds: 10, timestamp: t0)
        #expect(abs(live.interpolatedElapsed(at: t0.addingTimeInterval(5)) - 15) < 1e-9)
    }

    @Test("NowPlayingTrack defaults for new fields")
    func testTrackDefaults() {
        let idle = NowPlayingTrack()
        #expect(idle.playbackRate == 0.0)
        #expect(idle.artworkURL == nil)
        let withURL = NowPlayingTrack(title: "T", artworkURL: "https://example.com/a.jpg")
        #expect(withURL.artworkURL == "https://example.com/a.jpg")
    }

    @Test("MediaPlayerLayout raw values")
    func testMediaPlayerLayout() {
        #expect(MediaPlayerLayout.allCases == [.bento, .material])
        #expect(MediaPlayerLayout(rawValue: "bento") == .bento)
        #expect(MediaPlayerLayout(rawValue: "material") == .material)
        #expect(MediaPlayerLayout(rawValue: "other") == nil)
    }

    // MARK: - Config & settings

    @Test("Lyrics config defaults, get/set and clamping")
    func testConfigDefaultsAndAccessors() {
        var cfg = DMSConfig()
        #expect(cfg.enableLyrics == true)
        #expect(cfg.showMediaLyricLine == true)
        #expect(cfg.mediaPlayerLayout == .bento)
        #expect(cfg.lyricsOffsetMs == 0)

        #expect(cfg.getSetting("enableLyrics")?.boolValue == true)
        #expect(cfg.getSetting("mediaPlayerLayout")?.stringValue == "bento")
        #expect(cfg.getSetting("lyricsOffsetMs")?.intValue == 0)

        cfg.setSetting("enableLyrics", value: AnyCodable(false))
        cfg.setSetting("showMediaLyricLine", value: AnyCodable(false))
        cfg.setSetting("mediaPlayerLayout", value: AnyCodable("Material"))
        cfg.setSetting("lyricsOffsetMs", value: AnyCodable(250))
        #expect(cfg.enableLyrics == false)
        #expect(cfg.showMediaLyricLine == false)
        #expect(cfg.mediaPlayerLayout == .material)
        #expect(cfg.lyricsOffsetMs == 250)

        cfg.setSetting("mediaPlayerLayout", value: AnyCodable("nonsense"))
        #expect(cfg.mediaPlayerLayout == .material)
        cfg.setSetting("lyricsOffsetMs", value: AnyCodable(999_999))
        #expect(cfg.lyricsOffsetMs == 10_000)
        cfg.setSetting("lyricsOffsetMs", value: AnyCodable(-999_999))
        #expect(cfg.lyricsOffsetMs == -10_000)
    }

    @Test("Lyrics config survives an encode/decode round-trip and old files decode with defaults")
    func testConfigCodableBackwardCompatible() throws {
        var cfg = DMSConfig()
        cfg.enableLyrics = false
        cfg.mediaPlayerLayout = .material
        cfg.lyricsOffsetMs = -400
        let data = try cfg.encodeJSON()
        let decoded = try JSONDecoder().decode(DMSConfig.self, from: data)
        #expect(decoded.enableLyrics == false)
        #expect(decoded.mediaPlayerLayout == .material)
        #expect(decoded.lyricsOffsetMs == -400)
        // Known keys must not leak into rawSettings.
        #expect(decoded.rawSettings["enableLyrics"] == nil)
        #expect(decoded.rawSettings["lyricsOffsetMs"] == nil)

        // Pre-v0.5 config without any lyrics keys.
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["enableLyrics", "showMediaLyricLine", "mediaPlayerLayout", "lyricsOffsetMs"] {
            object.removeValue(forKey: key)
        }
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let old = try JSONDecoder().decode(DMSConfig.self, from: legacy)
        #expect(old.enableLyrics == true)
        #expect(old.showMediaLyricLine == true)
        #expect(old.mediaPlayerLayout == .bento)
        #expect(old.lyricsOffsetMs == 0)
    }

    @Test("Media Player settings tab exposes lyrics search keywords")
    func testMediaPlayerSearchKeywords() {
        let keywords = DMSSettingsTab.mediaPlayer.searchKeywords
        for expected in ["lyrics", "lrc", "lrclib", "synced", "bento", "karaoke"] {
            #expect(keywords.contains(expected))
        }
    }

    // MARK: - IPC

    @Test("IPC: dms mpris seek / lyrics (CLI)")
    func testIPCMprisCLI() {
        #expect(IPCCommand.parseCLI(args: ["mpris", "seek", "42.5"]) == .mprisSeek(seconds: 42.5))
        #expect(IPCCommand.parseCLI(args: ["ipc", "call", "mpris", "seek", "10"]) == .mprisSeek(seconds: 10))
        #expect(IPCCommand.parseCLI(args: ["mpris", "seek"]) == .unknown("mpris seek requires seconds"))
        #expect(IPCCommand.parseCLI(args: ["mpris", "seek", "abc"]) == .unknown("mpris seek requires seconds"))
        #expect(IPCCommand.parseCLI(args: ["mpris", "lyrics"]) == .lyrics(action: "current"))
        // Existing behaviour is unchanged.
        #expect(IPCCommand.parseCLI(args: ["mpris", "pause"]) == .mpris(action: "pause"))
        #expect(IPCCommand.parseCLI(args: ["mpris"]) == .mpris(action: "status"))
    }

    @Test("IPC: dms lyrics actions (CLI)")
    func testIPCLyricsCLI() {
        #expect(IPCCommand.parseCLI(args: ["lyrics"]) == .lyrics(action: "status"))
        #expect(IPCCommand.parseCLI(args: ["lyrics", "status"]) == .lyrics(action: "status"))
        #expect(IPCCommand.parseCLI(args: ["lyrics", "current"]) == .lyrics(action: "current"))
        #expect(IPCCommand.parseCLI(args: ["lyrics", "refresh"]) == .lyrics(action: "refresh"))
        #expect(IPCCommand.parseCLI(args: ["lyrics", "clear-cache"]) == .lyrics(action: "clear-cache"))
        #expect(IPCCommand.parseCLI(args: ["lyrics", "offset", "250"]) == .lyrics(action: "offset", value: "250"))
        #expect(IPCCommand.parseCLI(args: ["ipc", "call", "lyrics", "offset", "-300"]) == .lyrics(action: "offset", value: "-300"))
    }

    @Test("IPC: dms:// URL scheme for lyrics and mpris seek")
    func testIPCURLs() throws {
        #expect(IPCCommand.parse(url: try #require(URL(string: "dms://lyrics"))) == .lyrics(action: "status"))
        #expect(IPCCommand.parse(url: try #require(URL(string: "dms://lyrics/refresh"))) == .lyrics(action: "refresh"))
        #expect(IPCCommand.parse(url: try #require(URL(string: "dms://lyrics/offset?value=-300"))) == .lyrics(action: "offset", value: "-300"))
        #expect(IPCCommand.parse(url: try #require(URL(string: "dms://lyrics?action=current"))) == .lyrics(action: "current"))
        #expect(IPCCommand.parse(url: try #require(URL(string: "dms://mpris/seek?value=12"))) == .mprisSeek(seconds: 12))
        #expect(IPCCommand.parse(url: try #require(URL(string: "dms://mpris/seek"))) == .unknown("mpris seek requires seconds"))
        #expect(IPCCommand.parse(url: try #require(URL(string: "dms://mpris/lyrics"))) == .lyrics(action: "current"))
        #expect(IPCCommand.parse(url: try #require(URL(string: "dms://mpris/play"))) == .mpris(action: "play"))
    }

    // MARK: - MediaTitleCleaner & Universal Media Recognition

    @Test("Universal Media: YouTube title and artist extraction with video clutter stripping")
    func testYouTubeTitleCleaning() {
        let res1 = MediaTitleCleaner.clean(
            rawTitle: "Queen – Bohemian Rhapsody (Official Video Remastered) - YouTube",
            rawArtist: "",
            rawAppName: "Google Chrome"
        )
        #expect(res1.title == "Bohemian Rhapsody")
        #expect(res1.artist == "Queen")
        #expect(res1.appName == "YouTube")

        let res2 = MediaTitleCleaner.clean(
            rawTitle: "Rick Astley - Never Gonna Give You Up (Official Music Video) - YouTube",
            rawArtist: "YouTube",
            rawAppName: "Safari"
        )
        #expect(res2.title == "Never Gonna Give You Up")
        #expect(res2.artist == "Rick Astley")
        #expect(res2.appName == "YouTube")

        let res3 = MediaTitleCleaner.clean(
            rawTitle: "Daft Punk - Get Lucky (Official Audio) ft. Pharrell Williams - YouTube",
            rawArtist: "Daft Punk - Topic",
            rawAppName: "company.thebrowser.Browser"
        )
        #expect(res3.title == "Get Lucky ft. Pharrell Williams")
        #expect(res3.artist == "Daft Punk")
        #expect(res3.appName == "YouTube")
    }

    @Test("Universal Media: Browser wrappers and web media site suffixes (Zen, Firefox, SoundCloud)")
    func testBrowserAndSiteSuffixes() {
        let res1 = MediaTitleCleaner.clean(
            rawTitle: "Pink Floyd - Comfortably Numb - YouTube — Zen Browser",
            rawArtist: "",
            rawAppName: "Zen"
        )
        #expect(res1.title == "Comfortably Numb")
        #expect(res1.artist == "Pink Floyd")
        #expect(res1.appName == "YouTube")

        let res2 = MediaTitleCleaner.clean(
            rawTitle: "Massive Attack - Teardrop | SoundCloud",
            rawArtist: "",
            rawAppName: "Firefox"
        )
        #expect(res2.title == "Teardrop")
        #expect(res2.artist == "Massive Attack")
        #expect(res2.appName == "SoundCloud")

        let res3 = MediaTitleCleaner.clean(
            rawTitle: "Aphex Twin - Alberto Balsalm | Bandcamp",
            rawArtist: "",
            rawAppName: "Safari"
        )
        #expect(res3.title == "Alberto Balsalm")
        #expect(res3.artist == "Aphex Twin")
        #expect(res3.appName == "Bandcamp")
    }

    @Test("Universal Media: VLC and local file playback (extension and track number stripping)")
    func testVLCAndLocalFiles() {
        let res1 = MediaTitleCleaner.clean(
            rawTitle: "01. Pink Floyd - Time.flac",
            rawArtist: "",
            rawAppName: "org.videolan.vlc"
        )
        #expect(res1.title == "Time")
        #expect(res1.artist == "Pink Floyd")
        #expect(res1.appName == "VLC")

        let res2 = MediaTitleCleaner.clean(
            rawTitle: "04 - Starboy.mp3",
            rawArtist: "The Weeknd",
            rawAppName: "org.videolan.vlc"
        )
        #expect(res2.title == "Starboy")
        #expect(res2.artist == "The Weeknd")
        #expect(res2.appName == "VLC")
    }

    @Test("Universal Media: Bundle identifier to friendly application name mapping")
    func testBundleIDMapping() {
        #expect(MediaTitleCleaner.clean(rawTitle: "Song", rawArtist: "Art", rawAppName: "com.tidal.desktop").appName == "TIDAL")
        #expect(MediaTitleCleaner.clean(rawTitle: "Song", rawArtist: "Art", rawAppName: "com.spotify.client").appName == "Spotify")
        #expect(MediaTitleCleaner.clean(rawTitle: "Song", rawArtist: "Art", rawAppName: "com.apple.Music").appName == "Apple Music")
        #expect(MediaTitleCleaner.clean(rawTitle: "Song", rawArtist: "Art", rawAppName: "org.videolan.vlc").appName == "VLC")
        #expect(MediaTitleCleaner.clean(rawTitle: "Song", rawArtist: "Art", rawAppName: "io.iina.IINA").appName == "IINA")
        #expect(MediaTitleCleaner.clean(rawTitle: "Song", rawArtist: "Art", rawAppName: "com.google.Chrome").appName == "Google Chrome")
        #expect(MediaTitleCleaner.clean(rawTitle: "Song", rawArtist: "Art", rawAppName: "com.apple.Safari").appName == "Safari")
        #expect(MediaTitleCleaner.clean(rawTitle: "Song", rawArtist: "Art", rawAppName: "company.thebrowser.Browser").appName == "Arc")
        #expect(MediaTitleCleaner.clean(rawTitle: "Song", rawArtist: "Art", rawAppName: "com.brave.Browser").appName == "Brave")
        #expect(MediaTitleCleaner.clean(rawTitle: "Song", rawArtist: "Art", rawAppName: "app.zen-browser.zen").appName == "Zen")
    }
}
