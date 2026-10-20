import SwiftUI

/// An organic wavy contour shape that frames the circular album art.
public struct WavyVisualizerRing: Shape {
    public var harmonics: Int = 8
    public var amplitude: CGFloat = 4.0
    public var phase: CGFloat = 0.0

    public var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2.0 - amplitude - 2.0
        guard baseRadius > 0 else { return path }

        let steps = 120
        for i in 0...steps {
            let theta = (CGFloat(i) / CGFloat(steps)) * 2.0 * .pi
            let r = baseRadius + amplitude * sin(CGFloat(harmonics) * theta + phase) + (amplitude * 0.5) * cos(CGFloat(harmonics * 2) * theta)
            let x = center.x + r * cos(theta)
            let y = center.y + r * sin(theta)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}
