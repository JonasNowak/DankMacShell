import SwiftUI

/// Slanted Parallelogram Shape with tangential rounded corners inspired by skwd's slice launcher and wallpaper picker.
/// For positive skew:
///  Top edge is shifted to the right, bottom edge starts at 0.
///  Top-left: (skew, 0), Top-right: (width, 0)
///  Bottom-right: (width - skew, height), Bottom-left: (0, height)
public struct SlantedParallelogramShape: Shape {
    public var skew: CGFloat
    public var cornerRadius: CGFloat

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(skew, cornerRadius) }
        set {
            skew = newValue.first
            cornerRadius = newValue.second
        }
    }

    public init(skew: CGFloat = 32, cornerRadius: CGFloat = 16) {
        self.skew = skew
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        guard w > 0, h > 0 else { return path }

        // Clamp skew to half width to prevent degenerating
        let maxSkew = w * 0.45
        let sk = max(-maxSkew, min(maxSkew, skew))
        let skAbs = abs(sk)
        let maxR = max(0, min(cornerRadius, (w - skAbs) / 2 - 1, h / 2 - 1))

        let topLeft = CGPoint(x: sk >= 0 ? skAbs : 0, y: 0)
        let topRight = CGPoint(x: sk >= 0 ? w : w - skAbs, y: 0)
        let bottomRight = CGPoint(x: sk >= 0 ? w - skAbs : w, y: h)
        let bottomLeft = CGPoint(x: sk >= 0 ? 0 : skAbs, y: h)

        let startPoint = CGPoint(x: (topLeft.x + topRight.x) / 2, y: 0)
        path.move(to: startPoint)
        path.addArc(tangent1End: topRight, tangent2End: bottomRight, radius: maxR)
        path.addArc(tangent1End: bottomRight, tangent2End: bottomLeft, radius: maxR)
        path.addArc(tangent1End: bottomLeft, tangent2End: topLeft, radius: maxR)
        path.addArc(tangent1End: topLeft, tangent2End: topRight, radius: maxR)
        path.closeSubpath()

        return path
    }
}
