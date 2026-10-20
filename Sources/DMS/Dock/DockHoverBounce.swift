import SwiftUI

/// Two-phase directional hover bounce modifier matching upstream `DockHoverBounce.qml`.
/// Displaces icons toward screen center on hover:
/// `direction`: +1 for Top or Left docks, -1 for Bottom or Right docks.
public struct DockHoverBounceModifier: ViewModifier {
    public let isHovered: Bool
    public let position: Int // 0=top, 1=bottom, 2=left, 3=right
    public let enabled: Bool

    @State private var bounceOffset: CGFloat = 0.0

    private var isVertical: Bool {
        return position == 2 || position == 3
    }

    private var direction: CGFloat {
        // +1 for Top/Left, -1 for Bottom/Right (always toward screen center)
        return (position == 0 || position == 2) ? 1.0 : -1.0
    }

    public func body(content: Content) -> some View {
        content
            .offset(
                x: isVertical ? bounceOffset : 0,
                y: isVertical ? 0 : bounceOffset
            )
            .onChange(of: isHovered) { _, hovered in
                guard enabled else {
                    bounceOffset = 0
                    return
                }
                if hovered {
                    // Phase 1: Emphasized acceleration toward screen center
                    withAnimation(.timingCurve(0.05, 0.7, 0.1, 1.0, duration: 0.15)) {
                        bounceOffset = direction * 10.0 * 0.25 // ~2.5px
                    }
                    // Phase 2: Settling to steady hover offset
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.timingCurve(0.05, 0.9, 0.1, 1.0, duration: 0.15)) {
                            bounceOffset = direction * 10.0 * 0.20 // ~2.0px
                        }
                    }
                } else {
                    // Return to rest
                    withAnimation(.easeOut(duration: 0.15)) {
                        bounceOffset = 0
                    }
                }
            }
    }
}

extension View {
    public func dockHoverBounce(isHovered: Bool, position: Int, enabled: Bool = true) -> some View {
        modifier(DockHoverBounceModifier(isHovered: isHovered, position: position, enabled: enabled))
    }
}
