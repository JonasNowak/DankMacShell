import SwiftUI
import AppKit
import DMSCore

/// Full-bleed media hub (`DASH-MED-001`, `DASH-MED-002`): blurred art backdrop, organic color halo,
/// Bento / Material layouts and an interactive, auto-scrolling synchronized lyrics view.
public struct MediaPlayerTab: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var nowPlaying = NowPlayingService.shared
    @ObservedObject var lyrics = LyricsService.shared
    @ObservedObject var configStore = ConfigStore.shared
    let audio = AudioService.shared

    @State private var artImage: NSImage?
    @State private var artAverage: Color?

    public init() {}

    // MARK: - Derived state

    private var track: NowPlayingTrack { nowPlaying.currentTrack }

    private var hasActive: Bool {
        track.isPlaying || (!track.title.isEmpty && track.title != "No Track Playing")
    }

    private var displayTitle: String { hasActive ? track.title : "No Track Playing" }
    private var displayArtist: String { hasActive ? track.artist : "DMS Media Player" }
    private var layout: MediaPlayerLayout { configStore.config.mediaPlayerLayout }
    private var showLyrics: Bool { lyrics.isLyricsOverlayVisible }
    private var artToken: String { "\(track.title)|\(track.artist)#\(track.artworkData?.count ?? 0)" }

    // MARK: - Body

    public var body: some View {
        let p = themeStore.palette
        ZStack {
            MediaArtBackdrop(image: artImage, palette: p)

            VStack(spacing: 10) {
                header(p)
                Group {
                    if showLyrics {
                        lyricsLayout(p)
                    } else if layout == .bento {
                        bentoLayout(p)
                    } else {
                        materialLayout(p)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear {
            nowPlaying.addPositionRef("dash.media")
            decodeArtwork()
        }
        .onDisappear { nowPlaying.removePositionRef("dash.media") }
        .onChange(of: artToken) { _, _ in decodeArtwork() }
    }

    private func decodeArtwork() {
        if let data = track.artworkData, !data.isEmpty, let img = NSImage(data: data) {
            artImage = img
            artAverage = MediaColor.average(of: img)
        } else {
            artImage = nil
            artAverage = nil
        }
    }

    // MARK: - Header

    private func header(_ p: ThemePalette) -> some View {
        HStack(spacing: 8) {
            if !track.appName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: track.appName == "Apple Music" ? "applelogo" : (track.appName == "Spotify" ? "waveform" : "hifispeaker.fill"))
                        .font(.system(size: 9))
                    Text(track.appName)
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: p.primaryContainer.hex).opacity(0.7))
                .foregroundColor(Color(hex: p.primary.hex))
                .clipShape(Capsule())
            }

            Spacer()

            // Bento / Material switcher (DASH-MED-001)
            HStack(spacing: 2) {
                ForEach(MediaPlayerLayout.allCases, id: \.self) { option in
                    Button {
                        configStore.update { $0.mediaPlayerLayout = option }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: option == .bento ? "square.grid.2x2.fill" : "circle.circle.fill")
                                .font(.system(size: 9))
                            Text(option.displayName)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundColor(layout == option ? Color(hex: p.onPrimary.hex) : Color(hex: p.onSurfaceVariant.hex))
                        .background(
                            Capsule().fill(layout == option ? Color(hex: p.primary.hex) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Capsule().fill(Color(hex: p.surfaceContainerHigh.hex).opacity(0.8)))

            // Synchronized lyrics toggle
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    lyrics.isLyricsOverlayVisible.toggle()
                }
            } label: {
                Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(showLyrics ? Color(hex: p.onPrimary.hex) : Color(hex: p.onSurfaceVariant.hex))
                    .frame(width: 28, height: 24)
                    .background(Capsule().fill(showLyrics ? Color(hex: p.primary.hex) : Color(hex: p.surfaceContainerHigh.hex).opacity(0.8)))
            }
            .buttonStyle(.plain)
            .help("Toggle synchronized lyrics")
        }
    }

    // MARK: - Layouts

    private func bentoLayout(_ p: ThemePalette) -> some View {
        HStack(spacing: 12) {
            artTile(p, size: 176)

            VStack(spacing: 10) {
                bentoCard(p) { trackInfo(p, alignment: .leading) }
                bentoCard(p) { seekSection(p) }
                bentoCard(p) {
                    VStack(spacing: 8) {
                        transportRow(p, compact: false)
                        volumeRow(p)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func materialLayout(_ p: ThemePalette) -> some View {
        VStack(spacing: 10) {
            artTile(p, size: 120)
            trackInfo(p, alignment: .center)
            seekSection(p)
            HStack(spacing: 14) {
                transportRow(p, compact: false)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: p.surfaceContainerHigh.hex).opacity(0.85)))
            }
            volumeRow(p)
        }
        .frame(maxWidth: 420)
    }

    private func lyricsLayout(_ p: ThemePalette) -> some View {
        Group {
            if layout == .bento {
                HStack(spacing: 12) {
                    VStack(spacing: 10) {
                        artTile(p, size: 110)
                        trackInfo(p, alignment: .center)
                        transportRow(p, compact: true)
                        Spacer(minLength: 0)
                    }
                    .frame(width: 150)

                    LyricsPanel(palette: p)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: p.surfaceContainer.hex).opacity(0.55)))
                }
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        smallArt(p, size: 36)
                        trackInfo(p, alignment: .leading, compactTitle: true)
                        Spacer()
                        transportRow(p, compact: true)
                    }
                    LyricsPanel(palette: p)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: p.surfaceContainer.hex).opacity(0.45)))
                    seekSection(p, showLabels: false)
                }
            }
        }
    }

    // MARK: - Components

    private func bentoCard<Content: View>(_ p: ThemePalette, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: p.surfaceContainer.hex).opacity(0.7)))
    }

    private func artTile(_ p: ThemePalette, size: CGFloat) -> some View {
        ZStack {
            MediaBlobHalo(colors: haloColors(p), isPlaying: track.isPlaying)
                .frame(width: size * 1.45, height: size * 1.45)
            smallArt(p, size: size, radius: 18)
                .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 8)
        }
        .frame(width: size, height: size)
    }

    private func smallArt(_ p: ThemePalette, size: CGFloat, radius: CGFloat = 8) -> some View {
        ZStack {
            if let img = artImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: p.primaryContainer.hex), Color(hex: p.surfaceContainerHighest.hex)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: size, height: size)
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color(hex: p.outlineVariant.hex).opacity(0.3), lineWidth: 1))
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.28))
                    .foregroundColor(Color(hex: p.primary.hex))
            }
        }
        .frame(width: size, height: size)
    }

    private func haloColors(_ p: ThemePalette) -> [Color] {
        var colors = [Color(hex: p.primary.hex), Color(hex: p.tertiary.hex), Color(hex: p.secondary.hex)]
        if let avg = artAverage { colors.insert(avg, at: 0) }
        return colors
    }

    private func trackInfo(_ p: ThemePalette, alignment: HorizontalAlignment, compactTitle: Bool = false) -> some View {
        let textAlignment: TextAlignment = alignment == .center ? .center : .leading
        let frameAlignment: Alignment = alignment == .center ? .center : .leading
        return VStack(alignment: alignment, spacing: 3) {
            Text(displayTitle)
                .font(.system(size: compactTitle ? 13 : 17, weight: .bold))
                .foregroundColor(Color(hex: p.onSurface.hex))
                .lineLimit(compactTitle ? 1 : 2)
                .multilineTextAlignment(textAlignment)
            Text(displayArtist)
                .font(.system(size: compactTitle ? 11 : 13, weight: .medium))
                .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                .lineLimit(1)
            if !track.album.isEmpty && !compactTitle {
                Text(track.album)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: p.outline.hex))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    /// Seekbar driven by `interpolatedElapsed`, so it moves smoothly between 1 Hz polls.
    private func seekSection(_ p: ThemePalette, showLabels: Bool = true) -> some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: !track.isPlaying)) { context in
            let elapsed = track.interpolatedElapsed(at: context.date)
            let progress = track.durationSeconds > 0 ? min(1, max(0, elapsed / track.durationSeconds)) : 0
            VStack(spacing: 5) {
                SquigglyProgressBar(
                    progress: progress,
                    isPlaying: track.isPlaying,
                    color: Color(hex: p.primary.hex),
                    trackColor: themeStore.subtleTrackColor
                ) { newProgress in
                    nowPlaying.seek(to: newProgress)
                }
                if showLabels {
                    HStack {
                        Text(MediaTime.format(elapsed))
                        Spacer()
                        Text(track.formattedDuration)
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                }
            }
        }
    }

    private func transportRow(_ p: ThemePalette, compact: Bool) -> some View {
        let side: CGFloat = compact ? 30 : 38
        let main: CGFloat = compact ? 38 : 48
        return HStack(spacing: compact ? 12 : 22) {
            Button(action: { nowPlaying.previous() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: compact ? 12 : 15))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                    .frame(width: side, height: side)
                    .background(Color(hex: p.surfaceContainerHigh.hex))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button(action: { nowPlaying.playPause() }) {
                ZStack {
                    Circle()
                        .fill(Color(hex: p.primary.hex))
                        .frame(width: main, height: main)
                        .shadow(color: Color(hex: p.primary.hex).opacity(0.4), radius: 8, x: 0, y: 3)
                    Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: compact ? 15 : 18, weight: .bold))
                        .foregroundColor(Color(hex: p.onPrimary.hex))
                }
            }
            .buttonStyle(.plain)

            Button(action: { nowPlaying.next() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: compact ? 12 : 15))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                    .frame(width: side, height: side)
                    .background(Color(hex: p.surfaceContainerHigh.hex))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: compact ? nil : .infinity)
    }

    private func volumeRow(_ p: ThemePalette) -> some View {
        HStack(spacing: 10) {
            Image(systemName: audio.volume > 0.5 ? "speaker.wave.3.fill" : (audio.volume > 0 ? "speaker.wave.1.fill" : "speaker.slash.fill"))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: p.primary.hex))
                .frame(width: 16)

            Slider(value: Binding(
                get: { audio.volume },
                set: { val in audio.setVolume(val) }
            ), in: 0...1)
            .tint(Color(hex: p.primary.hex))

            Menu {
                let devices = audio.outputs.isEmpty
                    ? [AudioOutput(id: 0, name: audio.currentOutputName, isDefault: true)]
                    : audio.outputs

                ForEach(devices) { dev in
                    Button(dev.name) {
                        audio.setDefaultOutput(dev.id)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "hifispeaker.fill")
                        .font(.system(size: 10))
                    Text(audio.currentOutputName)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: p.surfaceVariant.hex))
                .cornerRadius(8)
                .foregroundColor(Color(hex: p.onSurface.hex))
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: 140)
        }
    }
}

// MARK: - Helpers

enum MediaTime {
    static func format(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

enum MediaColor {
    /// Average color of an image, computed by drawing it into a 1x1 bitmap.
    static func average(of image: NSImage) -> Color? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let ok: Bool = pixel.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard ok else { return nil }
        return Color(.sRGB, red: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255, blue: Double(pixel[2]) / 255, opacity: 1)
    }
}

// MARK: - Backdrop & halo

/// Blurred, color-tinted album-art background (`MediaArtBackdrop`).
struct MediaArtBackdrop: View {
    var image: NSImage?
    var palette: ThemePalette

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 46)
                    .saturation(1.35)
                    .scaleEffect(1.3)
                    .transition(.opacity)
            } else {
                LinearGradient(
                    colors: [Color(hex: palette.primaryContainer.hex).opacity(0.5), Color(hex: palette.surface.hex)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            // Scrim keeps text legible on bright art.
            Color(hex: palette.surface.hex).opacity(image == nil ? 0.0 : 0.62)
        }
        .animation(.easeInOut(duration: 0.5), value: image != nil)
        .clipped()
        .allowsHitTesting(false)
    }
}

/// Organic, slowly rotating cluster of blurred color blobs behind the album art (`MediaBlobHalo`).
struct MediaBlobHalo: View {
    var colors: [Color]
    var isPlaying: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let color = colors.isEmpty ? Color.accentColor : colors[i % colors.count]
                    let phase = t * (0.35 + Double(i) * 0.17) + Double(i) * 2.1
                    Circle()
                        .fill(color.opacity(0.55))
                        .frame(width: 96 + CGFloat(i) * 14, height: 84 + CGFloat(i) * 10)
                        .scaleEffect(x: 1.0 + 0.18 * CGFloat(sin(phase * 1.3)), y: 1.0 + 0.18 * CGFloat(cos(phase * 0.9)))
                        .offset(x: 34 * CGFloat(cos(phase)), y: 30 * CGFloat(sin(phase * 1.2)))
                        .blur(radius: 26)
                }
            }
            .rotationEffect(.radians(t * 0.25))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Lyrics view (DASH-MED-002)

/// Auto-scrolling synchronized lyrics with click-to-seek, word-level fill and inline timing controls.
private struct LyricsPanel: View {
    var palette: ThemePalette

    @ObservedObject private var lyrics = LyricsService.shared
    @ObservedObject private var nowPlaying = NowPlayingService.shared
    @ObservedObject private var configStore = ConfigStore.shared

    private var track: NowPlayingTrack { nowPlaying.currentTrack }
    private var hasTrack: Bool { !track.title.isEmpty && track.title != "No Track Playing" }
    private var offsetMs: Int { configStore.config.lyricsOffsetMs }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .onAppear { lyrics.addConsumer("dash.media") }
        .onDisappear { lyrics.removeConsumer("dash.media") }
    }

    // MARK: States

    @ViewBuilder
    private var content: some View {
        if !hasTrack {
            stateView(icon: "music.note", title: "No track playing", subtitle: "Start playback to see synchronized lyrics")
        } else if !configStore.config.enableLyrics {
            stateView(icon: "quote.bubble", title: "Lyrics are disabled", subtitle: "Enable automatic lyrics (LRCLIB) in Settings → Media Player")
        } else if lyrics.isLoading {
            VStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Fetching lyrics…")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
            }
        } else if let current = lyrics.currentLyrics {
            if current.instrumental && !current.isSynced && current.plainLyrics.isEmpty {
                stateView(icon: "pianokeys", title: "Instrumental", subtitle: "This track has no lyrics")
            } else if current.isSynced {
                syncedList(current)
            } else if !current.plainLyrics.isEmpty {
                plainView(current.plainLyrics)
            } else {
                stateView(icon: "text.badge.xmark", title: "No lyrics found", subtitle: "Try refreshing")
            }
        } else {
            stateView(icon: "text.badge.xmark", title: "No lyrics found", subtitle: "LRCLIB has no lyrics for this track")
        }
    }

    private func stateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(Color(hex: palette.primary.hex).opacity(0.8))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: palette.onSurface.hex))
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                .multilineTextAlignment(.center)
        }
        .padding(16)
    }

    private func plainView(_ text: String) -> some View {
        VStack(spacing: 4) {
            Text("Unsynced lyrics")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(hex: palette.outline.hex))
                .padding(.top, 8)
            ScrollView(showsIndicators: false) {
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
    }

    private func syncedList(_ current: ParsedLyrics) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .center, spacing: 8) {
                    Color.clear.frame(height: 60)
                    ForEach(current.lines) { line in
                        LyricRow(
                            line: line,
                            activeIndex: lyrics.activeLineIndex,
                            palette: palette,
                            offsetMs: offsetMs,
                            track: track
                        ) {
                            nowPlaying.seekToSeconds(line.time)
                        }
                        .id(line.id)
                    }
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 12)
            }
            .onChange(of: lyrics.activeLineIndex) { _, newIndex in
                guard let newIndex = newIndex else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onAppear {
                if let idx = lyrics.activeLineIndex {
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
        }
    }

    // MARK: Footer (offset + refresh)

    private var footer: some View {
        HStack(spacing: 6) {
            Text(statusLabel)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(hex: palette.outline.hex))
                .lineLimit(1)

            Spacer()

            footerButton("−0.5s", help: "Show lyrics later") {
                lyrics.setOffset(ms: offsetMs - 500)
            }
            Button {
                lyrics.setOffset(ms: 0)
            } label: {
                Text(String(format: "%+.1fs", Double(offsetMs) / 1000.0))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(offsetMs == 0 ? Color(hex: palette.onSurfaceVariant.hex) : Color(hex: palette.primary.hex))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
            .help("Reset timing offset")
            footerButton("+0.5s", help: "Show lyrics earlier") {
                lyrics.setOffset(ms: offsetMs + 500)
            }

            Button {
                lyrics.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.plain)
            .help("Refresh lyrics from LRCLIB")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: palette.surfaceContainerHigh.hex).opacity(0.5))
    }

    private var statusLabel: String {
        guard let l = lyrics.currentLyrics else { return "LRCLIB" }
        if l.isSynced { return "Synced · click a line to seek" }
        if l.instrumental { return "Instrumental" }
        return "Unsynced"
    }

    private func footerButton(_ title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: palette.onSurface.hex))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(hex: palette.surfaceContainerHighest.hex).opacity(0.8)))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// One lyric line: vocal emphasis on the active line, distance fade elsewhere, word-level fill for enhanced LRC.
private struct LyricRow: View {
    let line: LyricLine
    let activeIndex: Int?
    let palette: ThemePalette
    let offsetMs: Int
    let track: NowPlayingTrack
    let onSeek: () -> Void

    private var isActive: Bool { activeIndex == line.id }

    private var distanceOpacity: Double {
        guard let a = activeIndex else { return 0.55 }
        let d = abs(line.id - a)
        return max(0.22, 0.75 - Double(d) * 0.16)
    }

    var body: some View {
        Button(action: onSeek) {
            Group {
                if line.text.isEmpty {
                    Text("♪")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex).opacity(isActive ? 0.9 : 0.3))
                } else if isActive && !line.words.isEmpty {
                    TimelineView(.animation(minimumInterval: 0.1, paused: !track.isPlaying)) { ctx in
                        wordFilled(at: track.interpolatedElapsed(at: ctx.date) + Double(offsetMs) / 1000.0)
                    }
                } else {
                    Text(line.text)
                        .font(.system(size: 15, weight: isActive ? .bold : .medium))
                        .foregroundColor(isActive ? Color(hex: palette.primary.hex) : Color(hex: palette.onSurface.hex).opacity(distanceOpacity))
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .scaleEffect(isActive ? 1.03 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Words already sung are fully tinted; the current word fades in with its own progress.
    private func wordFilled(at t: Double) -> some View {
        var result = Text("")
        for (i, word) in line.words.enumerated() {
            let end = word.endTime ?? (word.startTime + 0.5)
            let span = max(0.05, end - word.startTime)
            let p = min(1, max(0, (t - word.startTime) / span))
            let primary = Color(hex: palette.primary.hex)
            let dim = Color(hex: palette.onSurface.hex).opacity(0.45)
            let color: Color = p >= 1 ? primary : (p <= 0 ? dim : primary.opacity(0.45 + 0.55 * p))
            let suffix = i == line.words.count - 1 ? "" : " "
            result = result + Text(word.text + suffix).foregroundColor(color)
        }
        return result.font(.system(size: 15, weight: .bold))
    }
}
