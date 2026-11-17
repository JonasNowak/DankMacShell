import SwiftUI
import DMSCore
import MaterialMacLibrary

/// A high-performance, mathematically continuous SwiftUI Shape that renders DankBar container
/// geometry according to Material Design 3 and DMS specification (`BAR-001`, `SURF-001`).
/// Supports Capsule, Continuous Rounded, Square (0px flush), and Gothic concave fillet curves
/// that bridge seamlessly into macOS screen bezels and MacBook camera notches.
/// Path geometry is delegated to `MaterialShapes.GothEarCornerShape`.
public struct BarGothCornerShape: Shape {
    public var position: String // "top", "bottom", "left", "right"
    public var cornerStyle: BarCornerStyle
    public var cornerRadius: CGFloat
    public var filletRadius: CGFloat
    public var isVertical: Bool
    public var isLeftWing: Bool?
    public var isRightWing: Bool?
    public var closedSeam: Bool

    public init(
        position: String = "bottom",
        cornerStyle: BarCornerStyle = .capsule,
        cornerRadius: CGFloat = -1,
        filletRadius: CGFloat = 14,
        isVertical: Bool = false,
        isLeftWing: Bool? = nil,
        isRightWing: Bool? = nil,
        closedSeam: Bool = true
    ) {
        self.position = position
        self.cornerStyle = cornerStyle
        self.cornerRadius = cornerRadius
        self.filletRadius = max(4.0, filletRadius)
        self.isVertical = isVertical
        self.isLeftWing = isLeftWing
        self.isRightWing = isRightWing
        self.closedSeam = closedSeam
    }

    private var edge: MaterialEdge {
        switch position.lowercased() {
        case "top": return .top
        case "left": return .left
        case "right": return .right
        default: return .bottom
        }
    }

    private var materialCornerStyle: MaterialCornerStyle {
        MaterialCornerStyle(rawValue: cornerStyle.rawValue) ?? .capsule
    }

    public func path(in rect: CGRect) -> Path {
        GothEarCornerShape(
            edge: edge,
            cornerStyle: materialCornerStyle,
            cornerRadius: cornerRadius,
            filletRadius: filletRadius,
            isVertical: isVertical,
            closedSeam: closedSeam
        )
        .path(in: rect)
    }
}
