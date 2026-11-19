import AppKit
import Darwin
import Foundation
import Observation
import SystemConfiguration

/// Detects active VPN connections via SystemConfiguration dynamic-store notifications plus a
/// getifaddrs sweep for utun/ppp/ipsec interfaces carrying non-link-local addresses.
@MainActor
public final class VPNService: ObservableObject {
    public static let shared = VPNService()

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var activeInterface: String?

    private var store: SCDynamicStore?
    private var runLoopSource: CFRunLoopSource?

    private init() {
        setupDynamicStoreNotifications()
        refresh()
    }

    private func setupDynamicStoreNotifications() {
        let callback: SCDynamicStoreCallBack = { _, _, _ in
            Task { @MainActor in
                VPNService.shared.refresh()
            }
        }
        var context = SCDynamicStoreContext()
        context.info = nil
        guard let store = SCDynamicStoreCreate(
            kCFAllocatorDefault,
            "DankMacShell.VPNService" as CFString,
            callback,
            &context
        ) else { return }
        self.store = store

        let patterns: CFArray = [
            "State:/Network/Global/IPv4",
            "State:/Network/Service/.*/PPP",
            "State:/Network/Service/.*/IPSec"
        ] as CFArray
        guard SCDynamicStoreSetNotificationKeys(store, nil, patterns) else { return }
        if let source = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, store, 0) {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }
    }

    /// Re-scans interfaces for an active VPN tunnel (utun/ppp/ipsec with a routable address).
    public func refresh() {
        let found = Self.findActiveVPNInterface()
        isConnected = found != nil
        activeInterface = found
    }

    public func openVPNSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Interface detection

    private nonisolated static func findActiveVPNInterface() -> String? {
        var ifaddrsPtr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddrsPtr) == 0, let ifaddrsPtr else { return nil }
        defer { freeifaddrs(ifaddrsPtr) }

        var current: UnsafeMutablePointer<ifaddrs>? = ifaddrsPtr
        while let addr = current {
            current = addr.pointee.ifa_next
            guard let name = addr.pointee.ifa_name else { continue }
            let interfaceName = String(cString: name)
            guard interfaceName.hasPrefix("utun")
                    || interfaceName.hasPrefix("ppp")
                    || interfaceName.hasPrefix("ipsec") else { continue }
            guard let sa = addr.pointee.ifa_addr else { continue }
            if sa.pointee.sa_family == AF_INET || sa.pointee.sa_family == AF_INET6 {
                if Self.isRoutableAddress(sa) {
                    return interfaceName
                }
            }
        }
        return nil
    }

    /// True for global IPv4/IPv6 addresses; filters out link-local (169.254.0.0/16, fe80::/10).
    private nonisolated static func isRoutableAddress(_ sa: UnsafePointer<sockaddr>) -> Bool {
        if sa.pointee.sa_family == AF_INET {
            let sin = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            let ip = UInt32(bigEndian: sin.sin_addr.s_addr)
            return (ip & 0xFFFF_0000) != 0xA9FE_0000 // not 169.254.0.0/16
        } else if sa.pointee.sa_family == AF_INET6 {
            let sin6 = sa.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
            let bytes = withUnsafeBytes(of: sin6.sin6_addr) { Array($0.prefix(2)) }
            // fe80::/10: first byte 0xfe and top two bits of the second byte set.
            return !(bytes.count >= 2 && bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80)
        }
        return false
    }
}
