# MEDIA — MPRIS Architecture, Synchronized Lyrics & Media UIs Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Media Player Abstraction (`MprisController.qml`), Synchronized Real-Time Lyrics Engine (`LyricsController.qml`, `LyricsService.qml`), Album Art Resolution (`TrackArtService.qml`, `AppleMusicArtService.qml`), Visual Effects (`MediaArtBackdrop.qml`, `MediaBlobHalo.qml`), Bar Widget (`Media.qml`, `MediaLyricLine.qml`), and Dashboard Media Player Tab.

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `quickshell/Services/MprisController.qml` | 612 | Master media player controller, player priority, position ref-counting |
| `quickshell/Services/LyricsController.qml` | 529 | Client-side lyrics synchronization, line index tracking, word-level timing |
| `quickshell/Services/LyricsService.qml` | 51 | Lyrics fetch coordinator and provider dispatch |
| `quickshell/Services/LyricsSubscription.qml` | 27 | Socket subscription for backend lyrics stream |
| `quickshell/Services/TrackArtService.qml` | 395 | Album art caching, URL extraction, local file fallback |
| `quickshell/Services/AppleMusicArtService.qml` | 277 | High-resolution album artwork scraper via Apple Music API |
| `quickshell/Common/MediaOptions.qml` | 129 | Media player preferences (preferred players, lyrics providers) |
| `quickshell/Widgets/MediaArtBackdrop.qml` | 165 | Blurred, color-tinted album art background canvas |
| `quickshell/Widgets/MediaBlobHalo.qml` | 157 | Dynamic rotating organic color blob halo behind album art |
| `quickshell/Widgets/DAnimatedAlbumArt.qml` | 42 | Smooth cross-fade animated cover art image component |
| `quickshell/Widgets/ScrollingText.qml` | 222 | Auto-scrolling marquee text for long song titles |
| `quickshell/Widgets/DSeekbar.qml` | 339 | Scrubbable media progress seekbar with hover preview time |
| `quickshell/Modules/DBar/Widgets/Media.qml` | 280 | Bar media pill (title, artist, controls, animated visualizer) |
| `quickshell/Modules/DBar/Widgets/MediaLyricLine.qml` | 120 | Single-line active lyric ticker embedded directly into DankBar |
| `quickshell/Modules/DDash/MediaPlayerTab.qml` | 450 | Full dashboard media hub with synchronized lyrics scrolling list |
| `core/internal/server/lyrics/` | 88 | Go backend lyrics fetcher (LRCLIB, NetEase, synced lyrics parsing) |

---

## 1. Purpose & User-Visible Behavior

1. **Zero-Idle Media Playback Engine**:
   - Rather than continuously polling media playback position (which wastes CPU), `MprisController.qml` implements **reference-counted position consumers** (`addPositionRef()`, `removePositionRef()`). High-frequency position tracking runs ONLY when a media UI (DankBar media pill, Dash media tab, or OSD) is visible on screen.
2. **Synchronized Lyrics**:
   - Downloads synchronized `.lrc` lyrics in real time from providers like LRCLIB.
   - Parses timestamp markers `[mm:ss.xx]` and highlights the active lyric line in real time with smooth scrolling.
   - **Bar Lyric Ticker**: The user can place `MediaLyricLine` directly on DankBar, streaming live song lyrics across the status bar as music plays!
3. **High-Fidelity Artwork**:
   - Scrapes 1000x1000 high-res album covers via `AppleMusicArtService.qml`.
   - Projects a fluid, organic rotating color halo (`MediaBlobHalo.qml`) matching the album art's dominant colors.

---

## 2. Detailed Requirements

### 2.1. Lyrics Synchronization Engine (`LyricsController.qml`)
- `MEDIA-001`: Lyrics data structure:
  - `lines`: Array of `{ time: double, text: string, words: [...] }`.
  - `synced`: Boolean (true if line timestamps exist).
- `MEDIA-002`: Active line calculation: `activeIndex` must resolve to the line where `currentTime >= line.time` and `currentTime < nextLine.time`.
- `MEDIA-003`: Bar lyric line (`MediaLyricLine.qml`):
  - Height: 24px pill inside DankBar.
  - Displays current singing line with smooth crossfade on lyric advance.
  - Clicking the lyric line opens the full `MediaPlayerTab` in DDash.

### 2.2. Media Bar Pill (`Media.qml`)
- `MEDIA-004`: Compact mode: Displays album art thumbnail (20x20px, radius 4px), scrolling track title, and play/pause button.
- `MEDIA-005`: Audio visualizer: An optional 4-bar mini equalizer animates in the pill when audio is actively playing.

---

## 3. Wayland/Linux Mechanisms → macOS Mapping

1. **Linux MPRIS D-Bus (`org.mpris.MediaPlayer2`)**:
   - Linux reads metadata and playback state via D-Bus properties.
   - **macOS Approach**:
     - System-wide Now Playing: Load private `MediaRemote.framework` (`MRMediaRemoteGetNowPlayingInfo`, `MRMediaRemoteRegisterForNowPlayingNotifications`).
     - Apple Music & Spotify: Listen to `DistributedNotificationCenter.default().addObserver(forName: "com.apple.Music.playerInfo")` and `"com.spotify.client.PlaybackStateChanged"`.
     - Control commands: Send AppleScript events (`tell application "Music" to playpause`) or `MRMediaRemoteSendCommand`.
2. **Lyrics Fetching**:
   - Connect to `https://lrclib.net/api/get` passing track title, artist, album, and duration.

---

## 4. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| Now Playing State | **Partial** | `NowPlayingService.swift`, `NowPlayingModel.swift` | Reads title, artist, playback state via AppleScript/DistributedNotificationCenter. Lacks position ref-counting (polls continuously). |
| `MEDIA-001` - `003` | **Missing** | None | **Zero lyrics support exists in the port**. `LyricsController`, LRC parsing, synchronized scrolling, and the bar lyric line do not exist. |
| High-Res Art & Halos| **Missing** | None | `MediaBlobHalo.qml`, `MediaArtBackdrop.qml`, and `AppleMusicArtService` do not exist. The port only renders a tiny SF Symbol `music.note`. |

### Audit Verdict:
The port has a rudimentary track title reader, but **completely lacks the synchronized lyrics engine, high-res album art scraping, and organic backdrop effects**. Parity: **~20%**.

---

## 5. Reimplementation Checklist

- [ ] Implement `LyricsService.swift` with LRCLIB API integration and `.lrc` timestamp parser.
- [ ] Implement `MediaLyricLineView.swift` for DankBar with lyric text crossfades.
- [ ] Build `MediaPlayerTabView.swift` for DDash with auto-scrolling lyrics list and seekbar.
- [ ] Refactor `NowPlayingService.swift` to use ref-counted position timers (~0% idle CPU).
