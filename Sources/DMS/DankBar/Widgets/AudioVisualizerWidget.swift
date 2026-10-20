import SwiftUI
import DMSCore

/// Mini 5-bar equalizer dancing to audio output frequency matching dankdash.png.
public struct AudioVisualizerWidget: View {
    public var isVertical: Bool
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var nowPlaying = NowPlayingService.shared

    @State private var barHeights: [CGFloat] = [0.2, 0.4, 0.7, 0.5, 0.3]
    @State private var animationTask: Task<Void, Never>? = nil

    public init(isVertical: Bool = false) {
        self.isVertical = isVertical
    }

    public var body: some View {
        Button {
            AudioPopoutController.shared.toggle(anchorX: NSEvent.mouseLocation.x)
        } label: {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<5, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(theme.primary)
                        .frame(width: 2.0, height: max(3, barHeights[idx] * 14))
                        .animation(.easeInOut(duration: 0.12), value: barHeights[idx])
                }
            }
            .frame(width: isVertical ? 24 : nil, height: isVertical ? 24 : 22)
            .padding(.horizontal, isVertical ? 0 : 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            updateAnimationState(isPlaying: nowPlaying.currentTrack.isPlaying)
        }
        .onChange(of: nowPlaying.currentTrack.isPlaying) { _, isPlaying in
            updateAnimationState(isPlaying: isPlaying)
        }
        .onDisappear {
            stopAnimation()
        }
    }


    private func updateAnimationState(isPlaying: Bool) {
        if isPlaying {
            startAnimation()
        } else {
            stopAnimation()
        }
    }

    private func startAnimation() {
        stopAnimation()
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000)
                if Task.isCancelled { break }
                barHeights = (0..<5).map { _ in CGFloat.random(in: 0.2...1.0) }
            }
        }
    }

    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
        barHeights = [0.2, 0.4, 0.7, 0.5, 0.3]
    }
}

