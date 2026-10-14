import Darwin
import Observation

/// Bluetooth power state through IOBluetooth private preferences.
@MainActor
@Observable
public final class BluetoothService {
    public static let shared = BluetoothService()

    private typealias GetPower = @convention(c) () -> Int32
    private typealias SetPower = @convention(c) (Int32) -> Int32

    public private(set) var isOn = false
    public let isAvailable: Bool

    @ObservationIgnored private var getPower: GetPower?
    @ObservationIgnored private var setPower: SetPower?

    private init() {
        let handle = dlopen("/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth", RTLD_LAZY)
        if let handle,
           let get = dlsym(handle, "IOBluetoothPreferenceGetControllerPowerState"),
           let set = dlsym(handle, "IOBluetoothPreferenceSetControllerPowerState") {
            getPower = unsafeBitCast(get, to: GetPower.self)
            setPower = unsafeBitCast(set, to: SetPower.self)
        }
        isAvailable = getPower != nil && setPower != nil
        refresh()
    }

    public func refresh() {
        isOn = (getPower?() ?? 0) != 0
    }

    public func toggle() {
        guard let setPower else { return }
        _ = setPower(isOn ? 0 : 1)
        isOn.toggle()
        Task {
            try? await Task.sleep(for: .seconds(1))
            refresh()
        }
    }
}
