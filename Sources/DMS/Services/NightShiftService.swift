import Darwin
import Foundation
import ObjectiveC
import Observation

/// Night Shift control via private CoreBrightness CBBlueLightClient.
@MainActor
@Observable
public final class NightShiftService {
    public static let shared = NightShiftService()

    public private(set) var isOn = false
    public let isAvailable: Bool

    @ObservationIgnored private let client: NSObject?

    private typealias SetEnabled = @convention(c) (AnyObject, Selector, Bool) -> Bool
    private typealias GetStatus = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool

    private static let setEnabledSelector = NSSelectorFromString("setEnabled:")
    private static let statusSelector = NSSelectorFromString("getBlueLightStatus:")

    private init() {
        _ = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY)
        let made = (NSClassFromString("CBBlueLightClient") as? NSObject.Type)?.init()
        let usable = made?.responds(to: Self.setEnabledSelector) == true
            && made?.responds(to: Self.statusSelector) == true
        client = usable ? made : nil
        isAvailable = usable
        refresh()
    }

    public func refresh() {
        guard let client,
              let imp = class_getMethodImplementation(type(of: client), Self.statusSelector) else { return }
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: 128, alignment: 16)
        defer { buffer.deallocate() }
        buffer.initializeMemory(as: UInt8.self, repeating: 0, count: 128)
        let getStatus = unsafeBitCast(imp, to: GetStatus.self)
        if getStatus(client, Self.statusSelector, buffer) {
            isOn = buffer.load(as: UInt8.self) != 0
        }
    }

    public func toggle() {
        guard let client,
              let imp = class_getMethodImplementation(type(of: client), Self.setEnabledSelector) else { return }
        let setEnabled = unsafeBitCast(imp, to: SetEnabled.self)
        if setEnabled(client, Self.setEnabledSelector, !isOn) { isOn.toggle() }
    }
}
