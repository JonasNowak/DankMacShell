import AppKit
import CoreAudio
import Darwin
import DMSCore
import Foundation

/// Output device descriptor carrying its CoreAudio UID so individual apps can be
/// routed to any hardware or Bluetooth audio sink independently.
public struct RoutableAudioOutput: Identifiable, Equatable, Sendable {
    public let id: String // CoreAudio device UID
    public let objectID: AudioObjectID
    public let name: String
    public let isDefault: Bool
    public var iconName: String { AudioService.iconForDevice(name: name) }
}

// MARK: - Real-Time CoreAudio Process Tap Session (macOS 14.2+)

/// Manages one driverless CoreAudio Process Tap (`AudioHardwareCreateProcessTap`)
/// wrapped in a private Aggregate Device (`AudioHardwareCreateAggregateDevice`)
/// with a lock-free real-time `AudioDeviceIOBlock` that scales PCM gain (`0%–200%`)
/// and routes audio to the target output sink while muting the app's original
/// direct output (`CATapMuteBehavior.mutedWhenTapped`) to prevent echo.
///
/// Architecture inspired by Vorssaint (`vorssaint/vorssaint-utils`) and FineTune (`ronitsingh10/FineTune`).
@available(macOS 14.2, *)
private final class ProcessAudioTapSession: @unchecked Sendable {
    enum TapError: Error, LocalizedError {
        case createTapFailed(OSStatus)
        case createAggregateFailed(OSStatus)
        case createIOProcFailed(OSStatus)
        case startDeviceFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .createTapFailed(let s):
                return "CoreAudio Process Tap failed (OSStatus \(s)). Check System Audio Recording permission."
            case .createAggregateFailed(let s):
                return "Failed to create private audio aggregate device (OSStatus \(s))."
            case .createIOProcFailed(let s):
                return "Failed to attach CoreAudio IOProc (OSStatus \(s))."
            case .startDeviceFailed(let s):
                return "Failed to start audio tap device (OSStatus \(s))."
            }
        }
    }

    let processObjectIDs: [AudioObjectID]
    let outputDeviceUID: String

    private var tapID: AudioObjectID = kAudioObjectUnknown
    private var aggregateDeviceID: AudioObjectID = kAudioObjectUnknown
    private var ioProcID: AudioDeviceIOProcID?
    private let gainPtr: UnsafeMutablePointer<Float>
    private var isStopped: Bool = false

    init(processObjectIDs: [AudioObjectID], outputDeviceUID: String, initialGain: Float) throws {
        self.processObjectIDs = processObjectIDs
        self.outputDeviceUID = outputDeviceUID
        self.gainPtr = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        self.gainPtr.initialize(to: max(0.0, min(2.0, initialGain)))

        do {
            try startPipeline()
        } catch {
            stop()
            gainPtr.deinitialize(count: 1)
            gainPtr.deallocate()
            throw error
        }
    }

    deinit {
        stop()
        gainPtr.deinitialize(count: 1)
        gainPtr.deallocate()
    }

    func setGain(_ gain: Float) {
        gainPtr.pointee = max(0.0, min(2.0, gain))
    }

    private func startPipeline() throws {
        let tapDescription = CATapDescription(stereoMixdownOfProcesses: processObjectIDs)
        tapDescription.muteBehavior = .mutedWhenTapped
        tapDescription.isPrivate = true
        tapDescription.isExclusive = false
        tapDescription.name = "DMS-Mix-\(UUID().uuidString.prefix(8))"

        var createdTapID: AudioObjectID = kAudioObjectUnknown
        let tapStatus = AudioHardwareCreateProcessTap(tapDescription, &createdTapID)
        guard tapStatus == noErr, createdTapID != kAudioObjectUnknown else {
            throw TapError.createTapFailed(tapStatus)
        }
        self.tapID = createdTapID

        let aggUID = "io.github.jonasnowak.dms.mix.\(UUID().uuidString)"
        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "DMS Per-App Mixer",
            kAudioAggregateDeviceUIDKey: aggUID,
            kAudioAggregateDeviceMainSubDeviceKey: outputDeviceUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputDeviceUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: tapDescription.uuid.uuidString
                ]
            ]
        ]

        var createdAggID: AudioObjectID = kAudioObjectUnknown
        let aggStatus = AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &createdAggID)
        guard aggStatus == noErr, createdAggID != kAudioObjectUnknown else {
            throw TapError.createAggregateFailed(aggStatus)
        }
        self.aggregateDeviceID = createdAggID

        // Capture raw pointer by value so the real-time audio callback performs zero
        // ARC retains, zero locks, and zero allocations.
        let gPtr = self.gainPtr
        var createdIOProcID: AudioDeviceIOProcID?
        let ioStatus = AudioDeviceCreateIOProcIDWithBlock(&createdIOProcID, createdAggID, nil) { _, inInputData, _, outOutputData, _ in
            let gain = gPtr.pointee
            let inList = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inInputData))
            let outList = UnsafeMutableAudioBufferListPointer(outOutputData)

            if gain <= 0.0001 || inList.isEmpty {
                for i in 0..<outList.count {
                    if let dst = outList[i].mData {
                        memset(dst, 0, Int(outList[i].mDataByteSize))
                    }
                }
                return
            }

            if inList.count == outList.count {
                // Fast path: matching buffer layout (both interleaved stereo or both planar stereo)
                for b in 0..<inList.count {
                    guard let srcRaw = inList[b].mData, let dstRaw = outList[b].mData else { continue }
                    let byteCount = min(Int(inList[b].mDataByteSize), Int(outList[b].mDataByteSize))
                    let sampleCount = byteCount / MemoryLayout<Float>.size
                    let src = srcRaw.assumingMemoryBound(to: Float.self)
                    let dst = dstRaw.assumingMemoryBound(to: Float.self)
                    if gain <= 1.0 {
                        for s in 0..<sampleCount {
                            dst[s] = src[s] * gain
                        }
                    } else {
                        for s in 0..<sampleCount {
                            let v = src[s] * gain
                            dst[s] = (v > 0.95 || v < -0.95) ? tanhf(v) : v
                        }
                    }
                    if Int(outList[b].mDataByteSize) > byteCount {
                        memset(dstRaw.advanced(by: byteCount), 0, Int(outList[b].mDataByteSize) - byteCount)
                    }
                }
            } else if inList.count == 1 && outList.count >= 2 && inList[0].mNumberChannels >= 2 {
                // De-interleave stereo tap into planar output buffers
                guard let srcRaw = inList[0].mData else { return }
                let inChannels = Int(inList[0].mNumberChannels)
                let frameCount = Int(inList[0].mDataByteSize) / (MemoryLayout<Float>.size * inChannels)
                let src = srcRaw.assumingMemoryBound(to: Float.self)
                for ch in 0..<outList.count {
                    guard let dstRaw = outList[ch].mData else { continue }
                    let dstSamples = Int(outList[ch].mDataByteSize) / MemoryLayout<Float>.size
                    let frames = min(frameCount, dstSamples)
                    let dst = dstRaw.assumingMemoryBound(to: Float.self)
                    let srcCh = min(ch, inChannels - 1)
                    for f in 0..<frames {
                        let v = src[f * inChannels + srcCh] * gain
                        dst[f] = (gain > 1.0 && (v > 0.95 || v < -0.95)) ? tanhf(v) : v
                    }
                }
            } else {
                // General fallback: copy overlapping buffers and zero any remainder
                let count = min(inList.count, outList.count)
                for b in 0..<count {
                    guard let srcRaw = inList[b].mData, let dstRaw = outList[b].mData else { continue }
                    let byteCount = min(Int(inList[b].mDataByteSize), Int(outList[b].mDataByteSize))
                    let sampleCount = byteCount / MemoryLayout<Float>.size
                    let src = srcRaw.assumingMemoryBound(to: Float.self)
                    let dst = dstRaw.assumingMemoryBound(to: Float.self)
                    for s in 0..<sampleCount {
                        let v = src[s] * gain
                        dst[s] = (gain > 1.0 && (v > 0.95 || v < -0.95)) ? tanhf(v) : v
                    }
                }
                if outList.count > count {
                    for b in count..<outList.count {
                        if let dst = outList[b].mData {
                            memset(dst, 0, Int(outList[b].mDataByteSize))
                        }
                    }
                }
            }
        }

        guard ioStatus == noErr, let createdIOProcID else {
            throw TapError.createIOProcFailed(ioStatus)
        }
        self.ioProcID = createdIOProcID

        let startStatus = AudioDeviceStart(createdAggID, createdIOProcID)
        guard startStatus == noErr else {
            throw TapError.startDeviceFailed(startStatus)
        }
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true

        if aggregateDeviceID != kAudioObjectUnknown, let ioProcID {
            AudioDeviceStop(aggregateDeviceID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
            self.ioProcID = nil
        }
        if aggregateDeviceID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = kAudioObjectUnknown
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = kAudioObjectUnknown
        }
    }
}

// MARK: - Per-App Audio Mixer Service

/// Universal driverless per-app audio mixer for macOS 14.2+ inspired by Vorssaint and FineTune.
///
/// - Enumerates CoreAudio process objects and rolls browser/Electron/WebKit helper processes
///   up into their owning `.app` bundle so each app appears as one clean mixer row.
/// - Zero background overhead at unity (100%): a CoreAudio Process Tap is only created when
///   you actually change an app's volume (`0%–200%`), mute it, or route it to a different
///   output device. Resetting an app back to `100%` on System Default destroys its tap cleanly.
/// - Automatically re-attaches active taps following System Default when you switch outputs
///   (e.g. connecting AirPods or an external DAC).
@MainActor
public final class AppAudioMixerService: ObservableObject {
    public static let shared = AppAudioMixerService()

    @Published public private(set) var streams: [AudioAppStream] = []
    @Published public private(set) var routableOutputs: [RoutableAudioOutput] = []
    @Published public private(set) var isRefreshing: Bool = false
    @Published public private(set) var tapPermissionError: String? = nil

    public var hasModifiedApps: Bool {
        streams.contains { $0.needsProcessTap }
    }

    private struct AppMixState {
        var volume: Double = 1.0
        var isMuted: Bool = false
        var preMuteVolume: Double = 1.0
        var outputDeviceUID: String? = nil
    }

    private static let pinnedDefaultsKey = "dms.audioMixer.pinnedBundleIDs"
    private nonisolated static let pollInterval: TimeInterval = 2.5

    private var pollTimer: Timer?
    private var iconCache: [String: NSImage] = [:]
    private var appStates: [String: AppMixState] = [:]
    private var pinnedIDs: Set<String> = []
    private var activeTapSessions: [String: AnyObject] = [:]
    private var lastDefaultOutputUID: String? = nil
    private var defaultOutputListener: AudioObjectPropertyListenerBlock?

    private init() {
        if let saved = UserDefaults.standard.stringArray(forKey: Self.pinnedDefaultsKey) {
            pinnedIDs = Set(saved)
        }
        installDefaultOutputListener()
    }

    // MARK: - Polling & Lifecycle

    /// Starts the visibility-gated refresh loop (called from AudioDetailPage `.onAppear`).
    public func startPolling() {
        stopPolling()
        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    /// Stops UI polling when the Audio detail sheet closes. Active user-modified taps
    /// stay alive in the background so muted/boosted/routed apps keep their settings!
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Tears down all active process taps (called on app quit or Reset All).
    public func stopAllTaps() {
        if #available(macOS 14.2, *) {
            for (_, obj) in activeTapSessions {
                (obj as? ProcessAudioTapSession)?.stop()
            }
        }
        activeTapSessions.removeAll()
    }

    // MARK: - Refresh

    public func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        routableOutputs = Self.enumerateRoutableOutputs()
        let currentDefaultUID = routableOutputs.first(where: { $0.isDefault })?.id
        let defaultOutputChanged = (lastDefaultOutputUID != nil && currentDefaultUID != nil && lastDefaultOutputUID != currentDefaultUID)
        lastDefaultOutputUID = currentDefaultUID

        var grouped = Self.enumerateGroupedProcessStreams(
            existingStates: appStates,
            pinnedIDs: pinnedIDs
        )

        // Include pinned apps that are currently running even when temporarily silent
        let existingKeys = Set(grouped.map(\.id))
        for pinnedKey in pinnedIDs where !existingKeys.contains(pinnedKey) {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == pinnedKey }) {
                let state = appStates[pinnedKey] ?? AppMixState()
                grouped.append(AudioAppStream(
                    id: pinnedKey,
                    pid: app.processIdentifier,
                    processObjectIDs: [],
                    bundleID: pinnedKey,
                    appName: app.localizedName ?? pinnedKey,
                    isRunningOutput: false,
                    isRunningInput: false,
                    volume: state.volume,
                    isMuted: state.isMuted,
                    isPinned: true,
                    outputDeviceUID: state.outputDeviceUID,
                    isTapActive: activeTapSessions[pinnedKey] != nil,
                    capability: Self.platformCapability
                ))
            }
        }

        // Prune tap sessions for apps that have completely exited
        let liveKeys = Set(grouped.map(\.id))
        if #available(macOS 14.2, *) {
            for key in Array(activeTapSessions.keys) where !liveKeys.contains(key) {
                (activeTapSessions.removeValue(forKey: key) as? ProcessAudioTapSession)?.stop()
            }
        }

        // Reconcile tap sessions (e.g. if a new helper process spawned or default output switched)
        for idx in grouped.indices {
            let key = grouped[idx].id
            reconcileTap(for: &grouped[idx], forceRebuild: defaultOutputChanged && grouped[idx].outputDeviceUID == nil)
            grouped[idx].isTapActive = activeTapSessions[key] != nil
        }

        streams = AppAudioMixerHelpers.sortStreams(grouped)
    }

    // MARK: - Per-App Controls

    /// Sets per-app volume multiplier (`0.0...2.0`, where `1.0` = 100% unity, `2.0` = 200% boost).
    public func setVolume(for stream: AudioAppStream, volume: Double) {
        let clamped = AppAudioMixerHelpers.clampVolume(volume)
        var state = appStates[stream.id] ?? AppMixState()
        state.volume = clamped
        if clamped > 0.001 {
            state.isMuted = false
            state.preMuteVolume = clamped
        } else {
            state.isMuted = true
        }
        appStates[stream.id] = state
        applyStateToStream(id: stream.id, state: state, forceRebuild: false)
    }

    /// Toggles per-app mute, restoring the pre-mute volume cleanly on unmute.
    public func toggleMute(for stream: AudioAppStream) {
        var state = appStates[stream.id] ?? AppMixState(volume: stream.volume, isMuted: stream.isMuted, preMuteVolume: max(stream.volume, 0.5), outputDeviceUID: stream.outputDeviceUID)
        if state.isMuted {
            state.isMuted = false
            state.volume = state.preMuteVolume > 0.05 ? state.preMuteVolume : 1.0
        } else {
            state.preMuteVolume = state.volume > 0.05 ? state.volume : 1.0
            state.isMuted = true
        }
        appStates[stream.id] = state
        applyStateToStream(id: stream.id, state: state, forceRebuild: false)
    }

    /// Resets a single app back to 100% unmuted on System Default and destroys its tap.
    public func resetApp(_ stream: AudioAppStream) {
        appStates.removeValue(forKey: stream.id)
        applyStateToStream(id: stream.id, state: AppMixState(), forceRebuild: false)
    }

    /// Resets every app back to 100% unmuted on System Default and destroys all taps.
    public func resetAll() {
        appStates.removeAll()
        stopAllTaps()
        tapPermissionError = nil
        for idx in streams.indices {
            streams[idx].volume = 1.0
            streams[idx].isMuted = false
            streams[idx].outputDeviceUID = nil
            streams[idx].isTapActive = false
        }
        streams = AppAudioMixerHelpers.sortStreams(streams)
    }

    /// Routes a specific app to a CoreAudio output device UID (`nil` = System Default).
    public func setOutputDevice(for stream: AudioAppStream, deviceUID: String?) {
        var state = appStates[stream.id] ?? AppMixState(volume: stream.volume, isMuted: stream.isMuted, preMuteVolume: max(stream.volume, 1.0), outputDeviceUID: stream.outputDeviceUID)
        state.outputDeviceUID = deviceUID
        appStates[stream.id] = state
        applyStateToStream(id: stream.id, state: state, forceRebuild: true)
    }

    /// Pins or unpins an app to the top of the mixer (persisted across launches).
    public func togglePin(for stream: AudioAppStream) {
        if pinnedIDs.contains(stream.id) {
            pinnedIDs.remove(stream.id)
        } else {
            pinnedIDs.insert(stream.id)
        }
        UserDefaults.standard.set(Array(pinnedIDs).sorted(), forKey: Self.pinnedDefaultsKey)
        if let idx = streams.firstIndex(where: { $0.id == stream.id }) {
            streams[idx].isPinned = pinnedIDs.contains(stream.id)
            streams = AppAudioMixerHelpers.sortStreams(streams)
        }
    }

    public func activateApp(pid: Int32) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        app.activate()
    }

    public func openAudioCapturePrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    public func icon(for stream: AudioAppStream) -> NSImage? {
        if let cached = iconCache[stream.id] { return cached }
        var image: NSImage?
        if let app = NSRunningApplication(processIdentifier: stream.pid), let icon = app.icon {
            image = icon
        } else if !stream.bundleID.isEmpty,
                  let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == stream.bundleID }) {
            if let icon = app.icon {
                image = icon
            } else if let bundleURL = app.bundleURL {
                image = NSWorkspace.shared.icon(forFile: bundleURL.path)
            }
        }
        if let image {
            image.size = NSSize(width: 24, height: 24)
            iconCache[stream.id] = image
        }
        return image
    }

    // MARK: - Tap Reconciliation

    private func applyStateToStream(id: String, state: AppMixState, forceRebuild: Bool) {
        guard let idx = streams.firstIndex(where: { $0.id == id }) else { return }
        streams[idx].volume = state.volume
        streams[idx].isMuted = state.isMuted
        streams[idx].outputDeviceUID = state.outputDeviceUID
        reconcileTap(for: &streams[idx], forceRebuild: forceRebuild)
        streams[idx].isTapActive = activeTapSessions[id] != nil
    }

    private func reconcileTap(for stream: inout AudioAppStream, forceRebuild: Bool) {
        guard #available(macOS 14.2, *) else { return }
        let key = stream.id

        // Unity 100% + unmuted + System Default => destroy tap for zero overhead!
        guard stream.needsProcessTap else {
            if let existing = activeTapSessions.removeValue(forKey: key) as? ProcessAudioTapSession {
                existing.stop()
            }
            return
        }

        // Wait until the app actually registers at least one CoreAudio process object
        guard !stream.processObjectIDs.isEmpty else { return }

        let targetUID = stream.outputDeviceUID
            ?? routableOutputs.first(where: { $0.isDefault })?.id
            ?? Self.defaultOutputDeviceUID()
        guard let targetUID, !targetUID.isEmpty else { return }

        let desiredGain = AppAudioMixerHelpers.effectiveGain(volume: stream.volume, isMuted: stream.isMuted)
        let desiredObjects = stream.processObjectIDs.map { AudioObjectID($0) }.sorted()

        if let existing = activeTapSessions[key] as? ProcessAudioTapSession,
           !forceRebuild,
           existing.outputDeviceUID == targetUID,
           existing.processObjectIDs == desiredObjects {
            existing.setGain(desiredGain)
            return
        }

        // Tear down old tap before creating the replacement
        if let old = activeTapSessions.removeValue(forKey: key) as? ProcessAudioTapSession {
            old.stop()
        }

        do {
            let session = try ProcessAudioTapSession(
                processObjectIDs: desiredObjects,
                outputDeviceUID: targetUID,
                initialGain: desiredGain
            )
            activeTapSessions[key] = session
            tapPermissionError = nil
        } catch {
            tapPermissionError = error.localizedDescription
        }
    }

    // MARK: - Default Output Device Watcher

    private func installDefaultOutputListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, !self.activeTapSessions.isEmpty else { return }
                self.refresh()
            }
        }
        defaultOutputListener = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block)
    }

    // MARK: - CoreAudio Enumeration & Helper Grouping

    private static var platformCapability: AudioAppControlCapability {
        if #available(macOS 14.2, *) {
            return .processTap
        }
        return .monitorOnly
    }

    private struct RawProcessGroup {
        var key: String
        var primaryPID: Int32
        var bundleID: String
        var appName: String
        var objectIDs: [UInt32]
        var isRunningOutput: Bool
        var isRunningInput: Bool
    }

    private static func enumerateGroupedProcessStreams(
        existingStates: [String: AppMixState],
        pinnedIDs: Set<String>
    ) -> [AudioAppStream] {
        guard #available(macOS 14.2, *) else { return [] }

        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var listAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var listSize = UInt32(0)
        guard AudioObjectGetPropertyDataSize(systemObject, &listAddress, 0, nil, &listSize) == noErr,
              listSize > 0 else { return [] }
        let count = Int(listSize) / MemoryLayout<AudioObjectID>.size
        guard count > 0 else { return [] }
        var objectIDs = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &listAddress, 0, nil, &listSize, &objectIDs) == noErr else {
            return []
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownBundleID = Bundle.main.bundleIdentifier ?? "io.github.jonasnowak.dms"
        var groups: [String: RawProcessGroup] = [:]

        for objectID in objectIDs {
            guard let pid = processPID(of: objectID), pid != ownPID else { continue }
            let rawBundleID = processBundleID(of: objectID) ?? ""
            if rawBundleID == ownBundleID { continue }

            let isRunningOutput = processFlag(of: objectID, selector: kAudioProcessPropertyIsRunningOutput)
            let isRunningInput = processFlag(of: objectID, selector: kAudioProcessPropertyIsRunningInput)

            // Walk parent PID chain so Chrome/Arc/Discord/Safari helpers roll up into their owning .app
            let ownerApp = resolveOwningRegularApp(for: pid)
            let directApp = NSRunningApplication(processIdentifier: pid)
            let resolvedApp = ownerApp ?? directApp

            let isRegularApp = resolvedApp?.activationPolicy == .regular
            guard isRegularApp || isRunningOutput || isRunningInput else { continue }

            let resolvedBundleID = resolvedApp?.bundleIdentifier ?? rawBundleID
            let key = AppAudioMixerHelpers.normalizedAppKey(bundleID: resolvedBundleID, pid: resolvedApp?.processIdentifier ?? pid)
            let appName = resolvedApp?.localizedName
                ?? (resolvedBundleID.isEmpty ? "PID \(pid)" : resolvedBundleID.components(separatedBy: ".").last ?? resolvedBundleID)
            let primaryPID = resolvedApp?.processIdentifier ?? pid

            if var group = groups[key] {
                if !group.objectIDs.contains(UInt32(objectID)) {
                    group.objectIDs.append(UInt32(objectID))
                }
                group.isRunningOutput = group.isRunningOutput || isRunningOutput
                group.isRunningInput = group.isRunningInput || isRunningInput
                groups[key] = group
            } else {
                groups[key] = RawProcessGroup(
                    key: key,
                    primaryPID: primaryPID,
                    bundleID: resolvedBundleID,
                    appName: appName,
                    objectIDs: [UInt32(objectID)],
                    isRunningOutput: isRunningOutput,
                    isRunningInput: isRunningInput
                )
            }
        }

        return groups.values.map { group in
            let state = existingStates[group.key] ?? AppMixState()
            return AudioAppStream(
                id: group.key,
                pid: group.primaryPID,
                processObjectIDs: group.objectIDs.sorted(),
                bundleID: group.bundleID,
                appName: group.appName,
                isRunningOutput: group.isRunningOutput,
                isRunningInput: group.isRunningInput,
                volume: state.volume,
                isMuted: state.isMuted,
                isPinned: pinnedIDs.contains(group.key),
                outputDeviceUID: state.outputDeviceUID,
                isTapActive: false,
                capability: platformCapability
            )
        }
    }

    /// Walks up `pbi_ppid` (up to 6 hops) to find the owning user-facing `.regular` application
    /// for multi-process browser/Electron/WebKit helpers.
    private static func resolveOwningRegularApp(for pid: pid_t) -> NSRunningApplication? {
        var currentPID = pid
        for _ in 0..<6 {
            if let app = NSRunningApplication(processIdentifier: currentPID),
               app.activationPolicy == .regular {
                return app
            }
            var bsdInfo = proc_bsdinfo()
            let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
            let written = proc_pidinfo(currentPID, PROC_PIDTBSDINFO, 0, &bsdInfo, size)
            guard written == size else { break }
            let parentPID = pid_t(bsdInfo.pbi_ppid)
            if parentPID <= 1 || parentPID == currentPID { break }
            currentPID = parentPID
        }
        return nil
    }

    // MARK: - CoreAudio Output Device UID Enumeration

    private static func enumerateRoutableOutputs() -> [RoutableAudioOutput] {
        let defaultID = AudioService.shared.outputs.first(where: { $0.isDefault })?.id ?? 0
        return AudioService.shared.outputs.compactMap { output in
            guard let uid = deviceUID(for: output.id), !uid.isEmpty else { return nil }
            // Skip our own private aggregate devices if any ever appear
            if uid.hasPrefix("io.github.jonasnowak.dms.mix.") { return nil }
            return RoutableAudioOutput(
                id: uid,
                objectID: output.id,
                name: output.name,
                isDefault: output.id == defaultID || output.isDefault
            )
        }
    }

    private static func defaultOutputDeviceUID() -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var devID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devID) == noErr,
              devID != 0 else { return nil }
        return deviceUID(for: devID)
    }

    private static func deviceUID(for deviceID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var unmanaged: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &unmanaged) == noErr,
              let unmanaged else { return nil }
        return unmanaged.takeRetainedValue() as String
    }

    private static func processAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    @available(macOS 14.2, *)
    private static func processPID(of objectID: AudioObjectID) -> Int32? {
        var address = processAddress(kAudioProcessPropertyPID)
        var pid: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &pid) == noErr else { return nil }
        return pid
    }

    @available(macOS 14.2, *)
    private static func processBundleID(of objectID: AudioObjectID) -> String? {
        var address = processAddress(kAudioProcessPropertyBundleID)
        var unmanaged: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &unmanaged) == noErr,
              let unmanaged else { return nil }
        return unmanaged.takeRetainedValue() as String
    }

    @available(macOS 14.2, *)
    private static func processFlag(of objectID: AudioObjectID, selector: AudioObjectPropertySelector) -> Bool {
        var address = processAddress(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }
}
