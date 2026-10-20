# 30 — Plugins & Desktop Widgets Specification (`PLUG`)

## 0. Coverage Manifest
- `quickshell/Modules/Plugins/DesktopPluginWrapper.qml` (180 lines) — Desktop surface window host pinning widgets directly to the desktop wallpaper layer beneath normal application windows.
- `quickshell/Modules/Plugins/DesktopWidgetGeometry.qml` (160 lines) — Placement engine: pixel coordinates, screen anchors (`top-left`, `center`, `bottom-right`), margins, and multi-display migration.
- `quickshell/Modules/Plugins/WidgetEditLayer.qml` (280 lines) & `WidgetEditorOverlay.qml` (360 lines) — Fullscreen interactive desktop customization mode:
  - Drag-and-drop widget repositioning
  - Resize handles for scalable widgets
  - Magnetic alignment guide lines (`DesktopWidgetGridLines.qml`)
  - Widget Library catalog drawer for adding clock, weather, system monitor, sticky notes, and media cards
  - In-situ options sheet for configuring individual widget instances
- `quickshell/Modules/Plugins/DesktopWidgetGridLines.qml` (110 lines) & `DesktopWidgetGridHint.qml` (75 lines) — Magnetic grid alignment overlay with snapping guidelines and distance measurements.
- `quickshell/Modules/Plugins/DesktopWidgetContent.qml` (95 lines) & `WidgetEditItem.qml` (140 lines) — Widget slot delegates and selection highlights.
- `quickshell/Modules/Plugins/PluginComponent.qml` (190 lines), `PopoutComponent.qml` (130 lines), `DashCardComponent.qml` (120 lines), `DashTabComponent.qml` (115 lines) — Plugin surface delegates injecting custom components into DankBar, Popouts, Control Center, and DDash tabs.
- `quickshell/Modules/Plugins/PluginSettings.qml` (210 lines) & Schema Fields (`ToggleSetting.qml`, `SliderSetting.qml`, `ColorSetting.qml`, `StringSetting.qml`, `SelectionSetting.qml`, `ListSetting.qml`) — Declarative settings renderer constructing native UI from plugin JSON schemas.
- `quickshell/Modules/Settings/DesktopWidgetsTab.qml` (240 lines) & `DesktopWidgetBrowser.qml` (130 lines) — Settings management page for enabled desktop widgets.
- `core/internal/server/plugins/*` (12 files) — Plugin daemon: lifecycle management (install, unpack, activate, deactivate, uninstall), manifest validation (`plugin.json`), versioning, and auto-update polling.
- `core/internal/server/registries/*` (3 files) — Central DMS Community Plugin Registry client fetching metadata, ratings, and tarball downloads.

---

## 1. Purpose & User-Visible Behavior
DMS provides a full-fledged desktop widget system (placing interactive cards directly on your wallpaper) combined with an extensible third-party plugin architecture.

Key user-visible behaviors include:
1. **Interactive Desktop Widgets**:
   - Widgets reside permanently on the desktop canvas behind active application windows.
   - Click-through mode (`clickThrough: true`) allows widgets to be purely visual without intercepting clicks meant for desktop files.
   - "Show on Overview Only" mode renders widgets only during Mission Control / Window Overview gestures.
2. **Visual Desktop Widget Customizer (Edit Mode)**:
   - Entering edit mode reveals a semi-transparent grid overlay with magnetic snap guides.
   - Users can drag widgets freely, resize them, delete them, or open their configuration sheets.
   - A floating "Add Widget" drawer lets users browse built-in and plugin widgets with live previews.
3. **Pluggable Shell Architecture**:
   - Plugins can inject custom pills into DankBar, custom tiles into Control Center, custom cards into DDash, or standalone popout dialogs.
   - Plugin settings are auto-generated into Material Design 3 forms based on declarative JSON schema types.
4. **Community Plugin Store**:
   - Users can browse, search, install, and update plugins directly from the DMS Settings UI or CLI.

---

## 2. Layout & Visual Tokens
- **Desktop Grid**:
  - Grid unit cell: 40x40 pt.
  - Snap threshold: 12 pt magnetic distance.
  - Guide lines: 1 pt dotted stroke `Theme.primary` (alpha 0.4).
- **Widget Canvas Window**:
  - Attached to `kCGDesktopWindowLevel` / `NSWindow.Level.desktop`.
- **M3 Elevation & Styling**:
  - Edit mode toolbar: Floating Action Button (FAB) bar anchored to the bottom center of the screen with `Theme.elevationLevel3`.
  - Selection ring: 2 pt solid `Theme.primary` border with corner circular resize handles (10 pt radius).

---

## 3. Internal Logic & State Management
- **Widget Instance Storage**:
  - Active desktop widgets serialized to `SettingsData.desktopWidgets` array:
    ```json
    [
      {
        "id": "uuid-1234",
        "type": "clockWidget",
        "screen": "all",
        "x": 120,
        "y": 140,
        "width": 320,
        "height": 180,
        "clickThrough": false,
        "showOnOverviewOnly": false,
        "config": { "showSeconds": true }
      }
    ]
    ```
- **Plugin Manifest (`plugin.json`)**:
  - Defines `id`, `name`, `version`, `author`, `entrypoints` (`barWidget`, `ccTile`, `dashCard`, `desktopWidget`), and `settingsSchema`.

---

## 4. Configuration Schema
| Settings Key | Type | Default | Description |
|---|---|---|---|
| `desktopWidgets.enabled` | bool | `true` | Master toggle for desktop widgets |
| `desktopWidgets.gridSnap` | bool | `true` | Enable magnetic snap to grid |
| `desktopWidgets.gridSize` | int | `40` | Grid cell dimension in points |
| `desktopWidgets.instances` | array | `[]` | List of configured widget instances |
| `plugins.enabled` | bool | `true` | Master plugin engine switch |
| `plugins.autoUpdate` | bool | `true` | Automatically check for plugin updates |

---

## 5. IPC / CLI API
| Command | Arguments | Returns | Description |
|---|---|---|---|
| `dms plugin list` | `--installed, --json` | `json` | Lists available / installed plugins |
| `dms plugin install <id>` | `id: string` | `bool` | Installs plugin from registry or URL |
| `dms plugin remove <id>` | `id: string` | `bool` | Uninstalls plugin |
| `desktopWidgets.editMode` | `enabled: bool` | `void` | Toggles interactive desktop edit overlay |
| `desktopWidgets.add` | `type: string, x: int, y: int`| `string` | Instantiates widget on desktop |

---

## 6. macOS Mapping
- **Desktop Window Layer**:
  - In AppKit, create a borderless transparent `NSWindow` with `level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))` (or `.belowNormal`) so it sits directly above the wallpaper and desktop icons, but below all application windows.
  - Set `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`.
  - For `clickThrough = true`, set `ignoresMouseEvents = true`.
- **Plugin Sandboxing**:
  - Plugins packaged as JavaScript / WASM or Swift bundles loaded into isolated execution contexts.

---

## 7. Port Audit
| Upstream File / Subsystem | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `quickshell/Modules/Plugins/Desktop*` (10 files) | Absent | **Missing (0%)** | Port has ZERO desktop widget support. No desktop-level window, no widget positioning, no magnetic grid snapping, and no desktop visual customizer. |
| `WidgetEditLayer.qml` & `WidgetEditorOverlay.qml` | Absent | **Missing (0%)** | No on-desktop visual drag-and-drop layout canvas exists. |
| Declarative Plugin Settings Renderer | Absent | **Missing (0%)** | Port has basic `PluginService.swift` / `PluginModel.swift` but cannot render dynamic setting controls from JSON schemas. |
| Community Plugin Registry Client | Absent | **Missing (0%)** | No CLI or GUI registry browsing or installation. |

---

## 8. Reimplementation Checklist
- [ ] Create `DesktopWidgetWindowController` (`NSWindow` at desktop window level) spanning active displays.
- [ ] Implement `DesktopWidgetEditOverlay` with interactive dragging, magnetic grid lines, and resize handles.
- [ ] Implement declarative settings form generator mapping plugin JSON schemas to SwiftUI input controls.
- [ ] Implement JSON persistence for configured desktop widget instances.
- [ ] Add `dms plugin [list|install|remove]` to CLI.
