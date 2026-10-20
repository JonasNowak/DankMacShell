# PWR — Power Management, Brightness, Night Mode & Display Architecture Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Battery Management (`BatteryService.qml`, `BatteryMeter.qml`), Battery History Chart (`BatteryHistoryChart.qml`), Brightness Control (`BrightnessService.qml`, `core/internal/server/brightness/`), Night Mode / Gamma (`NightModeService.qml`, 739 lines), Display Configuration Canvas (`Modules/Settings/DisplayConfig/*`), and ICC Profiles (`core/internal/icc/`).

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `quickshell/Services/BatteryService.qml` | 878 | Battery level, charging states, wattage calculation, health tracking |
| `quickshell/Services/BrightnessService.qml` | 728 | Backlight device control, DDC/CI monitor brightness, keyboard backlight |
| `quickshell/Services/NightModeService.qml` | 739 | Color temperature adjustment (Kelvin), automated solar schedules |
| `quickshell/Services/RefreshRateService.qml` | 494 | Display refresh rate enumeration and switching |
| `quickshell/Services/DisplayService.qml` | 94 | High-level display output manager |
| `quickshell/Modules/DBar/Popouts/BatteryPopout.qml` | 120 | Battery status popout with power draw in Watts and time estimates |
| `quickshell/Modules/DBar/Popouts/BatteryHistoryChart.qml` | 240 | Canvas-rendered 24-hour battery percentage drain history curve |
| `quickshell/Modules/Settings/DisplayConfig/DisplayConfigTab.qml` | 470 | Visual multi-monitor canvas: arrangement, resolution, scale, rotation |
| `core/internal/server/brightness/` | 2,636 | Go backend for sysfs backlight, DDC/CI I2C bus communications |
| `core/internal/icc/` | 705 | ICC color profile parser and loader |

---

## 1. Purpose & User-Visible Behavior

1. **Battery Health & Charge Statistics**:
   - Accurate battery percentage and dynamic charging status icon (charging lightning bolt, AC plug, discharging).
   - Time remaining until full / until empty.
   - Live power draw in Watts ($W = V \times A$).
   - Battery Health percentage ($\text{Health} = \frac{\text{Full Capacity}}{\text{Design Capacity}} \times 100\%$).
   - 24-hour historical discharge chart (`BatteryHistoryChart.qml`).
2. **Display Backlight & DDC/CI**:
   - Internal laptop screen brightness adjustments.
   - External desktop monitor hardware brightness via DDC/CI protocol.
   - Keyboard backlight illumination controls.
3. **Night Mode (Color Temperature)**:
   - Shifts screen white point from daytime 6500K down to warm night 3500K (or user-defined Kelvin value).
   - Automatic mode uses `SunCalc` to smoothly fade temperature over 45 minutes centered at sunset and sunrise.
4. **Display Arrangement Canvas**:
   - Visual drag-and-drop monitor layout editor allowing pixel-perfect spatial positioning, resolution selection, HiDPI scaling (1.0x, 1.25x, 1.5x, 2.0x), and display rotation (0°, 90°, 180°, 270°).

---

## 2. Detailed Requirements

### 2.1. Battery & Power (`BatteryService.qml`)
- `PWR-001`: Low battery warning alerts:
  - First warning: Toast and alert sound when discharging reaches 20%.
  - Critical warning: Urgent dialog and repeated chime when discharging reaches 10%.
- `PWR-002`: Battery history logging: Every 5 minutes while active, append `{ timestamp: Date.now(), percent: level, charging: isCharging }` to `~/Library/Caches/DMS/battery_history.json` (max 288 points = 24 hours).

### 2.2. Night Mode & Gamma (`NightModeService.qml`)
- `PWR-003`: Temperature range: 2500K (ultra warm) to 6500K (neutral daylight). Default night target: 4000K.
- `PWR-004`: Manual pause toggle: Allows disabling night shift temporarily for color-accurate work (1 hour or until sunrise).

---

## 3. Wayland/Linux Mechanisms → macOS Mapping

1. **Linux UPower / sysfs Battery**:
   - Upstream queries `/sys/class/power_supply` or UPower D-Bus.
   - **macOS Approach**: Use `IOPSCopyPowerSourcesInfo()` and `IOPSGetPowerSourceDescription()`. Access battery health, cycle count, and temperature via `IOKit` `AppleSmartBattery` dictionary (`CycleCount`, `DesignCapacity`, `MaxCapacity`, `Amperage`, `Voltage`).
2. **Display Brightness & DDC/CI**:
   - Linux talks to `/sys/class/backlight` and `/dev/i2c-*`.
   - **macOS Approach**:
     - Built-in display: Private `DisplayServices.framework` (`DisplayServicesGetBrightness`, `DisplayServicesSetBrightness`).
     - External displays: DDC/CI commands over IOKit `IOI2CInterfaceConnect`.
3. **Night Shift / Gamma**:
   - Linux uses `zwp_gamma_control_v1`.
   - **macOS Approach**: Use private `CBBlueLightClient` (`CoreBrightness.framework`):
     - `setEnabled(Bool)`
     - `setCachableStrength(Float)`
     - Or set gamma tables directly using `CGSetDisplayTransferByTable()`.
4. **Display Layout & Arrangement**:
   - Linux uses `wlr-output-management`.
   - **macOS Approach**: Query `CGGetOnlineDisplayList()`, read display bounds with `CGDisplayBounds()`, and reconfigure positions using `CGBeginDisplayConfiguration()`, `CGConfigureDisplayOrigin()`, and `CGCompleteDisplayConfiguration()`.

---

## 4. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| `PWR-001` - `002` | **Partial** | `BatteryService.swift` (65 lines) | Reads basic percent and charging flag via IOPowerSources. **Lacks wattage calculation, health %, history recording, and 24h history chart.** |
| Brightness Control | **Partial** | `BrightnessService.swift` (64 lines) | Controls built-in screen brightness. Lacks external monitor DDC/CI and keyboard backlight. |
| `PWR-003` - `004` | **Partial** | `NightShiftService.swift` (51 lines) | Calls private `CBBlueLightClient` toggle. Lacks custom Kelvin temperature adjustments and scheduled fade transitions. |
| Display Config Canvas| **Missing** | None | **Completely absent**. No visual multi-monitor layout canvas or resolution switcher exists. |

### Audit Verdict:
The port implements basic scalar battery and brightness readers, but **completely lacks the visual display layout canvas, battery history charting, and precise Kelvin temperature controls**. Parity: **~25%**.

---

## 5. Reimplementation Checklist

- [ ] Implement `BatteryHistoryStore.swift` recording 24h rolling battery drain.
- [ ] Build `BatteryHistoryChartView.swift` in SwiftUI using `Path` curves.
- [ ] Implement `DisplayConfigCanvasView.swift` providing interactive drag-and-drop display arrangement.
- [ ] Expand `NightShiftService.swift` to support custom Kelvin warmth adjustments.
