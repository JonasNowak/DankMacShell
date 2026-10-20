import SwiftUI
import CoreAudio
import DMSCore

/// Audio Output and Input detail subpage with sink router, input selector,
/// volume sliders, and per-app stream mixer cards.
/// Implements upstream DMS `quickshell/Modules/ControlCenter/Details/AudioOutputDetail.qml`.
public struct AudioDetailPage: View {
    @ObservedObject private var theme = ThemeStore.shared
    private let audio = AudioService.shared
    @ObservedObject private var nowPlaying = NowPlayingService.shared

    @State private var outputs: [AudioOutput] = []
    @State private var inputs: [AudioOutput] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MARK: - Output Volume & Sinks
            VStack(alignment: .leading, spacing: 10) {
                Text("OUTPUT DEVICE & VOLUME")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.outline)

                // Master Volume Slider
                VStack(spacing: 6) {
                    HStack {
                        Button {
                            audio.toggleMute()
                        } label: {
                            Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.primary)
                        }
                        .buttonStyle(.plain)

                        Text("Master Volume")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.onSurface)

                        Spacer()

                        Text("\(Int(audio.volume * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.onSurfaceVariant)
                    }

                    Slider(value: Binding(
                        get: { audio.volume },
                        set: { audio.setVolume($0) }
                    ), in: 0...1)
                    .tint(theme.primary)
                }
                .padding(12)
                .background(theme.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Output Devices Radio List
                VStack(spacing: 4) {
                    let availableOutputs = audio.outputs.isEmpty ? outputs : audio.outputs
                    ForEach(availableOutputs) { output in
                        Button {
                            audio.setDefaultOutput(output.id)
                            refreshDevices()
                            ToastCenter.shared.show(icon: outputIcon(name: output.name), message: "Output: \(output.name)")
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: outputIcon(name: output.name))
                                    .font(.system(size: 14))
                                    .foregroundColor(output.isDefault ? theme.primary : theme.onSurface)
                                    .frame(width: 20)

                                Text(output.name)
                                    .font(.system(size: 12, weight: output.isDefault ? .bold : .medium))
                                    .foregroundColor(theme.onSurface)

                                Spacer()

                                if output.isDefault {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(theme.primary)
                                } else {
                                    Circle()
                                        .stroke(theme.outlineVariant, lineWidth: 1.5)
                                        .frame(width: 14, height: 14)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(output.isDefault ? theme.surfaceContainerHigh : theme.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // MARK: - Input Device & Gain
            VStack(alignment: .leading, spacing: 10) {
                Text("INPUT / MICROPHONE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.outline)

                VStack(spacing: 6) {
                    HStack {
                        Button {
                            audio.toggleMicMute()
                        } label: {
                            Image(systemName: audio.isMicMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(audio.isMicMuted ? theme.error : theme.secondary)
                        }
                        .buttonStyle(.plain)

                        Text("Microphone Gain")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.onSurface)

                        Spacer()

                        Text("\(Int(audio.inputVolume * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.onSurfaceVariant)
                    }

                    Slider(value: Binding(
                        get: { audio.inputVolume },
                        set: { audio.setInputVolume($0) }
                    ), in: 0...1)
                    .tint(theme.secondary)
                }
                .padding(12)
                .background(theme.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Input Devices Radio List
                if !availableInputs.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(availableInputs) { input in
                            Button {
                                audio.setDefaultInput(input.id)
                                refreshDevices()
                                ToastCenter.shared.show(icon: inputIcon(name: input.name), message: "Input: \(input.name)")
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: inputIcon(name: input.name))
                                        .font(.system(size: 13))
                                        .foregroundColor(input.isDefault ? theme.secondary : theme.onSurface)
                                        .frame(width: 20)

                                    Text(input.name)
                                        .font(.system(size: 12, weight: input.isDefault ? .bold : .medium))
                                        .foregroundColor(theme.onSurface)

                                    Spacer()

                                    if input.isDefault {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(theme.secondary)
                                    } else {
                                        Circle()
                                            .stroke(theme.outlineVariant, lineWidth: 1.5)
                                            .frame(width: 14, height: 14)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(input.isDefault ? theme.surfaceContainerHigh : theme.surfaceContainer)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }


            // MARK: - Per-App Audio Stream Mixer
            VStack(alignment: .leading, spacing: 10) {
                Text("STREAM MIXER")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.outline)

                VStack(spacing: 10) {
                    // Active media player track
                    HStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .foregroundColor(theme.primary)
                            .frame(width: 28, height: 28)
                            .background(theme.primaryContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(nowPlaying.currentTrack.title.isEmpty ? "System Media" : nowPlaying.currentTrack.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(theme.onSurface)
                                .lineLimit(1)
                            Text(nowPlaying.currentTrack.artist.isEmpty ? "Active Stream" : nowPlaying.currentTrack.artist)
                                .font(.system(size: 10))
                                .foregroundColor(theme.onSurfaceVariant)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            nowPlaying.playPause()
                        } label: {
                            Image(systemName: nowPlaying.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 12))
                                .foregroundColor(theme.onPrimary)
                                .frame(width: 26, height: 26)
                                .background(theme.primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .onAppear {
            refreshDevices()
        }
    }

    private var availableOutputs: [AudioOutput] {
        let current = audio.outputs
        return !current.isEmpty ? current : outputs
    }

    private var availableInputs: [AudioOutput] {
        let current = audio.inputs
        return !current.isEmpty ? current : inputs
    }

    private func refreshDevices() {
        audio.refresh()
        outputs = audio.outputs
        inputs = audio.inputs
    }

    private func outputIcon(name: String) -> String {
        AudioService.iconForDevice(name: name)
    }

    private func inputIcon(name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpod") {
            return "airpods"
        } else if lower.contains("headphone") || lower.contains("headset") {
            return "headphones"
        }
        return "mic.fill"
    }
}

