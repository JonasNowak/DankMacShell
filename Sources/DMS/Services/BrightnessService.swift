import CoreFoundation
import CoreGraphics
import Darwin
import Foundation
import Observation
import DMSCore

/// Built-in and primary display brightness through the private DisplayServices framework.
/// Architecture inspired by ApolloShell (OSDBrightness display fallback) and Atoll.
@MainActor
@Observable
public final class BrightnessService {
    public static let shared = BrightnessService()

    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32
    // arm64e disassembly of DisplayServices`__getDSClient_block_invoke.182:
    // invokes callback with x0=NULL, x1=observer, x2=CFStringRef key, x3=NULL,
    // x4=CFDictionaryRef @{ "value": NSNumber }. Never populates FP register s0.
    private typealias BrightnessCallback = @convention(c) (
        UnsafeMutableRawPointer?,
        UnsafeMutableRawPointer?,
        CFString?,
        UnsafeRawPointer?,
        CFDictionary?
    ) -> Void
    // arm64e disassembly: DisplayServicesRegisterForBrightnessChangeNotifications takes
    // (CGDirectDisplayID display, void *refcon, callback).
    private typealias RegisterNotifications = @convention(c) (CGDirectDisplayID, UnsafeMutableRawPointer?, BrightnessCallback) -> Int32

    public private(set) var value: Double = 0
    public private(set) var isAvailable = false

    public var brightness: Double {
        get { value }
        set { set(newValue) }
    }

    @ObservationIgnored private var getBrightness: GetBrightness?
    @ObservationIgnored private var setBrightness: SetBrightness?
    @ObservationIgnored private var display: CGDirectDisplayID = 0
    @ObservationIgnored private var isInitialized: Bool = false
    @ObservationIgnored private var lastLocalWriteUptime: TimeInterval = -.infinity
    @ObservationIgnored private var lastRefreshUptime: TimeInterval = -.infinity

    public var onBrightnessChanged: ((Double) -> Void)?

    private init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        var registerFn: RegisterNotifications?
        if let handle = dlopen(path, RTLD_LAZY) {
            if let get = dlsym(handle, "DisplayServicesGetBrightness") {
                getBrightness = unsafeBitCast(get, to: GetBrightness.self)
            }
            if let set = dlsym(handle, "DisplayServicesSetBrightness") {
                setBrightness = unsafeBitCast(set, to: SetBrightness.self)
            }
            if let reg = dlsym(handle, "DisplayServicesRegisterForBrightnessChangeNotifications") {
                registerFn = unsafeBitCast(reg, to: RegisterNotifications.self)
            }
        }
        refresh()
        if let registerFn {
            let targetDisplay = display != 0 ? display : CGMainDisplayID()
            _ = registerFn(targetDisplay, nil, { (_, _, _, _, userInfo) in
                guard let dict = userInfo as? [AnyHashable: Any],
                      let parsed = DisplayBrightnessNotification.extractBrightness(from: dict) else {
                    return
                }
                Task { @MainActor in
                    BrightnessService.shared.handleExternalBrightnessChange(parsed)
                }
            })
        }
        isInitialized = true
    }

    public func handleExternalBrightnessChange(_ newBrightness: Double) {
        let now = ProcessInfo.processInfo.systemUptime
        guard let next = DisplayBrightnessNotification.externalUpdateValue(
            currentValue: value,
            candidateValue: newBrightness,
            isInitialized: isInitialized,
            secondsSinceLocalWrite: now - lastLocalWriteUptime
        ) else {
            return
        }
        SystemOSDManager.suppressNativeOSDNow()
        value = next
        onBrightnessChanged?(next)
    }

    public func refresh() {
        guard let getBrightness else {
            isAvailable = false
            return
        }
        display = Self.findDisplay()
        var v: Float = 0
        isAvailable = (getBrightness(display, &v) == 0)
        lastRefreshUptime = ProcessInfo.processInfo.systemUptime
        if isAvailable, v.isFinite {
            value = min(max(Double(v), 0), 1)
        }
    }

    /// Refreshes cached hardware brightness when unavailable or idle so stale values never drive steps.
    public func refreshIfStale(maxAge: TimeInterval = 1.0) {
        let now = ProcessInfo.processInfo.systemUptime
        if !isAvailable || (now - lastLocalWriteUptime > maxAge && now - lastRefreshUptime > maxAge) {
            refresh()
        }
    }

    public func set(_ fraction: Double) {
        guard fraction.isFinite, let setBrightness else { return }
        if display == 0 {
            display = Self.findDisplay()
        }
        let clamped = min(max(fraction, 0), 1)
        lastLocalWriteUptime = ProcessInfo.processInfo.systemUptime
        _ = setBrightness(display, Float(clamped))
        value = clamped
        isAvailable = true
        onBrightnessChanged?(clamped)
    }

    public func step(up: Bool, fine: Bool = false) {
        refreshIfStale()
        let d = SystemKey.step(fine: fine)
        let cur = value
        let next = SystemKey.stepped(cur, by: up ? d : -d)
        set(next)
    }

    private static func findDisplay() -> CGDirectDisplayID {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count) == .success else {
            return CGMainDisplayID()
        }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 } ?? CGMainDisplayID()
    }
}
