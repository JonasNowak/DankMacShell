import Foundation
import Darwin
import ObjectiveC
import Observation

/// Bluetooth power state through IOBluetooth private preferences.
@MainActor
@Observable
public final class BluetoothService {
    public static let shared = BluetoothService()

    private typealias GetPower = @convention(c) () -> Int32
    private typealias SetPower = @convention(c) (Int32) -> Int32
    // Typed IMPs for primitive-returning IOBluetoothDevice selectors (verified via the ObjC
    // runtime: isConnected -> BOOL 'B', openConnection/closeConnection -> IOReturn 'i',
    // batteryPercentSingle -> unsigned char 'C'). NSObject.perform(_:) on these returns an
    // Unmanaged whose opaque pointer is the raw return value reinterpreted as an object — UB.
    private typealias IsConnectedIMP = @convention(c) (AnyObject, Selector) -> Bool
    private typealias OpenConnectionIMP = @convention(c) (AnyObject, Selector) -> Int32
    private typealias CloseConnectionIMP = @convention(c) (AnyObject, Selector) -> Int32
    private typealias BatteryPercentSingleIMP = @convention(c) (AnyObject, Selector) -> UInt8

    private nonisolated static let isConnectedSelector = NSSelectorFromString("isConnected")
    private nonisolated static let openConnectionSelector = NSSelectorFromString("openConnection")
    private nonisolated static let closeConnectionSelector = NSSelectorFromString("closeConnection")
    private nonisolated static let batteryPercentSingleSelector = NSSelectorFromString("batteryPercentSingle")

    public private(set) var isOn = false
    public private(set) var connectedDevicesSummary: String = "Off"
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
        // Cache the summary as a published property so SwiftUI renders never run ObjC
        // reflection per frame.
        guard isOn else {
            connectedDevicesSummary = "Off"
            return
        }
        let connected = pairedDevices().filter { $0.isConnected }
        if connected.isEmpty {
            connectedDevicesSummary = "No devices"
        } else if connected.count == 1 {
            connectedDevicesSummary = connected[0].name
        } else {
            connectedDevicesSummary = "\(connected.count) connected"
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
            if dev.responds(to: Self.isConnectedSelector),
               let imp = class_getMethodImplementation(type(of: dev), Self.isConnectedSelector) {
                let fn = unsafeBitCast(imp, to: IsConnectedIMP.self)
                isConn = fn(dev, Self.isConnectedSelector)
            }

            var battery: Int? = nil
            if dev.responds(to: Self.batteryPercentSingleSelector),
               let imp = class_getMethodImplementation(type(of: dev), Self.batteryPercentSingleSelector) {
                let fn = unsafeBitCast(imp, to: BatteryPercentSingleIMP.self)
                let raw = fn(dev, Self.batteryPercentSingleSelector)
                let pct = Int(raw)
                if pct > 0 && pct <= 100 {
                    battery = pct
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
        guard let dev = Self.device(withAddress: address),
              dev.responds(to: Self.openConnectionSelector),
              let imp = class_getMethodImplementation(type(of: dev), Self.openConnectionSelector) else { return }
        let fn = unsafeBitCast(imp, to: OpenConnectionIMP.self)
        // openConnection blocks while pairing/connecting — run it off the main actor.
        Task.detached { [weak dev] in
            guard let dev else { return }
            _ = fn(dev, Self.openConnectionSelector)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                BluetoothService.shared.refresh()
            }
        }
    }

    public func disconnectDevice(address: String) {
        guard let dev = Self.device(withAddress: address),
              dev.responds(to: Self.closeConnectionSelector),
              let imp = class_getMethodImplementation(type(of: dev), Self.closeConnectionSelector) else { return }
        let fn = unsafeBitCast(imp, to: CloseConnectionIMP.self)
        Task.detached { [weak dev] in
            guard let dev else { return }
            _ = fn(dev, Self.closeConnectionSelector)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                BluetoothService.shared.refresh()
            }
        }
    }

    private static func device(withAddress address: String) -> NSObject? {
        guard let deviceClass = NSClassFromString("IOBluetoothDevice") as? NSObject.Type else { return nil }
        let withAddrSel = NSSelectorFromString("deviceWithAddressString:")
        guard deviceClass.responds(to: withAddrSel),
              let dev = deviceClass.perform(withAddrSel, with: address)?.takeUnretainedValue() as? NSObject else { return nil }
        return dev
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
