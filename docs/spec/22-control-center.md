# 22 — Control Center Specification (`CC`)

## 0. Coverage Manifest
- `quickshell/Modules/ControlCenter/ControlCenterPopout.qml` — Dedicated popout surface host, layout positioning relative to DankBar trigger pill, and dismissal management.
- `quickshell/Modules/ControlCenter/ControlCenterContent.qml` (622 lines) — Master Control Center container, grid state management, navigation stack (`pageHistory`), undo stack (`undoStack`, limit 50), audio ref-counting sync (`syncAudioRef`), and width resizer (`DPanelResizer`).
- `quickshell/Modules/ControlCenter/CcMetrics.qml` (161 lines) — Dimensional metrics singleton, column math (`clampColumns`, `sheetWidthFor`, `columnCapFor`), tile heights (`tileHeight: 64`), animation curves, and preferred detail page heights.
- `quickshell/Modules/ControlCenter/utils/sections.js` — Section router, instance ID parser (`parse`, `sectionFor`, `widgetForSection`), and multi-instance patch handler.
- `quickshell/Modules/ControlCenter/utils/widgets.js` (232 lines) — Tile specification catalog, dimension clamping (`clampSize`), dynamic grouping (`moveToGroup`, `ungroup`), avatar shape cycler (`USER_SHAPES`), and edit button fallback.
- `quickshell/Modules/ControlCenter/Models/WidgetModel.qml` — Dynamic model mapping settings array to active visual tile components.
- `quickshell/Modules/ControlCenter/Components/CcTileGrid.qml` (116 lines) — Bin-packed editable card grid (`DEditableGrid`), 0.5-step row quantization, drag-to-group detection (`groupAt`), and live compaction (`GridUtils.packCards`).
- `quickshell/Modules/ControlCenter/Components/CcTileSlot.qml` — Slot delegate hosting individual tiles with drop shadow, drag placeholder, and resize handles.
- `quickshell/Modules/ControlCenter/Components/CcTileLoader.qml` — Dynamic component instantiator matching widget IDs to concrete QML implementations.
- `quickshell/Modules/ControlCenter/Components/QuickTilesGroup.qml` — Container for compact 1x1 circular or icon-only tiles grouped horizontally within a single grid slot.
- `quickshell/Modules/ControlCenter/Components/CcDetailPage.qml` (431 lines) — Full-sheet detail subpage container with slide/fade transition (`enterAnimation`, `exitAnimation`), keyboard focus trapping, and breadcrumb header.
- `quickshell/Modules/ControlCenter/Components/CcEditChrome.qml` & `CcEditActions.qml` — Header and bottom action bar during edit mode (Add, Undo, Discard, Done, Reset to Default, Clear All).
- `quickshell/Modules/ControlCenter/Components/WidgetConfigOverlay.qml` — In-situ popover for configuring per-widget instance options (mount path, device target, avatar shape).
- `quickshell/Modules/ControlCenter/Components/CcWidgetSheet.qml` & `Widgets/CcWidgetLibrary.qml` — Searchable catalog sheet for browsing and inserting available tiles.
- `quickshell/Modules/ControlCenter/Components/PluginDetailShell.qml` — Standardized host wrapper for third-party and built-in plugin detail sheets.
- `quickshell/Modules/ControlCenter/Details/NetworkDetail.qml` — Wi-Fi network scanner, RSSI bucket icons, WPA/WPA2/WPA3 credential input, Ethernet status, and QR code sharing modal.
- `quickshell/Modules/ControlCenter/Details/BluetoothDetail.qml` — Bluetooth device list, battery indicators, pair/connect toggles, and codec selector launcher.
- `quickshell/Modules/ControlCenter/Details/BluetoothCodecSelector.qml` — Modal sheet selecting Bluetooth audio codecs (SBC, AAC, aptX, aptX HD, LDAC).
- `quickshell/Modules/ControlCenter/Details/AudioOutputDetail.qml` — Audio output sinks, default sink picker, volume sliders, per-app stream mixer, and port selector launcher.
- `quickshell/Modules/ControlCenter/Details/AudioPortSelector.qml` — Modal sheet selecting physical sink ports (Speakers, Headphones, Line Out, HDMI/DisplayPort).
- `quickshell/Modules/ControlCenter/Details/AudioInputDetail.qml` — Microphone input sources, gain slider, per-app capture stream monitor, and noise cancellation toggle.
- `quickshell/Modules/ControlCenter/Details/BrightnessDetail.qml` — Multi-display backlight sliders, DDC/CI hardware indicators, gamma/exponent curves, and night mode warmth.
- `quickshell/Modules/ControlCenter/Details/BatteryDetail.qml` — Real-time power draw (Watts), health %, charging time prediction, power profiles (Performance, Balanced, Power Saver), and 24h discharge graph.
- `quickshell/Modules/ControlCenter/Details/DoNotDisturbDetail.qml` — Do Not Disturb master switch, timed duration presets (15m, 1h, 2h, until tomorrow, indefinite), and priority app bypass list.
- `quickshell/Modules/ControlCenter/Details/IdleInhibitorDetail.qml` — "Caffeine" mode toggle, duration presets (30m, 1h, 2h, indefinite), and list of system processes holding idle inhibitors.
- `quickshell/Modules/ControlCenter/Details/DiskUsageDetail.qml` — Storage mount point list, filesystem type, total/used/free bytes, and warning/critical colored gauges.
- `quickshell/Modules/ControlCenter/Details/RunningAppsDetail.qml` — Live process table sorted by memory or CPU, search filter, kill button, and switch-to-window action.
- `quickshell/Modules/ControlCenter/Details/VpnDetailContent.qml` & `VpnProfileDelegate.qml` — Virtual Private Network connections (WireGuard, OpenVPN, Fortinet).
- `quickshell/Modules/ControlCenter/BuiltinPlugins/VpnWidget.qml`, `TailscaleWidget.qml`, `DisplayProfilesWidget.qml`, `CupsWidget.qml` — First-party plugin tile definitions.
- `quickshell/Modules/ControlCenter/Widgets/*` (25 widget helper files) — `NetworkTile.qml`, `BluetoothTile.qml`, `DarkModeTile.qml`, `NightModeTile.qml`, `DndTile.qml`, `IdleInhibitTile.qml`, `BatteryTile.qml`, `RunningAppsTile.qml`, `DiskUsageTile.qml`, `ColorPickerTile.qml`, `AudioDeviceTile.qml`, `UserTile.qml`, `ActionTile.qml`, `PluginTile.qml`, `AudioSliderRow.qml`, `BrightnessSliderRow.qml`, `CcSliderRow.qml`, `CcTile.qml`, `CcGroup.qml`, etc.

---

## 1. Purpose & User-Visible Behavior
The Control Center is an extensible, interactive quick-settings dashboard presented as a popout surface from the DankBar or Dank Island. It provides immediate control over hardware interfaces, system states, active media, and power actions.

Key user-visible behaviors include:
1. **Dynamic Bin-Packed Tile Grid**: A responsive grid containing system toggles, sliders, and status monitors. Tiles automatically flow and pack without awkward holes using 2D box packing (`GridUtils.packCards`).
2. **Interactive Quick Sliders**: Inline audio output volume, microphone input volume, and multi-monitor display brightness sliders with haptic feedback, value popovers, and mute buttons.
3. **Deep Navigation Stack & Detail Pages**: Clicking a tile's chevron or body slides smoothly into a full-sheet detail page (`CcDetailPage`), providing exhaustive configuration (e.g. Wi-Fi network scanner, Bluetooth device pairing, audio stream mixer, 24h battery discharge curves).
4. **Interactive In-Situ Customization (Edit Mode)**:
   - Users can drag tiles to reorder them in real time with physics-based slot reservation.
   - Tiles can be resized horizontally or vertically (1x1, 2x1, 4x1, 4x2).
   - Dropping a small toggle into another small toggle automatically creates a horizontal `QuickTilesGroup`.
   - Dragging a tile outside the panel triggers a trash swallow animation (`scale: 0.6`).
   - A multi-step Undo system allows rolling back up to 50 layout actions.
5. **Adjustable Column Width**: Users can grab the edge resizer (`DPanelResizer`) to dynamically widen the panel from 6 to 12 columns.
6. **Avatar Morphing**: The user profile avatar supports cycling through 12 geometric SVG/mask shapes (`circle`, `cookie4`, `cookie7`, `cookie12`, `clover4`, `clover8`, `sunny`, `pentagon`, `arch`, `slanted`, `gem`, `square`).
7. **Zero-Idle Ref-Counting**: Audio subsystem polling is only active while the Control Center popout is open (`live = true`), avoiding background CPU wakeups.

---

## 2. Architecture & Data Flow

```
                      ┌────────────────────────────────────────┐
                      │   SettingsData.controlCenterWidgets    │
                      └───────────────────┬────────────────────┘
                                          │
                         GridUtils.packCards / clampSize
                                          │
                                          ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│ ControlCenterContent.qml (Root FocusScope)                                    │
│                                                                               │
│  DPanelResizer: Width scaling (6 to N columns, step: columnWidth + gridGap)  │
│  UndoStack: Circular history buffer (50 snapshots of widgets + columns)      │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │ CcTileGrid (DEditableGrid with gravity & 0.5-step row quantization)    │  │
│  │                                                                         │  │
│  │  [UserTile] (Avatar shape, name)       [ActionTiles] (Lock, Power, etc.)│  │
│  │  [NetworkTile] (SSID, IP, RSSI)        [BluetoothTile] (Connected devs) │  │
│  │  [VolumeSliderRow] (Sink volume + mute)[BrightnessSliderRow] (Backlight)│  │
│  │  [QuickTilesGroup] (DND | Dark | Night | Caffeine compact 1x1 buttons)  │  │
│  │  [BatteryTile] (Watts, %, Profile)     [DiskUsageTile] (Mount gauge)    │  │
│  │  [PluginTile] (VPN / Tailscale / Cups / Third-Party Plugins...)         │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │ CcDetailPage.qml (Overlay Dialog Surface with slide/fade animation)     │  │
│  │                                                                         │  │
│  │  Header: [Back Button] [Page Title]                   [Close Button]    │  │
│  │  Content: Instantiated via Sections._componentFor(shownSection):        │  │
│  │    ├─ NetworkDetail (Wi-Fi list, credentials, QR code share)            │  │
│  │    ├─ BluetoothDetail (Device list, pairing, CodecSelector sheet)       │  │
│  │    ├─ AudioOutputDetail (Sink devices, per-app streams, PortSelector)   │  │
│  │    ├─ AudioInputDetail (Mic inputs, noise suppression, gain)            │  │
│  │    ├─ BrightnessDetail (Multi-display sliders, DDC/CI, gamma exponents) │  │
│  │    ├─ BatteryDetail (Watts draw, 24h curve, PowerProfiles)              │  │
│  │    ├─ DoNotDisturbDetail (Timed presets: 15m, 1h, 2h, tomorrow)         │  │
│  │    ├─ IdleInhibitorDetail (Caffeine presets: 30m, 1h, 2h, processes)    │  │
│  │    ├─ DiskUsageDetail (Mount paths, storage meters, critical thresholds)│  │
│  │    └─ RunningAppsDetail (Process list, CPU/RAM sort, task terminate)    │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  [CcWidgetSheet] (Slide-in catalog for adding new tiles in Edit Mode)         │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Detailed Requirements

### Layout Metrics & Responsive Grid (`CC-GRID`)
- `CC-GRID-001`: Tile height must be fixed to `CcMetrics.tileHeight = 64` px (`gridRowUnit`). Small row height must be $\min(\text{iconBoxSize}, \text{tileHeight})$ with `smallRowFraction = 0.5`.
- `CC-GRID-002`: Column count must be user-configurable between `minimumColumns = 6` and `gridColumnCap`, defaulting to 8 columns (`defaultColumns`).
- `CC-GRID-003`: Total sheet width must be calculated strictly via `CcMetrics.sheetWidthFor(columns)`:
  $$\text{width} = \text{sheetPadding} \times 2 + \text{columns} \times \text{columnWidth} + (\text{columns} - 1) \times \text{gridGap}$$
  where `columnWidth = tileHeight = 64` px, `gridGap = 8` px (`Theme.spacingS`), and `sheetPadding = 16` px (`PopoutMetrics.contentPadding`).
- `CC-GRID-004`: Grid layout must use 2D bin packing with gravity (`GridUtils.packCards`) and row quantization step of 0.5 (`CcMetrics.gridStep = 0.5`).
- `CC-GRID-005`: Dynamic width dragging via `DPanelResizer` must snap to column intervals `columnWidth + gridGap` (72px) and provide live preview before commit.

### Tile Specifications & Sizes (`CC-TILE`)
- `CC-TILE-001`: Standard system tiles (`network`, `bluetooth`, `battery`, `diskUsage`) must default to 4 columns $\times$ 1 row (`w: 4, h: 1`), shrinkable to 2x1 or 1x1.
- `CC-TILE-002`: Slider widgets (`volumeSlider`, `brightnessSlider`, `inputVolumeSlider`) must have minimum width 2 columns (`w: 2, h: 1`) or vertical orientation (`w: 1, h: 2`), and cannot be shrunk into small 1x1 buttons.
- `CC-TILE-003`: Action buttons (`settings`, `lock`, `power`, `edit`) must have size 1 column $\times$ 1 row (`w: 1, h: 1`) with `small = true`.
- `CC-TILE-004`: User avatar tile (`user`) must occupy remaining top columns: $\text{columns} - \text{ACTION\_IDS.length}$ (e.g. $8 - 3 = 5$ columns in an 8-column layout).
- `CC-TILE-005`: Avatar shapes must cycle through the 12 defined masks: `circle`, `cookie4`, `cookie7`, `cookie12`, `clover4`, `clover8`, `sunny`, `pentagon`, `arch`, `slanted`, `gem`, `square`.

### Grouping & Drag-and-Drop Interaction (`CC-DND`)
- `CC-DND-001`: In edit mode, dragging a tile over another small shrinkable tile must highlight the target and, on release, wrap them into a `QuickTilesGroup` (`GROUP_ID = "quickTiles"`).
- `CC-DND-002`: Inside a `QuickTilesGroup`, member tiles render horizontally with compact icon boxes (`quickBareWidth` or `iconBoxSize`). Dragging a member out of the group restores it as an independent grid tile.
- `CC-DND-003`: Dragging a tile outside the grid boundary sets `heldOutside = true`. If released outside without hovering a group, the tile is deleted with a swallow scale animation (`trashSwallowScale = 0.6`).
- `CC-DND-004`: All edit mode layout changes must push a state snapshot (`widgets`, `columns`) onto `undoStack`. The undo stack must retain up to 50 steps (`undoLimit = 50`).
- `CC-DND-005`: The edit button (`EDIT_ID = "edit"`) cannot be deleted or dragged to trash (`isRemovable = false`). If missing from settings, `WidgetUtils.ensureEditButton()` automatically reinstates it.

### Detail Subpages & Navigation Stack (`CC-NAV`)
- `CC-NAV-001`: Opening a detail section pushes the current section onto `pageHistory` and animates `CcDetailPage` into view over `CcMetrics.fadeDuration` (200ms) with entry scale from `0.92` to `1.0`.
- `CC-NAV-002`: Back navigation (via back button, Escape key, or swipe) pops the last history entry or collapses the detail page if history is empty.
- `CC-NAV-003`: Focus must be trapped inside `CcDetailPage` while active, and restored to `detailReturnFocus` upon closure.
- `CC-NAV-004`: The detail page height must dynamically adjust to content:
  - List-based details (Network, Bluetooth, Audio, Battery, Disk, Apps): `CcMetrics.detailHeightList = 350` px.
  - Multi-monitor Brightness detail: `CcMetrics.detailHeightBrightness = 400` px.
  - Default/generic details: `CcMetrics.detailHeightDefault = 250` px.

### Detail Section Requirements (`CC-DET`)
- `CC-DET-001` (Network):
  - Scan and display Wi-Fi networks sorted by RSSI signal strength.
  - RSSI signal icon buckets: 4 bars ($>75\%$), 3 bars ($50-75\%$), 2 bars ($25-50\%$), 1 bar ($<25\%$).
  - Display padlock badge for secured networks (WPA2/WPA3).
  - WPA-Enterprise and captive portal detection.
  - "Share Wi-Fi" action opening a generated QR code dialog for current Wi-Fi network.
- `CC-DET-002` (Bluetooth):
  - List paired and discovered Bluetooth peripherals.
  - Battery percentage indicator for supported headsets and peripherals.
  - Codec indicator badge with modal sheet selector (`BluetoothCodecSelector.qml`) allowing selection between SBC, AAC, aptX, aptX HD, and LDAC.
- `CC-DET-003` (Audio Output & Input):
  - List all audio sink and source nodes with active node highlighted.
  - Output port selector (`AudioPortSelector.qml`) for toggling between Headphones, Built-in Speakers, and HDMI/DisplayPort.
  - Per-app audio mixer listing active playback streams with app icon, stream title, volume slider, and individual mute button.
  - Input gain slider and toggle for hardware noise suppression.
- `CC-DET-004` (Display & Brightness):
  - Dedicated slider for each connected physical monitor.
  - DDC/CI communication indicator for external monitors.
  - Gamma / brightness curve exponent adjustment ($1.0$ to $2.5$, step $0.1$).
  - Night mode toggle and Kelvin temperature slider ($1000\text{K}$ to $10000\text{K}$).
- `CC-DET-005` (Battery & Power):
  - Real-time battery power draw displayed in Watts ($P = V \times I$).
  - Remaining time to full charge or empty discharge.
  - Battery health percentage and cycle count.
  - Power Profile toggle: `performance`, `balanced`, `power-saver`.
  - 24-hour battery discharge history graph.
- `CC-DET-006` (Do Not Disturb):
  - Master DND toggle.
  - Timed duration selector: "For 15 minutes", "For 1 hour", "For 2 hours", "Until tomorrow morning", "Until turned off".
  - Toggle for critical notification bypass.
- `CC-DET-007` (Idle Inhibitor / Caffeine):
  - Master idle inhibitor toggle.
  - Timed duration selector: 30 minutes, 1 hour, 2 hours, Indefinite.
  - System inhibitor inspector showing application names and reasons for active sleep inhibitors.
- `CC-DET-008` (Disk Usage):
  - Storage breakdown by mount point (`/`, `/home`, external drives).
  - Gauge bar with dynamic color grading: normal below 75%, warning color at $\ge 75\%$, critical error color at $\ge 90\%$.
- `CC-DET-009` (Running Applications):
  - Process table displaying application name, icon, PID, CPU %, and memory usage in MB/GB.
  - Real-time search filter bar.
  - Direct "Terminate" button (SIGTERM / SIGKILL) and "Focus Window" action.
- `CC-DET-010` (VPN & Built-in Plugins):
  - VPN profile switcher for WireGuard, OpenVPN, and Fortinet profiles.
  - Tailscale exit node picker and connection status.
  - CUPS printer queue monitor with active print jobs and cancel buttons.

---

## 4. Settings Keys
The Control Center state is managed under `SettingsData.controlCenterWidgets` and `SettingsData.controlCenterColumns`:

| Key | Type | Default | Description |
|---|---|---|---|
| `controlCenterWidgets` | `array` | Default Tile Array | Ordered list of widget objects `{ id, col, row, w, h, small?, group?, ... }` |
| `controlCenterColumns` | `int` | `8` | Number of grid columns (clamped $\ge 6$) |
| `controlCenterIconScale` | `real` | `1.0` | Global icon scaling factor in tiles |

### Default Widget Schema Item:
```json
{
  "id": "network",
  "col": 0,
  "row": 0,
  "w": 4,
  "h": 1,
  "small": false,
  "enabled": true
}
```

---

## 5. IPC/CLI API
| Method | Arguments | Returns | Description |
|---|---|---|---|
| `controlCenter.toggle` | `[screen?: string]` | `bool` | Toggles Control Center popout visibility |
| `controlCenter.open` | `[section?: string]` | `void` | Opens popout, optionally jumping directly to detail section |
| `controlCenter.close` | `none` | `void` | Closes popout and resets navigation |
| `controlCenter.editMode` | `enable: bool` | `void` | Activates or exits in-situ grid edit mode |
| `controlCenter.setColumns` | `columns: int` | `void` | Adjusts grid column count |
| `controlCenter.reset` | `none` | `void` | Restores default tile layout and columns |

---

## 6. macOS Mapping
- **UI Surfaces**:
  - `ControlCenterPopout` maps to an `NSPanel` with `.popUpMenu` level, floating directly below the menu bar or DankBar trigger button.
  - Detail pages map to a slide-over `NSView` / SwiftUI view transition with spring animation.
- **Hardware Integration**:
  - **Wi-Fi**: `CWWiFiClient` / `CWInterface` via CoreWLAN framework (scanning networks, SSID, RSSI, security mode).
  - **Bluetooth**: `IOBluetooth` framework for paired device enumeration, connection states, and battery level reading.
  - **Audio**: `CoreAudio` (`AudioObjectGetPropertyData`) for sink/source enumeration, default device selection, and volume controls.
  - **Display Brightness**: `CoreDisplay` / `DisplayServices` private APIs (`DisplayServicesSetBrightness`) or `DDC.swift` for external monitor DDC/CI commands.
  - **Battery**: `IOPowerSources` and `IOPSGetPowerSourceDescription` for wattage, battery health %, charging time, and cycle count.
  - **Caffeine / Sleep Inhibitor**: `IOPMAssertionCreateWithName` (`kIOPMAssertionTypePreventUserIdleSystemSleep` / `kIOPMAssertionTypePreventUserIdleDisplaySleep`).
  - **Disk Usage**: `FileManager.default.attributesOfFileSystem(forPath:)` for storage calculations.
  - **Running Processes**: `NSWorkspace.shared.runningApplications` combined with `libproc` (`proc_pidinfo`) for CPU and memory usage.

---

## 7. Port Audit
| File / Feature in Upstream | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `ControlCenterContent.qml` & Grid | Partially Insp. | **Major Gap** | Port has a static 2-column SwiftUI sheet (`ControlCenterView.swift`). Completely lacks dynamic bin packing (`GridUtils.packCards`), column resizing, and undo stack. |
| Detail Subpages (`Details/*.qml`) | Missing | **Absent** | Port has ZERO detail subpages. Clicking Wi-Fi, Bluetooth, Audio, or Battery in the port toggles a state or does nothing; there is no network scanner, device list, or audio mixer. |
| Quick Tiles Grouping (`QuickTilesGroup.qml`) | Missing | **Absent** | Port does not support compact grouping or drag-to-group functionality. |
| Edit Mode Chrome & Actions (`CcEditChrome.qml`) | Missing | **Absent** | Port has no edit mode, no drag-and-drop reordering, and no widget catalog sheet. |
| Battery Power Draw & Curves (`BatteryDetail.qml`) | Missing | **Absent** | Port only displays a single battery percentage number without wattage draw, health %, or 24h curves. |
| Audio App Mixer & Port Selector (`AudioOutputDetail.qml`) | Missing | **Absent** | Port does not support per-app stream volume mixing or output port switching. |
| Bluetooth Codec Selector (`BluetoothCodecSelector.qml`) | Missing | **Absent** | Port has no codec selector modal or peripheral battery meters. |
| Zero-Idle Ref-Counting (`syncAudioRef`) | Missing | **Absent** | Port does not gate background audio polling to surface visibility. |

---

## 8. Reimplementation Checklist
- [ ] Implement `CcMetrics` and `ControlCenterWidget` configuration data structures in Swift.
- [ ] Build responsive 2D bin-packing grid layout with 0.5-step row quantization in SwiftUI.
- [ ] Create `CcDetailPage` host supporting slide-in transitions, history breadcrumbs, and Escape key handling.
- [ ] Implement complete suite of 10 detail subpages:
  - [ ] `NetworkDetail`: CoreWLAN network scanner with RSSI bars and Wi-Fi QR code generator.
  - [ ] `BluetoothDetail`: `IOBluetooth` device manager with peripheral battery levels and audio codec selector.
  - [ ] `AudioOutputDetail`: CoreAudio default sink switcher, physical port picker, and per-app volume mixer.
  - [ ] `AudioInputDetail`: CoreAudio microphone selector, gain slider, and noise suppression toggle.
  - [ ] `BrightnessDetail`: Multi-display brightness sliders with DDC/CI support and night warmth temperature slider.
  - [ ] `BatteryDetail`: `IOPowerSources` power draw (Watts), health %, charging time, and 24h discharge curves.
  - [ ] `DoNotDisturbDetail`: macOS Focus/DND toggles with timed duration presets.
  - [ ] `IdleInhibitorDetail`: IOPMAssertion power assertions ("Caffeine") with duration presets.
  - [ ] `DiskUsageDetail`: Mounted volume storage breakdown with 75% warning and 90% critical gauge colors.
  - [ ] `RunningAppsDetail`: Process monitor with memory/CPU sorting and force quit action.
- [ ] Implement interactive Edit Mode with drag-to-reorder, drag-to-group (`QuickTilesGroup`), drag-to-trash swallow animation, and 50-step Undo stack.
- [ ] Add `DPanelResizer` edge handle allowing live column resizing from 6 to 12 columns.
