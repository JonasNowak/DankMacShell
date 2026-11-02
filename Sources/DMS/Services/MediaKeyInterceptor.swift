import AppKit
import ApplicationServices
import Observation
import DMSCore

/// Intercepts hardware media, volume, and display brightness keys using:
/// 1. Head-inserted active `CGEventTap`s (.cgSessionEventTap and .cghidEventTap) that swallow `NX_SYSDEFINED`
///    media key events (subtype 8) and dispatch them asynchronously before macOS bezel daemons can render.
///    Architecture inspired by ApolloShell (MediaKeyTap) and Atoll (MediaKeyInterceptor).
/// 2. Active OSDUIHelper suspension via `SystemOSDManager` (Atoll architecture) to ensure no system overlay
///    flashes even when CoreAudio changes or keys are pressed.
/// 3. Input source indicator suppression via `SystemInputIndicator` (ApolloShell architecture).
@MainActor
@Observable
public final class MediaKeyInterceptor {
    public static let shared = MediaKeyInterceptor()

    public enum InterceptionMode: String, Sendable {
        /// Active head-inserted tap that swallows key events and routes them directly.
        /// Requires Device Control and Data Access (Accessibility in older macOS).
        case active
        /// Passive listen-only tap that monitors keys without swallowing.
        /// Requires Input Monitoring permission.
        case passive
        /// Zero-permission fallback: CoreAudio hardware property listeners + OSDUIHelper suspension.
        case fallback
    }

    @ObservationIgnored private var sessionTap: CFMachPort?
    @ObservationIgnored private var sessionSource: CFRunLoopSource?
    @ObservationIgnored private var hidTap: CFMachPort?
    @ObservationIgnored private var hidSource: CFRunLoopSource?

    @ObservationIgnored private var permissionPollTimer: Timer?
    @ObservationIgnored private var activeObserver: Any?
    @ObservationIgnored private var hasPromptedAccessibilityThisSession = false
    @ObservationIgnored private var isWanted = false

    public private(set) var mode: InterceptionMode = .fallback
    public private(set) var isIntercepting: Bool = false
    public var hasAccessibilityPermission: Bool {
        let opts = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }
    public var hasInputMonitoringPermission: Bool {
        CGPreflightListenEventAccess()
    }

    public static var isOSDUIHelperSuppressed: Bool {
        SystemOSDManager.isOSDUIHelperRunning()
    }

    private init() {}

    public func start() {
        isWanted = true

        // 1. Freeze OSDUIHelper so it cannot render native overlays
        SystemOSDManager.disableSystemHUD()

        // 2. Hide macOS language / caps-lock popup overlay
        SystemInputIndicator.setHidden(true)

        // 3. Install event taps at session and HID levels (active -> passive -> fallback)
        _ = installTaps()

        // 4. If permissions are missing for active interception, prompt once and poll for grant
        if !hasAccessibilityPermission && !hasPromptedAccessibilityThisSession {
            hasPromptedAccessibilityThisSession = true
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }

        if mode != .active {
            startPermissionObserver()
        } else {
            stopPermissionObserver()
        }
    }

    public func stop() {
        isWanted = false
        stopPermissionObserver()
        SystemInputIndicator.setHidden(false)
        SystemOSDManager.enableSystemHUD()

        removeTaps()
        mode = .fallback
        isIntercepting = false
    }

    public static func setNativeOSDSuppression(enabled: Bool) {
        if enabled {
            SystemOSDManager.disableSystemHUD()
        } else {
            SystemOSDManager.enableSystemHUD()
        }
    }

    public func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // Try modern macOS 13+ / macOS 26 / macOS 27 pane extension URL, then fall back to legacy
        let modernURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")
        let legacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

        if let modernURL, NSWorkspace.shared.open(modernURL) {
            // Opened modern pane
        } else if let legacyURL {
            NSWorkspace.shared.open(legacyURL)
        }
        startPermissionObserver()
    }

    public func openInputMonitoringSettings() {
        _ = CGRequestListenEventAccess()

        let modernURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent")
        let legacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")

        if let modernURL, NSWorkspace.shared.open(modernURL) {
            // Opened modern pane
        } else if let legacyURL {
            NSWorkspace.shared.open(legacyURL)
        }
        startPermissionObserver()
    }

    // MARK: - Permission Polling

    private func startPermissionObserver() {
        guard permissionPollTimer == nil else { return }

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPermissionsAndRetryTaps()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionPollTimer = timer

        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPermissionsAndRetryTaps()
            }
        }
    }

    private func stopPermissionObserver() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
        if let obs = activeObserver {
            NotificationCenter.default.removeObserver(obs)
            activeObserver = nil
        }
    }

    @discardableResult
    public func checkPermissionsAndRetryTaps() -> Bool {
        guard isWanted else { return false }
        if mode != .active {
            if installTaps() && mode == .active {
                stopPermissionObserver()
                return true
            }
        } else {
            stopPermissionObserver()
            return true
        }
        return mode == .active
    }

    // MARK: - Event Tap Management

    @discardableResult
    private func installTaps() -> Bool {
        if mode == .active && sessionTap != nil {
            return true
        }

        let mask: CGEventMask = 1 << 14 // NX_SYSDEFINED

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                DispatchQueue.main.async {
                    MediaKeyInterceptor.shared.reEnableTaps()
                }
                return Unmanaged.passUnretained(event)
            }

            guard type.rawValue == 14,
                  let nsEvent = NSEvent(cgEvent: event),
                  nsEvent.subtype.rawValue == 8 else {
                return Unmanaged.passUnretained(event)
            }

            let data1 = nsEvent.data1
            guard let key = SystemKey(data1: data1) else {
                return Unmanaged.passUnretained(event)
            }

            let isDown = SystemKey.isDown(data1: data1)
            let fine = event.flags.contains([.maskShift, .maskAlternate])

            let currentMode = MediaKeyInterceptor.shared.mode

            if currentMode == .active {
                // Swallow key-up events immediately so macOS never triggers native HUD
                guard isDown else {
                    return nil
                }

                // Keep callback non-blocking: dispatch work asynchronously to main thread
                DispatchQueue.main.async {
                    MediaKeyInterceptor.shared.handleKey(key, fine: fine)
                }

                // Swallow key-down event
                return nil
            } else {
                // Passive (listenOnly) mode: cannot swallow events, pass them through
                if isDown {
                    DispatchQueue.main.async {
                        MediaKeyInterceptor.shared.handlePassiveKey(key, fine: fine)
                    }
                }
                return Unmanaged.passUnretained(event)
            }
        }

        // Clean up any existing taps before (re)installing
        removeTaps()

        // 1. Primary Attempt: Active Session Tap (.defaultTap)
        // Requires "Device Control and Data Access" (Accessibility in older macOS)
        if let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: nil
        ) {
            mode = .active
            isIntercepting = true

            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            CGEvent.tapEnable(tap: port, enable: true)
            sessionTap = port
            sessionSource = source

            // Secondary HID tap for raw hardware
            if let hPort = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: callback,
                userInfo: nil
            ) {
                let hSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, hPort, 0)
                CFRunLoopAddSource(CFRunLoopGetMain(), hSource, .commonModes)
                CFRunLoopAddSource(CFRunLoopGetMain(), hSource, .defaultMode)
                CGEvent.tapEnable(tap: hPort, enable: true)
                hidTap = hPort
                hidSource = hSource
            }

            return true
        }

        // 2. Secondary Attempt: Passive Session Tap (.listenOnly)
        // Requires Input Monitoring permission (kTCCServiceListenEvent)
        if let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: nil
        ) {
            mode = .passive
            isIntercepting = true

            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            CGEvent.tapEnable(tap: port, enable: true)
            sessionTap = port
            sessionSource = source

            return true
        }

        // 3. Fallback: CoreAudio hardware listener + OSDUIHelper suspension
        // Zero permissions needed!
        mode = .fallback
        isIntercepting = false
        return false
    }

    private func removeTaps() {
        if let tap = sessionTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = sessionSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
                sessionSource = nil
            }
            CFMachPortInvalidate(tap)
            sessionTap = nil
        }

        if let tap = hidTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = hidSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
                hidSource = nil
            }
            CFMachPortInvalidate(tap)
            hidTap = nil
        }
    }

    public func reEnableTaps() {
        if let tap = sessionTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        if let tap = hidTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        SystemOSDManager.suppressNativeOSDNow()
    }

    // MARK: - Key Action Dispatcher

    public func handleKey(_ key: SystemKey, fine: Bool = false) {
        SystemOSDManager.suppressNativeOSDNow()

        switch key {
        case .volumeUp:
            AudioService.shared.stepVolume(up: true, fine: fine)
        case .volumeDown:
            AudioService.shared.stepVolume(up: false, fine: fine)
        case .mute:
            AudioService.shared.toggleMute()
        case .brightnessUp:
            BrightnessService.shared.step(up: true, fine: fine)
        case .brightnessDown:
            BrightnessService.shared.step(up: false, fine: fine)
        case .playPause:
            NowPlayingService.shared.playPause()
        case .next, .fast:
            NowPlayingService.shared.next()
        case .previous, .rewind:
            NowPlayingService.shared.previous()
        case .illuminationUp:
            OSDController.shared.show(type: .keyboardBacklight, value: 1.0)
        case .illuminationDown:
            OSDController.shared.show(type: .keyboardBacklight, value: 0.0)
        case .illuminationToggle:
            OSDController.shared.show(type: .keyboardBacklight, text: "TOGGLE")
        case .eject:
            OSDController.shared.show(type: .mediaEject, text: "Eject")
        }
    }

    public func handlePassiveKey(_ key: SystemKey, fine: Bool = false) {
        SystemOSDManager.suppressNativeOSDNow()

        switch key {
        case .volumeUp:
            let cur = AudioService.shared.volume
            let step = SystemKey.step(fine: fine)
            let next = min(1.0, cur + step)
            OSDController.shared.show(type: .volume, value: next, isMuted: false)
        case .volumeDown:
            let cur = AudioService.shared.volume
            let step = SystemKey.step(fine: fine)
            let next = max(0.0, cur - step)
            OSDController.shared.show(type: .volume, value: next, isMuted: false)
        case .mute:
            let willMute = !AudioService.shared.isMuted
            OSDController.shared.show(type: .volume, value: AudioService.shared.volume, isMuted: willMute)
        case .brightnessUp:
            let cur = BrightnessService.shared.value
            let step = SystemKey.step(fine: fine)
            let next = min(1.0, cur + step)
            OSDController.shared.show(type: .brightness, value: next)
        case .brightnessDown:
            let cur = BrightnessService.shared.value
            let step = SystemKey.step(fine: fine)
            let next = max(0.0, cur - step)
            OSDController.shared.show(type: .brightness, value: next)
        case .playPause:
            NowPlayingService.shared.playPause()
        case .next, .fast:
            NowPlayingService.shared.next()
        case .previous, .rewind:
            NowPlayingService.shared.previous()
        case .illuminationUp, .illuminationDown, .illuminationToggle:
            OSDController.shared.show(type: .keyboardBacklight)
        case .eject:
            OSDController.shared.show(type: .mediaEject, text: "Eject")
        }
    }
}

/// Manages macOS system input source / language indicator overlay suppression.
/// Architecture inspired by ApolloShell.
@MainActor
public enum SystemInputIndicator {
    private static let key = "TSMLanguageIndicatorEnabled" as CFString
    private static let marker = "dms_hidSystemInputIndicator"

    public static func setHidden(_ hide: Bool) {
        let d = UserDefaults.standard
        if hide {
            guard !d.bool(forKey: marker) else { return }
            write(false)
            d.set(true, forKey: marker)
        } else if d.bool(forKey: marker) {
            write(nil)
            d.removeObject(forKey: marker)
        }
    }

    private static func write(_ v: Bool?) {
        CFPreferencesSetValue(
            key,
            v.map { $0 as CFBoolean },
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSynchronize(
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
    }
}
