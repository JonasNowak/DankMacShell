import Foundation
import IOKit.pwr_mgt

/// Manages system and display sleep inhibition (caffeinate).
@MainActor
public final class IdleInhibitService: ObservableObject {
    public static let shared = IdleInhibitService()

    @Published public private(set) var isInhibited: Bool = false
    private var assertionID: IOPMAssertionID = 0

    private init() {}

    public func toggle() {
        if isInhibited {
            disable()
        } else {
            enable()
        }
    }

    public func enable() {
        guard !isInhibited else { return }

        let reason = "DankMaterialShell Idle Inhibit" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        if result == kIOReturnSuccess {
            isInhibited = true
            ToastCenter.shared.show(icon: "cup.and.saucer.fill", message: "Sleep Inhibit: Enabled (Caffeinated)")
        }
    }

    public func disable() {
        guard isInhibited else { return }

        let result = IOPMAssertionRelease(assertionID)
        if result == kIOReturnSuccess {
            assertionID = 0
            isInhibited = false
            ToastCenter.shared.show(icon: "cup.and.saucer", message: "Sleep Inhibit: Disabled")
        }
    }
}
