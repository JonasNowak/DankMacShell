import SwiftUI
import DMSCore

/// A high-performance, mathematically continuous SwiftUI Shape that renders DankBar container
/// geometry according to Material Design 3 and DMS specification (`BAR-001`, `SURF-001`).
/// Supports Capsule, Continuous Rounded, Square (0px flush), and Gothic concave fillet curves
/// that bridge seamlessly into macOS screen bezels and MacBook camera notches.
public struct BarGothCornerShape: Shape {
    public var position: String // "top", "bottom", "left", "right"
    public var cornerStyle: BarCornerStyle
    public var cornerRadius: CGFloat
    public var filletRadius: CGFloat
    public var isVertical: Bool
    public var isLeftWing: Bool?
    public var isRightWing: Bool?

    public init(
        position: String = "bottom",
        cornerStyle: BarCornerStyle = .capsule,
        cornerRadius: CGFloat = -1,
        filletRadius: CGFloat = 14,
        isVertical: Bool = false,
        isLeftWing: Bool? = nil,
        isRightWing: Bool? = nil
    ) {
        self.position = position
        self.cornerStyle = cornerStyle
        self.cornerRadius = cornerRadius
        self.filletRadius = max(4.0, filletRadius)
        self.isVertical = isVertical
        self.isLeftWing = isLeftWing
        self.isRightWing = isRightWing
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0 && rect.height > 0 else { return path }

        // 1. Square Corners (BAR-001: 0px when edge-attached or square selected)
        if cornerStyle == .square || (cornerRadius == 0 && cornerStyle != .gothic) {
            path.addRect(rect)
            return path
        }

        // 2. Full Capsule (M3 full-pill shape)
        if cornerStyle == .capsule || (cornerRadius < 0 && cornerStyle != .gothic) {
            return Capsule().path(in: rect)
        }

        // 3. Continuous Rounded Rectangle
        if cornerStyle == .rounded {
            let r = min(cornerRadius > 0 ? cornerRadius : 16, min(rect.width, rect.height) * 0.5)
            return RoundedRectangle(cornerRadius: r, style: .continuous).path(in: rect)
        }

        // 4. Gothic Concave Fillet Corners (Connected Mode / Bezel Bridging)
        let pos = position.lowercased()
        let f = min(filletRadius, isVertical ? rect.height * 0.25 : rect.width * 0.25, isVertical ? rect.width * 0.45 : rect.height * 0.45)

        let outerR: CGFloat
        if cornerRadius < 0 {
            outerR = min((isVertical ? rect.width : rect.height) * 0.5, (isVertical ? rect.height - 2 * f : rect.width - 2 * f) * 0.5)
        } else if cornerRadius == 0 {
            outerR = 0
        } else {
            outerR = min(cornerRadius, (isVertical ? rect.height - 2 * f : rect.width - 2 * f) * 0.5, (isVertical ? rect.width - f : rect.height - f) * 0.5)
        }

        switch pos {
        case "top":
            // Anchored to top screen bezel (minY). Concave fillets curve inward-downward at top-left and top-right.
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            // Top edge across to top-right outer flange
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            // Right concave fillet curving inward-downward
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - f, y: rect.minY + f),
                control: CGPoint(x: rect.maxX - f, y: rect.minY)
            )
            // Down right vertical edge to bottom-right corner
            path.addLine(to: CGPoint(x: rect.maxX - f, y: rect.maxY - outerR))
            // Bottom-right convex corner
            if outerR > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - f - outerR, y: rect.maxY),
                    control: CGPoint(x: rect.maxX - f, y: rect.maxY)
                )
            }
            // Across bottom edge to bottom-left corner
            path.addLine(to: CGPoint(x: rect.minX + f + outerR, y: rect.maxY))
            // Bottom-left convex corner
            if outerR > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX + f, y: rect.maxY - outerR),
                    control: CGPoint(x: rect.minX + f, y: rect.maxY)
                )
            }
            // Up left vertical edge to top-left concave fillet
            path.addLine(to: CGPoint(x: rect.minX + f, y: rect.minY + f))
            // Top-left concave fillet curving outward-upward
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.minY),
                control: CGPoint(x: rect.minX + f, y: rect.minY)
            )
            path.closeSubpath()
            return path

        case "left":
            // Anchored to left screen bezel (minX). Concave fillets curve inward-rightward at top-left and bottom-left.
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            // Top-left concave fillet curving inward-rightward
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + f, y: rect.minY + f),
                control: CGPoint(x: rect.minX, y: rect.minY + f)
            )
            // Across top horizontal edge to top-right corner
            path.addLine(to: CGPoint(x: rect.maxX - outerR, y: rect.minY + f))
            // Top-right convex corner
            if outerR > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX, y: rect.minY + f + outerR),
                    control: CGPoint(x: rect.maxX, y: rect.minY + f)
                )
            }
            // Down right vertical edge to bottom-right corner
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - f - outerR))
            // Bottom-right convex corner
            if outerR > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - outerR, y: rect.maxY - f),
                    control: CGPoint(x: rect.maxX, y: rect.maxY - f)
                )
            }
            // Leftward along bottom horizontal edge
            path.addLine(to: CGPoint(x: rect.minX + f, y: rect.maxY - f))
            // Bottom-left concave fillet curving downward-outward to left screen bezel
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY),
                control: CGPoint(x: rect.minX, y: rect.maxY - f)
            )
            // Up along left screen bezel back to top
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.closeSubpath()
            return path

        case "right":
            // Anchored to right screen bezel (maxX). Concave fillets curve inward-leftward at top-right and bottom-right.
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            // Top-right concave fillet curving inward-leftward
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - f, y: rect.minY + f),
                control: CGPoint(x: rect.maxX, y: rect.minY + f)
            )
            // Across top horizontal edge to top-left corner
            path.addLine(to: CGPoint(x: rect.minX + outerR, y: rect.minY + f))
            // Top-left convex corner
            if outerR > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.minY + f + outerR),
                    control: CGPoint(x: rect.minX, y: rect.minY + f)
                )
            }
            // Down left vertical edge to bottom-left corner
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - f - outerR))
            // Bottom-left convex corner
            if outerR > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX + outerR, y: rect.maxY - f),
                    control: CGPoint(x: rect.minX, y: rect.maxY - f)
                )
            }
            // Rightward along bottom horizontal edge
            path.addLine(to: CGPoint(x: rect.maxX - f, y: rect.maxY - f))
            // Bottom-right concave fillet curving downward-outward to right screen bezel
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY - f)
            )
            // Up along right screen bezel back to top
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
            return path

        case "bottom":
            fallthrough
        default:
            // Anchored to bottom screen bezel (maxY). Concave fillets curve inward-upward at bottom-left and bottom-right.
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            // Bottom edge across to bottom-right outer flange
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            // Right concave fillet curving inward-upward
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - f, y: rect.maxY - f),
                control: CGPoint(x: rect.maxX - f, y: rect.maxY)
            )
            // Up right vertical edge to top-right corner
            path.addLine(to: CGPoint(x: rect.maxX - f, y: rect.minY + outerR))
            // Top-right convex corner
            if outerR > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - f - outerR, y: rect.minY),
                    control: CGPoint(x: rect.maxX - f, y: rect.minY)
                )
            }
            // Across top edge to top-left corner
            path.addLine(to: CGPoint(x: rect.minX + f + outerR, y: rect.minY))
            // Top-left convex corner
            if outerR > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX + f, y: rect.minY + outerR),
                    control: CGPoint(x: rect.minX + f, y: rect.minY)
                )
            }
            // Down left vertical edge to bottom-left concave fillet
            path.addLine(to: CGPoint(x: rect.minX + f, y: rect.maxY - f))
            // Bottom-left concave fillet curving outward-downward
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY),
                control: CGPoint(x: rect.minX + f, y: rect.maxY)
            )
            path.closeSubpath()
            return path
        }
    }
}
