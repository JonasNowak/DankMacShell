# 24 — Dynamic Island & Surface Widgets Specification (`ISLAND`)

## 0. Coverage Manifest
- `quickshell/Modules/DIsland/DIsland.qml` (492 lines) — Master Island instance registry, screen management, IPC routing (`island.move`, `island.center`, `island.toggle`, `island.openActivity`), host slot coordination.
- `quickshell/Modules/DIsland/DIslandHostWindow.qml` (150 lines) — Wayland layer-shell / AppKit window wrapper for anchored top/bottom notch islands.
- `quickshell/Modules/DIsland/DIslandSurface.qml` (844 lines) — The core morphing canvas, spring coordinate translation, anchor math, geometry tracking, and clipping masks.
- `quickshell/Modules/DIsland/IslandBarHost.qml` (545 lines) — Bar integration host when Island is embedded directly inside a DankBar band rather than floating.
- `quickshell/Modules/DIsland/IslandContentHost.qml` (394 lines) — Content delegate switcher managing cross-fades and layout swapping between compact and expanded activity states.
- `quickshell/Modules/DIsland/IslandController.qml` (1,061 lines) — Complete state machine governing island expansion (`hoverExpanded`, `keyboardYielded`, `interactionMode`), slot hover timeouts, media priority switching, and activity routing.
- `quickshell/Modules/DIsland/IslandFreeHostWindow.qml` (236 lines) & `IslandFreeDragArea.qml` (81 lines) — Free-floating window mode with interactive mouse dragging, multi-monitor migration, and anchor coordinate persistence.
- `quickshell/Modules/DIsland/IslandHostChrome.qml` (19 lines) & `IslandHostRegistry.qml` (32 lines) — Host container decoration, shadow styling, and singleton registry.
- `quickshell/Modules/DIsland/IslandMediaSource.qml` (10 lines), `IslandNotificationSource.qml` (170 lines), `IslandSystemSource.qml` (244 lines) — Reactive data feeder pipes providing audio track telemetry, transient notification banners, and hardware metrics (volume, brightness, battery).
- `quickshell/Modules/DIsland/Activities/*` (19 files) — Compact and expanded view faces:
  - `HomeCompact.qml` (557 lines) & `HomeExpanded.qml` (34 lines) — Default idle status pill (clock, battery icon, workspace dots, active app icon) and quick launcher tray.
  - `MediaCompact.qml` (33 lines) & `MediaExpanded.qml` (15 lines) — Compact equalizer visualizer + track title, expanding into full playback controls, artwork thumbnail, and scrub bar.
  - `NotificationCompact.qml` (90 lines) & `NotificationExpanded.qml` (144 lines) — Transient notification heads-up pill with app icon and title, expanding into interactive notification card with action buttons.
  - `ControlCenterExpanded.qml` (190 lines) — Quick toggle surface embedded inside the expanded island.
  - `SystemLevelCompact.qml` (150 lines) & `SystemLevelExpanded.qml` (79 lines) — Volume, brightness, and battery gauge indicators responding to OSD events.
  - `LauncherExpanded.qml` (98 lines) — Compact launcher search bar integrated directly within island geometry.
  - `ClipboardExpanded.qml` (87 lines) — Quick clipboard entry preview and selection sheet.
  - `PowerMenuExpanded.qml` (76 lines) — Shutdown, restart, lock, suspend controls.
  - `WallpaperExpanded.qml` (49 lines) & `WeatherExpanded.qml` (20 lines) — Live wallpaper thumbnail cycler and weather forecast card.
  - `DashTabFace.qml` (264 lines), `DestinationCompact.qml` (101 lines), `DotCompact.qml` (34 lines), `SystemStateCompact.qml` (30 lines), `NotificationCenterExpanded.qml` (20 lines), `IslandSlotHoverArea.qml` (33 lines).
- `quickshell/Modules/SurfaceWidgets/*` (14 files):
  - `VectorSpringMotion.qml` (201 lines) — 240 Hz physical spring integration engine simulating 8 degrees of freedom (width, height, offset along, offset cross, 4 individual corner radii).
  - `MorphSurface.qml` (12 lines) — Dynamic rectangle clipping mask matching spring motion coordinates.
  - `SurfaceWidgetFactory.qml` (971 lines) — Dynamic component loader instantiating bar pills, media faces, and application items.
  - `SurfaceStrip.qml` (533 lines) & `ApplicationStrip.qml` (452 lines) — Horizontal running app strip with active window indicators and icon scaling.
  - `BarPill.qml` (341 lines), `SurfaceWidgetHost.qml` (185 lines), `SurfaceContext.qml` (105 lines), `ApplicationItem.qml` (211 lines), `ApplicationModel.js` (65 lines), `GothCorner.qml` (62 lines), `MediaActivityFace.qml` (253 lines), `MediaActivity.qml` (24 lines), `MediaActivitySource.qml` (17 lines).

---

## 1. Purpose & User-Visible Behavior
The Dynamic Island (`DIsland`) is a shape-shifting, interactive status and notification hub that sits either attached to the screen edge (matching physical display notches or top bars) or floating freely on the desktop (`freeMode`).

Key user-visible behaviors include:
1. **Interactive Morphing Geometry**:
   - In its idle compact state, the Island is a small pill (~176x42 px) displaying the current time, battery percentage, or active application icon.
   - When media starts playing, it smoothly springs into a media pill with a live animated audio frequency waveform and track title.
   - When a system notification arrives, it expands into a notification banner showing sender, icon, and body preview.
   - When volume or brightness hotkeys are pressed, it expands temporarily into an OSD bar with an animated level gauge.
2. **Hover and Click Expansion**:
   - Hovering over a slot or clicking the pill triggers a smooth physics expansion into a rich interactive card (media controller, control center grid, clipboard manager, or quick launcher).
   - Mouse departure smoothly collapses the Island back to compact state after a configurable cooldown (`hoverCloseDelay: 400ms`).
3. **Free-Floating & Free-Dragging Mode**:
   - When detached from the bar, the Island can be dragged anywhere on screen using a gesture handle.
   - Snaps to display borders with a configurable margin (`freeMargin: 8px`).
   - Coordinates (`anchorX`, `anchorY`, display ID) are saved in settings and restored across restarts.
4. **Desktop Notch Integration**:
   - On MacBook displays with a hardware camera notch, the Island anchors flush against the notch bezel, perfectly concealing the cutout while expanding downward or horizontally.

---

## 2. Layout & Visual Tokens
- **Base Dimensions**:
  - `compactWidth`: 176 pt, `compactHeight`: 42 pt.
  - `expandedWidth`: 380 pt to 640 pt depending on active activity.
  - `expandedHeight`: 120 pt to 460 pt (ControlCenter/Clipboard).
- **Corner Radii**:
  - Compact: `pillRadius = 21 pt` (fully rounded capsule).
  - Expanded: `cornerRadius = 34 pt`.
  - Notch-anchored top edge: `topCornerRadius = 0 pt` (square against display top).
  - Reverse Gothic concave corners (`GothCorner.qml`): `radius: 12 pt` bridging island edges to the top screen bezel.
- **Physics Constants** (`VectorSpringMotion.qml`):
  - `stiffness`: 560
  - `damping`: 37
  - `mass`: 1.0
  - `positionEpsilon`: 0.035 pt
  - `velocityEpsilon`: 0.035 pt/s
  - `integrationStep`: 1/240 s (4.16 ms RK4 physics tick)
- **M3 Elevation & Tone**:
  - Surface base: `Theme.hostSurface` (M3 Surface Container High, rgba with 0.85 opacity).
  - Border: 1 pt `Theme.surfaceVariant` border with 0.12 opacity.
  - Drop shadow: Gaussian blur 24 pt, y-offset 8 pt, opacity 0.35.

---

## 3. Internal Logic & State Management
- **State Machine** (`IslandController.qml`):
  - States: `Idle`, `CompactMedia`, `CompactNotification`, `CompactOSD`, `ExpandedHome`, `ExpandedMedia`, `ExpandedNotification`, `ExpandedControlCenter`, `ExpandedClipboard`.
  - Priority Arbitration: `OSD Level` (highest, 3s timeout) > `Notification Alert` (5s timeout) > `Media Playback` (persistent if playing) > `Home Idle`.
  - Input Handling: Keyboard focus yielded to launcher/clipboard when expanded; automatically reclaimed on dismiss.

---

## 4. Configuration Schema
| Settings Key | Type | Default | Description |
|---|---|---|---|
| `island.enabled` | bool | `true` | Master toggle for Dynamic Island |
| `island.mode` | string | `"bar"` | `"bar"`, `"notch"`, or `"free"` |
| `island.edge` | string | `"top"` | Placement edge (`top`, `bottom`) |
| `island.anchorX` | real | `0.5` | Normalized X anchor position on screen |
| `island.anchorY` | real | `0.0` | Normalized Y anchor position on screen |
| `island.springStiffness` | real | `560` | Spring physics tension |
| `island.springDamping` | real | `37` | Spring physics friction |
| `island.hoverExpand` | bool | `true` | Expand on mouse hover |
| `island.hoverDelayMs` | int | `350` | Hover dwell delay before expanding |

---

## 5. IPC / CLI API
| Command | Arguments | Returns | Description |
|---|---|---|---|
| `island.toggle` | `[activity?: string]` | `bool` | Toggles island expansion |
| `island.openActivity` | `activity: string` | `void` | Expands island into specific activity |
| `island.close` | `none` | `void` | Collapses island to compact pill |
| `island.move` | `x: real, y: real, screen?: string`| `string` | Moves free-floating island |
| `island.center` | `screen?: string` | `string` | Centers free island on screen |

---

## 6. macOS Mapping
- **Window Architecture**: Dedicated borderless `NSPanel` (`.statusBar` or `.floating` window level) with transparent background and non-activating panel behavior (`NSWindow.CollectionBehavior.canJoinAllSpaces | .fullScreenAuxiliary`).
- **MacBook Notch Integration**: Query `NSScreen.auxiliaryTopLeftArea` and `auxiliaryTopRightArea`. If non-nil, align `DIslandHostWindow` between the auxiliary screen areas to seamlessly wrap the MacBook camera notch.
- **Spring Animation Engine**: Implement `VectorSpringMotion` in Swift using a `CADisplayLink` driving an 8-DOF Runge-Kutta 4th order integrator, or leverage SwiftUI's `.spring(response: 0.38, dampingRatio: 0.72)`.

---

## 7. Port Audit
| Upstream File / Subsystem | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `quickshell/Modules/DIsland/**` (33 files) | Absent | **Missing (0%)** | The port has no Dynamic Island window, controller, or activities. It only has a static text label "Dynamic Island" in `DankBarView.swift`. |
| `quickshell/Modules/SurfaceWidgets/**` (14 files) | Absent | **Missing (0%)** | Vector spring physics engine (`VectorSpringMotion.qml`), 8-DOF morphing surfaces, and running app strips are completely absent. |
| Notch detection & bridging | Absent | **Missing (0%)** | No detection of MacBook notch hardware or concave gothic corner smoothing. |

---

## 8. Reimplementation Checklist
- [ ] Create `DIslandHostWindow` (`NSPanel`) supporting bar-docked, notch-aligned, and free-floating modes.
- [ ] Implement `VectorSpringEngine` with 8 degrees of freedom simulating width, height, position, and 4 corner radii at display refresh rate.
- [ ] Implement `IslandController` state machine arbitrating between idle, media, OSD, and notification events.
- [ ] Port all 19 activity views (Compact Media, Expanded Media, OSD Gauges, Notification heads-up, Quick Clipboard, Control Center).
- [ ] Implement free-dragging gesture recognizer with desktop margin snapping and persistent settings storage.
- [ ] Add MacBook notch geometry detection via AppKit `NSScreen` safe area insets.
