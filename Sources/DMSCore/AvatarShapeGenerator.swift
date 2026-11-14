import Foundation
import CoreGraphics

// Avatar shape geometry now lives in the published `MaterialMacLibrary` package.
// `MaterialShapes.AvatarShapeGenerator` implements all 12 canonical userShapes
// (`circle`, `cookie4`, `cookie7`, `cookie12`, `clover4`, `clover8`, `sunny`,
// `pentagon`, `arch`, `slanted`, `gem`, `square`) and `MaterialShapes.GeometricAvatarShape`
// wraps it as a SwiftUI `Shape`. Re-exporting `MaterialShapes` here keeps DMSCore's
// public API (`AvatarShapeGenerator`, `GeometricAvatarShape`) intact for DMS and tests.
@_exported import MaterialShapes
