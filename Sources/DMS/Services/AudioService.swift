import AppKit
import CoreAudio
import Observation

public struct AudioOutput: Identifiable, Equatable, Sendable {
    public let id: AudioObjectID
    public let name: String
    public let isDefault: Bool
}

/// CoreAudio event-driven volume, mute, and default device selection.
@MainActor
@Observable
public final class AudioService {
    public static let shared = AudioService()

    public private(set) var volume: Double = 0
    public private(set) var isMuted = false
    public private(set) var outputs: [AudioOutput] = []

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
        for selector in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDevices] {
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
    }

    public func setVolume(_ value: Double) {
        guard device != 0 else { return }
        let clamped = Float32(min(max(value, 0), 1))
        Self.setFloat(device, Self.virtualMainVolume, clamped)
        if isMuted { Self.setUInt32(device, kAudioDevicePropertyMute, 0) }
        volume = Double(clamped)
        isMuted = false
        onVolumeChanged?(volume, isMuted)
    }

    public func toggleMute() {
        guard device != 0, Self.uint32(device, kAudioDevicePropertyMute) != nil else { return }
        Self.setUInt32(device, kAudioDevicePropertyMute, isMuted ? 0 : 1)
        isMuted.toggle()
        onVolumeChanged?(volume, isMuted)
    }

    public func setDefaultOutput(_ id: AudioObjectID) {
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        var value = id
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &value)
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

    private static func outputDevices(defaultID: AudioObjectID) -> [AudioOutput] {
        var address = address(kAudioHardwarePropertyDevices)
        var size = UInt32(0)
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            var streams = Self.address(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeOutput)
            var streamSize = UInt32(0)
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr, streamSize > 0,
                  let name = deviceName(id) else { return nil }
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
}
