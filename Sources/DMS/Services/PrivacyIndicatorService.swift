import Combine
import CoreAudio
import CoreMediaIO
import DMSCore
import Foundation
import Observation

/// Tracks whether the microphone or camera is in use system-wide, mirroring the macOS
/// menu-bar privacy indicators. Hardware state comes from CoreAudio
/// (kAudioDevicePropertyDeviceIsRunningSomewhere on input devices) and CoreMediaIO
/// (kCMIODevicePropertyDeviceIsRunningSomewhere across all CMIO devices); registered
/// consumers ("mic:<id>" / "camera:<id>") are ref-counted on top.
///
/// The 2s HAL poll runs ONLY while `"privacyIndicator"` is enabled in an active bar layout
/// or an explicit consumer is registered — preserving zero idle CPU otherwise.
@MainActor
public final class PrivacyIndicatorService: ObservableObject {
    public static let shared = PrivacyIndicatorService()

    @Published public private(set) var isMicActive: Bool = false
    @Published public private(set) var isCameraActive: Bool = false

    public var isAnyActive: Bool { isMicActive || isCameraActive }

    private var micConsumers: Set<String> = []
    private var cameraConsumers: Set<String> = []
    private var pollTimer: Timer?
    private var configCancellable: AnyCancellable?

    private init() {
        configCancellable = ConfigStore.shared.$config
            .map { cfg in
                Self.hasPrivacyWidgetEnabled(in: cfg)
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncPollingState()
            }
        syncPollingState()
    }

    private static func hasPrivacyWidgetEnabled(in cfg: DMSConfig) -> Bool {
        cfg.barConfigs.contains { bar in
            (bar.layout.left + bar.layout.center + bar.layout.right)
                .contains { $0.enabled && $0.widgetId == "privacyIndicator" }
        }
    }

    private var shouldPollHardware: Bool {
        let barWantsWidget = Self.hasPrivacyWidgetEnabled(in: ConfigStore.shared.config)
        return barWantsWidget || !micConsumers.isEmpty || !cameraConsumers.isEmpty
    }

    private func syncPollingState() {
        if shouldPollHardware {
            if pollTimer == nil {
                refresh()
                pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.refresh()
                    }
                }
            }
        } else {
            pollTimer?.invalidate()
            pollTimer = nil
            isMicActive = false
            isCameraActive = false
        }
    }

    /// Registers a consumer actively using the mic or camera. IDs are namespaced:
    /// "mic:<id>" for microphone consumers, "camera:<id>" for camera consumers.
    public func addConsumer(_ id: String) {
        if id.hasPrefix("mic:") {
            micConsumers.insert(id)
        } else if id.hasPrefix("camera:") {
            cameraConsumers.insert(id)
        } else {
            return
        }
        syncPollingState()
        refresh()
    }

    public func removeConsumer(_ id: String) {
        micConsumers.remove(id)
        cameraConsumers.remove(id)
        syncPollingState()
        if pollTimer != nil {
            refresh()
        }
    }

    public func refresh() {
        Task.detached(priority: .utility) { [weak self] in
            let micHardware = Self.hardwareMicActive()
            let cameraHardware = Self.hardwareCameraActive()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isMicActive = micHardware || !self.micConsumers.isEmpty
                self.isCameraActive = cameraHardware || !self.cameraConsumers.isEmpty
            }
        }
    }

    // MARK: - Hardware detection (call off the main actor if invoked directly)

    private nonisolated static func hardwareMicActive() -> Bool {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(system, &devicesAddr, 0, nil, &size) == noErr,
              size >= MemoryLayout<AudioObjectID>.size else { return false }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &devicesAddr, 0, nil, &size, &ids) == noErr else { return false }

        for id in ids where id != 0 {
            // Only input-capable devices can be "the microphone".
            var streamsAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize = UInt32(0)
            guard AudioObjectGetPropertyDataSize(id, &streamsAddr, 0, nil, &streamSize) == noErr,
                  streamSize > 0 else { continue }

            var runningAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectHasProperty(id, &runningAddr) else { continue }
            var running = UInt32(0)
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(id, &runningAddr, 0, nil, &runningSize, &running) == noErr,
               running != 0 {
                return true
            }
        }
        return false
    }

    // CoreMediaIO's anonymous C enums import as Int in Swift — convert explicitly.
    private nonisolated static let cmioNoError = OSStatus(truncatingIfNeeded: kCMIOHardwareNoError)
    private nonisolated static let cmioSystemObject = CMIOObjectID(truncatingIfNeeded: kCMIOObjectSystemObject)

    private nonisolated static func cmioAddress(
        _ selector: Int,
        scope: Int = kCMIOObjectPropertyScopeGlobal,
        element: Int = kCMIOObjectPropertyElementMain
    ) -> CMIOObjectPropertyAddress {
        CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(truncatingIfNeeded: selector),
            mScope: CMIOObjectPropertyScope(truncatingIfNeeded: scope),
            mElement: CMIOObjectPropertyElement(truncatingIfNeeded: element)
        )
    }

    private nonisolated static func hardwareCameraActive() -> Bool {
        var devicesAddr = cmioAddress(kCMIOHardwarePropertyDevices)
        var size = UInt32(0)
        guard CMIOObjectGetPropertyDataSize(cmioSystemObject, &devicesAddr, 0, nil, &size) == cmioNoError,
              size >= MemoryLayout<CMIOObjectID>.size else { return false }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used = UInt32(0)
        guard CMIOObjectGetPropertyData(cmioSystemObject, &devicesAddr, 0, nil, size, &used, &ids) == cmioNoError else {
            return false
        }

        for device in ids where device != 0 {
            var runningAddr = cmioAddress(kCMIODevicePropertyDeviceIsRunningSomewhere)
            var running = UInt32(0)
            let runningSize = UInt32(MemoryLayout<UInt32>.size)
            var runningUsed = UInt32(0)
            if CMIOObjectGetPropertyData(device, &runningAddr, 0, nil, runningSize, &runningUsed, &running) == cmioNoError,
               running != 0 {
                return true
            }
        }
        return false
    }
}
