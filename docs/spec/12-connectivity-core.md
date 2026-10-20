# NETCORE — Connectivity Backend Architecture & Socket Protocol Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Core Go Server Connectivity Managers (`core/internal/server/network/`, 17.7k lines; `bluez/`, 2.3k lines; `cups/`, 2.4k lines; `tailscale/`, 615 lines; `pkg/ipp/`, 2.5k lines).

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `core/internal/server/network/handlers.go` | 480 | Network RPC request dispatcher and method router |
| `core/internal/server/network/manager.go` | 890 | Network state coordinator, adapter polling, interface monitor |
| `core/internal/server/network/nm.go` | 3,450 | NetworkManager D-Bus client implementation |
| `core/internal/server/network/iwd.go` | 2,100 | iwd (Intel Wireless Daemon) backend implementation |
| `core/internal/server/network/vpn.go` | 1,820 | WireGuard and OpenVPN connection manager |
| `core/internal/server/network/modem.go` | 1,450 | ModemManager cellular / 4G / 5G backend |
| `core/internal/server/bluez/handlers.go` | 280 | Bluetooth BlueZ RPC request dispatcher |
| `core/internal/server/bluez/manager.go` | 650 | BlueZ device cache, discovery session, pairing agent |
| `core/internal/server/cups/handlers.go` | 240 | CUPS printing RPC request dispatcher |
| `core/internal/server/cups/manager.go` | 520 | CUPS daemon socket client, printer status poller |
| `core/internal/server/tailscale/manager.go` | 380 | Tailscale local API client |
| `core/pkg/ipp/` | 2,503 | Pure Go Internet Printing Protocol (IPP) client implementation |

---

## 1. Socket API Method Matrix

The core backend exposes a unified JSON-RPC protocol over `dms.sock`:

### 1.1. Network Methods (`network.*`)
| Method Name | Request Parameters | Response Payload |
| :--- | :--- | :--- |
| `network.getState` | `{}` | `{ "status": "connected", "primary": "wifi", "wifi": {...}, "ethernet": {...} }` |
| `network.wifi.scan` | `{ "force": bool }` | `{ "scanning": true }` (followed by async event stream) |
| `network.wifi.networks` | `{}` | `[ { "ssid": string, "bssid": string, "rssi": int, "security": string } ]` |
| `network.wifi.connect` | `{ "ssid": string, "password": string, "hidden": bool }` | `{ "success": bool, "message": string }` |
| `network.wifi.disconnect`| `{}` | `{ "success": bool }` |
| `network.wifi.forget` | `{ "ssid": string }` | `{ "success": bool }` |
| `network.wifi.toggle` | `{}` | `{ "enabled": bool }` |
| `network.ethernet.connect` | `{ "uuid": string }` | `{ "success": bool }` |
| `network.cellular.toggle`| `{}` | `{ "enabled": bool }` |
| `network.generate-qrcode`| `{ "ssid": string, "password": string, "security": string }` | `{ "qrSvg": string, "qrAscii": string }` |

### 1.2. Bluetooth Methods (`bluetooth.*`)
| Method Name | Request Parameters | Response Payload |
| :--- | :--- | :--- |
| `bluetooth.getState` | `{}` | `{ "powered": bool, "discovering": bool, "devices": [...] }` |
| `bluetooth.startDiscovery` | `{}` | `{ "success": bool }` |
| `bluetooth.stopDiscovery` | `{}` | `{ "success": bool }` |
| `bluetooth.togglePowered` | `{}` | `{ "powered": bool }` |
| `bluetooth.pair` | `{ "address": string }` | `{ "pairing": true }` |
| `bluetooth.connect` | `{ "address": string }` | `{ "success": bool }` |
| `bluetooth.disconnect` | `{ "address": string }` | `{ "success": bool }` |
| `bluetooth.remove` | `{ "address": string }` | `{ "success": bool }` |
| `bluetooth.pairing.submit`| `{ "address": string, "pin": string }` | `{ "success": bool }` |

### 1.3. CUPS Printing Methods (`cups.*`)
| Method Name | Request Parameters | Response Payload |
| :--- | :--- | :--- |
| `cups.getPrinters` | `{}` | `[ { "name": string, "state": "idle"|"printing"|"stopped", "uri": string } ]` |
| `cups.getJobs` | `{ "printer": string }` | `[ { "id": int, "title": string, "user": string, "state": string } ]` |
| `cups.cancelJob` | `{ "jobId": int }` | `{ "success": bool }` |
| `cups.pausePrinter` | `{ "printer": string }` | `{ "success": bool }` |
| `cups.resumePrinter` | `{ "printer": string }` | `{ "success": bool }` |

---

## 2. Event Subscription Streaming

Clients subscribe to live event streams using `{ "method": "<subsystem>.subscribe" }`:
- `network.event`: Broadcasts on IP changes, link down, or Wi-Fi AP scan updates.
- `bluetooth.event`: Broadcasts when RSSI changes, devices connect/disconnect, or pairing pin is requested.
- `cups.event`: Broadcasts on print job progress or printer state changes.

---

## 3. macOS Native Architecture Mapping

In the macOS edition, these 22,000+ lines of Linux D-Bus client code are replaced by a **Swift Actor-Based Service Hub**:
```swift
public actor ServiceHub {
    public let wifi = WiFiServiceActor()
    public let bluetooth = BluetoothServiceActor()
    public let print = CupsServiceActor()
    public let tailscale = TailscaleServiceActor()
}
```
All RPC method names (`network.wifi.scan`, `bluetooth.connect`, etc.) must remain supported on `dms.sock` so that external CLI scripts and plugins function identically.

---

## 4. Port Audit & Checklist

- Current Port: Does not implement the socket RPC router for connectivity; only has simple CLI commands (`dms wifi status`).
- Checklist:
  - [ ] Implement `ConnectivityRPCRouter.swift` handling all `network.*`, `bluetooth.*`, and `cups.*` methods on `IPCSocketServer`.
  - [ ] Expose Wi-Fi QR code generator using `CoreImage` (`CIQRCodeGenerator`).
