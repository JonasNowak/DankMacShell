import AppKit
import CoreAudio
import Observation

public struct AudioOutput: Identifiable, Equatable, Sendable {
    public let id: AudioObjectID
    public let name: String
    public let isDefault: Bool

    public var iconName: String {
        AudioService.iconForDevice(name: name)
    }
}

/// CoreAudio event-driven volume, mute, and default device selection.
@MainActor
@Observable
public final class AudioService {
    public static let shared = AudioService()

    public private(set) var volume: Double = 0
    public private(set) var isMuted = false
    public private(set) var outputs: [AudioOutput] = []
    public private(set) var inputs: [AudioOutput] = []

    public var currentOutputName: String {
        outputs.first(where: { $0.isDefault })?.name ?? "Speakers"
    }

    public var deviceIcon: String {
        guard let def = outputs.first(where: { $0.isDefault }) else {
            return Self.iconForDevice(name: currentOutputName)
        }
        return def.iconName
    }

    public var currentOutputIcon: String {
        if isMuted { return "speaker.slash.fill" }
        let dIcon = deviceIcon
        if dIcon == "speaker.wave.2.fill" {
            if volume <= 0.001 {
                return "speaker.fill"
            } else if volume < 0.33 {
                return "speaker.wave.1.fill"
            } else if volume < 0.66 {
                return "speaker.wave.2.fill"
            } else {
                return "speaker.wave.3.fill"
            }
        }
        return dIcon
    }

    public nonisolated static func iconForDevice(name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("mic") || lower.contains("mikrofon") || lower.contains("micro") || lower.contains("input") {
            return "mic.fill"
        } else if lower.contains("airpods max") || lower.contains("airpods.max") {
            return "airpodsmax"
        } else if lower.contains("airpods pro") || lower.contains("airpods.pro") {
            return "airpodspro"
        } else if lower.contains("airpod") {
            return "airpods"
        } else if lower.contains("earpod") || lower.contains("buds") || lower.contains("earbud") || lower.contains("earphone") || lower.contains("ohrhörer") || lower.contains("écouteur") {
            return "earbuds"
        } else if lower.contains("headphone") || lower.contains("headset") || lower.contains("kopfhörer") || lower.contains("casque") || lower.contains("auricular") || lower.contains("beats") || lower.contains("sony") || lower.contains("bose") || lower.contains("wh-1000") || lower.contains("wf-1000") || lower.contains("sennheiser") || lower.contains("shure") || lower.contains("audio-technica") || lower.contains("jabra") {
            return "headphones"
        } else if lower.contains("tv") || lower.contains("apple tv") || lower.contains("fernseher") || lower.contains("téléviseur") {
            return "tv.fill"
        } else if lower.contains("hdmi") || lower.contains("display") || lower.contains("monitor") || lower.contains("screen") || lower.contains("bildschirm") || lower.contains("écran") || lower.contains("dell") || lower.contains("lg") || lower.contains("samsung") || lower.contains("benq") || lower.contains("asus") || lower.contains("viewsonic") || lower.contains("pro display") || lower.contains("studio display") {
            return "display"
        } else if lower.contains("homepod") {
            return "homepod.fill"
        } else if lower.contains("blackhole") || lower.contains("soundflower") || lower.contains("loopback") || lower.contains("virtual") || lower.contains("aggregate") || lower.contains("multi-output") {
            return "waveform"
        } else if lower.contains("usb") || lower.contains("dac") || lower.contains("scarlett") || lower.contains("focusrite") || lower.contains("interface") || lower.contains("audioengine") || lower.contains("motu") || lower.contains("presonus") || lower.contains("rme") || lower.contains("apollo") {
            return "hifispeaker.2.fill"
        } else if lower.contains("speaker") || lower.contains("lautsprecher") || lower.contains("haut-parleur") || lower.contains("altavoz") || lower.contains("altavoces") || lower.contains("macbook") || lower.contains("built-in") || lower.contains("internal") || lower.contains("intern") || lower.contains("imac") || lower.contains("mac mini") || lower.contains("mac studio") || lower.contains("mac pro") {
            return "speaker.wave.2.fill"
        }
        return "speaker.wave.2.fill"
    }

    @ObservationIgnored private var device: AudioObjectID = 0
    @ObservationIgnored private var deviceListener: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private var systemListener: AudioObjectPropertyListenerBlock?

    public var onVolumeChanged: ((Double, Bool) -> Void)?

    private static let virtualMainVolume: AudioObjectPropertySelector = 0x766D_7663

    private init() {
        let listener: AudioObjectPropertyListenerBlock = { _, _ in
            MainActor.assumeIsolated { AudioService.shared.refresh() }
        }
        systemListener = listener
        for selector in [
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultInputDevice,
            kAudioHardwarePropertyDevices
        ] {
            var address = Self.address(selector)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        }
        refresh()
    }


    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    public func refresh() {
        let newDevice = Self.defaultOutputDevice()
        if newDevice != device { watch(newDevice) }
        if let v = Self.float(device, Self.virtualMainVolume) { volume = Double(v) }
        if let m = Self.uint32(device, kAudioDevicePropertyMute) { isMuted = m != 0 }
        let list = Self.outputDevices(defaultID: device)
        if list != outputs { outputs = list }
        let inList = Self.inputDevicesList()
        if inList != inputs { inputs = inList }
        EventSubscriptionBroker.shared.broadcast(event: "events.audio", payload: ["volume": volume, "isMuted": isMuted])
    }


    public func setVolume(_ value: Double) {
        guard device != 0 else { return }
        let clamped = Float32(min(max(value, 0), 1))
        Self.setFloat(device, Self.virtualMainVolume, clamped)
        if isMuted { Self.setUInt32(device, kAudioDevicePropertyMute, 0) }
        volume = Double(clamped)
        isMuted = false
        onVolumeChanged?(volume, isMuted)
        EventSubscriptionBroker.shared.broadcast(event: "events.audio", payload: ["volume": volume, "isMuted": isMuted])
    }

    public func setMuted(_ muted: Bool) {
        guard device != 0, Self.uint32(device, kAudioDevicePropertyMute) != nil else { return }
        Self.setUInt32(device, kAudioDevicePropertyMute, muted ? 1 : 0)
        isMuted = muted
        onVolumeChanged?(volume, isMuted)
        EventSubscriptionBroker.shared.broadcast(event: "events.audio", payload: ["volume": volume, "isMuted": isMuted])
    }

    public func toggleMute() {
        setMuted(!isMuted)
    }

    public var isMicMuted: Bool = false

    public func setMicMuted(_ muted: Bool) {
        isMicMuted = muted
        let script = muted ? "set volume input volume 0" : "set volume input volume 100"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    public func toggleMicMute() {
        setMicMuted(!isMicMuted)
    }

    public func setDefaultOutput(_ id: AudioObjectID) {
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        var value = id
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &value)
        if status == noErr {
            refresh()
        }
    }

    public func setDefaultInput(_ id: AudioObjectID) {
        var address = Self.address(kAudioHardwarePropertyDefaultInputDevice)
        var value = id
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &value)
        if status == noErr {
            refresh()
        }
    }

    @discardableResult
    public func setDefaultOutputByName(_ name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let matching = outputs.first(where: {
            $0.name.lowercased() == clean ||
            $0.name.lowercased().contains(clean) ||
            String($0.id) == clean
        }) else {
            return false
        }
        setDefaultOutput(matching.id)
        return true
    }

    private func watch(_ newDevice: AudioObjectID) {
        for selector in [Self.virtualMainVolume, kAudioDevicePropertyMute] {
            var address = Self.address(selector, scope: kAudioDevicePropertyScopeOutput)
            if let old = deviceListener, device != 0 {
                AudioObjectRemovePropertyListenerBlock(device, &address, .main, old)
            }
        }
        device = newDevice
        guard newDevice != 0 else { return }
        let listener: AudioObjectPropertyListenerBlock = { _, _ in
            MainActor.assumeIsolated { AudioService.shared.refresh() }
        }
        deviceListener = listener
        for selector in [Self.virtualMainVolume, kAudioDevicePropertyMute] {
            var address = Self.address(selector, scope: kAudioDevicePropertyScopeOutput)
            AudioObjectAddPropertyListenerBlock(newDevice, &address, .main, listener)
        }
    }

    private static func defaultOutputDevice() -> AudioObjectID {
        var address = address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return id
    }

    private static func float(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector) -> Float32? {
        var address = address(selector, scope: kAudioDevicePropertyScopeOutput)
        guard device != 0, AudioObjectHasProperty(device, &address) else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func uint32(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var address = address(selector, scope: kAudioDevicePropertyScopeOutput)
        guard device != 0, AudioObjectHasProperty(device, &address) else { return nil }
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func setFloat(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: Float32) {
        var address = address(selector, scope: kAudioDevicePropertyScopeOutput)
        var v = value
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
    }

    private static func setUInt32(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: UInt32) {
        var address = address(selector, scope: kAudioDevicePropertyScopeOutput)
        var v = value
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &v)
    }

    public static func hasInputStreams(_ id: AudioObjectID) -> Bool {
        var streams = address(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeInput)
        var streamSize = UInt32(0)
        if AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr && streamSize > 0 {
            return true
        }
        var configAddr = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeInput)
        var configSize = UInt32(0)
        if AudioObjectGetPropertyDataSize(id, &configAddr, 0, nil, &configSize) == noErr && configSize > 0 {
            let data = malloc(Int(configSize))
            defer { free(data) }
            if let data = data, AudioObjectGetPropertyData(id, &configAddr, 0, nil, &configSize, data) == noErr {
                let bufferList = data.bindMemory(to: AudioBufferList.self, capacity: 1)
                if bufferList.pointee.mNumberBuffers > 0 {
                    return true
                }
            }
        }
        return false
    }

    public static func hasOutputStreams(_ id: AudioObjectID) -> Bool {
        var streams = address(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeOutput)
        var streamSize = UInt32(0)
        if AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr && streamSize > 0 {
            return true
        }
        var configAddr = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeOutput)
        var configSize = UInt32(0)
        if AudioObjectGetPropertyDataSize(id, &configAddr, 0, nil, &configSize) == noErr && configSize > 0 {
            let data = malloc(Int(configSize))
            defer { free(data) }
            if let data = data, AudioObjectGetPropertyData(id, &configAddr, 0, nil, &configSize, data) == noErr {
                let bufferList = data.bindMemory(to: AudioBufferList.self, capacity: 1)
                if bufferList.pointee.mNumberBuffers > 0 {
                    return true
                }
            }
        }
        return false
    }

    private static func outputDevices(defaultID: AudioObjectID) -> [AudioOutput] {
        var address = address(kAudioHardwarePropertyDevices)
        var size = UInt32(0)
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            guard hasOutputStreams(id), let name = deviceName(id) else { return nil }
            return AudioOutput(id: id, name: name, isDefault: id == defaultID)
        }
    }

    private static func deviceName(_ device: AudioObjectID) -> String? {
        var address = address(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }

    public var inputVolume: Double = 0.75

    public func setInputVolume(_ value: Double) {
        inputVolume = min(1.0, max(0.0, value))
        let script = "set volume input volume \(Int(inputVolume * 100))"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    public var currentInputName: String {
        inputDevices().first(where: { $0.isDefault })?.name ?? "Built-in Microphone"
    }

    public static func defaultInputDevice() -> AudioObjectID {
        var address = address(kAudioHardwarePropertyDefaultInputDevice)
        var id = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return id
    }

    public static func inputDevicesList() -> [AudioOutput] {
        var address = address(kAudioHardwarePropertyDevices)
        var size = UInt32(0)
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        let defID = defaultInputDevice()
        return ids.compactMap { id in
            guard hasInputStreams(id), let name = deviceName(id) else { return nil }
            return AudioOutput(id: id, name: name, isDefault: id == defID)
        }
    }

    public func inputDevices() -> [AudioOutput] {
        if inputs.isEmpty {
            inputs = Self.inputDevicesList()
        }
        return inputs
    }
}

