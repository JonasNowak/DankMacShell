# COMP — Compositor Abstraction, Workspaces, Window Tracking & Window Rules Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Compositor Abstraction Layer (`CompositorService.qml`, 2,237 lines; `NiriService.qml`, 1,928 lines; `HyprlandService.qml`, 1,054 lines), Workspace Models (`WorkspaceModel.js`, `WorkspaceSwitcherModel.qml`), Window Tracking (`WindowModel.js`, `FocusedApp.qml`), Workspace Overlays (`Modules/WorkspaceOverlays/*`), and Window Rules Engine (`WindowRulesTab.qml`, `WindowRuleEditorDialog.qml`, 1,544 lines).

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `quickshell/Services/CompositorService.qml` | 2,237 | Unified compositor abstraction: detection, workspaces, windows, overview |
| `quickshell/Services/NiriService.qml` | 1,928 | Niri scrollable tiling compositor IPC client and event parser |
| `quickshell/Services/HyprlandService.qml` | 1,054 | Hyprland socket2 event listener, dispatch commands, workspace sync |
| `quickshell/Services/MangoService.qml` | 812 | MangoWC / DWL compositor IPC client |
| `quickshell/Services/LabwcService.qml` | 15 | Labwc compositor integration |
| `quickshell/Common/WorkspaceModel.js` | 644 | Workspace indexing, naming algorithms, and sorting across monitors |
| `quickshell/Common/WindowModel.js` | 192 | Window normalization: app_id, title, active, urgent, floating states |
| `quickshell/Widgets/WorkspaceSwitcherModel.qml` | 239 | Bar workspace switcher item delegate model |
| `quickshell/Modules/WorkspaceOverlays/` | 4 files | Compositor workspace overview overlays and thumbnail cards |
| `quickshell/Modules/DBar/Widgets/WorkspaceSwitcher.qml` | 220 | DankBar workspace switcher pill (scroll to switch, urgent dots) |
| `quickshell/Modules/DBar/Widgets/FocusedApp.qml` | 140 | Active window title and application icon pill |
| `quickshell/Modules/Settings/WindowRulesTab.qml` | 692 | Window rules list and management interface |
| `quickshell/Modules/Settings/WindowRuleEditorDialog.qml` | 1,544 | Rule editor modal (match criteria: app_id, title; actions: workspace, float) |
| `core/internal/server/wayland/` | 3,093 | Go backend for Wayland compositor protocol handling |
| `core/internal/windowrules/` | 3,081 | Window rules compiler and compositor config injector |

---

## 1. Purpose & User-Visible Behavior

1. **Unified Workspace Engine**:
   - Presents a consistent workspace switcher regardless of backend: numbered pills, named labels, active highlights, and orange urgent indicators for apps requesting attention.
   - **Scroll-to-Switch**: Scrolling on the workspace switcher smoothly cycles through active spaces.
2. **Focused Window Pill (`FocusedApp.qml`)**:
   - Displays the active application's high-res icon and truncated window title in the bar.
   - Right-clicking opens `FocusedWindowContextMenu` (Close, Minimize, Toggle Floating, Move to Workspace).
3. **Window Rules Engine**:
   - Users can define rules matching applications by identifier or title regex to:
     - Automatically route an app to a specific workspace.
     - Force floating or tiled mode.
     - Set initial window opacity, borders, or default size.

---

## 2. Detailed Requirements

### 2.1. Workspace Switching (`WorkspaceSwitcher.qml`)
- `COMP-001`: Workspace model fields:
  - `id`: String identifier.
  - `number`: 1-based integer index.
  - `name`: Custom label or stringified number.
  - `isCurrent`: Boolean (active workspace on screen).
  - `hasWindows`: Boolean.
  - `isUrgent`: Boolean (window demands attention).
- `COMP-002`: Scroll behavior: Scroll down advances to next space; scroll up returns to previous space.

### 2.2. Window Rules Model (`WindowRuleEditorDialog.qml`)
- `COMP-003`: Match criteria: `appId` (exact or regex), `title` (regex), `initialClass`.
- `COMP-004`: Action properties: `workspace` (target space number), `floating` (bool), `opacity` (0.0 to 1.0), `border` (bool).

---

## 3. Wayland/Linux Mechanisms → macOS Mapping

1. **Compositor Workspaces (Hyprland / Niri / Sway)**:
   - Linux compositors provide rich IPC sockets.
   - **macOS Approach**: Map macOS Mission Control **Spaces**:
     - Read Spaces: Private SkyLight framework `CGSCopyManagedDisplaySpaces(_CGSDefaultConnection())`.
     - Active Space: Observe `NSWorkspace.activeSpaceDidChangeNotification`.
     - Switch Space: Invoke SkyLight `CGSSetWorkspaceWithOptions()` or synthesize keyboard shortcuts (Ctrl+Left / Ctrl+Right) via Accessibility API.
2. **Window Tracking & Focused App**:
   - Linux uses `zwlr_foreign_toplevel_manager_v1`.
   - **macOS Approach**:
     - Active App: Observe `NSWorkspace.didActivateApplicationNotification`.
     - Window Title: Query Accessibility API (`AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute, ...)` -> `kAXTitleAttribute`).
     - Window List: `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)`.
3. **Window Rules**:
   - macOS window positioning is application-controlled.
   - **macOS Approach**: Implement an Accessibility API observer (`AXObserver`) that detects when newly launched windows appear (`kAXWindowCreatedNotification`), matching `bundleIdentifier` against user rules, and setting frame size/position via `AXUIElementSetAttributeValue`.

---

## 4. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| `COMP-001` - `002` | **Partial** | `WorkspaceService.swift` (210 lines) | Reads active space index, but lacks per-monitor spaces tracking, custom workspace naming, and urgent indicators. |
| Focused App | **Partial** | `RunningAppsService.swift` | Reads active app name, but lacks live window title extraction via Accessibility API. |
| `COMP-003` - `004` | **Missing** | None | **Window rules engine does not exist in the port**. `WindowRuleEditorDialog` and auto-positioning rules are completely missing. |

### Audit Verdict:
The port implements basic Space switching via SkyLight, but **lacks window title tracking and omits the entire Window Rules engine**. Parity: **~25%**.

---

## 5. Reimplementation Checklist

- [ ] Implement `AccessibilityWindowTracker.swift` reading live focused window titles and active windows.
- [ ] Implement `WindowRulesEngine.swift` observing `kAXWindowCreatedNotification` to apply user-defined rules.
- [ ] Add workspace naming and urgent indicator badges to `WorkspaceSwitcherView.swift`.
