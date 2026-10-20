# 32 — Settings UI Part B: Bar, Dock, Widgets, Launcher & Display Specification (`SET-B`)

## 0. Coverage Manifest
- `quickshell/Modules/Settings/DBarTab.qml` (705 lines) & `DBarAppearanceTab.qml` (804 lines) — Master DankBar configuration: multi-bar instance management, monitor assignment rules, placement edge (Top, Bottom, Left, Right), thickness, segment distribution, and autohide physics.
- `quickshell/Modules/Settings/BarWidgetTab.qml` (208 lines) & `BarWidgetOptions/*` (16 files) — Detailed inspector sheets for each bar widget:
  - `AppsDockOptions.qml` (330 lines), `BatteryOptions.qml` (101 lines), `ClockOptions.qml` (49 lines), `ControlCenterOptions.qml` (168 lines), `FocusedWindowOptions.qml` (40 lines), `IslandOptions.qml` (39 lines), `KeyboardLayoutOptions.qml` (159 lines), `LauncherButtonOptions.qml` (141 lines), `MusicOptions.qml` (93 lines), `NetworkMonitorOptions.qml` (30 lines), `PrivacyOptions.qml` (38 lines), `RunningAppsOptions.qml` (40 lines), `SystemMonitorOptions.qml` (97 lines), `SystemTrayOptions.qml` (102 lines), `SystemUpdateOptions.qml` (29 lines), `WorkspaceSwitcherOptions.qml` (220 lines).
- `quickshell/Modules/Settings/DockGeneralTab.qml` (127 lines), `DockAppearanceTab.qml` (265 lines), `DockWidgetsTab.qml` (240 lines), `DockAdvancedTab.qml` (96 lines) — Desktop Dock manager: multi-dock instances, placement edge, icon size, magnification factor, pinned applications, group window indicators, and trash can toggle.
- `quickshell/Modules/Settings/WidgetsTab.qml` (820 lines) & `WidgetsTabSection.qml` (242 lines) — Widget catalog manager: enables/disables bar widgets, Control Center tiles, and Dash cards.
- `quickshell/Modules/Settings/DesktopWidgetsTab.qml` (307 lines) & `DesktopWidgetSettings/*` (5 files) — Desktop wallpaper widget instances manager and properties inspector.
- `quickshell/Modules/Settings/LauncherTab.qml` (868 lines) — DLauncherV2 configuration: scoring weights (`titleWeight`, `execWeight`, `keywordWeight`, `frecencyFactor`), presentation mode (Tile Grid vs List), screen anchor (Center vs Island attached), hidden app blacklist, and action keywords.
- `quickshell/Modules/Settings/DisplayConfigTab.qml` (470 lines) & `DisplayConfig/DisplayConfigState.qml` (1,988 lines) — Visual multi-monitor arrangement canvas:
  - `MonitorCanvas.qml` (117 lines) & `MonitorRect.qml` (162 lines) — 2D drag-to-arrange monitor positions
  - `OutputCard.qml` (342 lines) — Per-display resolution dropdown, refresh rate selector (Hz), scaling mode (100%, 125%, 150%, 200%), and rotation (0°, 90°, 180°, 270°)
  - `ICCProfileInfoModal.qml` (249 lines) — Color profile inspector
  - `MonitorIdentifyOverlay.qml` (82 lines) — Large on-screen monitor number badges
- `quickshell/Modules/Settings/GammaControlTab.qml` (353 lines) & `DisplayWidgetsTab.qml` (170 lines) — Night light color temperature, gamma curves, and ambient display widgets.

---

## 1. Purpose & User-Visible Behavior
Settings Part B governs the layout, positioning, multi-instance creation, and visual behavior of all primary desktop shell surfaces (Bars, Docks, Desktop Widgets, Launcher, and Physical Displays).

Key user-visible behaviors include:
1. **Multi-Bar Management**:
   - Users can create multiple independent DankBars across multiple displays.
   - Each bar can be attached to any display edge (Top, Bottom, Left, Right).
   - Segments (Left, Center, Right) can be populated with widgets via drag-and-drop.
2. **Multi-Dock Configuration**:
   - Supports creating separate application docks with independent icon sizes, magnification levels, and pinned applications.
3. **Interactive Multi-Monitor Visual Canvas**:
   - A scaled-down 2D canvas allows users to drag monitors to match physical desk placement.
   - Clicking "Identify Displays" flashes large numeric badges across all connected monitors.
   - Individual controls for resolution, refresh rate, HiDPI scale factor, and orientation.
4. **Fine-Grained Launcher Tuning**:
   - Configure search behavior, frecency scoring weights, default view (Tile vs List), and app exclusions.

---

## 2. Layout & Visual Tokens
- **Monitor Canvas**:
  - Scaled coordinate representation (e.g. 1:16 ratio).
  - Active screen highlight: 2 pt solid `Theme.primary` with label badge.
  - Snap tolerance: 8 pt magnetic alignment.
- **Bar / Dock Preview Cards**:
  - Live miniature preview of bar and dock configurations showing current pills and colors.

---

## 3. Internal Logic & State Management
- **Multi-Instance JSON Arrays**:
  - `SettingsData.bars`: Array of bar configurations `[{id, screen, edge, thickness, segments}]`.
  - `SettingsData.docks`: Array of dock configurations `[{id, screen, edge, iconSize, pinnedApps}]`.
- **Display Output State Engine (`DisplayConfigState.qml`)**:
  - Direct integration with OS display APIs (`CGDisplay`, `NSScreen`) to query native modes, refresh rates, and coordinate origins.

---

## 4. Configuration Schema
| Settings Key | Type | Default | Description |
|---|---|---|---|
| `bars` | array | `[...]` | List of configured bar instances |
| `docks` | array | `[...]` | List of configured dock instances |
| `launcher.viewMode` | string | `"list"` | Launcher mode (`list`, `tile`) |
| `launcher.attachMode` | string | `"center"` | Placement (`center`, `island`) |
| `launcher.frecencyEnabled`| bool | `true` | Weight results by historical usage |
| `display.nightLightEnabled`| bool | `false` | Warm color temperature filter |
| `display.nightLightTemp` | int | `4000` | Target color temperature in Kelvin |

---

## 5. IPC / CLI API
| Command | Arguments | Returns | Description |
|---|---|---|---|
| `dms bar list` | `none` | `json` | Lists configured bars |
| `dms bar add` | `screen: string, edge: string` | `string` | Creates new bar instance |
| `dms bar remove <id>` | `id: string` | `bool` | Removes bar instance |
| `dms display list` | `none` | `json` | Lists connected displays and modes |
| `dms display identify` | `none` | `void` | Triggers on-screen monitor identify overlay |

---

## 6. macOS Mapping
- **Display Configuration**:
  - macOS displays managed via CoreGraphics `CGDisplay` APIs (`CGGetOnlineDisplayList`, `CGDisplayCopyAllDisplayModes`, `CGConfigureDisplayWithDisplayMode`).
  - Screen geometry and identification via `NSScreen.screens` and `NSScreen.frame`.
- **Night Shift**:
  - Connect to private `CBBlueLightClient` or macOS Night Shift settings to query and toggle screen warmth.

---

## 7. Port Audit
| Upstream File / Subsystem | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `DBarTab.qml`, `BarWidgetOptions/*` (16 files) | Absent | **Missing (0%)** | Port has no multi-bar management and no per-widget options configuration tabs. |
| `DockGeneralTab.qml`, `DockAppearanceTab.qml` | Absent | **Missing (0%)** | Port lacks multi-dock management and dock appearance customization. |
| `DisplayConfigTab.qml` & `DisplayConfigState.qml` (2,450 lines) | Absent | **Missing (0%)** | Visual multi-monitor arrangement canvas, resolution/Hz picker, and monitor identification overlay are 100% missing in port. |
| `LauncherTab.qml` (868 lines) | Partially Insp. | **Major Gap** | Port has a simple search tab without scoring weights, tile mode toggles, or blacklist management. |

---

## 8. Reimplementation Checklist
- [ ] Implement `DBarSettingsView` supporting multi-bar creation, edge selection, and segment widget ordering.
- [ ] Build per-widget options dialogs for all bar widget types.
- [ ] Build `DockSettingsView` for configuring icon sizes, magnification, and pinned application lists.
- [ ] Implement `DisplayArrangementCanvas` allowing interactive dragging of display rectangles with snap guides.
- [ ] Build `DisplayIdentifyOverlay` flashing large display numbers across active screens.
- [ ] Add `dms bar [list|add|remove]` and `dms display [list|identify]` CLI commands.
