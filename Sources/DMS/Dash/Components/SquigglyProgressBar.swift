import SwiftUI
import DMSCore
import MaterialMacLibrary
import MaterialComponents

/// Material 3 expressive squiggly seek bar matching Android 13/14 and DankDash design.
/// Wave drawing, needle marker, and seek gesture are delegated to
/// `MaterialComponents.SquigglyProgressBar` with the bridged `MaterialTheme`.
@MainActor
public struct SquigglyProgressBar: View {
    public var progress: Double // 0.0 to 1.0 (clamped on init)
    public var isPlaying: Bool
    public var color: Color
    public var trackColor: Color
    public var onSeek: ((Double) -> Void)?

    @ObservedObject private var theme = ThemeStore.shared

    public init(
        progress: Double,
        isPlaying: Bool = true,
        color: Color,
        trackColor: Color? = nil,
        onSeek: ((Double) -> Void)? = nil
    ) {
        self.progress = min(1.0, max(0.0, progress))
        self.isPlaying = isPlaying
        self.color = color
        self.trackColor = trackColor ?? ThemeStore.shared.subtleTrackColor
        self.onSeek = onSeek
    }

    public var body: some View {
        MaterialComponents.SquigglyProgressBar(
            progress: progress,
            isPlaying: isPlaying,
            activeColor: color,
            trackColor: trackColor,
            onSeek: onSeek
        )
        .materialTheme(theme.materialTheme)
    }
}
