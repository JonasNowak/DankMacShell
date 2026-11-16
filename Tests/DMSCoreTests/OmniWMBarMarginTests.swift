import Testing
import Foundation
@testable import DMSCore

@Suite("OmniWM Bar Location Margin Tests")
struct OmniWMBarMarginTests {

    private let baseTOML = """
    # OmniWM Settings
    schemaVersion = 5

    [gaps]
    fullscreenUsesOuterGaps = true
    size = 10.0

    [gaps.outer]
    bottom = 60.0
    left = 14.0
    right = 16.0
    top = 12.0

    [general]
    animationsEnabled = true

    [[hotkeys]]
    binding = "Option+1"
    id = "switchWorkspace.0"
    """

    @Test("All 12 bar position transitions update [gaps.outer] correctly")
    func testAllBarTransitions() {
        // Distinct resting values per axis to prove opposite-edge lookup is exact:
        // horizontal resting: left=14, right=16; vertical resting: top=12, bottom=18.
        let resting: [OmniWMBarEdge: String] = [
            .top: "12.0",
            .bottom: "18.0",
            .left: "14.0",
            .right: "16.0"
        ]

        for fromEdge in OmniWMBarEdge.allCases {
            for toEdge in OmniWMBarEdge.allCases where fromEdge != toEdge {
                var initialLines = ["[gaps.outer]"]
                for edge in OmniWMBarEdge.allCases {
                    let val = (edge == fromEdge) ? "60.0" : resting[edge]!
                    initialLines.append("\(edge.rawValue) = \(val)")
                }
                let input = initialLines.joined(separator: "\n") + "\n"

                let updated = OmniWMMarginUpdater.updateOuterGaps(
                    in: input,
                    from: fromEdge.rawValue,
                    to: toEdge.rawValue
                )

                for edge in OmniWMBarEdge.allCases {
                    let expectedValue: String
                    if edge == toEdge {
                        expectedValue = "60.0"
                    } else if edge == fromEdge {
                        expectedValue = resting[fromEdge.opposite]!
                    } else {
                        expectedValue = resting[edge]!
                    }
                    #expect(
                        updated.contains("\(edge.rawValue) = \(expectedValue)"),
                        "Transition \(fromEdge.rawValue) -> \(toEdge.rawValue): expected \(edge.rawValue) = \(expectedValue) in:\n\(updated)"
                    )
                }
            }
        }
    }

    @Test("Explicit user scenarios: top->bottom, left->right, left->top, top->left")
    func testExplicitUserScenarios() {
        // 1. top -> bottom: top gets bottom's value (12.0), bottom gets 60.0
        let topTOML = """
        [gaps.outer]
        bottom = 12.0
        left = 10.0
        right = 10.0
        top = 60.0
        """
        let topToBottom = OmniWMMarginUpdater.updateOuterGaps(in: topTOML, from: "top", to: "bottom")
        #expect(topToBottom == """
        [gaps.outer]
        bottom = 60.0
        left = 10.0
        right = 10.0
        top = 12.0
        """)

        // 2. left -> right: left gets right's value (16.0), right gets 60.0
        let leftTOML = """
        [gaps.outer]
        bottom = 10.0
        left = 60.0
        right = 16.0
        top = 10.0
        """
        let leftToRight = OmniWMMarginUpdater.updateOuterGaps(in: leftTOML, from: "left", to: "right")
        #expect(leftToRight == """
        [gaps.outer]
        bottom = 10.0
        left = 16.0
        right = 60.0
        top = 10.0
        """)

        // 3. left -> top: left gets right's value (16.0), top gets 60.0
        let leftToTop = OmniWMMarginUpdater.updateOuterGaps(in: leftTOML, from: "left", to: "top")
        #expect(leftToTop == """
        [gaps.outer]
        bottom = 10.0
        left = 16.0
        right = 16.0
        top = 60.0
        """)

        // 4. top -> left: top gets bottom's value (12.0), left gets 60.0
        let topToLeft = OmniWMMarginUpdater.updateOuterGaps(in: topTOML, from: "top", to: "left")
        #expect(topToLeft == """
        [gaps.outer]
        bottom = 12.0
        left = 60.0
        right = 10.0
        top = 12.0
        """)
    }

    @Test("Sequential round-trip transitions preserve axis margins")
    func testSequentialTransitions() {
        var doc = baseTOML
        doc = OmniWMMarginUpdater.updateOuterGaps(in: doc, from: "bottom", to: "top")
        #expect(doc.contains("bottom = 12.0"))
        #expect(doc.contains("top = 60.0"))

        doc = OmniWMMarginUpdater.updateOuterGaps(in: doc, from: "top", to: "left")
        #expect(doc.contains("top = 12.0"))
        #expect(doc.contains("left = 60.0"))

        doc = OmniWMMarginUpdater.updateOuterGaps(in: doc, from: "left", to: "right")
        #expect(doc.contains("left = 16.0"))
        #expect(doc.contains("right = 60.0"))

        doc = OmniWMMarginUpdater.updateOuterGaps(in: doc, from: "right", to: "bottom")
        #expect(doc.contains("right = 16.0"))
        #expect(doc.contains("bottom = 60.0"))

        // Unrelated sections and comments remain intact
        #expect(doc.contains("# OmniWM Settings"))
        #expect(doc.contains("schemaVersion = 5"))
        #expect(doc.contains("fullscreenUsesOuterGaps = true"))
        #expect(doc.contains("size = 10.0"))
        #expect(doc.contains("animationsEnabled = true"))
        #expect(doc.contains("binding = \"Option+1\""))
    }

    @Test("Same or invalid positions leave TOML byte-identical")
    func testNoOpOnSameOrInvalidPositions() {
        #expect(OmniWMMarginUpdater.updateOuterGaps(in: baseTOML, from: "bottom", to: "bottom") == baseTOML)
        #expect(OmniWMMarginUpdater.updateOuterGaps(in: baseTOML, from: "TOP", to: " top ") == baseTOML)
        #expect(OmniWMMarginUpdater.updateOuterGaps(in: baseTOML, from: "center", to: "top") == baseTOML)
        #expect(OmniWMMarginUpdater.updateOuterGaps(in: baseTOML, from: "bottom", to: "invalid") == baseTOML)
    }

    @Test("Missing keys in [gaps.outer] and missing section are handled cleanly")
    func testMissingKeysAndMissingSection() {
        let partial = """
        [gaps]
        size = 10.0

        [gaps.outer]
        bottom = 60.0
        left = 10.0

        [general]
        ipcEnabled = true
        """
        let updatedPartial = OmniWMMarginUpdater.updateOuterGaps(in: partial, from: "bottom", to: "top")
        #expect(updatedPartial == """
        [gaps]
        size = 10.0

        [gaps.outer]
        bottom = 0.0
        left = 10.0
        top = 60.0

        [general]
        ipcEnabled = true
        """)

        let noOuterSection = """
        schemaVersion = 5
        [gaps]
        size = 10.0
        """
        let updatedNoSection = OmniWMMarginUpdater.updateOuterGaps(in: noOuterSection, from: "bottom", to: "top")
        #expect(updatedNoSection == """
        schemaVersion = 5
        [gaps]
        size = 10.0

        [gaps.outer]
        bottom = 0.0
        top = 60.0
        """)
    }

    @Test("Inline comments and section header comments are parsed safely")
    func testCommentsAndThemeUpdaterCompatibility() {
        let commented = """
        [gaps.outer] # outer padding
        bottom = 60.0 # bar space
        left = 10.5 # side
        right = 10.5
        top = 8.0 # top margin

        [borders]
        enabled = true
        """
        let afterMove = OmniWMMarginUpdater.updateOuterGaps(in: commented, from: "bottom", to: "top")
        #expect(afterMove.contains("bottom = 8.0"))
        #expect(afterMove.contains("top = 60.0"))
        #expect(afterMove.contains("left = 10.5 # side"))

        let afterTheme = OmniWMThemeUpdater.applyTheme(to: afterMove, palette: StockThemes.purpleDark)
        #expect(afterTheme.contains("bottom = 8.0"))
        #expect(afterTheme.contains("top = 60.0"))
        #expect(afterTheme.contains("[borders.color]"))
    }
}
