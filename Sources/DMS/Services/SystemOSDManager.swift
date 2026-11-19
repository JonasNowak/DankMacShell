import Foundation
import AppKit
import Darwin
import os

/// Manages native macOS OSD (On-Screen Display) bezel suppression by suspending OSDUIHelper.
/// When active, `OSDUIHelper` is placed in a suspended state (`SIGSTOP`) so macOS cannot render
/// the large native volume, brightness, or keyboard backlight bezel overlays.
/// Cleanly resumes execution (`SIGCONT`) upon sleep, app termination, build restarts, or when toggled off.
public final class SystemOSDManager: @unchecked Sendable {
    public static let shared = SystemOSDManager()

    /// True while OSDUIHelper is actively frozen (SIGSTOP) by DMS.
    public private(set) var isSuppressed: Bool = false

    private struct SuppressionState {
        var active = false
        var systemSleeping = false
        var transitionGeneration: UInt64 = 0
        /// OSDUIHelper PIDs currently frozen and monitored for exit.
        var trackedPIDs: Set<pid_t> = []
        var exitSources: [pid_t: DispatchSourceProcess] = [:]
    }

    private static let suppressionState = OSAllocatedUnfairLock(initialState: SuppressionState())
    private static let log = Logger(subsystem: "com.dank.macshell", category: "SystemOSDManager")

    /// Register sleep, wake and launch lifecycle observers once.
    private static let lifecycleSetupOnce: Void = {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleSystemSleep()
        }
        nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleSystemWake()
        }
        // A fresh OSDUIHelper instance may launch while suppression is active: re-scan
        // once per launch instead of polling the full PID table on a timer.
        nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let path = app.bundleURL?.path ?? ""
            let name = app.localizedName ?? ""
            guard path.contains("OSDUIHelper") || name.contains("OSDUIHelper") else { return }
            let shouldSuppress = suppressionState.withLock { $0.active && !$0.systemSleeping && $0.trackedPIDs.isEmpty }
            if shouldSuppress {
                suspendOSDUIHelper()
            }
        }
    }()

    private init() {}

    // MARK: - Sleep / Wake

    private static func handleSystemSleep() {
        suppressionState.withLock { $0.systemSleeping = true }
        resumeOSDUIHelperProcess()
    }

    private static func handleSystemWake() {
        suppressionState.withLock { $0.systemSleeping = false }
        let active = suppressionState.withLock { $0.active }
        if active {
            // PIDs may have changed across sleep: re-scan once instead of polling.
            suspendOSDUIHelper()
        }
    }

    // MARK: - Public API

    /// Disables the native system HUD by suspending OSDUIHelper with SIGSTOP.
    public static func disableSystemHUD() {
        _ = lifecycleSetupOnce
        suppressionState.withLock { state in
            state.active = true
            state.transitionGeneration &+= 1
        }
        suspendOSDUIHelper()
    }

    /// Re-enables the system HUD by sending SIGCONT to resume OSDUIHelper.
    public static func enableSystemHUD() {
        suppressionState.withLock { state in
            state.active = false
            state.transitionGeneration &+= 1
        }
        resumeOSDUIHelperProcess()
    }

    /// Fast-path suspension triggered on media key adjustments. Re-scans only when no
    /// OSDUIHelper PID is currently tracked; otherwise just re-sends SIGSTOP.
    public static func suppressNativeOSDNow() {
        let needsScan = suppressionState.withLock { state -> Bool in
            guard state.active && !state.systemSleeping else { return false }
            return state.trackedPIDs.isEmpty
        }
        if needsScan {
            suspendOSDUIHelper()
        } else {
            let pids = suppressionState.withLock { Array($0.trackedPIDs) }
            for pid in pids {
                kill(pid, SIGSTOP)
            }
        }
    }

    /// Synchronously ensures OSDUIHelper is resumed with SIGCONT on termination.
    public static func resumeOSDUIHelperForTermination() {
        suppressionState.withLock { state in
            state.active = false
            state.transitionGeneration &+= 1
        }
        resumeOSDUIHelperProcess()
    }

    // MARK: - Process Control Helpers

    public static func osduiHelperPIDs() -> [pid_t] {
        var pids = [pid_t](repeating: 0, count: 2048)
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(MemoryLayout<pid_t>.stride * pids.count))
        guard bytes > 0 else { return [] }
        let count = min(Int(bytes) / MemoryLayout<pid_t>.stride, pids.count)
        var result: [pid_t] = []
        for i in 0..<count {
            let pid = pids[i]
            guard pid > 0 else { continue }
            var buffer = [CChar](repeating: 0, count: 4096)
            let len = dms_proc_pidpath(pid, &buffer, UInt32(buffer.count))
            if len > 0 {
                let path = buffer.withUnsafeBufferPointer { ptr in
                    ptr.baseAddress.map { String(cString: $0) } ?? ""
                }
                if path.hasSuffix("/OSDUIHelper") || path.contains("OSDUIHelper.app") {
                    result.append(pid)
                }
            }
        }
        return result
    }

    public static func isOSDUIHelperRunning() -> Bool {
        !osduiHelperPIDs().isEmpty
    }

    public static func osduiHelperPID() -> Int32? {
        osduiHelperPIDs().first
    }

    public static func suspendOSDUIHelper() {
        let pids = osduiHelperPIDs()
        if pids.isEmpty {
            warmUpAndFreezeOSDUIHelper()
            return
        }
        for pid in pids {
            kill(pid, SIGSTOP)
            trackOSDUIHelperPID(pid)
        }
        shared.isSuppressed = true
    }

    /// Attaches a process-exit dispatch source so we only re-scan when OSDUIHelper
    /// actually exits or relaunches — no periodic PID-table polling.
    private static func trackOSDUIHelperPID(_ pid: pid_t) {
        suppressionState.withLock { state in
            guard !state.trackedPIDs.contains(pid) else { return }
            state.trackedPIDs.insert(pid)
            let source = DispatchSource.makeProcessSource(
                identifier: pid,
                eventMask: .exit,
                queue: DispatchQueue.global(qos: .background)
            )
            source.setEventHandler {
                handleTrackedOSDUIHelperExit(pid)
            }
            source.resume()
            state.exitSources[pid] = source
        }
    }

    private static func handleTrackedOSDUIHelperExit(_ pid: pid_t) {
        let shouldSuppress = suppressionState.withLock { state -> Bool in
            state.trackedPIDs.remove(pid)
            if let source = state.exitSources.removeValue(forKey: pid) {
                source.cancel()
            }
            return state.active && !state.systemSleeping
        }
        if suppressionState.withLock({ $0.trackedPIDs.isEmpty }) {
            shared.isSuppressed = false
        }
        if shouldSuppress {
            // OSDUIHelper exited (or was relaunched): re-scan once and freeze any new instance.
            suspendOSDUIHelper()
        }
    }

    private static func resumeOSDUIHelperProcess() {
        let tracked = suppressionState.withLock { state -> [pid_t] in
            let pids = Array(state.trackedPIDs)
            state.trackedPIDs.removeAll()
            for (_, source) in state.exitSources {
                source.cancel()
            }
            state.exitSources.removeAll()
            return pids
        }
        let pids = tracked.isEmpty ? osduiHelperPIDs() : tracked
        for pid in pids {
            kill(pid, SIGCONT)
        }
        shared.isSuppressed = false
    }

    private static func warmUpAndFreezeOSDUIHelper() {
        let helperPath = "/System/Library/CoreServices/OSDUIHelper.app"
        guard FileManager.default.fileExists(atPath: helperPath) else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-g", "-j", "-a", helperPath]
        do {
            try task.run()
            // Reap the short-lived `open` child so it never lingers as a zombie.
            DispatchQueue.global(qos: .utility).async {
                task.waitUntilExit()
            }
        } catch {
            log.error("Failed to launch OSDUIHelper warm-up: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Wait briefly for launchd to spin up the process, then immediately freeze it
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.08) {
            suspendOSDUIHelper()
        }
    }
}
