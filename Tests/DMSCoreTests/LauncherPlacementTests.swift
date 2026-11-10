import Testing
import Foundation
@testable import DMSCore

@Suite("Launcher Placement Solver Tests (v0.6 LAUNCH island attachment)")
struct LauncherPlacementTests {

    // Built-in MacBook Pro 14" (1512x982) with a 200x34 notch, menu bar ~24pt
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let visible = CGRect(x: 0, y: 0, width: 1512, height: 982 - 24)
    private let notch = ScreenNotchGeometry.notchedMacBook(width: 1512, height: 982, notchWidth: 200, notchHeight: 34)

    @Test("Center Mode Matches Legacy Formula")
    func testCenterMode() {
        let frame = LauncherPlacementSolver.solve(
            screenFrame: screen,
            visibleFrame: visible,
            notch: notch,
            mode: .center,
            panelWidth: 680,
            panelHeight: 540
        )
        #expect(frame.width == 680)
        #expect(frame.height == 540)
        #expect(frame.minX == screen.midX - 340)
        #expect(frame.minY == screen.midY - 270 + LauncherPlacementSolver.centerLift)
    }

    @Test("Island Mode Anchors Below the Notch, Centered on Notch MidX")
    func testIslandModeWithNotch() {
        let frame = LauncherPlacementSolver.solve(
            screenFrame: screen,
            visibleFrame: visible,
            notch: notch,
            mode: .island,
            panelWidth: 680,
            panelHeight: 540
        )
        let notchMidX = CGFloat(notch.notchMidX) // 756
        #expect(frame.minX == notchMidX - 340)
        #expect(frame.maxY == screen.maxY - CGFloat(notch.notchHeight) - LauncherPlacementSolver.islandGap)
        #expect(frame.width == 680)
        #expect(frame.height == 540)
    }

    @Test("Island Mode on Notchless Display Falls Back to Top-Center Below Menu Bar")
    func testIslandModeWithoutNotch() {
        let external = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let externalVisible = CGRect(x: 0, y: 0, width: 1920, height: 1080 - 24)
        let noNotch = ScreenNotchGeometry.standardMonitor(width: 1920, height: 1080)

        let frame = LauncherPlacementSolver.solve(
            screenFrame: external,
            visibleFrame: externalVisible,
            notch: noNotch,
            mode: .island,
            panelWidth: 680,
            panelHeight: 540
        )
        #expect(frame.minX == externalVisible.midX - 340)
        #expect(frame.maxY == externalVisible.maxY - LauncherPlacementSolver.islandGap)
        #expect(frame.minY >= externalVisible.minY)
    }

    @Test("Panel Is Clamped Into the Visible Frame on Small Screens")
    func testClamping() {
        let smallScreen = CGRect(x: 0, y: 0, width: 800, height: 600)
        let smallVisible = CGRect(x: 0, y: 0, width: 800, height: 576)
        let frame = LauncherPlacementSolver.solve(
            screenFrame: smallScreen,
            visibleFrame: smallVisible,
            notch: .standardMonitor(width: 800, height: 600),
            mode: .island,
            panelWidth: 680,
            panelHeight: 540
        )
        #expect(frame.minX >= smallVisible.minX)
        #expect(frame.minY >= smallVisible.minY)
        #expect(frame.maxX <= smallVisible.maxX + 0.001)
        #expect(frame.maxY <= smallVisible.maxY + 0.001)

        // Oversized panel shrinks to the visible frame
        let huge = LauncherPlacementSolver.solve(
            screenFrame: smallScreen,
            visibleFrame: smallVisible,
            notch: .standardMonitor(width: 800, height: 600),
            mode: .center,
            panelWidth: 5000,
            panelHeight: 5000
        )
        #expect(huge.width == smallVisible.width)
        #expect(huge.height == smallVisible.height)
    }

    @Test("Attachment Mode Parsing")
    func testModeParsing() {
        #expect(LauncherAttachmentMode.parse("island") == .island)
        #expect(LauncherAttachmentMode.parse("CENTER") == .center)
        #expect(LauncherAttachmentMode.parse(nil) == .center)
        #expect(LauncherAttachmentMode.parse("bogus") == .center)
    }
}
