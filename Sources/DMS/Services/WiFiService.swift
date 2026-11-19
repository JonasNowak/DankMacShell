import CoreWLAN
import CoreLocation
import Observation

/// Wi-Fi power and connection state through CoreWLAN events.
@MainActor
@Observable
public final class WiFiService: NSObject, CWEventDelegate, CLLocationManagerDelegate {
    public static let shared = WiFiService()

    public private(set) var isPowerOn = false
    public private(set) var isConnected = false
    public private(set) var ssid: String?
    /// False until CoreLocation authorization is granted — on macOS 14.4+ CoreWLAN redacts
    /// ssid()/scanForNetworks to nil/empty without it.
    public private(set) var locationAuthorized = false
    /// Latest scan results, updated by the background scan task.
    public private(set) var lastScannedNetworks: [ScannedNetwork] = []
    public private(set) var isScanningNetworks = false

    @ObservationIgnored private let client = CWWiFiClient.shared()
    @ObservationIgnored private var locationManager: CLLocationManager?
    @ObservationIgnored private var scanTask: Task<Void, Never>?

    private override init() {
        super.init()
        client.delegate = self
        for event in [CWEventType.powerDidChange, .ssidDidChange, .linkDidChange] {
            try? client.startMonitoringEvent(with: event)
        }
        requestLocationAuthorizationIfNeeded()
        refresh()
    }

    /// Requests CoreLocation authorization if needed so CoreWLAN can report SSIDs on macOS 14.4+.
    public func requestLocationAuthorizationIfNeeded() {
        let manager = CLLocationManager()
        locationManager = manager
        manager.delegate = self
        let status = manager.authorizationStatus
        locationAuthorized = Self.isAuthorized(status)
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    private nonisolated static func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        // On macOS the "when in use" equivalent is `.authorized`.
        status == .authorizedAlways || status == .authorized
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            WiFiService.shared.locationAuthorized = Self.isAuthorized(status)
            WiFiService.shared.refresh()
        }
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

    /// Kicks off a background scan and returns the most recent cached results immediately, so
    /// synchronous callers (ControlCenter, IPCSocketServer) keep compiling and never block the
    /// main actor on the CoreWLAN scan.
    public func scanNetworks() -> [ScannedNetwork] {
        startBackgroundScan()
        return lastScannedNetworks
    }

    /// Awaits a fresh background scan and returns its results.
    public func scanNetworksAsync() async -> [ScannedNetwork] {
        await startBackgroundScanAsync()
        return lastScannedNetworks
    }

    private func startBackgroundScan() {
        guard scanTask == nil else { return }
        isScanningNetworks = true
        scanTask = Task.detached { [weak self] in
            let results = Self.performScan()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.lastScannedNetworks = results
                self.isScanningNetworks = false
                self.scanTask = nil
            }
        }
    }

    private func startBackgroundScanAsync() async {
        if let scanTask { await scanTask.value; return }
        isScanningNetworks = true
        let task = Task.detached { [weak self] in
            let results = Self.performScan()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.lastScannedNetworks = results
                self.isScanningNetworks = false
                self.scanTask = nil
            }
        }
        scanTask = task
        await task.value
    }

    /// Blocking CoreWLAN scan — must only run off the main actor.
    private nonisolated static func performScan() -> [ScannedNetwork] {
        let client = CWWiFiClient.shared()
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
        // scanForNetworks + associate block — run them off the main actor.
        Task.detached { [weak self] in
            let client = CWWiFiClient.shared()
            guard let interface = client.interface() else { return }
            let networks = (try? interface.scanForNetworks(withName: networkSSID)) ?? []
            if let target = networks.first {
                try? interface.associate(to: target, password: password)
            }
            Task { @MainActor in
                self?.refresh()
            }
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
