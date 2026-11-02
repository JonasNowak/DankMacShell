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

    private struct SuppressionState {
        var task: Task<Void, Never>?
        var active = false
        var systemSleeping = false
        var transitionGeneration: UInt64 = 0
    }

    private static let suppressionState = OSAllocatedUnfairLock(initialState: SuppressionState())

    /// Register sleep and wake lifecycle observers once.
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
        startSuppressionWatcher()
    }

    /// Re-enables the system HUD by sending SIGCONT to resume OSDUIHelper.
    public static func enableSystemHUD() {
        suppressionState.withLock { state in
            state.active = false
            state.transitionGeneration &+= 1
        }
        stopSuppressionWatcher()
        resumeOSDUIHelperProcess()
    }

    /// Fast-path suspension triggered on media key adjustments.
    public static func suppressNativeOSDNow() {
        let active = suppressionState.withLock { $0.active && !$0.systemSleeping }
        if active {
            suspendOSDUIHelper()
        }
    }

    /// Synchronously ensures OSDUIHelper is resumed with SIGCONT on termination.
    public static func resumeOSDUIHelperForTermination() {
        suppressionState.withLock { state in
            state.active = false
            state.transitionGeneration &+= 1
        }
        stopSuppressionWatcher()
        resumeOSDUIHelperProcess()
    }

    // MARK: - Process Control Helpers

    public static func osduiHelperPIDs() -> [pid_t] {
        var pids = [pid_t](repeating: 0, count: 2048)
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(MemoryLayout<pid_t>.stride * pids.count))
        guard bytes > 0 else { return [] }
        let count = Int(bytes) / MemoryLayout<pid_t>.stride
        var result: [pid_t] = []
        for i in 0..<count {
            let pid = pids[i]
            guard pid > 0 else { continue }
            var buffer = [CChar](repeating: 0, count: 4096)
            let len = proc_pidpath(pid, &buffer, UInt32(buffer.count))
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
        }
    }

    private static func resumeOSDUIHelperProcess() {
        let pids = osduiHelperPIDs()
        for pid in pids {
            kill(pid, SIGCONT)
        }
    }

    private static func warmUpAndFreezeOSDUIHelper() {
        let helperPath = "/System/Library/CoreServices/OSDUIHelper.app"
        guard FileManager.default.fileExists(atPath: helperPath) else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-g", "-j", "-a", helperPath]
        try? task.run()

        // Wait briefly for launchd to spin up the process, then immediately freeze it
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.08) {
            let spawnedPids = osduiHelperPIDs()
            for pid in spawnedPids {
                kill(pid, SIGSTOP)
            }
        }
    }

    private static func startSuppressionWatcher() {
        stopSuppressionWatcher()
        let newTask = Task.detached(priority: .background) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms periodic libproc kernel scan
                let shouldSuppress = suppressionState.withLock { $0.active && !$0.systemSleeping }
                if shouldSuppress {
                    let pids = osduiHelperPIDs()
                    for pid in pids {
                        kill(pid, SIGSTOP)
                    }
                }
            }
        }
        suppressionState.withLock { state in
            state.task = newTask
        }
    }

    private static func stopSuppressionWatcher() {
        let task = suppressionState.withLock { state -> Task<Void, Never>? in
            let existing = state.task
            state.task = nil
            return existing
        }
        task?.cancel()
    }
}
