import SwiftUI
import DMSCore
import MaterialMacLibrary

/// Two-phase directional hover bounce modifier matching upstream `DockHoverBounce.qml`.
/// Displaces icons toward screen center on hover:
/// `position`: 0 = top, 1 = bottom, 2 = left, 3 = right.
/// Bounce choreography is delegated to `MaterialComponents.HoverBounceModifier` with the
/// bridged `MaterialTheme` (motion curves come from its motion tokens).
public struct DockHoverBounceModifier: ViewModifier {
    public let isHovered: Bool
    public let position: Int // 0=top, 1=bottom, 2=left, 3=right
    public let enabled: Bool

    @ObservedObject private var theme = ThemeStore.shared

    public init(isHovered: Bool, position: Int, enabled: Bool = true) {
        self.isHovered = isHovered
        self.position = position
        self.enabled = enabled
    }

    public func body(content: Content) -> some View {
        content
            .materialTheme(theme.materialTheme)
            .modifier(HoverBounceModifier(isHovered: isHovered, position: position, enabled: enabled))
    }
}

extension View {
    public func dockHoverBounce(isHovered: Bool, position: Int, enabled: Bool = true) -> some View {
        modifier(DockHoverBounceModifier(isHovered: isHovered, position: position, enabled: enabled))
    }
}
