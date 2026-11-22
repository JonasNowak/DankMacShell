import Foundation
import Testing
@testable import DMSCore

@Suite("Per-App Audio Mixer (CoreAudio Process Tap) & Model Tests")
struct AppAudioModelTests {

    @Test("Volume clamps cleanly to 0.0...2.0 (0%–200% Vorssaint boost range)")
    func testVolumeClamping() {
        #expect(AppAudioMixerHelpers.clampVolume(-0.5) == 0.0)
        #expect(AppAudioMixerHelpers.clampVolume(0.0) == 0.0)
        #expect(AppAudioMixerHelpers.clampVolume(1.0) == 1.0)
        #expect(AppAudioMixerHelpers.clampVolume(1.65) == 1.65)
        #expect(AppAudioMixerHelpers.clampVolume(2.0) == 2.0)
        #expect(AppAudioMixerHelpers.clampVolume(3.5) == 2.0)
        #expect(AppAudioMixerHelpers.clampVolume(.nan) == 1.0)
        #expect(AppAudioMixerHelpers.clampVolume(.infinity) == 1.0)
    }

    @Test("Effective gain returns 0 when muted and linear gain otherwise")
    func testEffectiveGain() {
        #expect(AppAudioMixerHelpers.effectiveGain(volume: 1.5, isMuted: true) == 0.0)
        #expect(AppAudioMixerHelpers.effectiveGain(volume: 0.75, isMuted: false) == 0.75)
        #expect(AppAudioMixerHelpers.effectiveGain(volume: 2.0, isMuted: false) == 2.0)
    }

    @Test("Soft-clipping passes unity/attenuated samples cleanly and limits boosted peaks")
    func testSoftClipBoost() {
        // Unity & attenuated samples are bit-transparent
        #expect(AppAudioMixerHelpers.processSample(0.5, gain: 1.0) == 0.5)
        #expect(AppAudioMixerHelpers.processSample(0.8, gain: 0.5) == 0.4)
        // Boosted sample exceeding 0.95 is smoothly soft-clipped below 1.0
        let boosted = AppAudioMixerHelpers.processSample(0.8, gain: 2.0)
        #expect(boosted > 0.9 && boosted < 1.0)
        let negBoosted = AppAudioMixerHelpers.processSample(-0.8, gain: 2.0)
        #expect(negBoosted < -0.9 && negBoosted > -1.0)
    }

    @Test("AudioAppStream.needsProcessTap stays false at unity unmuted default for zero overhead")
    func testNeedsProcessTapZeroOverheadAtUnity() {
        let unity = AudioAppStream(
            pid: 100,
            processObjectIDs: [42],
            bundleID: "com.google.Chrome",
            appName: "Google Chrome",
            isRunningOutput: true,
            isRunningInput: false,
            volume: 1.0,
            isMuted: false,
            outputDeviceUID: nil
        )
        #expect(unity.needsProcessTap == false)
        #expect(unity.isBoosted == false)
        #expect(unity.displayPercent == 100)

        var attenuated = unity
        attenuated.volume = 0.65
        #expect(attenuated.needsProcessTap == true)
        #expect(attenuated.isBoosted == false)
        #expect(attenuated.displayPercent == 65)

        var boosted = unity
        boosted.volume = 1.5
        #expect(boosted.needsProcessTap == true)
        #expect(boosted.isBoosted == true)
        #expect(boosted.displayPercent == 150)

        var muted = unity
        muted.isMuted = true
        #expect(muted.needsProcessTap == true)
        #expect(muted.displayPercent == 0)

        var routed = unity
        routed.outputDeviceUID = "BuiltInSpeakerDevice"
        #expect(routed.needsProcessTap == true)
    }

    @Test("normalizedAppKey folds browser/Electron/WebKit helper bundle IDs into parent app")
    func testNormalizedAppKey() {
        #expect(AppAudioMixerHelpers.normalizedAppKey(bundleID: "com.google.Chrome.helper.renderer", pid: 500) == "com.google.Chrome")
        #expect(AppAudioMixerHelpers.normalizedAppKey(bundleID: "com.hnc.Discord.helper", pid: 501) == "com.hnc.Discord")
        #expect(AppAudioMixerHelpers.normalizedAppKey(bundleID: "com.apple.Safari.WebContent", pid: 502) == "com.apple.Safari")
        #expect(AppAudioMixerHelpers.normalizedAppKey(bundleID: "", pid: 503) == "pid:503")
    }

    @Test("sortStreams orders pinned first, then actively outputting, then modified, then alphabetical")
    func testSortStreamsVorssaintOrder() {
        let pinnedIdle = AudioAppStream(pid: 1, bundleID: "com.pinned", appName: "Zed Music", isRunningOutput: false, isRunningInput: false, isPinned: true)
        let activeA = AudioAppStream(pid: 2, bundleID: "com.active.a", appName: "Arc", isRunningOutput: true, isRunningInput: false)
        let activeB = AudioAppStream(pid: 3, bundleID: "com.active.b", appName: "Discord", isRunningOutput: true, isRunningInput: false)
        let modifiedIdle = AudioAppStream(pid: 4, bundleID: "com.mod", appName: "Spotify", isRunningOutput: false, isRunningInput: false, volume: 0.5)
        let plainIdle = AudioAppStream(pid: 5, bundleID: "com.plain", appName: "Apple Music", isRunningOutput: false, isRunningInput: false)

        let sorted = AppAudioMixerHelpers.sortStreams([plainIdle, activeB, modifiedIdle, activeA, pinnedIdle])
        #expect(sorted.map(\.appName) == ["Zed Music", "Arc", "Discord", "Spotify", "Apple Music"])
    }

    @Test("AudioAppStream Codable round-trip preserves boost, pin, routing, and process objects")
    func testStreamCodableRoundTrip() throws {
        let original = AudioAppStream(
            pid: 777,
            processObjectIDs: [101, 102],
            bundleID: "com.google.Chrome",
            appName: "Google Chrome",
            isRunningOutput: true,
            isRunningInput: true,
            volume: 1.75,
            isMuted: false,
            isPinned: true,
            outputDeviceUID: "AirPodsPro-UID",
            isTapActive: true,
            capability: .processTap
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AudioAppStream.self, from: data)
        #expect(decoded == original)
    }

    @Test("Legacy AppAudioScriptRegistry retains VLC 0..256 scaling and clamping")
    func testLegacyScriptRegistry() {
        #expect(AppAudioScriptRegistry.capability(forBundleID: "com.spotify.client") == .directVolume)
        #expect(AppAudioScriptRegistry.capability(forBundleID: "com.google.Chrome") == .monitorOnly)
        #expect(AppAudioScriptRegistry.setVolumeScript(forBundleID: "org.videolan.vlc", volume0to1: 0.5) == "tell application id \"org.videolan.vlc\" to set volume to 128")
        #expect(AppAudioScriptRegistry.parseScriptVolumeOutput("512\n", bundleID: "org.videolan.vlc") == 1.0)
        #expect(AppAudioScriptRegistry.parseScriptVolumeOutput("not-a-number", bundleID: "com.spotify.client") == nil)
    }
}
