import SwiftUI
import DMSCore
import MaterialMacLibrary

/// Role of a segment inside a segmented pill run, bridged to `MaterialSegmentRole`.
public typealias BarSegmentRole = MaterialSegmentRole

/// A custom Shape that renders rounded corners according to a widget's SegmentRole and axis
/// orientation. Corner curve logic is delegated to `MaterialShapes.SegmentedPillShape`:
/// outer ends get the full half-extent radius, inner joints get `min(radius, 4)`.
public struct M3SegmentedPillShape: Shape {
    public var role: SegmentRole
    public var isVertical: Bool
    public var radius: CGFloat

    public init(role: SegmentRole, isVertical: Bool = false, radius: CGFloat = 14) {
        self.role = role
        self.isVertical = isVertical
        self.radius = radius
    }

    private var materialRole: MaterialSegmentRole {
        MaterialSegmentRole(rawValue: role.rawValue) ?? .solo
    }

    public func path(in rect: CGRect) -> Path {
        SegmentedPillShape(role: materialRole, isVertical: isVertical, radius: radius)
            .path(in: rect)
    }
}

/// Clips content to the segment's pill shape (scaled through the theme shape tokens) and
/// draws the thin inner divider between adjacent segments. Delegates to
/// `MaterialComponents.SegmentedPillModifier` with the bridged `MaterialTheme`.
public struct M3SegmentedPillModifier: ViewModifier {
    public var role: SegmentRole
    public var isVertical: Bool
    public var radius: CGFloat

    @ObservedObject private var theme = ThemeStore.shared

    public init(role: SegmentRole, isVertical: Bool = false, radius: CGFloat = 14) {
        self.role = role
        self.isVertical = isVertical
        self.radius = radius
    }

    private var materialRole: MaterialSegmentRole {
        MaterialSegmentRole(rawValue: role.rawValue) ?? .solo
    }

    public func body(content: Content) -> some View {
        content
            .materialTheme(theme.materialTheme)
            .modifier(SegmentedPillModifier(role: materialRole, isVertical: isVertical, radius: radius))
    }
}

public extension View {
    func segmentedPill(role: SegmentRole, isVertical: Bool = false, radius: CGFloat = 14) -> some View {
        self.modifier(M3SegmentedPillModifier(role: role, isVertical: isVertical, radius: radius))
    }
}
