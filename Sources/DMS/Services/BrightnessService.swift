import CoreGraphics
import Darwin
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
    private typealias BrightnessCallback = @convention(c) (CGDirectDisplayID, Float, UnsafeMutableRawPointer?) -> Void
    private typealias RegisterNotifications = @convention(c) (BrightnessCallback, UnsafeMutableRawPointer?) -> Int32

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

    public var onBrightnessChanged: ((Double) -> Void)?

    private init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        if let handle = dlopen(path, RTLD_LAZY) {
            if let get = dlsym(handle, "DisplayServicesGetBrightness") {
                getBrightness = unsafeBitCast(get, to: GetBrightness.self)
            }
            if let set = dlsym(handle, "DisplayServicesSetBrightness") {
                setBrightness = unsafeBitCast(set, to: SetBrightness.self)
            }
            if let reg = dlsym(handle, "DisplayServicesRegisterForBrightnessChangeNotifications") {
                let registerFn = unsafeBitCast(reg, to: RegisterNotifications.self)
                _ = registerFn({ (display, brightness, refcon) in
                    Task { @MainActor in
                        BrightnessService.shared.handleExternalBrightnessChange(Double(brightness))
                    }
                }, nil)
            }
        }
        refresh()
        isInitialized = true
    }

    public func handleExternalBrightnessChange(_ newBrightness: Double) {
        let clamped = min(max(newBrightness, 0), 1)
        guard isInitialized, abs(value - clamped) > 0.005 else { return }
        SystemOSDManager.suppressNativeOSDNow()
        value = clamped
        onBrightnessChanged?(clamped)
    }

    public func refresh() {
        guard let getBrightness else {
            isAvailable = false
            return
        }
        display = Self.findDisplay()
        var v: Float = 0
        isAvailable = (getBrightness(display, &v) == 0)
        if isAvailable { value = Double(v) }
    }

    public func set(_ fraction: Double) {
        guard let setBrightness else { return }
        if display == 0 {
            display = Self.findDisplay()
        }
        let clamped = min(max(fraction, 0), 1)
        _ = setBrightness(display, Float(clamped))
        value = clamped
        isAvailable = true
        onBrightnessChanged?(clamped)
    }

    public func step(up: Bool, fine: Bool = false) {
        if !isAvailable { refresh() }
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
