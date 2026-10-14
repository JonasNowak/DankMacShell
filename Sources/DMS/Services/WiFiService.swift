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

    public func refresh() {
        let interface = client.interface()
        isPowerOn = interface?.powerOn() ?? false
        ssid = isPowerOn ? interface?.ssid() : nil
        isConnected = isPowerOn && (ssid != nil || (interface?.rssiValue() ?? 0) != 0)
    }

    public func togglePower() {
        try? client.interface()?.setPower(!isPowerOn)
        refresh()
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
