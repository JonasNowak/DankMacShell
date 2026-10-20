import SwiftUI
import AppKit
import DMSCore

/// Simplified full-fidelity media player tab with actual cover art, responsive controls, and audio routing.
public struct MediaPlayerTab: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var nowPlaying = NowPlayingService.shared
    let audio = AudioService.shared

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let track = nowPlaying.currentTrack
        let hasActive = track.isPlaying || (!track.title.isEmpty && track.title != "No Track Playing")
        let displayTitle = hasActive ? track.title : "No Track Playing"
        let displayArtist = hasActive ? track.artist : "DMS Media Player"

        HStack(spacing: 20) {
            // Left Side: Hero Album Artwork
            ZStack {
                if let data = track.artworkData, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 8)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: p.primaryContainer.hex), Color.black.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color(hex: p.outlineVariant.hex).opacity(0.3), lineWidth: 1)
                        )

                    VStack(spacing: 10) {
                        Image(systemName: "music.note")
                            .font(.system(size: 42))
                            .foregroundColor(Color(hex: p.primary.hex))

                        if !hasActive {
                            Text("Ready to Play")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        }
                    }
                }
            }
            .frame(width: 200, height: 200)

            // Right Side: Track Info, Scrubber, Transport & Audio Controls
            VStack(alignment: .leading, spacing: 14) {
                // Track Headers & Source App Badge
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
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
                    }

                    Text(displayTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                        .lineLimit(2)

                    Text(displayArtist)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .lineLimit(1)

                    if !track.album.isEmpty {
                        Text(track.album)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: p.outline.hex))
                            .lineLimit(1)
                    }
                }

                // Progress Bar & Scrubbing
                VStack(spacing: 6) {
                    SquigglyProgressBar(
                        progress: track.durationSeconds > 0 ? track.progress : 0.0,
                        isPlaying: track.isPlaying,
                        color: Color(hex: p.primary.hex),
                        trackColor: Color.white.opacity(0.12)
                    ) { newProgress in
                        nowPlaying.seek(to: newProgress)
                    }


                    HStack {
                        Text(track.formattedElapsed)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        Spacer()
                        Text(track.formattedDuration)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    }
                }

                // Simplified Working Media Controls
                HStack(spacing: 24) {
                    Spacer()

                    // Previous Button
                    Button(action: { nowPlaying.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: p.onSurface.hex))
                            .frame(width: 38, height: 38)
                            .background(Color(hex: p.surfaceContainerHigh.hex))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    // Play / Pause Button
                    Button(action: { nowPlaying.playPause() }) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: p.primary.hex))
                                .frame(width: 48, height: 48)
                                .shadow(color: Color(hex: p.primary.hex).opacity(0.4), radius: 8, x: 0, y: 3)

                            Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: p.onPrimary.hex))
                        }
                    }
                    .buttonStyle(.plain)

                    // Next Button
                    Button(action: { nowPlaying.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: p.onSurface.hex))
                            .frame(width: 38, height: 38)
                            .background(Color(hex: p.surfaceContainerHigh.hex))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                // Volume & Output Audio Sink Selection
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
                .padding(8)
                .background(Color(hex: p.surfaceContainerHigh.hex))
                .cornerRadius(12)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
