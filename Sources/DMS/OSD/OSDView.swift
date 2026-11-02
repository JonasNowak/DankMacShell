import SwiftUI
import AppKit
import DMSCore

public struct OSDView: View {
    @ObservedObject private var theme = ThemeStore.shared
    public let type: OSDType
    public let value: Double?
    public let isMuted: Bool
    public let text: String?

    public init(type: OSDType, value: Double? = nil, isMuted: Bool = false, text: String? = nil) {
        self.type = type
        self.value = value
        self.isMuted = isMuted
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.iconName(isMuted: isMuted, value: value, text: text))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.primary)
                .frame(width: 24)

            if type.isGaugeMetric, let val = value {
                // M3 Progress Track
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.surfaceContainerHighest)

                        Capsule()
                            .fill(theme.primary)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(val))))
                    }
                }
                .frame(height: 8)

                Text(type.formattedValue(isMuted: isMuted, value: value, text: text))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.onSurface)
                    .frame(width: 44, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.title)
                        .font(theme.font(size: 10, weight: .medium))
                        .foregroundColor(theme.onSurfaceVariant)
                    Text(type.formattedValue(isMuted: isMuted, value: value, text: text))
                        .font(theme.font(size: 13, weight: .bold))
                        .foregroundColor(theme.onSurface)
                        .lineLimit(1)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 260)
        .background(GlassSurfaceBackground(forceGlass: true))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(theme.panelBorderColor, lineWidth: 1)
        )
        .shadow(color: theme.adaptiveShadowColor(baseOpacity: 0.28), radius: 15, x: 0, y: 6)
    }
}
