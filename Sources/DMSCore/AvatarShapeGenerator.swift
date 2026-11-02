import Foundation
import CoreGraphics

/// Generates geometric mask paths for header user avatars.
/// Ported from upstream DMS `quickshell/Modules/ControlCenter/Components/UserAvatar.qml`
/// supporting all 12 canonical userShapes:
/// `circle`, `cookie4`, `cookie7`, `cookie12`, `clover4`, `clover8`, `sunny`, `pentagon`, `arch`, `slanted`, `gem`, `square`.
public enum AvatarShapeGenerator: Sendable {

    public static func path(for shapeName: String, in rect: CGRect) -> CGPath {
        let w = rect.width
        let h = rect.height
        guard w > 0, h > 0 else {
            return CGPath(rect: rect, transform: nil)
        }

        let cx = rect.midX
        let cy = rect.midY
        let r = min(w, h) / 2.0

        switch shapeName.lowercased() {
        case "cookie4":
            return modulatedPolarPath(cx: cx, cy: cy, baseR: r, frequency: 4, amplitude: 0.14, steps: 96)

        case "cookie7":
            return modulatedPolarPath(cx: cx, cy: cy, baseR: r, frequency: 7, amplitude: 0.12, steps: 112)

        case "cookie12":
            return modulatedPolarPath(cx: cx, cy: cy, baseR: r, frequency: 12, amplitude: 0.10, steps: 144)

        case "clover4":
            return cloverPath(cx: cx, cy: cy, baseR: r, leaves: 4, steps: 96)

        case "clover8":
            return cloverPath(cx: cx, cy: cy, baseR: r, leaves: 8, steps: 128)

        case "sunny":
            return sunnyPath(cx: cx, cy: cy, outerR: r, innerR: r * 0.78, rays: 8)

        case "pentagon":
            return regularPolygonPath(cx: cx, cy: cy, radius: r, sides: 5, startAngle: -CGFloat.pi / 2.0)

        case "arch":
            return archPath(rect: rect)

        case "slanted":
            return slantedPath(rect: rect)

        case "gem":
            return gemPath(rect: rect)

        case "square":
            return CGPath(roundedRect: rect, cornerWidth: w * 0.22, cornerHeight: h * 0.22, transform: nil)

        case "circle":
            fallthrough
        default:
            return CGPath(ellipseIn: rect, transform: nil)
        }
    }

    // MARK: - Private Path Solvers

    private static func modulatedPolarPath(
        cx: CGFloat,
        cy: CGFloat,
        baseR: CGFloat,
        frequency: Int,
        amplitude: CGFloat,
        steps: Int
    ) -> CGPath {
        let path = CGMutablePath()
        let freq = CGFloat(frequency)
        let totalSteps = max(24, steps)
        let dTheta = (2.0 * CGFloat.pi) / CGFloat(totalSteps)

        for i in 0..<totalSteps {
            let theta = CGFloat(i) * dTheta
            let radius = baseR * (1.0 - amplitude + amplitude * cos(freq * theta))
            let x = cx + radius * cos(theta)
            let y = cy + radius * sin(theta)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }

    private static func cloverPath(
        cx: CGFloat,
        cy: CGFloat,
        baseR: CGFloat,
        leaves: Int,
        steps: Int
    ) -> CGPath {
        let path = CGMutablePath()
        let halfLeaves = CGFloat(leaves) / 2.0
        let totalSteps = max(24, steps)
        let dTheta = (2.0 * CGFloat.pi) / CGFloat(totalSteps)

        for i in 0..<totalSteps {
            let theta = CGFloat(i) * dTheta
            let modulation = abs(cos(halfLeaves * theta))
            let radius = baseR * (0.72 + 0.28 * modulation)
            let x = cx + radius * cos(theta)
            let y = cy + radius * sin(theta)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }

    private static func sunnyPath(
        cx: CGFloat,
        cy: CGFloat,
        outerR: CGFloat,
        innerR: CGFloat,
        rays: Int
    ) -> CGPath {
        let path = CGMutablePath()
        let totalPoints = rays * 2
        let dTheta = (2.0 * CGFloat.pi) / CGFloat(totalPoints)

        for i in 0..<totalPoints {
            let theta = CGFloat(i) * dTheta - CGFloat.pi / 2.0
            let radius = (i % 2 == 0) ? outerR : innerR
            let x = cx + radius * cos(theta)
            let y = cy + radius * sin(theta)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }

    private static func regularPolygonPath(
        cx: CGFloat,
        cy: CGFloat,
        radius: CGFloat,
        sides: Int,
        startAngle: CGFloat
    ) -> CGPath {
        let path = CGMutablePath()
        let dTheta = (2.0 * CGFloat.pi) / CGFloat(sides)

        for i in 0..<sides {
            let theta = startAngle + CGFloat(i) * dTheta
            let x = cx + radius * cos(theta)
            let y = cy + radius * sin(theta)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }

    private static func archPath(rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let r = rect.width / 2.0
        let bottom = rect.maxY
        let left = rect.minX
        let right = rect.maxX
        let domeCenterY = rect.minY + r

        // Bottom horizontal line
        path.move(to: CGPoint(x: left, y: bottom))
        path.addLine(to: CGPoint(x: right, y: bottom))
        // Right side wall
        path.addLine(to: CGPoint(x: right, y: domeCenterY))
        // Top semicircular arch
        path.addArc(
            center: CGPoint(x: rect.midX, y: domeCenterY),
            radius: r,
            startAngle: 0,
            endAngle: CGFloat.pi,
            clockwise: true
        )
        // Left side wall
        path.addLine(to: CGPoint(x: left, y: bottom))
        path.closeSubpath()
        return path
    }

    private static func slantedPath(rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let shear = rect.width * 0.18
        let cr = min(rect.width, rect.height) * 0.18

        // Parallelogram: top shifted right, bottom shifted left
        let p1 = CGPoint(x: rect.minX + shear, y: rect.minY)
        let p2 = CGPoint(x: rect.maxX, y: rect.minY)
        let p3 = CGPoint(x: rect.maxX - shear, y: rect.maxY)
        let p4 = CGPoint(x: rect.minX, y: rect.maxY)

        // Rounded polygon
        path.move(to: CGPoint(x: p1.x + cr, y: p1.y))
        path.addArc(tangent1End: p2, tangent2End: p3, radius: cr)
        path.addArc(tangent1End: p3, tangent2End: p4, radius: cr)
        path.addArc(tangent1End: p4, tangent2End: p1, radius: cr)
        path.addArc(tangent1End: p1, tangent2End: p2, radius: cr)
        path.closeSubpath()
        return path
    }

    private static func gemPath(rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let w = rect.width
        let h = rect.height

        // Octagonal faceted gem
        let insetX = w * 0.25
        let insetY = h * 0.25

        let pt0 = CGPoint(x: rect.minX + insetX, y: rect.minY)
        let pt1 = CGPoint(x: rect.maxX - insetX, y: rect.minY)
        let pt2 = CGPoint(x: rect.maxX, y: rect.minY + insetY)
        let pt3 = CGPoint(x: rect.maxX, y: rect.maxY - insetY)
        let pt4 = CGPoint(x: rect.maxX - insetX, y: rect.maxY)
        let pt5 = CGPoint(x: rect.minX + insetX, y: rect.maxY)
        let pt6 = CGPoint(x: rect.minX, y: rect.maxY - insetY)
        let pt7 = CGPoint(x: rect.minX, y: rect.minY + insetY)

        path.move(to: pt0)
        path.addLine(to: pt1)
        path.addLine(to: pt2)
        path.addLine(to: pt3)
        path.addLine(to: pt4)
        path.addLine(to: pt5)
        path.addLine(to: pt6)
        path.addLine(to: pt7)
        path.closeSubpath()
        return path
    }
}
