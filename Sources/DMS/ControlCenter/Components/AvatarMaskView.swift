import SwiftUI
import DMSCore

/// SwiftUI Shape wrapping `AvatarShapeGenerator` for the 12 geometric avatar masks.
public struct GeometricAvatarShape: Shape {
    public let shapeName: String

    public init(shapeName: String) {
        self.shapeName = shapeName
    }

    public func path(in rect: CGRect) -> Path {
        let cgPath = AvatarShapeGenerator.path(for: shapeName, in: rect)
        return Path(cgPath)
    }
}
