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
    @ObservedObject private var mixer = AppAudioMixerService.shared

    @State private var outputs: [AudioOutput] = []
    @State private var inputs: [AudioOutput] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MARK: - Output Volume & Sinks
            VStack(alignment: .leading, spacing: 10) {
                Text("OUTPUT DEVICE & VOLUME")
                    .font(ThemeStore.shared.font(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.outline)

                // Master Volume Slider
                VStack(spacing: 6) {
                    HStack {
                        Button {
                            audio.toggleMute()
                        } label: {
                            Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                                .font(ThemeStore.shared.font(size: 14, weight: .semibold))
                                .foregroundColor(theme.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(audio.isMuted ? "Unmute output" : "Mute output")

                        Text("Master Volume")
                            .font(ThemeStore.shared.font(size: 12, weight: .semibold))
                            .foregroundColor(theme.onSurface)

                        Spacer()

                        Text("\(Int(audio.volume * 100))%")
                            .font(ThemeStore.shared.font(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.onSurfaceVariant)
                    }

                    Slider(value: Binding(
                        get: { audio.volume },
                        set: { audio.setVolume($0) }
                    ), in: 0...1)
                    .tint(theme.primary)
                    .accessibilityLabel("Master volume")
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
                                    .font(ThemeStore.shared.font(size: 14))
                                    .foregroundColor(output.isDefault ? theme.primary : theme.onSurface)
                                    .frame(width: 20)

                                Text(output.name)
                                    .font(ThemeStore.shared.font(size: 12, weight: output.isDefault ? .bold : .medium))
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
                    .font(ThemeStore.shared.font(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.outline)

                VStack(spacing: 6) {
                    HStack {
                        Button {
                            audio.toggleMicMute()
                        } label: {
                            Image(systemName: audio.isMicMuted ? "mic.slash.fill" : "mic.fill")
                                .font(ThemeStore.shared.font(size: 14, weight: .semibold))
                                .foregroundColor(audio.isMicMuted ? theme.error : theme.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(audio.isMicMuted ? "Unmute microphone" : "Mute microphone")

                        Text("Microphone Gain")
                            .font(ThemeStore.shared.font(size: 12, weight: .semibold))
                            .foregroundColor(theme.onSurface)

                        Spacer()

                        Text("\(Int(audio.inputVolume * 100))%")
                            .font(ThemeStore.shared.font(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.onSurfaceVariant)
                    }

                    Slider(value: Binding(
                        get: { audio.inputVolume },
                        set: { audio.setInputVolume($0) }
                    ), in: 0...1)
                    .tint(theme.secondary)
                    .accessibilityLabel("Microphone gain")
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
                                        .font(ThemeStore.shared.font(size: 13))
                                        .foregroundColor(input.isDefault ? theme.secondary : theme.onSurface)
                                        .frame(width: 20)

                                    Text(input.name)
                                        .font(ThemeStore.shared.font(size: 12, weight: input.isDefault ? .bold : .medium))
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


            // MARK: - Per-App Audio Mixer (Vorssaint-style CoreAudio Process Taps)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("APP VOLUME MIXER")
                        .font(ThemeStore.shared.font(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(theme.outline)

                    Text("\(activeStreamCount)")
                        .font(ThemeStore.shared.font(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(activeStreamCount > 0 ? theme.onPrimary : theme.onSurfaceVariant)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(activeStreamCount > 0 ? theme.primary : theme.surfaceContainerHighest)
                        .clipShape(Capsule())

                    Spacer()

                    if mixer.hasModifiedApps {
                        Button {
                            mixer.resetAll()
                        } label: {
                            Text("Reset All")
                                .font(ThemeStore.shared.font(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(theme.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(theme.primaryContainer.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Reset all apps to 100% on System Default")
                    }

                    Button {
                        mixer.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                            .foregroundColor(theme.onSurfaceVariant)
                            .rotationEffect(.degrees(mixer.isRefreshing ? 360 : 0))
                            .animation(mixer.isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: mixer.isRefreshing)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Refresh per-app audio streams")
                }

                if let permError = mixer.tapPermissionError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(ThemeStore.shared.font(size: 13))
                            .foregroundColor(theme.error)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("System Audio Recording Required")
                                .font(ThemeStore.shared.font(size: 11, weight: .bold))
                                .foregroundColor(theme.onSurface)
                            Text(permError)
                                .font(ThemeStore.shared.font(size: 9))
                                .foregroundColor(theme.onSurfaceVariant)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button {
                            mixer.openAudioCapturePrivacySettings()
                        } label: {
                            Text("Grant")
                                .font(ThemeStore.shared.font(size: 10, weight: .bold))
                                .foregroundColor(theme.onPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(theme.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(theme.errorContainer.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Active media player transport card
                if !nowPlaying.currentTrack.title.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .foregroundColor(theme.primary)
                            .frame(width: 28, height: 28)
                            .background(theme.primaryContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(nowPlaying.currentTrack.title)
                                .font(ThemeStore.shared.font(size: 12, weight: .bold))
                                .foregroundColor(theme.onSurface)
                                .lineLimit(1)
                            Text(nowPlaying.currentTrack.artist.isEmpty ? "Active Stream" : nowPlaying.currentTrack.artist)
                                .font(ThemeStore.shared.font(size: 10))
                                .foregroundColor(theme.onSurfaceVariant)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            nowPlaying.playPause()
                        } label: {
                            Image(systemName: nowPlaying.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                                .font(ThemeStore.shared.font(size: 12))
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

                if mixer.streams.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.slash")
                            .font(ThemeStore.shared.font(size: 16, weight: .semibold))
                            .foregroundColor(theme.onSurfaceVariant)
                            .frame(width: 28, height: 28)
                            .background(theme.surfaceContainerHighest)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 1) {
                            Text("No active audio apps")
                                .font(ThemeStore.shared.font(size: 12, weight: .semibold))
                                .foregroundColor(theme.onSurface)
                            Text("Play audio in any app (Chrome, Spotify, Discord…) to mix volume up to 200% or route outputs.")
                                .font(ThemeStore.shared.font(size: 10))
                                .foregroundColor(theme.onSurfaceVariant)
                                .lineLimit(2)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        ForEach(mixer.streams) { stream in
                            streamRow(stream)
                        }
                    }
                }
            }
        }
        .onAppear {
            refreshDevices()
            mixer.startPolling()
        }
        .onDisappear {
            mixer.stopPolling()
        }
    }

    private var activeStreamCount: Int {
        mixer.streams.filter(\.isRunningOutput).count
    }

    private func routedOutputLabel(for stream: AudioAppStream) -> (icon: String, name: String) {
        if let uid = stream.outputDeviceUID,
           let matched = mixer.routableOutputs.first(where: { $0.id == uid }) {
            return (matched.iconName, matched.name)
        }
        return ("speaker.wave.2", "Default")
    }

    private func streamRow(_ stream: AudioAppStream) -> some View {
        let routed = routedOutputLabel(for: stream)
        let sliderTint: Color = stream.isMuted
            ? theme.outline
            : (stream.isBoosted ? theme.tertiary : theme.primary)

        return VStack(spacing: 7) {
            HStack(spacing: 8) {
                Button {
                    mixer.activateApp(pid: stream.pid)
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let icon = mixer.icon(for: stream) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(systemName: "app.fill")
                                    .font(ThemeStore.shared.font(size: 15, weight: .semibold))
                                    .foregroundColor(theme.onSurfaceVariant)
                            }
                        }
                        .frame(width: 24, height: 24)

                        if stream.isRunningOutput {
                            Circle()
                                .fill(theme.success)
                                .frame(width: 7, height: 7)
                                .overlay(Circle().stroke(theme.surfaceContainerHigh, lineWidth: 1.2))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Focus \(stream.appName)")

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(stream.appName)
                            .font(ThemeStore.shared.font(size: 12, weight: .semibold))
                            .foregroundColor(theme.onSurface)
                            .lineLimit(1)
                        if stream.isBoosted {
                            statusPill(text: "BOOST", color: theme.tertiary)
                        }
                        if stream.isRunningInput {
                            statusPill(text: "MIC", color: theme.secondary)
                        }
                    }
                    if let uid = stream.outputDeviceUID,
                       let matched = mixer.routableOutputs.first(where: { $0.id == uid }) {
                        Text("Routed → \(matched.name)")
                            .font(ThemeStore.shared.font(size: 9, weight: .medium))
                            .foregroundColor(theme.primary)
                            .lineLimit(1)
                    } else if stream.isTapActive {
                        Text(stream.isMuted ? "Muted via CoreAudio Tap" : "Active CoreAudio Tap")
                            .font(ThemeStore.shared.font(size: 9, weight: .medium))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                }

                Spacer(minLength: 4)

                // Per-app output device routing menu (Vorssaint / FineTune style)
                if stream.capability == .processTap && !mixer.routableOutputs.isEmpty {
                    Menu {
                        Button {
                            mixer.setOutputDevice(for: stream, deviceUID: nil)
                        } label: {
                            Label(
                                "System Default",
                                systemImage: stream.outputDeviceUID == nil ? "checkmark" : "speaker.wave.2"
                            )
                        }
                        Divider()
                        ForEach(mixer.routableOutputs) { output in
                            Button {
                                mixer.setOutputDevice(for: stream, deviceUID: output.id)
                            } label: {
                                Label(
                                    output.name,
                                    systemImage: stream.outputDeviceUID == output.id ? "checkmark" : output.iconName
                                )
                            }
                        }
                    } label: {
                        Image(systemName: routed.icon)
                            .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                            .foregroundColor(stream.outputDeviceUID != nil ? theme.primary : theme.onSurfaceVariant)
                            .frame(width: 22, height: 22)
                            .background(stream.outputDeviceUID != nil ? theme.primaryContainer : theme.surfaceContainer)
                            .clipShape(Circle())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Route \(stream.appName) to a specific output device")
                }

                // Pin app to top of mixer
                Button {
                    mixer.togglePin(for: stream)
                } label: {
                    Image(systemName: stream.isPinned ? "pin.fill" : "pin")
                        .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                        .foregroundColor(stream.isPinned ? theme.primary : theme.onSurfaceVariant.opacity(0.7))
                        .frame(width: 22, height: 22)
                        .background(stream.isPinned ? theme.primaryContainer.opacity(0.75) : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(stream.isPinned ? "Unpin \(stream.appName)" : "Pin \(stream.appName) to top")
            }

            if stream.capability == .processTap || stream.capability == .directVolume {
                HStack(spacing: 8) {
                    Button {
                        mixer.toggleMute(for: stream)
                    } label: {
                        Image(systemName: stream.isMuted ? "speaker.slash.fill" : (stream.isBoosted ? "speaker.wave.3.fill" : "speaker.wave.2.fill"))
                            .font(ThemeStore.shared.font(size: 12, weight: .semibold))
                            .foregroundColor(stream.isMuted ? theme.error : sliderTint)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(stream.isMuted ? "Unmute \(stream.appName)" : "Mute \(stream.appName)")

                    // 0%–200% slider with subtle 100% unity marker at the midpoint
                    ZStack {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(theme.outlineVariant.opacity(0.75))
                                .frame(width: 1.5, height: 10)
                                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
                                .allowsHitTesting(false)
                        }
                        Slider(
                            value: Binding(
                                get: { stream.isMuted ? 0.0 : stream.volume },
                                set: { mixer.setVolume(for: stream, volume: $0) }
                            ),
                            in: 0.0...2.0
                        )
                        .tint(sliderTint)
                        .accessibilityLabel("\(stream.appName) volume (0 to 200 percent)")
                    }
                    .frame(height: 20)

                    // Click percentage pill to snap back to 100% unity
                    Button {
                        mixer.resetApp(stream)
                    } label: {
                        Text(stream.isMuted ? "MUTE" : "\(stream.displayPercent)%")
                            .font(ThemeStore.shared.font(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(stream.isMuted ? theme.error : (stream.isBoosted ? theme.tertiary : theme.onSurfaceVariant))
                            .frame(width: 40, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                    .help("Click to reset \(stream.appName) to 100%")
                }
            }
        }
        .padding(10)
        .background(stream.isTapActive ? theme.surfaceContainerHighest : theme.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusPill(text: String, color: Color) -> some View {
        Text(text)
            .font(ThemeStore.shared.font(size: 8, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
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

