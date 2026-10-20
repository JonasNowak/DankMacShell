import Foundation
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

    public var connectedDevicesSummary: String {
        guard isOn else { return "Off" }
        let connected = pairedDevices().filter { $0.isConnected }
        if connected.isEmpty {
            return "No devices"
        } else if connected.count == 1 {
            return connected[0].name
        } else {
            return "\(connected.count) connected"
        }
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

    public func pairedDevices() -> [BluetoothDeviceInfo] {
        guard let deviceClass = NSClassFromString("IOBluetoothDevice") as? NSObject.Type else { return [] }
        let selector = NSSelectorFromString("pairedDevices")
        guard deviceClass.responds(to: selector),
              let devices = deviceClass.perform(selector)?.takeUnretainedValue() as? [NSObject] else { return [] }

        var result: [BluetoothDeviceInfo] = []
        for dev in devices {
            let name = (dev.perform(NSSelectorFromString("name"))?.takeUnretainedValue() as? String) ?? "Bluetooth Device"
            let addr = (dev.perform(NSSelectorFromString("addressString"))?.takeUnretainedValue() as? String) ?? UUID().uuidString

            var isConn = false
            let isConnectedSel = NSSelectorFromString("isConnected")
            if dev.responds(to: isConnectedSel) {
                if let unmanaged = dev.perform(isConnectedSel) {
                    let ptr = unmanaged.toOpaque()
                    isConn = ptr != UnsafeMutableRawPointer(bitPattern: 0)
                }
            }

            var battery: Int? = nil
            let batterySel = NSSelectorFromString("batteryPercentSingle")
            if dev.responds(to: batterySel) {
                if let val = dev.perform(batterySel) {
                    let intVal = Int(bitPattern: val.toOpaque())
                    if intVal > 0 && intVal <= 100 {
                        battery = intVal
                    }
                }
            }

            result.append(BluetoothDeviceInfo(
                id: addr,
                name: name,
                isConnected: isConn,
                batteryLevel: battery
            ))
        }
        return result
    }

    public func connectDevice(address: String) {
        guard let deviceClass = NSClassFromString("IOBluetoothDevice") as? NSObject.Type else { return }
        let withAddrSel = NSSelectorFromString("deviceWithAddressString:")
        guard deviceClass.responds(to: withAddrSel),
              let dev = deviceClass.perform(withAddrSel, with: address)?.takeUnretainedValue() as? NSObject else { return }
        let openSel = NSSelectorFromString("openConnection")
        if dev.responds(to: openSel) {
            _ = dev.perform(openSel)
        }
    }

    public func disconnectDevice(address: String) {
        guard let deviceClass = NSClassFromString("IOBluetoothDevice") as? NSObject.Type else { return }
        let withAddrSel = NSSelectorFromString("deviceWithAddressString:")
        guard deviceClass.responds(to: withAddrSel),
              let dev = deviceClass.perform(withAddrSel, with: address)?.takeUnretainedValue() as? NSObject else { return }
        let closeSel = NSSelectorFromString("closeConnection")
        if dev.responds(to: closeSel) {
            _ = dev.perform(closeSel)
        }
    }
}

public struct BluetoothDeviceInfo: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let isConnected: Bool
    public let batteryLevel: Int?

    public init(id: String, name: String, isConnected: Bool, batteryLevel: Int? = nil) {
        self.id = id
        self.name = name
        self.isConnected = isConnected
        self.batteryLevel = batteryLevel
    }
}
