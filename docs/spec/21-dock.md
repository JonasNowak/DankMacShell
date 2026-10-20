# 21 — Desktop Dock Specification (`DOCK`)

## 0. Coverage Manifest
- `quickshell/Modules/Dock/Dock.qml` — Multi-screen layer-shell dock surface host, layer toggle (Overlay during edit mode or when `useOverlayLayer` is set, else Top), edge exclusions, connected frame chrome integration, and input mask routing.
- `quickshell/Modules/Dock/DockBody.qml` (939 lines) — Core dock container, VectorSpringMotion surface physics (`VectorSpringMotion`), inline widget strip & app provider loader (`BarWidgets.AppsDock`), auto-hide/smart-auto-hide edge trigger zones, edit mode overlay with scrim, and widget expansion host.
- `quickshell/Modules/Dock/DockAppButton.qml` (681 lines) — Dock application icon item, running/focused state dot & bar indicators, grouping badge (up to 4 dots), drag-and-drop reordering with axis hysteresis, long-press handling, and hover scale animations.
- `quickshell/Modules/Dock/DockHoverBounce.qml` — Two-phase hover bounce physics animation (`emphasizedAccel` peak followed by `emphasizedDecel` settling) with directional displacement based on dock edge.
- `quickshell/Modules/Dock/DockGeometry.qml` — Geometric metrics solver, reservation insets for connected frame chrome, edge exclusion calculations, dpr normalization, and margin/gap compensation.
- `quickshell/Modules/Dock/DockEditChrome.qml` — Floating interactive edit bar shown during dock edit mode, offering "Add Widget", "Settings", and "Done" actions with keyboard focus traps.
- `quickshell/Modules/Dock/DockOverflowButton.qml` — Dynamic chevron indicator button shown when pinned/running apps exceed `maxVisibleApps`, toggling the overflow popout tray.
- `quickshell/Modules/Dock/DockLauncherButton.qml` — Dedicated application launcher icon slot for the dock with secondary right-click action for overview toggle.
- `quickshell/Modules/Dock/DockTrashButton.qml` — Integrated trash bin launcher slot with empty vs. full icon morphing and item count badge tooltip.
- `quickshell/Modules/Dock/DockContextMenu.qml` — Wayland popout context menu for dock apps: launch new window, pin/unpin toggle, app window list, force quit, and settings jump shortcuts.
- `quickshell/Modules/Dock/DockContextMenuBase.qml` — Shared base surface for dock contextual menus with screen bounding box collision prevention.
- `quickshell/Modules/Dock/DockTrashContextMenu.qml` — Specialized context menu for trash button ("Open Trash", destructive "Empty Trash (N)").
- `quickshell/Modules/Dock/DockTrashMenuItem.qml` — Standardized menu row item supporting destructive color highlighting on hover.
- `quickshell/Common/settings/DockConfig.js` — Dock configuration schema, multi-dock screen edge allocation solver (`resolveEdge`, `resolveAll`), magnification physics curves (`parabolic`, `gaussian`, `cosine`), and unit reordering logic (`unitList`, `unitOrder`, `unitTarget`).
- `quickshell/Modules/Settings/Widgets/DockSelectionState.qml` — UI selection state for multi-dock management in settings.
- `quickshell/Modules/Settings/DockGeneralTab.qml`, `DockAppearanceTab.qml`, `DockWidgetsTab.qml`, `DockAdvancedTab.qml`, `DockHubHeader.qml` — Dock configuration inspector panels.
- `quickshell/Modules/Frame/FrameDockHost.qml` — Integrated host when dock is embedded directly inside the desktop frame border.
- `quickshell/Modules/DBar/Widgets/AppsDock.qml` & `quickshell/Modules/DankBar/Widgets/AppsDock.qml` — Bar-hosted variant of the apps dock engine.

---

## 1. Purpose & User-Visible Behavior
The Desktop Dock provides a floating, auto-hiding, or frame-connected application launcher, taskbar, and widget strip positioned along any screen edge (Bottom, Top, Left, Right).

Key user-visible behaviors include:
1. **Dynamic Placement & Multi-Dock**: Users can configure independent dock instances per monitor edge. Each screen can have 0 to 4 docks simultaneously.
2. **Compact vs Taskbar Mode**: In `compact` mode, the dock shrinks or grows dynamically to envelope its contents with spring physics. In `taskbar` mode, it stretches across the full display edge with customizable alignment (`start`, `center`, `end`).
3. **Magnification Engine**: Moving the mouse over the dock smoothly scales hovered and adjacent icons according to mathematical magnification profiles (`parabolic`, `cosine`, `gaussian`) up to 160% scale.
4. **App States & Indicators**:
   - Pinned apps show icon only.
   - Running apps show an indicator (`dot` or `line`).
   - Multiple windows for an app show up to 4 grouped indicator dots.
   - The focused active window expands its indicator dot into an elongated pill (`baseWidth * 3`).
5. **Interactive Reordering & Drag-and-Drop**: Dragging icons smoothly pushes siblings aside using middle-threshold hysteresis math (`unitTarget`).
6. **Edit Mode Chrome**: Right-clicking or triggering edit mode expands the window to capture clicks, displays a floating `DockEditChrome` pill ("Add Widget", "Settings", "Done"), and enables widget removal buttons and drag handles.
7. **Hover Bounce**: Hovering an unsuppressed dock icon triggers a playful two-stage bounce animation toward the display center.
8. **Auto-Hide & Smart Auto-Hide**: Hides when windows overlap the dock area or when mouse leaves, exposing an invisible edge trigger zone that smoothly slides the dock into view.
9. **Trash & Overflow Trays**: Dedicated trash icon with real-time fullness state and an overflow chevron button when open apps exceed user limits.

---

## 2. Architecture & Data Flow

```
                        ┌───────────────────────────────┐
                        │   SettingsData.dockConfigs    │
                        └───────────────┬───────────────┘
                                        │
                         DockConfig.resolveEdge(...)
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Dock.qml (PanelWindow Variants per Screen & Edge)                          │
│                                                                             │
│  WlrLayershell.layer: body.editMode || useOverlayLayer ? Overlay : Top      │
│  WindowBlur: Target blur with animated corner radii                         │
│  EdgeExclusion: Dynamic reserve zone based on autoHide & frame chrome       │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ DockBody.qml                                                          │  │
│  │                                                                       │  │
│  │  VectorSpringMotion: Animates width, height, and 4 corner radii      │  │
│  │  SlideSpring: Animates slide-in / slide-out on auto-hide edge         │  │
│  │                                                                       │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │ Widget / App Strip (Flow / Row / Column)                        │  │  │
│  │  │                                                                 │  │  │
│  │  │  [DockLauncherButton]                                           │  │  │
│  │  │  [DockAppButton] (App 1 - Running, 1 dot)                       │  │  │
│  │  │  [DockAppButton] (App 2 - Focused, expanded pill)               │  │  │
│  │  │  [DockAppButton] (App 3 - Grouped, 3 dots)                      │  │  │
│  │  │  [DockOverflowButton] (Chevron if count > maxVisibleApps)       │  │  │
│  │  │  [DockTrashButton] (Empty/Full state, count badge)              │  │  │
│  │  │  [Embedded Surface Widgets...] (Clock, Weather, Controls)       │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                       │  │
│  │  [DockEditChrome] (Visible in Edit Mode: Add, Settings, Done)         │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ├──────────► DockContextMenu (App actions, Quit, Pin)
                                  └──────────► DockTrashContextMenu (Open, Empty)
```

---

## 3. Detailed Requirements

### Configuration & Multi-Dock Engine (`DOCK-CFG`)
- `DOCK-CFG-001`: Each dock instance must be uniquely identified by `id` (e.g. `"dock"`, `"dock_1700000000"`) and configured via `DockConfig.create(id, name)`.
- `DOCK-CFG-002`: The multi-dock solver (`DockConfig.resolveEdge`) must allow assigning docks to specific monitors (`screenPreferences: ["all"]`, screen name, or monitor model), with fallback to single-display environments.
- `DOCK-CFG-003`: Each display edge (`top`, `bottom`, `left`, `right`) may host at most one active dock.
- `DOCK-CFG-004`: The layout mode must support both `"compact"` (dynamic shrink-wrap pill with animated vector springs) and `"taskbar"` (edge-to-edge bar with alignment `"start"`, `"center"`, or `"end"`).
- `DOCK-CFG-005`: Effective thickness must be derived dynamically as `config.iconSize + config.spacing * 2`. Thickness must never be hardcoded.

### Magnification Physics Engine (`DOCK-MAG`)
- `DOCK-MAG-001`: When `config.magnification` is enabled, icon size dynamically scales up to `config.magnificationScale` (between 105% and 160%, default 130%).
- `DOCK-MAG-002`: Proximity influence radius must be computed per `DockConfig.magnificationRadius(baseSize, profile)`:
  - `"parabolic"`: `baseSize * 1.8`
  - `"gaussian"`: `baseSize * 2.2`
  - `"cosine"`: `baseSize * 2.5`
- `DOCK-MAG-003`: Magnification decay factor $F(d)$ for distance $d \in [0, R]$ must follow exact formulas (`DockConfig.magnificationFactor`):
  - If $d \ge R$, $F(d) = 0$.
  - Let $u = \frac{d}{R}$.
  - `"cosine"`: $F(u) = 0.5 \times (1 + \cos(\pi u))$
  - `"gaussian"`: $F(u) = \frac{\exp(-3 u^2) - \exp(-3)}{1 - \exp(-3)}$
  - `"parabolic"`: $F(u) = 1 - u^2$
- `DOCK-MAG-004`: When `magnificationExpand` is true, the dock bounding container must dynamically expand its primary and cross dimensions to contain magnified icons without clipping.

### Hover Bounce Animation (`DOCK-BNC`)
- `DOCK-BNC-001`: On mouse enter, an icon must trigger a two-phase sequential bounce (`DockHoverBounce.qml`):
  1. Offset to `direction * distance * 0.25` using `Anims.emphasizedAccel` (`[0.05, 0.7, 0.1, 1.0]`) over `Anims.durShort` (150ms).
  2. Offset settling to `direction * distance * 0.20` using `Anims.emphasizedDecel` (`[0.05, 0.9, 0.1, 1.0]`) over `Anims.durShort` (150ms).
- `DOCK-BNC-002`: On mouse leave, offset must animate back to `0` via `exit` animation over `Theme.shortDuration` (150ms).
- `DOCK-BNC-003`: `direction` must be `+1` for `Top` or `Left` docks, and `-1` for `Bottom` or `Right` docks (always bouncing toward screen center).
- `DOCK-BNC-004`: Bounce must be suppressed when the item is pressed/dragged or when `Theme.springMotionDisabled` is set.

### Running & Focus Indicators (`DOCK-IND`)
- `DOCK-IND-001`: Running state indicators must support two styles: `"circle"` (dots) and `"line"` (bars).
- `DOCK-IND-002`: For `"circle"` style:
  - Normal running dot: width and height equal to $\max(4, \text{actualIconSize} \times 0.10)$.
  - Focused window dot: width expands to $\text{baseWidth} \times 3$, corner radius $\frac{\text{height}}{2}$.
  - Color transitions from `Theme.surfaceTextSecondary` (unfocused) to `Theme.primary` (focused) with `shortDuration` (150ms).
- `DOCK-IND-003`: For `"line"` style:
  - Width: $\max(6, \text{actualIconSize} \times 0.20)$ for single window; $\max(3, \text{actualIconSize} \times 0.10)$ for grouped windows.
  - Height: $\max(2, \text{actualIconSize} \times 0.05)$.
  - Focused line: width expands to $\text{baseWidth} \times 3$.
- `DOCK-IND-004`: Grouped windows must display up to 4 individual dots representing separate open windows of that app.
- `DOCK-IND-005`: When `indicatorAtFarEdge` is true, indicators position along the screen-adjacent edge inside the dock padding lane (`DockConfig.indicatorLane(config)` = $\max(8, \text{round}(\text{iconSize} \times 0.18))$).

### Drag-and-Drop Reordering Engine (`DOCK-DND`)
- `DOCK-DND-001`: Dragging an icon along the dock axis must track cursor displacement `dragAxisOffset` with drag initiation threshold of 6px.
- `DOCK-DND-002`: Neighbor unit swap target must be computed using `DockConfig.unitTarget(spans, id, offset)`:
  - Target changes when icon's leading/trailing edge crosses the midpoint $\frac{\text{start} + \text{end}}{2}$ of a neighboring unit span.
- `DOCK-DND-003`: Non-dragged sibling items must smoothly shift their visual position using Bezier displacement animations to preview the new layout slot.
- `DOCK-DND-004`: Dropping updates `config.order` in `SettingsData` and reorganizes pinned apps in `strip.pinnedApps` via `DockConfig.reorderPins`.

### Auto-Hide & Smart Auto-Hide (`DOCK-HIDE`)
- `DOCK-HIDE-001`: When `autoHide` is enabled, the dock slides completely off-screen along its anchor edge when the mouse leaves.
- `DOCK-HIDE-002`: An invisible edge trigger zone (thickness 2px) remains active along the display edge. Moving the mouse into this zone reveals the dock.
- `DOCK-HIDE-003`: When `smartAutoHide` is enabled, the dock stays visible until an application window overlaps the dock's geometric screen rectangle, at which point it hides.
- `DOCK-HIDE-004`: Slide motion must use spring dynamics (`stiffness: 400`, `damping: 32`) or animated translation off-edge.
- `DOCK-HIDE-005`: When dock context menu or popout is open, hiding must be suppressed (`interactionActive = true`).

### Edit Mode & Widget Chrome (`DOCK-EDIT`)
- `DOCK-EDIT-001`: Edit mode is toggled via context menu "Edit Dock" or IPC.
- `DOCK-EDIT-002`: During edit mode, the `PanelWindow` expands to fullscreen scrim (`WlrLayershell.layer = Overlay`, `WlrKeyboardFocus.Exclusive`) to intercept all clicks outside the dock.
- `DOCK-EDIT-003`: A floating pill `DockEditChrome.qml` appears offset from the dock containing:
  - Dock title label (`root.title`).
  - "Add Widget" button (`addButton`) triggering the widget selection picker.
  - "Settings" button (`settingsButton`) navigating to Settings -> Dock tab.
  - "Finish" button (`finishButton`) exiting edit mode.
- `DOCK-EDIT-004`: Each widget and app button displays an overlay badge with a delete icon (`close`) and drag handle.
- `DOCK-EDIT-005`: Pressing Escape immediately closes widget library or exits edit mode.

### Context Menus & Actions (`DOCK-CTX`)
- `DOCK-CTX-001`: Right-clicking an app button presents `DockContextMenu`:
  - App Name header with icon.
  - "New Window" (launches fresh instance).
  - List of open windows for this app with title preview; clicking raises and focuses that specific window.
  - "Pin to Dock" / "Unpin from Dock" toggle.
  - For DMS settings shortcut: grouped subpage jumps (`settingsJumpGroups`).
  - "Force Quit" (destructive red action, sends SIGKILL / close request).
- `DOCK-CTX-002`: Right-clicking the trash button presents `DockTrashContextMenu`:
  - "Open Trash" (launches configured file manager or `TrashService.openTrash`).
  - "Empty Trash (N)" (destructive red action with item count confirmation modal).
- `DOCK-CTX-003`: Right-clicking dock background presents dock edit actions: "Edit Dock", "Dock Settings", "Add Widget".

---

## 4. Settings Keys
The dock configuration is governed by `SettingsData.dockConfigs` array, where each item adheres to:

| Key | Type | Default | Valid Range / Options | Description |
|---|---|---|---|---|
| `id` | `string` | `"dock"` | Non-empty string | Unique dock identifier |
| `name` | `string` | `"Dock"` | Any string | Human-readable dock label |
| `enabled` | `bool` | `false` | `true`, `false` | Master visibility toggle |
| `screenPreferences` | `array` | `["all"]` | Monitor names, models, or `"all"` | Target screen bindings |
| `showOnLastDisplay` | `bool` | `true` | `true`, `false` | Fallback to last display if preferred unplugged |
| `position` | `int` | `1` | `0` (Top), `1` (Bottom), `2` (Left), `3` (Right) | Dock display edge |
| `mode` | `string` | `"compact"` | `"compact"`, `"taskbar"` | Content shrink-wrap vs full edge stretch |
| `taskbarAlign` | `string` | `"center"` | `"start"`, `"center"`, `"end"` | Alignment when in taskbar mode |
| `widgetExpansion` | `string` | `"popout"` | `"popout"`, `"inline"` | How widgets expand (popout balloon vs inline bar push) |
| `iconSize` | `int` | `42` | `16` to `96` px | Base icon diameter |
| `spacing` | `int` | `8` | `0` to `128` px | Internal dock surface padding |
| `itemSpacing` | `int` | `8` | `0` to `32` px | Space between adjacent icons |
| `margin` | `int` | `8` | `0` to `128` px | Distance from screen edge |
| `bottomGap` | `int` | `0` | `-128` to `128` px | Secondary offset along cross-axis |
| `transparency` | `real` | `1.0` | `0.0` to `1.0` | Background opacity |
| `autoHide` | `bool` | `false` | `true`, `false` | Slide away when cursor leaves |
| `smartAutoHide` | `bool` | `false` | `true`, `false` | Slide away only when windows intersect dock rect |
| `useOverlayLayer` | `bool` | `false` | `true`, `false` | Force overlay layer above fullscreen apps |
| `indicatorStyle` | `string` | `"circle"` | `"circle"`, `"line"` | Running app indicator shape |
| `magnification` | `bool` | `false` | `true`, `false` | Proximity cursor zoom effect |
| `magnificationScale` | `real` | `130` | `105` to `160` % | Maximum zoom scale at cursor center |
| `magnificationProfile` | `string` | `"parabolic"` | `"parabolic"`, `"gaussian"`, `"cosine"` | Mathematical decay curve |
| `magnificationExpand` | `bool` | `false` | `true`, `false` | Dock bounds dynamically stretch for magnified icons |
| `maxVisibleApps` | `int` | `0` | `0` (unlimited) to `100` | Truncate running apps and show overflow button |
| `showTrash` | `bool` | `false` | `true`, `false` | Show trash can slot |
| `widgets` | `array` | Defaults | Array of widget objects | Active widgets hosted on dock |
| `order` | `array` | `[]` | Array of unit IDs | Custom user-ordered sequence of pins and widgets |

---

## 5. IPC/CLI API
| Method | Arguments | Returns | Description |
|---|---|---|---|
| `dock.toggle` | `[dockId?: string]` | `bool` | Toggles dock visibility on/off |
| `dock.editMode` | `dockId: string, enable: bool` | `void` | Activates or exits dock edit mode with chrome |
| `dock.reveal` | `dockId: string` | `void` | Temporarily slides out an auto-hidden dock |
| `dock.addWidget` | `dockId: string, widgetId: string` | `void` | Appends a widget to the specified dock |
| `dock.removeWidget` | `dockId: string, instanceId: string` | `void` | Deletes a widget instance from dock |
| `dock.reorder` | `dockId: string, order: string[]` | `void` | Updates the item ordering array |

---

## 6. macOS Mapping
- **Window Management**:
  - Wayland `WlrLayershell` translates to `NSPanel` with `NSWindow.Level.dock` or `.statusBar` (or `.screenSaver` for fullscreen Overlay mode).
  - Floating panels must use `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`.
- **Blur & Transparency**:
  - `NSVisualEffectView` with `.behindWindow` material or `CAFilter` gaussian background blur.
- **Auto-Hide Edge Detection**:
  - Local `NSTrackingArea` along screen edge (2px thickness) with `mouseEntered:` and `mouseExited:` handlers.
- **App Icons & Running State**:
  - Running apps queried via `NSWorkspace.shared.runningApplications`.
  - Focused app tracked via `NSWorkspace.shared.frontmostApplication` and `NSWorkspace.didActivateApplicationNotification`.
  - Icon extraction via `NSWorkspace.shared.icon(forFile:)` or bundle identifier.
  - Window count per application queried via Accessibility API (`AXUIElementCopyAttributeValues` for `kAXWindowsAttribute`).
- **Drag-and-Drop**:
  - AppKit drag destination or custom SwiftUI gesture tracking using `.gesture(DragGesture())` with spring reordering offsets.

---

## 7. Port Audit
| File / Feature in Upstream | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `Dock.qml` & `DockBody.qml` | Partially Insp. | **Major Gap** | Port has a basic `DockView.swift` that renders a fixed horizontal row. Missing multi-dock support, vertical dock orientations, taskbar mode, and layer toggles. |
| Magnification Curves (`DockConfig.js`) | Missing | **Absent** | Port does not implement parabolic, cosine, or gaussian proximity magnification curves. |
| Hover Bounce (`DockHoverBounce.qml`) | Missing | **Absent** | Port has no two-stage directional spring bounce on icon hover. |
| Indicators (`DockAppButton.qml`) | Partially Insp. | **Major Gap** | Port shows static dots; missing focused dot-to-pill elongation ($3\times$), grouped 4-dot rendering, and `"line"` style. |
| Edit Mode Chrome (`DockEditChrome.qml`) | Missing | **Absent** | Port lacks interactive edit mode, scrim capture, widget removal badges, and floating edit pill. |
| Overflow Button (`DockOverflowButton.qml`) | Missing | **Absent** | Port has no overflow badge or tray when apps exceed limits. |
| Trash Slot (`DockTrashButton.qml`) | Missing | **Absent** | Port has no integrated trash button with empty/full states or count badges. |
| Multi-Screen Edge Resolver (`resolveEdge`) | Missing | **Absent** | Port binds to main screen only; lacks per-edge multi-monitor resolution. |

---

## 8. Reimplementation Checklist
- [ ] Implement `DockConfig` model in Swift with full normalization, default values, and migration from legacy settings.
- [ ] Implement mathematical magnification engine (`parabolic`, `gaussian`, `cosine`) using proximity distance formulas.
- [ ] Build `DockHoverBounce` directional two-phase spring animation using SwiftUI / CoreAnimation.
- [ ] Implement `DockAppButton` with dot-to-pill elongation on active app focus and grouped window counters.
- [ ] Create `DockEditChrome` floating control bar with widget adder and delete badges.
- [ ] Implement auto-hide and smart auto-hide edge monitors with window intersection tests.
- [ ] Implement Drag-and-Drop icon reordering with live midpoint hysteresis calculations.
- [ ] Add `DockOverflowButton` tray and `DockTrashButton` with empty/empty confirmation modal.
