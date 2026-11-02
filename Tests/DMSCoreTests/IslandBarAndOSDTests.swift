import Testing
import Foundation
@testable import DMSCore

@Suite("DMS 1.6 Island Bar Mode, Surface Morphing, and OSD Tests")
struct IslandBarAndOSDTests {

    // MARK: - 1. IslandActivity and IslandPresentationState with .dash

    @Test("IslandActivity and IslandPresentationState Dash Parsing and Roundtrip")
    func testIslandActivityAndPresentationStateDash() throws {
        // Parsing aliases
        #expect(IslandActivity.parse("dash") == .dash)
        #expect(IslandActivity.parse("DankDash") == .dash)
        #expect(IslandActivity.parse("dashboard") == .dash)
        #expect(IslandActivity.parse("overview") == .dash)

        // Codable roundtrip
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let act = IslandActivity.dash
        let encodedAct = try encoder.encode(act)
        let decodedAct = try decoder.decode(IslandActivity.self, from: encodedAct)
        #expect(decodedAct == .dash)

        let state = IslandPresentationState.expandedDash
        #expect(state.isExpanded)
        #expect(state.activity == .dash)

        let encodedState = try encoder.encode(state)
        let decodedState = try decoder.decode(IslandPresentationState.self, from: encodedState)
        #expect(decodedState == .expandedDash)
        #expect(decodedState.isExpanded)
        #expect(decodedState.activity == .dash)
    }

    @Test("IslandStateMachine Expand and Resolve State for Dash")
    func testStateMachineDashResolution() {
        var sm = IslandStateMachine()
        #expect(sm.resolveState() == .idle)

        sm.expand(to: .dash)
        #expect(sm.isExpanded)
        #expect(sm.resolveState() == .expandedDash)

        sm.collapse()
        #expect(!sm.isExpanded)
        #expect(sm.resolveState() == .idle)
    }

    // MARK: - 2. IslandStateMachine Target Geometry Calculations

    @Test("IslandStateMachine Geometry for expandedDash is 580x414")
    func testExpandedDashGeometry() {
        let settings = IslandSettings(
            instance: .mainBar,
            float: false,
            useOverlayLayer: false,
            reservedHeight: 38,
            compactIslandHeight: 34,
            compactWidth: 176,
            expandedWidth: 380,
            expandedHeight: 180,
            outerGaps: 8,
            horizontalOffset: 0,
            springStiffness: 560,
            springDamping: 37,
            animationCurve: .expressive,
            hoverExpand: false,
            hoverDelayMs: 250,
            hoverCloseDelayMs: 300,
            mediaLauncher: .hidden,
            batteryControlCenter: .hidden,
            weather: .hidden,
            compactClockPill: false,
            palette: "default",
            opacity: 1.0,
            borderEnabled: true,
            shadowEnabled: true,
            gothCorners: false,
            gothFilletRadius: 12,
            edge: "top",
            anchorX: 0.5,
            anchorY: 0.0,
            enabledActivities: IslandActivity.allCases.map { $0.rawValue }
        )

        let geom = IslandStateMachine.targetGeometry(
            for: .expandedDash,
            settings: settings,
            notch: .standardMonitor()
        )

        #expect(geom.width == 580.0)
        #expect(geom.height == 414.0)
        #expect(geom.bottomLeftRadius == 34.0)
        #expect(geom.bottomRightRadius == 34.0)
    }

    @Test("IslandStateMachine Geometry for expandedControlCenter Respects CcMetrics")
    func testExpandedControlCenterGeometryDynamicColumns() {
        let settings = IslandSettings(
            instance: .mainBar,
            float: false,
            useOverlayLayer: false,
            reservedHeight: 38,
            compactIslandHeight: 34,
            compactWidth: 176,
            expandedWidth: 380,
            expandedHeight: 180,
            outerGaps: 8,
            horizontalOffset: 0,
            springStiffness: 560,
            springDamping: 37,
            animationCurve: .expressive,
            hoverExpand: false,
            hoverDelayMs: 250,
            hoverCloseDelayMs: 300,
            mediaLauncher: .hidden,
            batteryControlCenter: .hidden,
            weather: .hidden,
            compactClockPill: false,
            palette: "default",
            opacity: 1.0,
            borderEnabled: true,
            shadowEnabled: true,
            gothCorners: false,
            gothFilletRadius: 12,
            edge: "top",
            anchorX: 0.5,
            anchorY: 0.0,
            enabledActivities: IslandActivity.allCases.map { $0.rawValue }
        )

        // Default columns = 8 -> 394 or 418 pt width, height = defaultSheetHeight (348.0)
        let geomDefault = IslandStateMachine.targetGeometry(
            for: .expandedControlCenter,
            settings: settings,
            notch: .standardMonitor(),
            controlCenterColumns: 8
        )
        #expect(geomDefault.width == Double(CcMetrics.defaultSheetWidth))
        #expect(geomDefault.height == Double(CcMetrics.defaultSheetHeight))

        // 6 columns -> 318 pt width
        let geom6 = IslandStateMachine.targetGeometry(
            for: .expandedControlCenter,
            settings: settings,
            notch: .standardMonitor(),
            controlCenterColumns: 6
        )
        #expect(geom6.width == Double(CcMetrics.sheetWidthFor(columns: 6)))
        #expect(geom6.height == Double(CcMetrics.defaultSheetHeight))

        // 12 columns -> 618 pt width
        let geom12 = IslandStateMachine.targetGeometry(
            for: .expandedControlCenter,
            settings: settings,
            notch: .standardMonitor(),
            controlCenterColumns: 12
        )
        #expect(geom12.width == Double(CcMetrics.sheetWidthFor(columns: 12)))
        #expect(geom12.height == Double(CcMetrics.defaultSheetHeight))
    }

    // MARK: - 3. OSDType Mapping, Icon Selection, and Percentage Formatting

    @Test("OSDType Cases, Gauge Metric Properties, and Titles")
    func testOSDTypeProperties() {
        #expect(OSDType.allCases.count == 8)
        #expect(OSDType.volume.title == "Volume")
        #expect(OSDType.micVolume.title == "Microphone")
        #expect(OSDType.brightness.title == "Brightness")
        #expect(OSDType.capsLock.title == "Caps Lock")
        #expect(OSDType.audioOutput.title == "Audio Output")
        #expect(OSDType.idleInhibit.title == "Keep Awake")
        #expect(OSDType.keyboardBacklight.title == "Keyboard Backlight")
        #expect(OSDType.mediaEject.title == "Eject")

        #expect(OSDType.volume.isGaugeMetric)
        #expect(OSDType.micVolume.isGaugeMetric)
        #expect(OSDType.brightness.isGaugeMetric)
        #expect(OSDType.keyboardBacklight.isGaugeMetric)
        #expect(!OSDType.capsLock.isGaugeMetric)
        #expect(!OSDType.audioOutput.isGaugeMetric)
        #expect(!OSDType.idleInhibit.isGaugeMetric)
        #expect(!OSDType.mediaEject.isGaugeMetric)
    }

    @Test("OSDType Icon Selection Logic")
    func testOSDIconSelection() {
        // Volume icons
        #expect(OSDType.volume.iconName(isMuted: true, value: 0.8) == "speaker.slash.fill")
        #expect(OSDType.volume.iconName(isMuted: false, value: 0.0) == "speaker.fill")
        #expect(OSDType.volume.iconName(isMuted: false, value: 0.25) == "speaker.wave.1.fill")
        #expect(OSDType.volume.iconName(isMuted: false, value: 0.5) == "speaker.wave.2.fill")
        #expect(OSDType.volume.iconName(isMuted: false, value: 0.85) == "speaker.wave.3.fill")

        // Mic volume icons
        #expect(OSDType.micVolume.iconName(isMuted: true) == "mic.slash.fill")
        #expect(OSDType.micVolume.iconName(isMuted: false) == "mic.fill")

        // Brightness icons
        #expect(OSDType.brightness.iconName(value: 0.2) == "sun.min.fill")
        #expect(OSDType.brightness.iconName(value: 0.75) == "sun.max.fill")

        // Caps Lock icon
        #expect(OSDType.capsLock.iconName() == "capslock.fill")

        // Audio output device icon
        #expect(OSDType.audioOutput.iconName(text: "AirPods Pro") == "airpodspro")
        #expect(OSDType.audioOutput.iconName(text: "Sony WH-1000XM4") == "headphones")
        #expect(OSDType.audioOutput.iconName(text: "Built-in Speakers") == "speaker.wave.2.fill")

        // Keep Awake icon
        #expect(OSDType.idleInhibit.iconName(isMuted: false, text: "Awake") == "cup.and.saucer.fill")
        #expect(OSDType.idleInhibit.iconName(isMuted: true, text: "Normal") == "cup.and.saucer")
    }

    @Test("OSDType Percentage and Value Formatting")
    func testOSDValueFormatting() {
        #expect(OSDType.volume.formattedValue(isMuted: true, value: 0.75) == "Muted")
        #expect(OSDType.volume.formattedValue(isMuted: false, value: 0.75) == "75%")
        #expect(OSDType.volume.formattedValue(isMuted: false, value: 0.0) == "0%")
        #expect(OSDType.volume.formattedValue(isMuted: false, value: 1.0) == "100%")

        #expect(OSDType.micVolume.formattedValue(isMuted: true, value: 0.5) == "Muted")
        #expect(OSDType.micVolume.formattedValue(isMuted: false, value: 0.5) == "50%")

        #expect(OSDType.brightness.formattedValue(value: 0.62) == "62%")

        #expect(OSDType.capsLock.formattedValue(isMuted: false) == "ON")
        #expect(OSDType.capsLock.formattedValue(isMuted: true) == "OFF")

        #expect(OSDType.audioOutput.formattedValue(text: "Studio Display") == "Studio Display")
        #expect(OSDType.idleInhibit.formattedValue(isMuted: false) == "Awake")
        #expect(OSDType.idleInhibit.formattedValue(isMuted: true) == "Normal")
    }

    // MARK: - 4. Bar Layout Geometry Solver under "island" Background Style

    @Test("Bar Layout Solver Solves Satellite Pill Boundaries for Island Mode")
    func testIslandPillBarSolver() {
        let notch = ScreenNotchGeometry.notchedMacBook(
            width: 1512,
            height: 982,
            notchWidth: 200,
            notchHeight: 34
        )

        let solution = NotchAwareBarLayoutSolver.solveIslandPillBar(
            screenWidth: 1512,
            barLength: 1496,
            barMargin: 8,
            notch: notch,
            islandExclusionWidth: 240
        )

        #expect(solution.isSplitActive)
        #expect(solution.leftPillBounds.lowerBound == 0.0)
        #expect(solution.leftPillBounds.upperBound >= 60.0)
        #expect(solution.rightPillBounds.upperBound == 1496.0)
        #expect(solution.rightPillBounds.lowerBound > solution.leftPillBounds.upperBound)

        // Center gap must separate left and right pills cleanly
        #expect(solution.centerGapBounds.lowerBound == solution.leftPillBounds.upperBound)
        #expect(solution.centerGapBounds.upperBound >= solution.rightPillBounds.lowerBound)
        #expect((solution.centerGapBounds.upperBound - solution.centerGapBounds.lowerBound) >= 100.0)
    }

    @Test("InterceptMediaKeys Configuration Setting Default and Toggle")
    func testInterceptMediaKeysSetting() {
        var cfg = DMSConfig()
        #expect(cfg.interceptMediaKeys == true)

        cfg.interceptMediaKeys = false
        #expect(cfg.interceptMediaKeys == false)
        #expect(cfg.rawSettings["interceptMediaKeys"]?.boolValue == false)

        cfg.interceptMediaKeys = true
        #expect(cfg.interceptMediaKeys == true)
        #expect(cfg.rawSettings["interceptMediaKeys"]?.boolValue == true)
    }

    // MARK: - 5. SystemKey Parsing and Stepping Tests (ApolloShell & Atoll Integration)

    @Test("SystemKey Parsing from NX_SYSDEFINED data1")
    func testSystemKeyParsing() {
        let soundUpData1 = Int((SystemKey.NX_KEYTYPE_SOUND_UP << 16) | (0x0A << 8))
        let soundDownData1 = Int((SystemKey.NX_KEYTYPE_SOUND_DOWN << 16) | (0x0A << 8))
        let muteData1 = Int((SystemKey.NX_KEYTYPE_MUTE << 16) | (0x0A << 8))
        let brightUpData1 = Int((SystemKey.NX_KEYTYPE_BRIGHTNESS_UP << 16) | (0x0A << 8))
        let brightDownData1 = Int((SystemKey.NX_KEYTYPE_BRIGHTNESS_DOWN << 16) | (0x0A << 8))
        let playData1 = Int((SystemKey.NX_KEYTYPE_PLAY << 16) | (0x0A << 8))
        let nextData1 = Int((SystemKey.NX_KEYTYPE_NEXT << 16) | (0x0A << 8))
        let prevData1 = Int((SystemKey.NX_KEYTYPE_PREVIOUS << 16) | (0x0A << 8))

        #expect(SystemKey(data1: soundUpData1) == .volumeUp)
        #expect(SystemKey(data1: soundDownData1) == .volumeDown)
        #expect(SystemKey(data1: muteData1) == .mute)
        #expect(SystemKey(data1: brightUpData1) == .brightnessUp)
        #expect(SystemKey(data1: brightDownData1) == .brightnessDown)
        #expect(SystemKey(data1: playData1) == .playPause)
        #expect(SystemKey(data1: nextData1) == .next)
        #expect(SystemKey(data1: prevData1) == .previous)

        // Key state down vs up
        #expect(SystemKey.isDown(data1: soundUpData1) == true)
        let keyUpData1 = Int((SystemKey.NX_KEYTYPE_SOUND_UP << 16) | (0x0B << 8))
        #expect(SystemKey.isDown(data1: keyUpData1) == false)

        // Unknown key types return nil
        #expect(SystemKey(data1: 99 << 16) == nil)
    }

    @Test("SystemKey Stepped Math Snapping and Bounds Clamping")
    func testSystemKeyStepping() {
        let standardStep = SystemKey.step(fine: false)
        #expect(abs(standardStep - (1.0 / 16.0)) < 0.0001)

        let fineStep = SystemKey.step(fine: true)
        #expect(abs(fineStep - (1.0 / 64.0)) < 0.0001)

        // Step up snaps to nearest 1/16th tick
        let steppedUp = SystemKey.stepped(0.5, by: standardStep)
        #expect(abs(steppedUp - 0.5625) < 0.0001)

        // Step down snaps to nearest 1/16th tick
        let steppedDown = SystemKey.stepped(0.5, by: -standardStep)
        #expect(abs(steppedDown - 0.4375) < 0.0001)

        // Boundary clamping at 0.0 and 1.0
        #expect(SystemKey.stepped(0.98, by: standardStep) == 1.0)
        #expect(SystemKey.stepped(1.0, by: standardStep) == 1.0)
        #expect(SystemKey.stepped(0.02, by: -standardStep) == 0.0)
        #expect(SystemKey.stepped(0.0, by: -standardStep) == 0.0)

        // Fine step up from 0.5
        let fineUp = SystemKey.stepped(0.5, by: fineStep)
        #expect(abs(fineUp - 0.515625) < 0.0001)
    }

    // MARK: - 6. macOS 27 Volume Interception & Privacy URL Regression Tests

    @Test("SystemKey Repeat Flag Detection and Transport Controls")
    func testSystemKeyRepeatAndTransport() {
        let repeatSoundUpData1 = Int((SystemKey.NX_KEYTYPE_SOUND_UP << 16) | (0x0A << 8) | 0x01)
        let nonRepeatSoundUpData1 = Int((SystemKey.NX_KEYTYPE_SOUND_UP << 16) | (0x0A << 8) | 0x00)

        #expect(SystemKey.isRepeat(data1: repeatSoundUpData1) == true)
        #expect(SystemKey.isRepeat(data1: nonRepeatSoundUpData1) == false)

        let fastData1 = Int((SystemKey.NX_KEYTYPE_FAST << 16) | (0x0A << 8))
        let rewindData1 = Int((SystemKey.NX_KEYTYPE_REWIND << 16) | (0x0A << 8))
        #expect(SystemKey(data1: fastData1) == .fast)
        #expect(SystemKey(data1: rewindData1) == .rewind)
    }

    @Test("OSDType Volume Formatting and Icon Resolution")
    func testOSDTypeVolumeIcons() {
        let vol = OSDType.volume
        #expect(vol.title == "Volume")
        #expect(vol.isGaugeMetric == true)

        // Muted returns slash icon
        #expect(vol.iconName(isMuted: true, value: 0.8) == "speaker.slash.fill")
        #expect(vol.formattedValue(isMuted: true, value: 0.8) == "Muted")

        // Unmuted levels
        #expect(vol.iconName(isMuted: false, value: 0.0) == "speaker.fill")
        #expect(vol.iconName(isMuted: false, value: 0.2) == "speaker.wave.1.fill")
        #expect(vol.iconName(isMuted: false, value: 0.5) == "speaker.wave.2.fill")
        #expect(vol.iconName(isMuted: false, value: 0.9) == "speaker.wave.3.fill")
        #expect(vol.formattedValue(isMuted: false, value: 0.75) == "75%")
    }

    @Test("macOS 27 Device Control and Input Monitoring URL Scheme Validity")
    func testMacOS27SettingsURLSchemes() {
        let modernAccessibility = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")
        let legacyAccessibility = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        let modernListenEvent = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent")
        let legacyListenEvent = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")

        #expect(modernAccessibility != nil)
        #expect(legacyAccessibility != nil)
        #expect(modernListenEvent != nil)
        #expect(legacyListenEvent != nil)

        #expect(modernAccessibility?.scheme == "x-apple.systempreferences")
        #expect(modernListenEvent?.scheme == "x-apple.systempreferences")
    }

    @Test("Surface Tokens and Config Support 100% Transparency (0.0 Opacity)")
    func testZeroOpacityTransparencySupport() {
        let tokens = M3SurfaceTokens(
            surfaceOpacity: 0.0,
            popupTransparency: 0.0,
            floatingWindowTransparency: 0.0
        )
        #expect(tokens.surfaceOpacity == 0.0)
        #expect(tokens.popupTransparency == 0.0)
        #expect(tokens.floatingWindowTransparency == 0.0)

        var cfg = DMSConfig()
        cfg.surfaceOpacity = 0.0
        cfg.popupTransparency = 0.0
        cfg.floatingWindowTransparency = 0.0
        #expect(cfg.surfaceOpacity == 0.0)
        #expect(cfg.popupTransparency == 0.0)
        #expect(cfg.floatingWindowTransparency == 0.0)

        var bar = BarConfig.default
        bar.transparency = 0.0
        #expect(bar.transparency == 0.0)
    }
}
