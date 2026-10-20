import SwiftUI
import DMSCore

/// A custom Shape that renders rounded corners according to a widget's SegmentRole and axis orientation.
public struct M3SegmentedPillShape: Shape {
    public var role: SegmentRole
    public var isVertical: Bool
    public var radius: CGFloat

    public init(role: SegmentRole, isVertical: Bool = false, radius: CGFloat = 14) {
        self.role = role
        self.isVertical = isVertical
        self.radius = radius
    }

    public func path(in rect: CGRect) -> Path {
        let maxR = min(rect.width, rect.height) / 2.0
        let innerR = min(radius, 4.0)

        let topLeading: CGFloat
        let bottomLeading: CGFloat
        let bottomTrailing: CGFloat
        let topTrailing: CGFloat

        switch role {
        case .solo:
            topLeading = maxR
            topTrailing = maxR
            bottomLeading = maxR
            bottomTrailing = maxR

        case .middle:
            topLeading = innerR
            topTrailing = innerR
            bottomLeading = innerR
            bottomTrailing = innerR

        case .first:
            if isVertical {
                // Top rounded, bottom flat/inner
                topLeading = maxR
                topTrailing = maxR
                bottomLeading = innerR
                bottomTrailing = innerR
            } else {
                // Left rounded, right flat/inner
                topLeading = maxR
                bottomLeading = maxR
                topTrailing = innerR
                bottomTrailing = innerR
            }

        case .last:
            if isVertical {
                // Top flat/inner, bottom rounded
                topLeading = innerR
                topTrailing = innerR
                bottomLeading = maxR
                bottomTrailing = maxR
            } else {
                // Left flat/inner, right rounded
                topLeading = innerR
                bottomLeading = innerR
                topTrailing = maxR
                bottomTrailing = maxR
            }
        }

        return UnevenRoundedRectangle(
            topLeadingRadius: topLeading,
            bottomLeadingRadius: bottomLeading,
            bottomTrailingRadius: bottomTrailing,
            topTrailingRadius: topTrailing
        ).path(in: rect)
    }
}

public struct M3SegmentedPillModifier: ViewModifier {
    public var role: SegmentRole
    public var isVertical: Bool
    public var radius: CGFloat
    @ObservedObject private var theme = ThemeStore.shared

    public func body(content: Content) -> some View {
        let effectiveRadius = theme.scaledRadius(radius)
        let shape = M3SegmentedPillShape(role: role, isVertical: isVertical, radius: effectiveRadius)
        content
            .clipShape(shape)
            .overlay(alignment: isVertical ? .bottom : .trailing) {
                if role == .first || role == .middle {
                    Rectangle()
                        .fill(theme.outlineVariant.opacity(0.28))
                        .frame(
                            width: isVertical ? 16 : 1,
                            height: isVertical ? 1 : 16
                        )
                }
            }
    }
}

public extension View {
    func segmentedPill(role: SegmentRole, isVertical: Bool = false, radius: CGFloat = 14) -> some View {
        self.modifier(M3SegmentedPillModifier(role: role, isVertical: isVertical, radius: radius))
    }
}
