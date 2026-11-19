import SwiftUI
import AppKit
import DMSCore

/// Compact privacy indicator pill for the DankBar (`privacyIndicator` widget).
/// Observes `PrivacyIndicatorService` and renders an orange mic badge while the microphone
/// is in use and/or a green camera badge while the camera is in use. Hidden when neither is active.
/// Complies with `docs/spec/20-bar-widgets.md`.
public struct PrivacyIndicatorWidget: View {
    public var isVertical: Bool
    public var options: [String: AnyCodable]
    public var style: BarWidgetStyleOptions

    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var privacy = PrivacyIndicatorService.shared

    public init(
        isVertical: Bool = false,
        options: [String: AnyCodable] = [:],
        style: BarWidgetStyleOptions = BarWidgetStyleOptions()
    ) {
        self.isVertical = isVertical
        self.options = options
        self.style = style
    }

    private var backgroundColor: Color {
        if let hex = style.customBackgroundHex, !hex.isEmpty { return Color(hex: hex) }
        return theme.barWidgetBackground
    }

    public var body: some View {
        Group {
            if privacy.isAnyActive {
                HStack(spacing: 4) {
                    if privacy.isMicActive {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.warning)
                            .accessibilityLabel("Microphone in use")
                    }
                    if privacy.isCameraActive {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.success)
                            .accessibilityLabel("Camera in use")
                    }
                    if !isVertical && style.showLabel && !style.compactMode {
                        Text(privacy.isMicActive && privacy.isCameraActive ? "Mic+Cam" : (privacy.isMicActive ? "Mic" : "Cam"))
                            .font(theme.font(size: 10, weight: .bold))
                            .foregroundColor(theme.onSurface)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, isVertical ? 0 : 7)
                .frame(width: isVertical ? 28 : nil, height: 28)
                .background(backgroundColor)
            }
        }
    }
}
