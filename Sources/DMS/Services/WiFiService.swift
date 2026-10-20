import CoreWLAN
import Observation

/// Wi-Fi power and connection state through CoreWLAN events.
@MainActor
@Observable
public final class WiFiService: NSObject, CWEventDelegate {
    public static let shared = WiFiService()

    public private(set) var isPowerOn = false
    public private(set) var isConnected = false
    public private(set) var ssid: String?

    @ObservationIgnored private let client = CWWiFiClient.shared()

    private override init() {
        super.init()
        client.delegate = self
        for event in [CWEventType.powerDidChange, .ssidDidChange, .linkDidChange] {
            try? client.startMonitoringEvent(with: event)
        }
        refresh()
    }

    public var symbolName: String {
        if !isPowerOn { return "wifi.slash" }
        return isConnected ? "wifi" : "wifi.exclamationmark"
    }

    public var subtitle: String {
        if !isPowerOn { return "Off" }
        if let ssid { return ssid }
        return isConnected ? "Connected" : "Not connected"
    }

    public var currentRssiPercent: Int {
        guard let interface = client.interface(), isConnected else { return 0 }
        let rssi = interface.rssiValue()
        if rssi == 0 { return 0 }
        let clamped = max(-100, min(-50, rssi))
        return Int(Double(clamped + 100) / 50.0 * 100.0)
    }

    public func refresh() {
        let interface = client.interface()
        isPowerOn = interface?.powerOn() ?? false
        ssid = isPowerOn ? interface?.ssid() : nil
        isConnected = isPowerOn && (ssid != nil || (interface?.rssiValue() ?? 0) != 0)
        EventSubscriptionBroker.shared.broadcast(event: "events.wifi", payload: [
            "isPowerOn": isPowerOn,
            "isConnected": isConnected,
            "ssid": ssid ?? ""
        ])
    }

    public func togglePower() {
        try? client.interface()?.setPower(!isPowerOn)
        refresh()
    }

    public func scanNetworks() -> [ScannedNetwork] {
        guard let interface = client.interface(), interface.powerOn() else { return [] }
        let networks = (try? interface.scanForNetworks(withName: nil)) ?? []
        let currentBSSID = interface.bssid() ?? ""
        let currentSSID = interface.ssid() ?? ""
        var seenSSIDs = Set<String>()
        var result: [ScannedNetwork] = []

        for net in networks {
            guard let name = net.ssid, !name.isEmpty else { continue }
            if seenSSIDs.contains(name) { continue }
            seenSSIDs.insert(name)

            let isSec = net.supportsSecurity(.wpaPersonal) ||
                        net.supportsSecurity(.wpa2Personal) ||
                        net.supportsSecurity(.wpa3Personal) ||
                        net.supportsSecurity(.wpaEnterprise) ||
                        net.supportsSecurity(.wpa2Enterprise) ||
                        net.supportsSecurity(.wpa3Enterprise)
            let isCurr = (net.bssid == currentBSSID && !currentBSSID.isEmpty) || (name == currentSSID)

            result.append(ScannedNetwork(
                ssid: name,
                bssid: net.bssid ?? "",
                rssi: net.rssiValue,
                isSecure: isSec,
                isConnected: isCurr
            ))
        }

        return result.sorted {
            if $0.isConnected != $1.isConnected {
                return $0.isConnected
            }
            return $0.rssi > $1.rssi
        }
    }

    public func connect(to networkSSID: String, password: String?) {
        guard let interface = client.interface() else { return }
        let networks = (try? interface.scanForNetworks(withName: networkSSID)) ?? []
        if let target = networks.first {
            try? interface.associate(to: target, password: password)
            refresh()
        }
    }

    nonisolated public func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in WiFiService.shared.refresh() }
    }

    nonisolated public func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in WiFiService.shared.refresh() }
    }

    nonisolated public func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in WiFiService.shared.refresh() }
    }
}

public struct ScannedNetwork: Identifiable, Sendable, Equatable {
    public var id: String { bssid.isEmpty ? ssid : bssid }
    public let ssid: String
    public let bssid: String
    public let rssi: Int
    public let isSecure: Bool
    public let isConnected: Bool

    public var signalBars: Int {
        if rssi >= -60 { return 4 }
        if rssi >= -70 { return 3 }
        if rssi >= -80 { return 2 }
        return 1
    }
}
