import Foundation
import CoreGraphics

// Avatar shape geometry now lives in the published `MaterialMacLibrary` package.
// `MaterialShapes.AvatarShapeGenerator` implements all 35 Material 3 Expressive shapes
// (including the 12 classic userShapes) and `MaterialShapes.GeometricAvatarShape` /
// `MaterialShapes.MaterialMorphingShape` wrap them as SwiftUI `Shape`s.
// Re-exporting `MaterialShapes` here keeps DMSCore's public API intact for DMS and tests.
@_exported import MaterialShapes

public typealias M3ExpressiveShape = MaterialExpressiveShape
public typealias M3MorphingShape = MaterialMorphingShape
