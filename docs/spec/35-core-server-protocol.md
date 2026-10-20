# 35 — Core Server & IPC Protocol Specification (`CORE`)

## 0. Coverage Manifest
- `core/internal/server/server.go` (1,220 lines) — Master IPC daemon engine, Unix domain socket listener (`/run/user/$UID/dms.sock`), non-blocking connection pool, client session tracker, and graceful shutdown signal handler.
- `core/internal/server/router.go` (340 lines) — Path-based request router (`router.HandleFunc("/api/v1/...", handler)`), request parameter parsing, structured error responses, and audit logging middleware.
- `core/internal/server/subscription.go` (632 lines) & `subscribe_test.go` (180 lines) — Pub/sub event broker supporting continuous event streams over persistent socket connections (`"subscribe:events.audio"`, `"subscribe:events.workspaces"`, `"subscribe:events.battery"`).
- `core/internal/server/bluez/*` (14 files, 1,480 lines) — Bluetooth subsystem: device scanning, RSSI tracking, pairing authentication, battery level reporting, and audio codec selection.
- `core/internal/server/network/*` (68 files, 7,200 lines) — Network management: Wi-Fi scanning (WPA/WPA2/WPA3), Ethernet link monitoring, cellular modems, VPN profile activation (WireGuard/OpenVPN), and Wi-Fi QR encoding.
- `core/internal/server/brightness/*` (20 files, 2,100 lines) — Backlight brightness control (sysfs backlight and DDC/CI I2C protocol for external monitors).
- `core/internal/server/clipboard/*` (6 files, 4,050 lines) — Clipboard manager daemon with `bbolt` database persistence, MIME handling, image thumbnailing, and self-destruct timers.
- `core/internal/server/cups/*` (17 files, 1,850 lines) — CUPS printing architecture: printer discovery, queue status, paper/ink levels, and print job dispatch.
- `core/internal/server/lyrics/*` (3 files, 420 lines) — Synchronized lyrics engine: LRC format parser, millisecond-accurate timestamp alignment, and remote lyrics search (LRCLIB, NetEase).
- `core/internal/server/tailscale/*` (9 files, 890 lines) — Tailscale mesh network client: node status, IP display, exit node toggles, and peer availability.
- `core/internal/server/wellbeing/*` (7 files, 740 lines) — Digital wellbeing tracker: active foreground window sampler, daily screen time aggregator, and app quota alerts.
- `core/internal/server/sysupdate/*` (35 files, 3,400 lines) — Package manager abstraction layer (pacman, dnf, apt, apk, nix).

---

## 1. Purpose & User-Visible Behavior
The DMS Core Server is the unified headless background daemon that abstracts hardware, manages persistent databases, coordinates OS-level events, and provides a centralized IPC bus for all shell frontends (QML/SwiftUI), CLI tools, and external scripts.

Key user-visible behaviors include:
1. **Zero-Latency Reactive Subscriptions**:
   - Instead of polling hardware or state in loops, frontends subscribe to event channels over a single persistent socket connection.
   - Updates (volume changes, Wi-Fi reconnects, battery percent drops) are pushed immediately in under 1 millisecond.
2. **Unified Hardware Abstraction**:
   - Single API for controlling internal display backlights and external DDC/CI monitors alike.
   - Abstracted network management seamlessly transitioning between Wi-Fi, Ethernet, and cellular.
3. **Ambient Background Services**:
   - Synchronized lyrics fetched and aligned automatically in the background while music plays.
   - Digital wellbeing logs window focus without impacting system performance or draining battery.

---

## 2. IPC Wire Protocol & Framing
The server supports two protocols over the Unix domain socket:

### A. Line-Oriented Text / JSON Protocol (Lightweight CLI)
- **Request Format**: Single line terminated by `\n`:
  `<METHOD> <PATH> [JSON_PAYLOAD]\n`
  - Example: `GET /api/v1/audio/status\n`
  - Example: `POST /api/v1/clipboard/copy {"text":"hello world"}\n`
- **Response Format**: Single JSON line terminated by `\n`:
  `{"status":"ok","data":{...}}\n` or `{"status":"error","message":"..."}\n`

### B. Streaming / Event Subscription Protocol
- **Request**: `SUBSCRIBE <EVENT_TOPIC>\n`
  - Example: `SUBSCRIBE events.workspaces\n`
- **Stream Frame**: Continuous JSON lines:
  `{"event":"workspace_changed","activeId":2,"windows":[...]}\n`
  `{"event":"workspace_changed","activeId":3,"windows":[...]}\n`

---

## 3. Core Server Subsystems & Route Map
| Route Path | Method | Description |
|---|---|---|
| `/api/v1/audio/volume` | `GET` / `POST` | Query or adjust master audio volume |
| `/api/v1/audio/sinks` | `GET` / `POST` | List output sinks or switch default sink |
| `/api/v1/network/wifi/scan` | `GET` | Initiate wireless network scan |
| `/api/v1/network/wifi/connect`| `POST` | Connect to SSID with credentials |
| `/api/v1/bluetooth/devices` | `GET` | List paired and discovered Bluetooth devices |
| `/api/v1/brightness/set` | `POST` | Adjust display backlight or DDC/CI level |
| `/api/v1/clipboard/history` | `GET` | Query paginated clipboard history |
| `/api/v1/lyrics/current` | `GET` | Get synchronized LRC lyrics for active media |
| `/api/v1/wellbeing/summary` | `GET` | Fetch daily application screen time stats |
| `/api/v1/tailscale/status` | `GET` | Query Tailscale network peer status |

---

## 4. Configuration Schema
Server configurations are stored in `SettingsData`:
- `server.socketPath`: Path to Unix socket (`~/Library/Application Support/DMS/dms.sock`).
- `server.maxConnections`: Max concurrent socket clients (default: 64).
- `server.workerPoolSize`: Goroutine / Swift Task worker pool size (default: 16).

---

## 5. macOS Mapping
- **Socket Implementation**:
  - `Network.framework` `NWListener` with `.unix` endpoint or BSD sockets (`socket(AF_UNIX, SOCK_STREAM, 0)`).
  - Background dispatch queue with async non-blocking `select()` or `DispatchSourceRead`.
- **Subsystem Bridges in macOS**:
  - Audio: `CoreAudio` AudioHardware APIs.
  - Network: `CoreWLAN` (`CWWiFiClient`) & `Network.framework` `NWPathMonitor`.
  - Bluetooth: `IOBluetooth` framework (`IOBluetoothDevice`, `IOBluetoothHostController`).
  - Brightness: `DisplayServices` (`DisplayServicesSetBrightness`) & `DDC.swift` for external I2C monitors.
  - Wellbeing: `NSWorkspace.shared.frontmostApplication` tracking.
  - Lyrics: Built-in Swift LRC parser querying LRCLIB REST API.

---

## 6. Port Audit
| Upstream File / Subsystem | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `subscription.go` (Pub/Sub Event Broker) | Absent | **Missing (0%)** | Port's `IPCSocketServer.swift` only supports one-shot command-response. It has ZERO event streaming or subscribe capabilities. |
| `router.go` (URL path-based router) | Absent | **Missing (0%)** | Port uses a rigid `switch` statement on raw strings in `IPCCommandExecutor.swift` without path routing or middleware. |
| `lyrics/` (Synchronized LRC lyrics engine) | Absent | **Missing (0%)** | Zero lyrics parsing, timing synchronization, or LRCLIB fetching in port. |
| `cups/`, `tailscale/`, `sysupdate/` | Absent | **Missing (0%)** | All auxiliary hardware and maintenance daemon modules are completely missing. |

---

## 7. Reimplementation Checklist
- [ ] Upgrade `IPCSocketServer` to support multi-client persistent socket connections.
- [ ] Implement `EventSubscriptionBroker` enabling clients to subscribe to live system event streams (`events.audio`, `events.workspaces`, etc.).
- [ ] Implement URL path-based router (`/api/v1/...`) with JSON request/response encoding.
- [ ] Implement `LyricsService` with real-time LRC file parsing and LRCLIB REST API client.
- [ ] Implement `TailscaleService` monitoring local `tailscale status --json` output.
- [ ] Implement external monitor DDC/CI brightness control using I2C frame transmission.
