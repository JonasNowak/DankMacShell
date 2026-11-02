import Foundation

/// System on-screen display (OSD) notification types supported across DankMacShell.
public enum OSDType: String, Sendable, Codable, CaseIterable {
    case volume
    case micVolume
    case brightness
    case capsLock
    case audioOutput
    case idleInhibit
    case keyboardBacklight
    case mediaEject

    public var title: String {
        switch self {
        case .volume: return "Volume"
        case .micVolume: return "Microphone"
        case .brightness: return "Brightness"
        case .capsLock: return "Caps Lock"
        case .audioOutput: return "Audio Output"
        case .idleInhibit: return "Keep Awake"
        case .keyboardBacklight: return "Keyboard Backlight"
        case .mediaEject: return "Eject"
        }
    }

    public var isGaugeMetric: Bool {
        switch self {
        case .volume, .micVolume, .brightness, .keyboardBacklight:
            return true
        case .capsLock, .audioOutput, .idleInhibit, .mediaEject:
            return false
        }
    }

    public func iconName(isMuted: Bool = false, value: Double? = nil, text: String? = nil) -> String {
        switch self {
        case .volume:
            if isMuted { return "speaker.slash.fill" }
            guard let val = value else { return "speaker.wave.2.fill" }
            if val <= 0.001 { return "speaker.fill" }
            if val < 0.33 { return "speaker.wave.1.fill" }
            if val < 0.66 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"

        case .micVolume:
            return isMuted ? "mic.slash.fill" : "mic.fill"

        case .brightness:
            guard let val = value else { return "sun.max.fill" }
            if val < 0.33 { return "sun.min.fill" }
            return "sun.max.fill"

        case .capsLock:
            return "capslock.fill"

        case .audioOutput:
            if let customText = text, !customText.isEmpty {
                return AudioDeviceIconResolver.icon(for: customText)
            }
            return "speaker.wave.2.fill"

        case .idleInhibit:
            let active = (text?.lowercased() == "awake" || (value ?? 0) > 0 || !isMuted)
            return active ? "cup.and.saucer.fill" : "cup.and.saucer"

        case .keyboardBacklight:
            guard let val = value else { return "keyboard.fill" }
            if val <= 0.001 { return "keyboard" }
            return "keyboard.fill"

        case .mediaEject:
            return "eject.fill"
        }
    }

    public func formattedValue(isMuted: Bool = false, value: Double? = nil, text: String? = nil) -> String {
        switch self {
        case .volume:
            if isMuted { return "Muted" }
            if let val = value { return "\(Int(round(min(1.0, max(0.0, val)) * 100)))%" }
            return text ?? "0%"

        case .micVolume:
            if isMuted { return "Muted" }
            if let val = value { return "\(Int(round(min(1.0, max(0.0, val)) * 100)))%" }
            return text ?? (isMuted ? "Muted" : "100%")

        case .brightness:
            if let val = value { return "\(Int(round(min(1.0, max(0.0, val)) * 100)))%" }
            return text ?? "100%"

        case .capsLock:
            if let t = text, !t.isEmpty { return t.uppercased() }
            return isMuted ? "OFF" : "ON"

        case .audioOutput:
            return text ?? "Default"

        case .idleInhibit:
            if let t = text, !t.isEmpty { return t }
            return isMuted ? "Normal" : "Awake"

        case .keyboardBacklight:
            if let val = value { return "\(Int(round(min(1.0, max(0.0, val)) * 100)))%" }
            return text ?? "100%"

        case .mediaEject:
            return text ?? "Ejected"
        }
    }
}

/// Helper resolver for device names to SF Symbols in DMSCore.
public enum AudioDeviceIconResolver: Sendable {
    public static func icon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("mic") || lower.contains("mikrofon") || lower.contains("micro") || lower.contains("input") {
            return "mic.fill"
        } else if lower.contains("airpods max") || lower.contains("airpods.max") {
            return "airpodsmax"
        } else if lower.contains("airpods pro") || lower.contains("airpods.pro") {
            return "airpodspro"
        } else if lower.contains("airpod") {
            return "airpods"
        } else if lower.contains("earpod") || lower.contains("buds") || lower.contains("earbud") || lower.contains("earphone") {
            return "earbuds"
        } else if lower.contains("headphone") || lower.contains("headset") || lower.contains("beats") || lower.contains("sony") || lower.contains("bose") {
            return "headphones"
        } else if lower.contains("tv") || lower.contains("apple tv") {
            return "tv.fill"
        } else if lower.contains("hdmi") || lower.contains("display") || lower.contains("monitor") {
            return "display"
        } else if lower.contains("homepod") {
            return "homepod.fill"
        } else if lower.contains("blackhole") || lower.contains("soundflower") || lower.contains("virtual") {
            return "waveform"
        } else {
            return "speaker.wave.2.fill"
        }
    }
}

/// Hardware media and system keys intercepted from NX_SYSDEFINED events.
/// Architecture inspired by ApolloShell and Atoll.
public enum SystemKey: Equatable, Sendable {
    case volumeUp
    case volumeDown
    case mute
    case brightnessUp
    case brightnessDown
    case playPause
    case next
    case previous
    case fast
    case rewind
    case illuminationUp
    case illuminationDown
    case illuminationToggle
    case eject

    // macOS NX Auxiliary Key Types (IOKit/hidsystem/ev_keymap.h)
    public static let NX_KEYTYPE_SOUND_UP: Int32 = 0
    public static let NX_KEYTYPE_SOUND_DOWN: Int32 = 1
    public static let NX_KEYTYPE_BRIGHTNESS_UP: Int32 = 2
    public static let NX_KEYTYPE_BRIGHTNESS_DOWN: Int32 = 3
    public static let NX_KEYTYPE_MUTE: Int32 = 7
    public static let NX_KEYTYPE_CONTRAST_UP: Int32 = 11
    public static let NX_KEYTYPE_CONTRAST_DOWN: Int32 = 12
    public static let NX_KEYTYPE_EJECT: Int32 = 14
    public static let NX_KEYTYPE_PLAY: Int32 = 16
    public static let NX_KEYTYPE_NEXT: Int32 = 17
    public static let NX_KEYTYPE_PREVIOUS: Int32 = 18
    public static let NX_KEYTYPE_FAST: Int32 = 19
    public static let NX_KEYTYPE_REWIND: Int32 = 20
    public static let NX_KEYTYPE_ILLUMINATION_UP: Int32 = 21
    public static let NX_KEYTYPE_ILLUMINATION_DOWN: Int32 = 22
    public static let NX_KEYTYPE_ILLUMINATION_TOGGLE: Int32 = 23

    public init?(data1: Int) {
        let code = Int32((data1 & 0xFFFF_0000) >> 16)
        switch code {
        case Self.NX_KEYTYPE_SOUND_UP: self = .volumeUp
        case Self.NX_KEYTYPE_SOUND_DOWN: self = .volumeDown
        case Self.NX_KEYTYPE_MUTE: self = .mute
        case Self.NX_KEYTYPE_BRIGHTNESS_UP, Self.NX_KEYTYPE_CONTRAST_UP: self = .brightnessUp
        case Self.NX_KEYTYPE_BRIGHTNESS_DOWN, Self.NX_KEYTYPE_CONTRAST_DOWN: self = .brightnessDown
        case Self.NX_KEYTYPE_PLAY: self = .playPause
        case Self.NX_KEYTYPE_NEXT: self = .next
        case Self.NX_KEYTYPE_PREVIOUS: self = .previous
        case Self.NX_KEYTYPE_FAST: self = .fast
        case Self.NX_KEYTYPE_REWIND: self = .rewind
        case Self.NX_KEYTYPE_ILLUMINATION_UP: self = .illuminationUp
        case Self.NX_KEYTYPE_ILLUMINATION_DOWN: self = .illuminationDown
        case Self.NX_KEYTYPE_ILLUMINATION_TOGGLE: self = .illuminationToggle
        case Self.NX_KEYTYPE_EJECT: self = .eject
        default: return nil
        }
    }

    public static func isDown(data1: Int) -> Bool {
        ((data1 & 0xFF00) >> 8) == 0x0A
    }

    public static func isRepeat(data1: Int) -> Bool {
        (data1 & 0x0001) == 1
    }

    public static func step(fine: Bool) -> Double {
        fine ? (1.0 / 64.0) : (1.0 / 16.0)
    }

    public static func stepped(_ v: Double, by d: Double) -> Double {
        let n = (v / abs(d)).rounded() + (d > 0 ? 1.0 : -1.0)
        return min(max(n * abs(d), 0.0), 1.0)
    }
}
