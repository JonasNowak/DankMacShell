import Foundation

/// How DMS controls a running app's audio output.
public enum AudioAppControlCapability: String, Codable, Sendable, Equatable {
    /// Universal macOS 14.2+ CoreAudio Process Tap (`AudioHardwareCreateProcessTap`)
    /// supporting 0%–200% gain scaling, muting, and per-app output device routing
    /// without virtual audio drivers (inspired by Vorssaint & FineTune).
    case processTap
    /// Fallback native AppleScript volume control (macOS < 14.2 only).
    case directVolume
    /// Observation-only fallback when neither CoreAudio Process Taps nor AppleScript apply.
    case monitorOnly
}

/// One grouped application audio stream in the Vorssaint-style per-app mixer.
/// Helper processes (e.g. Chrome/Arc/Electron/WebKit renderers) are merged under
/// their owning application with all CoreAudio process object IDs preserved in
/// `processObjectIDs` so a single process tap captures every stream of that app.
public struct AudioAppStream: Identifiable, Codable, Sendable, Equatable {
    /// Stable application key (`bundleID` when available, otherwise `"pid:<pid>"`).
    public let id: String
    /// Primary owning application PID.
    public let pid: Int32
    /// All CoreAudio `AudioObjectID`s belonging to this app and its audio helper processes.
    public var processObjectIDs: [UInt32]
    public let bundleID: String
    public let appName: String
    /// True if any process belonging to this app is actively outputting audio.
    public var isRunningOutput: Bool
    /// True if any process belonging to this app is actively capturing microphone audio.
    public var isRunningInput: Bool
    /// Per-app volume gain multiplier in `0.0...2.0` (`1.0` = 100% unity, `2.0` = 200% boost).
    public var volume: Double
    public var isMuted: Bool
    /// User-pinned apps stay at the top of the mixer list.
    public var isPinned: Bool
    /// Optional CoreAudio device UID override (`nil` follows macOS System Default output).
    public var outputDeviceUID: String?
    /// True while an active CoreAudio Process Tap is currently intercepting this app's audio.
    public var isTapActive: Bool
    public let capability: AudioAppControlCapability

    /// True when this app requires a live CoreAudio Process Tap (muted, non-unity volume, or custom output route).
    public var needsProcessTap: Bool {
        isMuted || abs(volume - 1.0) > 0.005 || outputDeviceUID != nil
    }

    /// True when the user boosted volume above 100%.
    public var isBoosted: Bool {
        !isMuted && volume > 1.005
    }

    /// Display percentage integer (`0...200`, `0` when muted).
    public var displayPercent: Int {
        isMuted ? 0 : Int(round(AppAudioMixerHelpers.clampVolume(volume) * 100.0))
    }

    public init(
        id: String? = nil,
        pid: Int32,
        processObjectIDs: [UInt32] = [],
        bundleID: String,
        appName: String,
        isRunningOutput: Bool,
        isRunningInput: Bool,
        volume: Double = 1.0,
        isMuted: Bool = false,
        isPinned: Bool = false,
        outputDeviceUID: String? = nil,
        isTapActive: Bool = false,
        capability: AudioAppControlCapability = .processTap
    ) {
        self.id = id ?? (bundleID.isEmpty ? "pid:\(pid)" : bundleID)
        self.pid = pid
        self.processObjectIDs = processObjectIDs
        self.bundleID = bundleID
        self.appName = appName
        self.isRunningOutput = isRunningOutput
        self.isRunningInput = isRunningInput
        self.volume = AppAudioMixerHelpers.clampVolume(volume)
        self.isMuted = isMuted
        self.isPinned = isPinned
        self.outputDeviceUID = outputDeviceUID
        self.isTapActive = isTapActive
        self.capability = capability
    }
}

/// Pure-logic helpers for the CoreAudio Process Tap per-app mixer (0%–200% boost,
/// soft-clipping, sorting, and helper-bundle normalization).
public enum AppAudioMixerHelpers: Sendable {
    public static let minVolume: Double = 0.0
    public static let unityVolume: Double = 1.0
    public static let maxVolume: Double = 2.0

    /// Clamps a volume multiplier to `0.0...2.0` (`0%` to `200%`).
    public static func clampVolume(_ value: Double) -> Double {
        guard value.isFinite else { return unityVolume }
        return min(maxVolume, max(minVolume, value))
    }

    /// Computes linear gain for the real-time audio IOProc (`0.0` when muted, otherwise `0.0...2.0`).
    public static func effectiveGain(volume: Double, isMuted: Bool) -> Float {
        guard !isMuted else { return 0.0 }
        return Float(clampVolume(volume))
    }

    /// Soft-clips boosted PCM samples smoothly above `0.95` using `tanhf` so 100%–200% boost
    /// avoids harsh digital clipping while keeping unity/attenuated samples bit-transparent.
    public static func processSample(_ sample: Float, gain: Float) -> Float {
        let scaled = sample * gain
        if gain > 1.0 && (scaled > 0.95 || scaled < -0.95) {
            return tanhf(scaled)
        }
        return scaled
    }

    /// Normalizes common Chromium/Electron/WebKit helper bundle identifiers back toward
    /// a stable parent application identifier when parent PID resolution is unavailable.
    public static func normalizedAppKey(bundleID: String, pid: Int32) -> String {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "pid:\(pid)" }
        let helperSuffixes = [
            ".helper.renderer",
            ".helper.gpu",
            ".helper.plugin",
            ".helper.alerts",
            ".helper",
            ".Helper.Renderer",
            ".Helper.GPU",
            ".Helper",
            ".WebContent",
            ".GPU",
            ".Networking"
        ]
        for suffix in helperSuffixes where trimmed.hasSuffix(suffix) {
            let base = String(trimmed.dropLast(suffix.count))
            if !base.isEmpty { return base }
        }
        return trimmed
    }

    /// Orders mixer rows Vorssaint-style:
    /// 1) Pinned apps first
    /// 2) Actively outputting audio first
    /// 3) Modified/tapped apps first
    /// 4) Alphabetical by `appName`
    public static func sortStreams(_ streams: [AudioAppStream]) -> [AudioAppStream] {
        streams.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            if lhs.isRunningOutput != rhs.isRunningOutput {
                return lhs.isRunningOutput
            }
            if lhs.needsProcessTap != rhs.needsProcessTap {
                return lhs.needsProcessTap
            }
            return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
        }
    }
}

/// Legacy AppleScript fallback registry retained for macOS < 14.2 compatibility and unit coverage.
public enum AppAudioScriptRegistry: Sendable {
    public static let scriptableBundleIDs: [String] = [
        "com.spotify.client",
        "com.apple.Music",
        "com.apple.TV",
        "org.videolan.vlc",
        "com.colliderli.iina",
    ]

    private static let vlcBundleID = "org.videolan.vlc"
    private static let vlcMaxVolume: Double = 256.0
    private static let standardMaxVolume: Double = 100.0

    public static func capability(forBundleID bundleID: String) -> AudioAppControlCapability {
        scriptableBundleIDs.contains(bundleID) ? .directVolume : .monitorOnly
    }

    public static func getVolumeScript(forBundleID bundleID: String) -> String? {
        guard scriptableBundleIDs.contains(bundleID) else { return nil }
        return "tell application id \"\(bundleID)\" to get volume"
    }

    public static func setVolumeScript(forBundleID bundleID: String, volume0to1: Double) -> String? {
        guard scriptableBundleIDs.contains(bundleID) else { return nil }
        let clamped = min(1.0, max(0.0, volume0to1))
        let maxVolume = bundleID == vlcBundleID ? vlcMaxVolume : standardMaxVolume
        let native = Int(round(clamped * maxVolume))
        return "tell application id \"\(bundleID)\" to set volume to \(native)"
    }

    public static func parseScriptVolumeOutput(_ stdout: String, bundleID: String) -> Double? {
        guard scriptableBundleIDs.contains(bundleID) else { return nil }
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = Double(trimmed), raw.isFinite else { return nil }
        let maxVolume = bundleID == vlcBundleID ? vlcMaxVolume : standardMaxVolume
        return min(1.0, max(0.0, raw / maxVolume))
    }

    public static func sortStreams(_ streams: [AudioAppStream]) -> [AudioAppStream] {
        AppAudioMixerHelpers.sortStreams(streams)
    }
}
