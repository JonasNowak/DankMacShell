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
        let f = min(filletRadius, isVertical ? rect.width * 0.45 : rect.height * 0.45, isVertical ? rect.height * 0.25 : rect.width * 0.25)

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
            // Anchored to top screen bezel / bar edge (minY). Concave fillets curve inward-downward at top-left and top-right.
            if closedSeam {
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            } else {
                path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            }
            // Right concave circular fillet curving inward-downward into bar body
            path.addArc(
                center: CGPoint(x: rect.maxX, y: rect.minY + f),
                radius: f,
                startAngle: .degrees(270),
                endAngle: .degrees(180),
                clockwise: true
            )
            // Down right vertical edge to bottom-right corner
            path.addLine(to: CGPoint(x: rect.maxX - f, y: rect.maxY - outerR))
            // Bottom-right convex corner
            if outerR > 0 {
                path.addArc(
                    center: CGPoint(x: rect.maxX - f - outerR, y: rect.maxY - outerR),
                    radius: outerR,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false
                )
            } else {
                path.addLine(to: CGPoint(x: rect.maxX - f, y: rect.maxY))
            }
            // Across bottom edge to bottom-left corner
            path.addLine(to: CGPoint(x: rect.minX + f + outerR, y: rect.maxY))
            // Bottom-left convex corner
            if outerR > 0 {
                path.addArc(
                    center: CGPoint(x: rect.minX + f + outerR, y: rect.maxY - outerR),
                    radius: outerR,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false
                )
            } else {
                path.addLine(to: CGPoint(x: rect.minX + f, y: rect.maxY))
            }
            // Up left vertical edge to top-left concave fillet
            path.addLine(to: CGPoint(x: rect.minX + f, y: rect.minY + f))
            // Top-left concave circular fillet curving outward-upward to screen bezel
            path.addArc(
                center: CGPoint(x: rect.minX, y: rect.minY + f),
                radius: f,
                startAngle: .degrees(0),
                endAngle: .degrees(270),
                clockwise: true
            )
            if closedSeam {
                path.closeSubpath()
            }
            return path

        case "left":
            // Anchored to left screen bezel / bar edge (minX). Concave fillets curve inward-rightward at top-left and bottom-left.
            if closedSeam {
                path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            } else {
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            }
            // Top-left concave circular fillet
            path.addArc(
                center: CGPoint(x: rect.minX, y: rect.minY + f),
                radius: f,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            // Across top horizontal edge to top-right corner
            path.addLine(to: CGPoint(x: rect.maxX - outerR, y: rect.minY + f))
            // Top-right convex corner
            if outerR > 0 {
                path.addArc(
                    center: CGPoint(x: rect.maxX - outerR, y: rect.minY + f + outerR),
                    radius: outerR,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(0),
                    clockwise: false
                )
            } else {
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + f))
            }
            // Down right vertical edge to bottom-right corner
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - f - outerR))
            // Bottom-right convex corner
            if outerR > 0 {
                path.addArc(
                    center: CGPoint(x: rect.maxX - outerR, y: rect.maxY - f - outerR),
                    radius: outerR,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false
                )
            } else {
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - f))
            }
            // Leftward along bottom horizontal edge
            path.addLine(to: CGPoint(x: rect.minX + f, y: rect.maxY - f))
            // Bottom-left concave fillet
            path.addArc(
                center: CGPoint(x: rect.minX, y: rect.maxY - f),
                radius: f,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            if closedSeam {
                path.closeSubpath()
            }
            return path

        case "right":
            // Anchored to right screen bezel / bar edge (maxX). Concave fillets curve inward-leftward at top-right and bottom-right.
            if closedSeam {
                path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            } else {
                path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }
            // Bottom-right concave fillet
            path.addArc(
                center: CGPoint(x: rect.maxX, y: rect.maxY - f),
                radius: f,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            // Across bottom horizontal edge to bottom-left corner
            path.addLine(to: CGPoint(x: rect.minX + outerR, y: rect.maxY - f))
            // Bottom-left convex corner
            if outerR > 0 {
                path.addArc(
                    center: CGPoint(x: rect.minX + outerR, y: rect.maxY - f - outerR),
                    radius: outerR,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false
                )
            } else {
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - f))
            }
            // Up left vertical edge to top-left corner
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + f + outerR))
            // Top-left convex corner
            if outerR > 0 {
                path.addArc(
                    center: CGPoint(x: rect.minX + outerR, y: rect.minY + f + outerR),
                    radius: outerR,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false
                )
            } else {
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + f))
            }
            // Across top horizontal edge
            path.addLine(to: CGPoint(x: rect.maxX - f, y: rect.minY + f))
            // Top-right concave fillet
            path.addArc(
                center: CGPoint(x: rect.maxX, y: rect.minY + f),
                radius: f,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
            if closedSeam {
                path.closeSubpath()
            }
            return path

        case "bottom":
            fallthrough
        default:
            // Anchored to bottom screen bezel / bar edge (maxY). Concave fillets curve inward-upward at bottom-left and bottom-right.
            if closedSeam {
                path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            } else {
                path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }
            // Right concave circular fillet curving inward-upward
            path.addArc(
                center: CGPoint(x: rect.maxX, y: rect.maxY - f),
                radius: f,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            // Up right vertical edge to top-right corner
            path.addLine(to: CGPoint(x: rect.maxX - f, y: rect.minY + outerR))
            // Top-right convex corner
            if outerR > 0 {
                path.addArc(
                    center: CGPoint(x: rect.maxX - f - outerR, y: rect.minY + outerR),
                    radius: outerR,
                    startAngle: .degrees(0),
                    endAngle: .degrees(-90),
                    clockwise: true
                )
            } else {
                path.addLine(to: CGPoint(x: rect.maxX - f, y: rect.minY))
            }
            // Across top edge to top-left corner
            path.addLine(to: CGPoint(x: rect.minX + f + outerR, y: rect.minY))
            // Top-left convex corner
            if outerR > 0 {
                path.addArc(
                    center: CGPoint(x: rect.minX + f + outerR, y: rect.minY + outerR),
                    radius: outerR,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(180),
                    clockwise: true
                )
            } else {
                path.addLine(to: CGPoint(x: rect.minX + f, y: rect.minY))
            }
            // Down left vertical edge to bottom-left concave fillet
            path.addLine(to: CGPoint(x: rect.minX + f, y: rect.maxY - f))
            // Bottom-left concave circular fillet curving outward-downward to bezel
            path.addArc(
                center: CGPoint(x: rect.minX, y: rect.maxY - f),
                radius: f,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            if closedSeam {
                path.closeSubpath()
            }
            return path
        }
    }
}
