# 33 — Settings UI Part C: Audio, Network, Power, Keybinds, Lock & System Specification (`SET-C`)

## 0. Coverage Manifest
- `quickshell/Modules/Settings/AudioTab.qml` (525 lines) & `SoundsTab.qml` (146 lines) — Audio output sinks, default input microphones, volume limits, UI sound effects pack selector, per-app audio stream mixer.
- `quickshell/Modules/Settings/NetworkWifiTab.qml` (968 lines), `NetworkEthernetTab.qml` (364 lines), `NetworkCellularTab.qml` (293 lines), `NetworkVpnTab.qml` (137 lines), `NetworkStatusTab.qml` (175 lines) — Network configuration: Wi-Fi network scanner, known network profiles, static IP/DNS settings, VPN profiles (WireGuard, OpenVPN), and real-time interface telemetry.
- `quickshell/Modules/Settings/PowerSleepTab.qml` (453 lines) & `BatteryTab.qml` (453 lines) — Power profiles (Performance, Balanced, Power Saver), screen blank timeouts, system sleep timers, low battery notifications, and charge limit thresholds (80% battery protection).
- `quickshell/Modules/Settings/KeybindsTab.qml` (907 lines), `KeybindEditorDialog.qml` (1,294 lines), `KeybindRow.qml` (86 lines) — Master hotkey management: categorized action catalog, collision detection, interactive key capture recorder dialog, and custom CLI command binding.
- `quickshell/Modules/Settings/KeyboardTab.qml` (182 lines) & `MouseTouchpadTab.qml` (286 lines) — Input hardware settings: key repeat rate, repeat delay, natural scrolling, acceleration curve, and touchpad tap-to-click.
- `quickshell/Modules/Settings/LockScreenTab.qml` (888 lines), `GreeterTab.qml` (553 lines), `GreeterAuthTab.qml` (103 lines), `LockWidgetSettings/*` (5 files) — Lock screen customization: auth backends (PAM, Biometrics), lock screen widgets (Clock, Media, Weather, Notifications), video screensavers, and greeter synchronization.
- `quickshell/Modules/Settings/UsersTab.qml` (199 lines), `CreateUserTab.qml` (207 lines), `UserAccountsTab.qml` (95 lines) — User account management: user list, avatar assignment, account creation, password modification.
- `quickshell/Modules/Settings/NotificationsTab.qml` (466 lines), `NotificationRulesTab.qml` (326 lines), `NotificationRuleEditorDialog.qml` (250 lines) — Notification management: global popup timeouts, per-app rules (sound mute, DND bypass, popup suppression, priority elevation).
- `quickshell/Modules/Settings/SoftwareUpdatesTab.qml` (812 lines), `PrinterTab.qml` (773 lines), `AutoStartTab.qml` (612 lines), `DefaultAppsTab.qml` (424 lines), `DigitalWellbeingTab.qml` (205 lines), `WindowRulesTab.qml` (692 lines), `WindowRuleEditorDialog.qml` (1,544 lines), `AboutTab.qml` (322 lines), `ChangelogTab.qml` (77 lines).

---

## 1. Purpose & User-Visible Behavior
Settings Part C covers the deep system, hardware control, input mapping, security, and application integration tabs.

Key user-visible behaviors include:
1. **Interactive Keybind Editor**:
   - Comprehensive table of all shortcuts grouped by category (Shell, Navigation, Windows, Media, Apps).
   - Clicking any shortcut opens `KeybindEditorDialog` with an interactive keystroke listener that detects modifiers (`Cmd`, `Option`, `Control`, `Shift`) and key codes in real time.
   - Immediate warning if the key combination collides with an existing action.
2. **Wi-Fi & Network Management**:
   - Live scanning of wireless SSIDs with signal strength meters and security type tags.
   - Inline credential modal and connection status indicators.
3. **Audio Routing & Sound Themes**:
   - Device selectors for playback and recording.
   - Sound effect toggle for shell interactions (clicks, pops, notifications, power events).
4. **Lock Screen & Security**:
   - Live preview of lock screen layout with selectable clock styles and widget positioning.
   - Biometric toggle (Touch ID on macOS).
5. **Per-App Notification Rules**:
   - Users can create granular rules per application: e.g. "Silence Slack notifications during work hours", "Always allow Calendar alerts to break through DND".
6. **Autostart & Default Applications**:
   - Manage login items, background helpers, and default browser/terminal/editor handlers.

---

## 2. Layout & Visual Tokens
- **Keybind Editor Dialog**:
  - Modal size: 540x480 pt.
  - Keystroke pill display: Large animated keycaps rendering captured key icons (`⌘`, `⌥`, `⌃`, `⇧`, `Enter`).
- **Network SSID List**:
  - Row height: 48 pt.
  - Signal strength: 4-bar RSSI glyph colored according to quality.
- **M3 Colors & Indicators**:
  - Connected network: `Theme.primary` text and checkmark badge.
  - Collision error: `Theme.error` badge with "Conflict with [Action Name]".

---

## 3. Internal Logic & State Management
- **Keybind Action Registry**:
  - Actions mapped to canonical string identifiers (`"dms.launcher.toggle"`, `"dms.controlcenter.toggle"`, `"dms.screenshot.area"`, `"dms.media.playpause"`).
- **Notification Rule Engine**:
  - Evaluates incoming notifications against stored regex patterns matching `appName` and `summary`.

---

## 4. Configuration Schema
| Settings Key | Type | Default | Description |
|---|---|---|---|
| `keybinds.custom` | array | `[]` | User-defined hotkeys and commands |
| `network.autoConnect` | bool | `true` | Automatically connect to known Wi-Fi |
| `power.sleepTimeoutMinutes` | int | `15` | Inactivity time before system sleep |
| `power.displayTimeoutMinutes`| int | `5` | Inactivity time before display blank |
| `lock.showMedia` | bool | `true` | Show media controls on lock screen |
| `lock.showClock` | bool | `true` | Show clock on lock screen |
| `notifications.rules` | array | `[]` | List of per-application notification rules |

---

## 5. IPC / CLI API
| Command | Arguments | Returns | Description |
|---|---|---|---|
| `dms keybinds list` | `--json` | `json` | Lists all active shortcuts and actions |
| `dms keybinds set <action> <combo>`| `action: string, combo: string`| `bool` | Rebinds action to shortcut |
| `dms wifi scan` | `none` | `json` | Scans available Wi-Fi networks |
| `dms wifi connect <ssid>` | `--password` | `bool` | Connects to specified network |
| `dms audio setVolume <0-100>` | `volume: int` | `void` | Adjusts master volume |

---

## 6. macOS Mapping
- **Keybind Listening & Interception**:
  - `CGEventTapCreate` or `NSEvent.addGlobalMonitorForEvents` for global shortcut monitoring (requires Accessibility permissions).
- **Wi-Fi Scanning**:
  - CoreWLAN framework (`CWWiFiClient`, `CWInterface`) for scanning SSIDs, RSSI, and security protocols.
- **Audio Control**:
  - CoreAudio (`AudioObjectGetPropertyData`, `AudioObjectSetPropertyData`) for system volume and default device routing.
- **Touch ID / Authentication**:
  - LocalAuthentication framework (`LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`).

---

## 7. Port Audit
| Upstream File / Subsystem | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `KeybindsTab.qml` & `KeybindEditorDialog.qml` (2,200 lines) | Partially Insp. | **Major Gap** | Port has a static read-only table in `KeybindsView.swift`. It lacks key capture dialogs, conflict detection, and customizable shortcut binding. |
| `NetworkWifiTab.qml` & CoreWLAN scanning | Absent | **Missing (0%)** | Port lacks a Wi-Fi scanning settings tab, connection credentials dialog, and network profile management. |
| `LockScreenTab.qml` & Lock settings | Absent | **Missing (0%)** | Port has no lock screen configuration tab or Touch ID settings. |
| `NotificationRulesTab.qml` & Rule Editor | Absent | **Missing (0%)** | Port has no notification rule management interface. |
| `SoftwareUpdatesTab.qml`, `PrinterTab.qml`, `AutoStartTab.qml` | Absent | **Missing (0%)** | All system maintenance settings tabs are completely missing in port. |

---

## 8. Reimplementation Checklist
- [ ] Build interactive `KeybindEditorDialog` with real-time keystroke recording and collision detection.
- [ ] Implement `NetworkWifiSettingsView` using CoreWLAN for wireless scanning and credential inputs.
- [ ] Build `LockScreenSettingsView` with Touch ID and widget toggles.
- [ ] Implement `NotificationRulesView` with per-app rule creation dialogs.
- [ ] Add `dms keybinds [list|set]`, `dms wifi [scan|connect]`, and `dms audio setVolume` to CLI.
