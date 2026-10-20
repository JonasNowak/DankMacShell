# BARW — DankBar Widgets & Bar Popouts Complete Catalog Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Complete Inventory of all 33 DankBar Widgets (`quickshell/Modules/DBar/Widgets/*`, `Modules/DankBar/Widgets/*`), Widget Options Schemas, and Bar Popout Sheets (`Modules/DBar/Popouts/*`).

---

## 0. Coverage Manifest

| Widget ID | Upstream File | Role & Primary Function |
| :--- | :--- | :--- |
| `appsDock` | `Widgets/AppsDock.qml` | Embedded mini application dock with pinned icons and running dots |
| `audioVisualization`| `Widgets/AudioVisualization.qml` | Mini 4-bar equalizer dancing to audio output frequency |
| `battery` | `Widgets/Battery.qml` | Battery percentage, charging glyph, and battery popout trigger |
| `capsLockIndicator`| `Widgets/CapsLockIndicator.qml` | Caps lock warning badge (visible only when active) |
| `clipboardButton` | `Widgets/ClipboardButton.qml` | Clipboard history trigger button |
| `clock` | `Widgets/Clock.qml` | Formatted time and date; opens calendar or DDash |
| `colorPicker` | `Widgets/ColorPicker.qml` | Eyedropper tool trigger and recent color popout |
| `controlCenterButton`| `Widgets/ControlCenterButton.qml`| Quick Settings Control Center toggle button |
| `cpuMonitor` | `Widgets/CpuMonitor.qml` | Real-time aggregate CPU load percentage |
| `cpuTemperature` | `Widgets/CpuTemperature.qml` | CPU thermal core temperature in °C or °F |
| `diskUsage` | `Widgets/DiskUsage.qml` | Primary filesystem storage used/available percentage |
| `dwlLayout` | `Widgets/DWLLayout.qml` | Tiling layout symbol (tile, float, monocle) |
| `focusedApp` | `Widgets/FocusedApp.qml` | Active window icon, app title, and right-click context menu |
| `gpuTemperature` | `Widgets/GpuTemperature.qml` | GPU thermal core temperature |
| `idleInhibitor` | `Widgets/IdleInhibitor.qml` | Coffee-cup sleep inhibitor toggle button |
| `keyboardLayoutName`| `Widgets/KeyboardLayoutName.qml`| Input language badge (US, DE, FR, JP) |
| `launcherButton` | `Widgets/LauncherButton.qml` | DLauncherV2 trigger with OS / custom logo |
| `media` | `Widgets/Media.qml` | Compact playback controls, track title, and album art |
| `mediaLyricLine` | `Widgets/MediaLyricLine.qml` | Live real-time scrolling synchronized song lyrics ticker |
| `monitorPill` | `Widgets/MonitorPill.qml` | Display identifier tag (e.g. "DP-1") |
| `networkMonitor` | `Widgets/NetworkMonitor.qml` | Live network bandwidth throughput (KB/s, MB/s) |
| `notepadButton` | `Widgets/NotepadButton.qml` | Quick notepad trigger button |
| `notificationCenterButton`| `Widgets/NotificationCenterButton.qml`| Unread notifications bell with badge count |
| `powerMenuButton` | `Widgets/PowerMenuButton.qml` | Power menu trigger button |
| `privacyIndicator` | `Widgets/PrivacyIndicator.qml` | Hardware sensor warning dots (Cam, Mic, Screen) |
| `ramMonitor` | `Widgets/RamMonitor.qml` | Memory utilization percentage |
| `runningApps` | `Widgets/RunningApps.qml` | Running window taskbar pills with active highlights |
| `systemTrayBar` | `Widgets/SystemTrayBar.qml` | StatusNotifierItem / AppIndicator system tray container |
| `systemUpdate` | `Widgets/SystemUpdate.qml` | Package update badge indicating pending updates |
| `trayItemIcon` | `Widgets/TrayItemIcon.qml` | Individual system tray icon delegate |
| `vpn` | `Widgets/Vpn.qml` | Active VPN tunnel indicator and connection popout |
| `weather` | `Widgets/Weather.qml` | Weather condition icon and temperature readout |
| `workspaceSwitcher`| `Widgets/WorkspaceSwitcher.qml`| Numbered / named virtual workspace switcher pills |

---

## 1. Widget Specifications (Core Highlights)

### 1.1. Clock Widget (`Widgets/Clock.qml`)
- `BARW-001`: Options schema:
  - `showDate`: Boolean (default true).
  - `timeFormat`: Enum `"12h"` or `"24h"`.
  - `showSeconds`: Boolean (default false).
  - `dateFormat`: String format pattern (e.g. `"EEE, MMM d"`).
- `BARW-002`: Interaction: Left-click opens DDash Overview / Calendar; middle-click toggles 12h/24h mode.

### 1.2. Telemetry Monitors (`CpuMonitor`, `RamMonitor`, `NetworkMonitor`)
- `BARW-003`: Update rate: Polled strictly every 2,000ms while visible; completely pauses when bar is hidden (`updatesEnabled: visible`).
- `BARW-004`: Color thresholds:
  - Normal ($< 70\%$): `Theme.onSurface`.
  - Warning ($70\% - 85\%$): `Theme.tertiary` (amber).
  - Critical ($> 85\%$): `Theme.error` (red).

### 1.3. System Tray (`Widgets/SystemTrayBar.qml`)
- `BARW-005`: Displays icons for background applications. Right-click opens the application's native menu. Supports icon overflow expansion if more than 5 icons are active.

---

## 2. Bar Popouts Specification

| Popout File | Dimensions | Contents & Actions |
| :--- | :--- | :--- |
| `Popouts/BatteryPopout.qml` | 280x320px | Battery health %, wattage draw, time remaining, 24h drain chart |
| `Popouts/ColorPickerPopout.qml`| 240x260px | Screen eyedropper trigger, recent 12 color hex swatches, copy button |
| `Popouts/DurationPopout.qml` | 200x220px | Sleep inhibitor presets (30m, 1h, 2h, 4h, Indefinite) |
| `Popouts/PowerMenuPopout.qml` | 220x240px | Quick actions: Lock, Sleep, Restart, Shutdown, Logout |
| `Popouts/VpnPopout.qml` | 260x300px | List of configured VPN tunnels with individual toggle switches |

---

## 3. Port Audit (Current macOS Port vs. Upstream)

| Metric | Upstream DMS | Current Port (`dms-shell`) | Deficiencies in Port |
| :--- | :--- | :--- | :--- |
| Total Bar Widgets | 33 widgets | 6 hardcoded pills | **27 widgets are completely missing** (e.g. AudioVisualization, CapsLock, CPU temp, GPU temp, Disk, MediaLyricLine, NetworkMonitor, SystemUpdate, Vpn, etc.). |
| Widget Options | Per-widget configurable | None | Port pills have no customizable options (e.g. date format, seconds, thresholds). |
| Bar Popout Sheets | 7 rich popouts | 0 popouts | Clicking pills in port opens full windows instead of integrated bar popout sheets. |

### Audit Verdict:
The port implements only a tiny fraction (**~18%**) of the DMS bar widget library and completely omits widget popouts and per-widget options. Parity: **~18%**.

---

## 4. Reimplementation Checklist

- [ ] Implement all 27 missing bar widget SwiftUI views in `Sources/DMS/DankBar/Widgets/`.
- [ ] Implement `BarWidgetOptions` model supporting custom date formats and telemetry thresholds.
- [ ] Build the 7 bar popout sheets in `Sources/DMS/DankBar/Popouts/`.
- [ ] Connect system tray extra items to `NSStatusBar` menu items.
