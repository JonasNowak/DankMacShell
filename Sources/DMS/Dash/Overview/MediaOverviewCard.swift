import SwiftUI
import DMSCore

/// Right column full-height media player overview card matching DankDash design.
public struct MediaOverviewCard: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var nowPlaying = NowPlayingService.shared
    @State private var wavePhase: CGFloat = 0.0

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let track = nowPlaying.currentTrack
        let hasActive = track.isPlaying || (!track.title.isEmpty && track.title != "No Track Playing")
        let displayTitle = hasActive ? track.title : "No Track Playing"
        let displayArtist = hasActive ? track.artist : "DMS Media Player"
        let displayProgress = track.durationSeconds > 0 ? track.progress : 0.0

        VStack(spacing: 6) {
            Spacer(minLength: 4)

            // Circular Artwork with Organic Wavy Visualizer Ring
            ZStack {
                // Organic Wavy Ring
                WavyVisualizerRing(harmonics: 7, amplitude: track.isPlaying ? 2.8 : 1.2, phase: wavePhase)
                    .stroke(Color(hex: p.primary.hex), lineWidth: 2.0)
                    .frame(width: 74, height: 74)

                // Album Artwork Circle
                ZStack {
                    if let data = track.artworkData, let img = NSImage(data: data) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: p.surfaceVariant.hex), Color.black],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        ZStack {
                            RadialGradient(
                                gradient: Gradient(colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.4), Color.clear]),
                                center: .center,
                                startRadius: 2,
                                endRadius: 28
                            )

                            Image(systemName: "music.note")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            }
            .frame(width: 78, height: 78)

            Spacer(minLength: 4)

            // Track Title & Artist
            VStack(spacing: 1.5) {
                Text(displayTitle)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(displayArtist)
                    .font(.system(size: 9.0, weight: .medium))
                    .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 2)

            // Squiggly Progress Seek Bar (Material UI 3)
            SquigglyProgressBar(
                progress: displayProgress,
                isPlaying: track.isPlaying,
                color: Color(hex: p.primary.hex),
                trackColor: Color.white.opacity(0.12)
            ) { newProgress in
                nowPlaying.seek(to: newProgress)
            }
            .padding(.horizontal, 2)

            // Playback Controls: Prev | Play/Pause Pill | Next
            HStack(spacing: 10) {
                Button(action: { nowPlaying.previous() }) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 10.5))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                }
                .buttonStyle(.plain)

                Button(action: { nowPlaying.playPause() }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: p.primary.hex))
                            .frame(width: 28, height: 28)

                        Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(Color(hex: p.onPrimary.hex))
                    }
                }
                .buttonStyle(.plain)

                Button(action: { nowPlaying.next() }) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 10.5))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: p.surfaceContainerHigh.hex))
        .cornerRadius(12)
    }
}
