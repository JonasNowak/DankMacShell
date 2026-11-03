import SwiftUI
import AppKit
import DMSCore

/// Live synchronized lyric ticker pill for DankBar (`MEDIA-003`, `mediaLyricLine` widget).
///
/// - 28pt tall pill showing the active lyric line with slide + crossfade transitions.
/// - Optional word-level highlight (`options["wordHighlight"]`, default on) for enhanced LRC.
/// - Left click opens DankDash on the Media tab with the lyrics view visible; middle click toggles play/pause.
public struct MediaLyricLineWidget: View {
    public var isVertical: Bool
    public var options: [String: AnyCodable]
    public var style: BarWidgetStyleOptions

    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var nowPlaying = NowPlayingService.shared
    @ObservedObject private var lyrics = LyricsService.shared
    @ObservedObject private var configStore = ConfigStore.shared

    private static let consumerID = "bar.lyric"

    public init(
        isVertical: Bool = false,
        options: [String: AnyCodable] = [:],
        style: BarWidgetStyleOptions = BarWidgetStyleOptions()
    ) {
        self.isVertical = isVertical
        self.options = options
        self.style = style
    }

    private var wordHighlightEnabled: Bool {
        options["wordHighlight"]?.boolValue ?? true
    }

    private var tint: Color {
        if let hex = style.customTintHex, !hex.isEmpty { return Color(hex: hex) }
        return theme.primary
    }

    private var background: Color {
        if let hex = style.customBackgroundHex, !hex.isEmpty { return Color(hex: hex) }
        return theme.barWidgetBackground
    }

    private var hasTrack: Bool {
        let t = nowPlaying.currentTrack
        return !t.title.isEmpty && t.title != "No Track Playing"
    }

    public var body: some View {
        Group {
            if hasTrack && configStore.config.showMediaLyricLine {
                pill
            }
        }
        .onAppear { lyrics.addConsumer(Self.consumerID) }
        .onDisappear { lyrics.removeConsumer(Self.consumerID) }
    }

    private var pill: some View {
        Button(action: openLyricsHub) {
            HStack(spacing: 5) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 10))
                    .foregroundColor(tint)
                if !isVertical {
                    lyricTicker
                        .frame(maxWidth: 220, alignment: .leading)
                }
            }
            .padding(.horizontal, isVertical ? 0 : (style.paddingOverride.map { CGFloat($0) } ?? 8))
            .frame(width: isVertical ? 28 : nil, height: 28)
            .background(background)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(MiddleClickCatcher { nowPlaying.playPause() })
        .help("Open synchronized lyrics (middle-click: play/pause)")
    }

    /// The active line, keyed by `activeLineIndex` so SwiftUI slides + crossfades on each change.
    private var lyricTicker: some View {
        ZStack(alignment: .leading) {
            lineView
                .id(lyrics.activeLineIndex ?? -1)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    )
                )
        }
        .frame(height: 28)
        .clipped()
        .animation(.easeInOut(duration: 0.28), value: lyrics.activeLineIndex)
    }

    @ViewBuilder
    private var lineView: some View {
        let font = theme.font(size: 11, weight: .medium)
        if let idx = lyrics.activeLineIndex,
           let lines = lyrics.currentLyrics?.lines,
           idx < lines.count,
           !lines[idx].text.isEmpty {
            let line = lines[idx]
            if wordHighlightEnabled, !line.words.isEmpty {
                wordHighlighted(line: line)
                    .font(font)
                    .lineLimit(1)
            } else {
                Text(line.text)
                    .font(font)
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)
            }
        } else {
            let track = nowPlaying.currentTrack
            Text(lyrics.isLoading ? "Loading lyrics…" : (track.artist.isEmpty ? track.title : "\(track.title) — \(track.artist)"))
                .font(font)
                .foregroundColor(theme.onSurfaceVariant)
                .lineLimit(1)
        }
    }

    private func wordHighlighted(line: LyricLine) -> Text {
        let active = lyrics.activeWordIndex ?? -1
        var result = Text("")
        for (i, word) in line.words.enumerated() {
            let color = i <= active ? tint : theme.onSurfaceVariant
            result = result + Text(word.text + (i == line.words.count - 1 ? "" : " ")).foregroundColor(color)
        }
        return result
    }

    private func openLyricsHub() {
        lyrics.isLyricsOverlayVisible = true
        DashController.shared.toggle(tab: .media, fromBar: true)
    }
}

// MARK: - Mini equalizer (MEDIA-005)

/// 4-bar mini equalizer that animates only while `isPlaying` is true.
struct MiniEqualizerView: View {
    var isPlaying: Bool
    var color: Color

    @State private var heights: [CGFloat] = [0.35, 0.65, 0.5, 0.8]
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<4, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2, height: max(3, heights[idx] * 12))
                    .animation(.easeInOut(duration: 0.14), value: heights[idx])
            }
        }
        .frame(width: 12, height: 12, alignment: .bottom)
        .onAppear { update(isPlaying) }
        .onChange(of: isPlaying) { _, playing in update(playing) }
        .onDisappear { stop() }
    }

    private func update(_ playing: Bool) {
        if playing { start() } else { stop() }
    }

    private func start() {
        stop()
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 140_000_000)
                if Task.isCancelled { break }
                heights = (0..<4).map { _ in CGFloat.random(in: 0.25...1.0) }
            }
        }
    }

    private func stop() {
        animationTask?.cancel()
        animationTask = nil
        heights = [0.35, 0.65, 0.5, 0.8]
    }
}

// MARK: - Album art thumbnail (MEDIA-004)

/// Rounded album-art thumbnail. The `NSImage` is decoded once per artwork change instead of on every render.
struct MediaArtThumbnail: View {
    var data: Data?
    var identity: String
    var size: CGFloat = 20
    var cornerRadius: CGFloat = 4
    var tint: Color
    var isPlaying: Bool

    @State private var image: NSImage?

    private var token: String { "\(identity)#\(data?.count ?? 0)" }

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(0.18))
                Image(systemName: isPlaying ? "music.note" : "pause.fill")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundColor(tint)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { decode() }
        .onChange(of: token) { _, _ in decode() }
    }

    private func decode() {
        if let data = data, !data.isEmpty {
            image = NSImage(data: data)
        } else {
            image = nil
        }
    }
}

// MARK: - Middle click support

/// Transparent overlay that only intercepts middle-button clicks, letting every other event pass through.
struct MiddleClickCatcher: NSViewRepresentable {
    var action: () -> Void

    func makeNSView(context: Context) -> CatcherView {
        let v = CatcherView()
        v.action = action
        return v
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.action = action
    }

    final class CatcherView: NSView {
        var action: (() -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent, event.type == .otherMouseDown || event.type == .otherMouseUp else {
                return nil
            }
            return super.hitTest(point)
        }

        override func otherMouseDown(with event: NSEvent) {
            if event.buttonNumber == 2 { action?() }
        }

        override func otherMouseUp(with event: NSEvent) {}
    }
}
