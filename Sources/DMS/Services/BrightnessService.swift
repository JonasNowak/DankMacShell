import CoreGraphics
import Darwin
import Observation

/// Built-in display brightness through the private DisplayServices framework.
@MainActor
@Observable
public final class BrightnessService {
    public static let shared = BrightnessService()

    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32

    public private(set) var value: Double = 0
    public private(set) var isAvailable = false

    @ObservationIgnored private var getBrightness: GetBrightness?
    @ObservationIgnored private var setBrightness: SetBrightness?
    @ObservationIgnored private var display: CGDirectDisplayID = 0

    public var onBrightnessChanged: ((Double) -> Void)?

    private init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        if let handle = dlopen(path, RTLD_LAZY),
           let get = dlsym(handle, "DisplayServicesGetBrightness"),
           let set = dlsym(handle, "DisplayServicesSetBrightness") {
            getBrightness = unsafeBitCast(get, to: GetBrightness.self)
            setBrightness = unsafeBitCast(set, to: SetBrightness.self)
        }
        refresh()
    }

    public func refresh() {
        guard let getBrightness, let builtIn = Self.builtInDisplay() else {
            isAvailable = false
            return
        }
        display = builtIn
        var v: Float = 0
        isAvailable = getBrightness(builtIn, &v) == 0
        if isAvailable { value = Double(v) }
    }

    public func set(_ fraction: Double) {
        guard isAvailable, let setBrightness else { return }
        let clamped = min(max(fraction, 0), 1)
        _ = setBrightness(display, Float(clamped))
        value = clamped
        onBrightnessChanged?(clamped)
    }

    private static func builtInDisplay() -> CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }
}
