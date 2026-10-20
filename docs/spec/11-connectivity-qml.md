# NET — Connectivity QML Services & UI Logic Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Network Services (`NetworkService.qml`, `DMSNetworkService.qml`, 1,374 lines), Bluetooth (`BluetoothService.qml`, 1,035 lines), VPN Management (`VPNService.qml`), CUPS Printers (`CupsService.qml`), Tailscale Mesh (`TailscaleService.qml`), and Connectivity Bar/Popout UI Components.

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `quickshell/Services/DMSNetworkService.qml` | 1,374 | Primary network client (Wi-Fi scanning, security protocols, Ethernet, Cellular) |
| `quickshell/Services/NetworkService.qml` | 401 | Legacy network provider adapter and connection status mapper |
| `quickshell/Services/BluetoothService.qml` | 1,035 | Bluetooth adapter, discovery, pairing flows, device battery, codec switching |
| `quickshell/Services/VPNService.qml` | 250 | VPN active state, WireGuard / OpenVPN profile list, connection triggers |
| `quickshell/Services/TailscaleService.qml` | 239 | Tailscale daemon state, exit nodes, peer machine list |
| `quickshell/Services/CupsService.qml` | 746 | CUPS print queue monitor, printer states, job cancellations |
| `quickshell/Modules/DBar/Widgets/Vpn.qml` | 85 | DankBar VPN status pill and popout button |
| `quickshell/Modules/DBar/Widgets/NetworkMonitor.qml` | 120 | DankBar live upload/download bandwidth speed monitor |
| `quickshell/Modules/DBar/Popouts/VpnPopout.qml` | 140 | Quick VPN profile connection popout sheet |
| `quickshell/Modules/Network/WifiConnectionActions.qml` | 195 | Wi-Fi password prompt, WPA2/WPA3 enterprise dialog |

---

## 1. Purpose & User-Visible Behavior

1. **Wi-Fi Connectivity**:
   - Real-time Wi-Fi network scanning with signal strength RSSI icons (0 to 4 bars).
   - Saved network auto-connection and forget actions.
   - Secure passphrase modal (`WifiConnectionActions.qml`) with security type detection (WPA-PSK, WPA2, WPA3, WEP, Open).
2. **Bluetooth Hub**:
   - Device discovery with active scanning timer.
   - Categorized device lists: Paired vs. Available.
   - Device icons automatically mapped by class (Headphones, Speaker, Keyboard, Mouse, Phone, Watch).
   - Live battery percentage indicators for connected Bluetooth peripherals.
   - Advanced: Bluetooth audio codec selector (LDAC, aptX HD, AAC, SBC).
3. **VPN & Tailscale**:
   - One-click toggle for WireGuard and OpenVPN tunnels.
   - Tailscale node browser with exit node selection.
4. **CUPS Printing Hub**:
   - Displays all configured local and network printers with status (`idle`, `printing`, `stopped`).
   - Active print job list with pause/resume and cancel buttons.

---

## 2. Detailed Requirements

### 2.1. Wi-Fi & Network Engine (`DMSNetworkService.qml`)
- `NET-001`: Network interface prioritization:
  - If Ethernet is connected, primary indicator displays Ethernet icon and suppresses Wi-Fi warnings.
  - If Wi-Fi is active, signal quality maps: $\ge 80\% \to 4\text{ bars}$, $\ge 60\% \to 3\text{ bars}$, $\ge 40\% \to 2\text{ bars}$, $\ge 20\% \to 1\text{ bar}$, $< 20\% \to \text{dot}$.
- `NET-002`: Wi-Fi scanning: Scans run when opening the Control Center network detail page, refreshing every 10 seconds while open, and shutting off when closed to preserve battery.

### 2.2. Bluetooth Engine (`BluetoothService.qml`)
- `NET-003`: Device state tracking: `connected`, `connecting`, `paired`, `trusted`, `blocked`.
- `NET-004`: Device icon resolution:
  - Audio: `headset` / `speaker`
  - Input: `keyboard` / `mouse`
  - Mobile: `smartphone`
  - Fallback: `bluetooth`

---

## 3. Wayland/Linux Mechanisms → macOS Mapping

1. **NetworkManager / iwd D-Bus API**:
   - Upstream talks to NetworkManager over D-Bus.
   - **macOS Approach**: Use `CoreWLAN` framework:
     - Wi-Fi Interface: `CWWiFiClient.shared().interface()`.
     - Power: `interface.setPower(bool)`.
     - Scan: `try interface.scanForNetworks(withName: nil)`.
     - Associate: `try interface.associate(to: network, password: pass)`.
     - Events: Implement `CWEventDelegate` for SSID/BSSID and link changes.
     - Ethernet: Query `SCDynamicStoreCopyValue` under key `State:/Network/Global/IPv4`.
2. **BlueZ D-Bus API**:
   - Upstream talks to BlueZ over D-Bus.
   - **macOS Approach**: Use `IOBluetooth` and `CoreBluetooth`:
     - Device list: `IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]`.
     - Connection: `device.openConnection()`, `device.closeConnection()`.
     - Power: Private `IOBluetoothPreferences` or AppleScript.
3. **CUPS Printing**:
   - Linux uses CUPS via HTTP socket `/run/cups/cups.sock`.
   - **macOS Approach**: macOS runs native CUPS! Connect directly to local CUPS C API (`#include <cups/cups.h>`) or `cupsGetDests()`.
4. **Tailscale**:
   - Upstream communicates with `tailscaled` local socket.
   - **macOS Approach**: Execute `/Applications/Tailscale.app/Contents/MacOS/Tailscale status --json` or query Tailscale local API `http://local-tailscaled.sock`.

---

## 4. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| `NET-001` - `002` | **Partial** | `WiFiService.swift` (59 lines) | Only reads current SSID and power state via CoreWLAN. **Lacks Wi-Fi network scanning, scan results model, connect dialogs, and Ethernet handling.** |
| `NET-003` - `004` | **Partial** | `BluetoothService.swift` (44 lines) | Only toggles power. **Lacks device discovery, paired device list, battery percentages, and device connection actions.** |
| VPN & Tailscale | **Missing** | None | Completely absent. |
| CUPS Printers | **Missing** | None | Completely absent. |

### Audit Verdict:
The port contains only **stub services** for Wi-Fi and Bluetooth (~50 lines each) that read basic power states. Network scanning, connection dialogs, peripheral device lists, VPN, and printing are completely missing. Parity: **~10%**.

---

## 5. Reimplementation Checklist

- [ ] Rewrite `WiFiService.swift` to scan for SSIDs, report RSSI levels, and handle WPA password connections.
- [ ] Rewrite `BluetoothService.swift` using `IOBluetoothDevice` to enumerate paired devices with battery percentages and connection triggers.
- [ ] Implement `CupsService.swift` wrapping macOS `libcups` for printer queues.
- [ ] Implement `TailscaleService.swift` parsing local daemon JSON status.
