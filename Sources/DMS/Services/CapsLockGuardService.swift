import AppKit
import CoreGraphics
import IOKit
import IOKit.hidsystem
import DMSCore

/// Prevents Caps Lock from locking ON while remaining compatible with external Hyper Key
/// remappers (e.g. Hyperkey.app, Karabiner).
///
/// Strategy (3 layers, zero `hidutil` keycode remapping so Hyperkey still sees physical key 57):
/// 1. Tail-appended session `CGEventTap` (`.cgSessionEventTap`, `.tailAppendEventTap`) runs
///    *after* Hyperkey's head tap: swallows bare leaked keycode-57 `flagsChanged` events,
///    strips `.maskAlphaShift` from key/modifier events, and clears hardware Caps Lock.
/// 2. IOKit `IOHIDSetModifierLockState(..., kIOHIDCapsLockState, false)` via a persistent
///    `kIOHIDParamConnectType` handle clears both software state and the physical Caps Lock LED.
/// 3. Fallback global/local `.flagsChanged` NSEvent monitors + wake-from-sleep observer clear
///    Caps Lock even when Accessibility active-tap permission is not yet granted.
@MainActor
public final class CapsLockGuardService: ObservableObject {
    public static let shared = CapsLockGuardService()

    @Published public private(set) var isActive: Bool = false

    private var hidConnect: io_connect_t = 0
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var wakeObserver: Any?

    private init() {}

    deinit {
        if hidConnect != 0 {
            IOServiceClose(hidConnect)
        }
    }

    public func start() {
        guard !isActive else {
            clearHardwareCapsLock()
            return
        }
        isActive = true
        openHIDConnectionIfNeeded()
        clearHardwareCapsLock()
        installEventTap()
        installFallbackMonitors()
        installWakeObserver()
    }

    public func stop() {
        guard isActive else { return }
        isActive = false
        removeEventTap()
        removeFallbackMonitors()
        removeWakeObserver()
        closeHIDConnection()
    }

    /// Immediately forces macOS hardware and software Caps Lock lock state to OFF
    /// (clears `.maskAlphaShift` and turns off the Caps Lock keyboard LED).
    public func clearHardwareCapsLock() {
        openHIDConnectionIfNeeded()
        guard hidConnect != 0 else { return }
        IOHIDSetModifierLockState(hidConnect, Int32(kIOHIDCapsLockState), false)
    }

    // MARK: - Persistent IOKit HID Connection

    private func openHIDConnectionIfNeeded() {
        guard hidConnect == 0 else { return }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(service) }
        var connect: io_connect_t = 0
        if IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect) == KERN_SUCCESS {
            hidConnect = connect
        }
    }

    private func closeHIDConnection() {
        if hidConnect != 0 {
            IOServiceClose(hidConnect)
            hidConnect = 0
        }
    }

    // MARK: - Tail-Appended Session Event Tap

    private func installEventTap() {
        removeEventTap()

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                DispatchQueue.main.async {
                    CapsLockGuardService.shared.reEnableTap()
                }
                return Unmanaged.passUnretained(event)
            }

            let hasAlphaShift = event.flags.contains(.maskAlphaShift)

            if type == .flagsChanged {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                if keyCode == 57 || hasAlphaShift {
                    DispatchQueue.main.async {
                        CapsLockGuardService.shared.clearHardwareCapsLock()
                    }
                    // Strip Caps Lock flag without disturbing Cmd/Opt/Ctrl/Shift from Hyperkey.
                    if hasAlphaShift {
                        event.flags.remove(.maskAlphaShift)
                    }
                    // Swallow leaked bare Caps Lock press/release when no Hyper modifiers are held.
                    let otherMods: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
                    if keyCode == 57 && event.flags.intersection(otherMods).isEmpty {
                        return nil
                    }
                }
            } else if hasAlphaShift {
                event.flags.remove(.maskAlphaShift)
                DispatchQueue.main.async {
                    CapsLockGuardService.shared.clearHardwareCapsLock()
                }
            }

            return Unmanaged.passUnretained(event)
        }

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: nil
        ) else {
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        CGEvent.tapEnable(tap: port, enable: true)
        eventTap = port
        runLoopSource = source
    }

    private func removeEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .defaultMode)
                runLoopSource = nil
            }
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    private func reEnableTap() {
        guard isActive, let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: - Fallback Monitors & Wake Observer

    private func installFallbackMonitors() {
        removeFallbackMonitors()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { _ in
            if CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift) {
                Task { @MainActor in
                    CapsLockGuardService.shared.clearHardwareCapsLock()
                }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            if event.modifierFlags.contains(.capsLock) ||
                CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift) {
                CapsLockGuardService.shared.clearHardwareCapsLock()
            }
            return event
        }
    }

    private func removeFallbackMonitors() {
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
    }

    private func installWakeObserver() {
        removeWakeObserver()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                CapsLockGuardService.shared.clearHardwareCapsLock()
            }
        }
    }

    private func removeWakeObserver() {
        if let obs = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            wakeObserver = nil
        }
    }
}
