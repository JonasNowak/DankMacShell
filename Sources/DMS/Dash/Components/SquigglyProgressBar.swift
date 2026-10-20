import SwiftUI
import Combine
import DMSCore

/// Material 3 expressive squiggly seek bar matching Android 13/14 and DankDash design.
public struct SquigglyProgressBar: View {
    public var progress: Double // 0.0 to 1.0
    public var isPlaying: Bool
    public var color: Color
    public var trackColor: Color
    public var onSeek: ((Double) -> Void)? = nil

    @State private var wavePhase: Double = 0.0
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    public init(
        progress: Double,
        isPlaying: Bool = true,
        color: Color,
        trackColor: Color = Color.white.opacity(0.12),
        onSeek: ((Double) -> Void)? = nil
    ) {
        self.progress = min(1.0, max(0.0, progress))
        self.isPlaying = isPlaying
        self.color = color
        self.trackColor = trackColor
        self.onSeek = onSeek
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midY = h / 2.0
            let playedWidth = max(0, min(w, w * CGFloat(progress)))
            let currentAmplitude: CGFloat = isPlaying ? 2.2 : 0.0
            let waveLength: CGFloat = 18.0

            ZStack(alignment: .leading) {
                // Background remaining track (subtle straight horizontal line)
                if playedWidth < w {
                    Path { p in
                        p.move(to: CGPoint(x: playedWidth, y: midY))
                        p.addLine(to: CGPoint(x: w, y: midY))
                    }
                    .stroke(trackColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }

                // Material 3 Squiggly played track
                Path { p in
                    let step: CGFloat = 2.0
                    var x: CGFloat = 0.0

                    p.move(to: CGPoint(x: 0, y: midY))
                    while x <= playedWidth {
                        let angle = (x / waveLength) * 2.0 * .pi + CGFloat(wavePhase)
                        let y = midY + sin(angle) * currentAmplitude
                        p.addLine(to: CGPoint(x: x, y: y))
                        x += step
                    }
                    // Connect smoothly to the thumb position
                    if currentAmplitude > 0 && playedWidth > 0 {
                        let finalAngle = (playedWidth / waveLength) * 2.0 * .pi + CGFloat(wavePhase)
                        let finalY = midY + sin(finalAngle) * currentAmplitude
                        p.addLine(to: CGPoint(x: playedWidth, y: finalY))
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                // Subtle vertical needle marker (avoids an overly clickable / chunky slider knob appearance)
                if progress > 0.01 && progress < 0.99 {
                    RoundedRectangle(cornerRadius: 1.0)
                        .fill(color)
                        .frame(width: 2.0, height: 10.5)
                        .position(x: playedWidth, y: midY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard w > 0 else { return }
                        let newProg = Double(max(0, min(1, value.location.x / w)))
                        onSeek?(newProg)
                    }
            )
        }
        .frame(height: 14)
        .onReceive(timer) { _ in
            if isPlaying {
                wavePhase += 0.12
                if wavePhase > 2.0 * .pi {
                    wavePhase -= 2.0 * .pi
                }
            }
        }
    }
}
