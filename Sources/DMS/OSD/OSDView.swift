import SwiftUI
import AppKit
import DMSCore

public enum OSDType {
    case volume
    case brightness
}

public struct OSDView: View {
    @ObservedObject private var theme = ThemeStore.shared
    public let type: OSDType
    public let value: Double
    public let isMuted: Bool

    public init(type: OSDType, value: Double, isMuted: Bool = false) {
        self.type = type
        self.value = value
        self.isMuted = isMuted
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.primary)
                .frame(width: 24)

            // M3 Progress Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.surfaceContainerHighest)

                    Capsule()
                        .fill(theme.primary)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(value))))
                }
            }
            .frame(height: 8)

            Text("\(Int(value * 100))%")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(theme.onSurface)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 260)
        .background(theme.surfaceContainer)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(theme.outlineVariant.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 6)
    }

    private var iconName: String {
        switch type {
        case .volume:
            if isMuted { return "speaker.slash.fill" }
            if value > 0.6 { return "speaker.wave.3.fill" }
            if value > 0.2 { return "speaker.wave.2.fill" }
            return "speaker.wave.1.fill"
        case .brightness:
            return "sun.max.fill"
        }
    }
}
