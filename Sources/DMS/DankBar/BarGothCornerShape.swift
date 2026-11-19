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
        let base = GothEarCornerShape(
            edge: edge,
            cornerStyle: materialCornerStyle,
            cornerRadius: cornerRadius,
            filletRadius: filletRadius,
            isVertical: isVertical,
            closedSeam: closedSeam
        )
        .path(in: rect)

        // Single-ear wing clipping: `GothEarCornerShape` has no wing parameters, so for a
        // top bar in gothic style we rebuild the path manually and keep the concave fillet
        // only on the notch-facing side. The bezel-facing side gets a straight square seam,
        // so notch wings no longer ignore their wing flags.
        guard cornerStyle == .gothic,
              position.lowercased() == "top",
              rect.width > 0, rect.height > 0,
              isLeftWing == true || isRightWing == true else {
            return base
        }

        let f = min(filletRadius, rect.width * 0.25, rect.height * 0.5)
        let cr = cornerRadius >= 0 ? cornerRadius : 18
        let br = min(cr, (rect.width - 2 * f) * 0.5, rect.height * 0.5)
        let bl = min(cr, (rect.width - 2 * f) * 0.5, rect.height * 0.5)

        var path = Path()
        if isLeftWing == true {
            // Left wing: concave ear on the RIGHT (notch side), square seam on the LEFT (bezel)
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX, y: rect.minY + f),
                radius: f,
                startAngle: .degrees(270),
                endAngle: .degrees(180),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: rect.maxX - f, y: rect.maxY - br))
            path.addArc(
                center: CGPoint(x: rect.maxX - f - br, y: rect.maxY - br),
                radius: br,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                radius: bl,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.closeSubpath()
        } else {
            // Right wing: concave ear on the LEFT (notch side), square seam on the RIGHT (bezel)
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
            path.addArc(
                center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                radius: br,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX + f + bl, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + f + bl, y: rect.maxY - bl),
                radius: bl,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX + f, y: rect.minY + f))
            path.addArc(
                center: CGPoint(x: rect.minX, y: rect.minY + f),
                radius: f,
                startAngle: .degrees(0),
                endAngle: .degrees(270),
                clockwise: true
            )
            path.closeSubpath()
        }
        return path
    }
}
