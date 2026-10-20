# DMS Master Specification: Upstream Architecture, Port Comparison, and Reimplementation Blueprint

> **Upstream Reference**: `AvengeMedia/DankMaterialShell` (commit `699eb237751bc5d61fdf90e1709fb6cabe9896a4`)  
> **Current Port**: `dms-shell` (macOS Native Swift 6 / SwiftUI / AppKit)  
> **Target**: 1-to-1 Functional, Visual, and Architectural Parity for macOS

---

## 1. Executive Summary & Problem Analysis

The `dms-shell` repository was created to bring the unified, Material Design 3 desktop shell experience of **DankMaterialShell (DMS)** to macOS. 

However, a systematic architectural and code-level audit reveals that while certain high-level concepts and rudimentary views were created, **the current macOS port largely presents "vaguely inspired" approximations rather than faithful implementations**. Large, critical subsystems of DMS were either completely omitted, drastically simplified into static placeholders, or implemented without the configurability, dynamic data binding, and precision interactions that define DMS.

### Key Findings of the Port Audit:
1. **DankBar Structural Architecture vs. Static SwiftUI HStack**:
   - **Upstream DMS**: Features a dynamic layout engine (`DBar.qml`, `AxisContext`, `BarSegment`, `SegmentRoles`, `CenterLayout.js`, `OverflowLayout.js`) capable of horizontal and vertical bars on any screen edge, per-monitor independent bar layouts, true-center alignment with collision avoidance, segment grouping with customizable roles, dynamic widget ordering, and over 30 modular bar widgets.
   - **Current Port**: Has a single static `DankBarView.swift` hardcoding a Left/Center/Right layout. It supports only top/bottom placement, lacks multi-monitor bar configurations, lacks segment roles, and implements only ~6 hardcoded pills.
2. **Dank Island (DIsland)**:
   - **Upstream DMS**: A dedicated interactive notch and floating island system (`quickshell/Modules/DIsland/**`) with spring-physics morphing surfaces, state machines (idle, compact, expanded, home), activity routing for media, notifications, and system status, and free-dragging capabilities.
   - **Current Port**: Completely absent. The port merely labeled its center clock/media pill in `DankBarView.swift` as "Dynamic Island".
3. **Control Center**:
   - **Upstream DMS**: A modular control hub (`quickshell/Modules/ControlCenter/**`) featuring a reorderable tile grid (`CcTileGrid`), an interactive edit mode, a tile library sheet, and 12+ full detail subpages (Wi-Fi network scan & connect dialogs, Bluetooth device pairing & codec selector, Audio input/output routing, Battery health & history, Do Not Disturb duration presets, Idle Inhibitor, Disk metrics, Running apps manager, VPN profiles, CUPS printers, and Tailscale).
   - **Current Port**: A static 2-column grid of basic buttons (`ControlCenterView.swift`). None of the 12+ detail subpages or editing capabilities exist.
4. **DankDash (DDash)**:
   - **Upstream DMS**: A full multi-tab dashboard overlay (`quickshell/Modules/DDash/**`) with 6 distinct tabs: Overview, Media (with synchronized lyrics), Notifications Center, Wallpaper Carousel, Weather (multi-day, hourly, UV, air quality), and Digital Wellbeing (app usage graphs).
   - **Current Port**: A single fixed card (`DashView.swift`) containing basic weather and now-playing snippets; none of the tabs or detailed analytics exist.
5. **DLauncherV2**:
   - **Upstream DMS**: An extensive application and action launcher (`quickshell/Modals/DLauncherV2/**`, over 8,900 lines) with weighted frecency scoring (`Scorer.js`), both Spotlight and Island attachment modes, Tile/Grid and List view modes, in-launcher application entry/tag editing (`AppEditView.qml`), rich file search (`DSearchService`), context menus, and DMenu IPC protocol support.
   - **Current Port**: A simplified SwiftUI search list (`LauncherView.swift`) with basic string prefix filtering.
6. **Configuration Schema**:
   - **Upstream DMS**: Features a comprehensive settings engine (`SettingsSpec.js`, `SettingsData.qml`) managing over **420 distinct configuration keys**, multi-bar and multi-dock JSON array definitions, widget options schemas, config fragment inclusion (`ConfigIncludeResolve.js`), and hot-reloading.
   - **Current Port**: Only ~35 configuration keys defined in `Config.swift`, lacking per-bar/per-dock structures and widget option configuration.
7. **Settings UI**:
   - **Upstream DMS**: 96 QML files (~33,500 lines) providing dedicated settings pages for every subsystem, search indexing (`settings_search_index.json`), deep-linking, visual display canvas layout editors, and keybind editors.
   - **Current Port**: A single 8-tab view (`SettingsView.swift`) where most controls are simple toggles disconnected from runtime services.
8. **Subsystems Completely Missing in the Port**:
   - **Desktop Notifications Daemon**: Upstream implements the full desktop notification spec with popup stacking, swipe-to-dismiss physics, notification rules, sound playback, and history. The port only has simple internal toasts (`ToastCenter`).
   - **File Browser Modal**: Upstream includes a full-featured M3 file browser (`DCommon/FileBrowser`, ~45 components). Absent in port.
   - **True Lock Screen & Screensaver**: Upstream features PAM integration, biometric authentication, video screensavers, and background samplers. Absent in port.
   - **Dynamic Island Surface Widgets**: Notch/pill activity morphing engine. Absent in port.
   - **Synchronized Lyrics**: Real-time LRC lyric parsing and rendering in bar and dash. Absent in port.
   - **Keybinds Editor & Engine**: Upstream has a 3,600-line action catalog (`KeybindActions.js`) and parser. Port has a static read-only table.

---

## 2. Quantitative System Comparison Matrix

| Subsystem / Metric | Upstream DMS (Wayland / Linux) | Current macOS Port (`dms-shell`) | Fidelity Status | Primary Gap / Required Work |
| :--- | :--- | :--- | :--- | :--- |
| **Total Source Lines** | ~218,000 lines (QML, JS, Go) | ~12,300 lines (Swift) | **~5.6% scale** | Subsystems need complete native Swift/SwiftUI implementations |
| **Settings Keys** | 427 keys (`SettingsSpec.js`) | 35 keys (`Config.swift`) | **8.2% parity** | 392 settings keys missing; multi-instance schemas missing |
| **DankBar Engine** | Modular, horizontal/vertical, true center, segment roles, 30+ widgets | Fixed horizontal `HStack`, 6 pills, top/bottom only | **Divergent** | Rebuild bar layout engine; implement all 30+ widgets |
| **DankBar Widgets** | 33 distinct widgets | 6 hardcoded pill types | **18.2% parity** | 27 widgets missing (AudioVisualizer, CapsLock, Disk, CPU temp, GPU, etc.) |
| **Desktop Dock** | Multi-dock, 4 edges, magnification bounce, grouping, trash, edit chrome | Pinned app row inside DankBar or separate dock | **Partial** | Window grouping, bounce physics, trash menu, per-dock configs |
| **Dynamic Island** | Morphing surface, activity routing, spring physics, notch modes | None (misattributed name) | **Missing (0%)** | Build complete `DIsland` NSPanel with spring animations & activity bus |
| **Control Center** | Tile grid, reorder edit mode, 12+ rich detail subpages | Static 2-column grid of basic toggle buttons | **Divergent** | Build all 12+ detail subpages (Wi-Fi picker, BT codecs, Audio routes, etc.) |
| **DankDash** | 6 full tabs (Overview, Media, Notifs, Wallpaper, Weather, Wellbeing) | Single static 2-column card | **Divergent** | Build 6 tab views, calendar widget, lyrics engine, wellbeing tracker |
| **DLauncherV2** | Scorer.js frecency, AppEdit, ActionPanel, Tile/List modes, DMenu IPC | Simple search field + 4 tab filters | **Partial** | Implement weighted scorer, tile mode, context menus, dmenu CLI |
| **Notifications** | Desktop Notification server, popup stack, center, rules, swipe wheel | Internal transient toasts only | **Missing (0%)** | Implement local notification daemon, popup window stack, rule engine |
| **M3 Widget Library** | 60+ components in `DCommon/Widgets` + custom GLSL shaders | Basic ad-hoc SwiftUI views | **Partial** | Build reusable M3 component kit (buttons, sliders, toggles, steppers, wave) |
| **Theming & Palettes** | Full M3 HCT tonal palettes, stock themes, Matugen, Dank16 | `ThemePalette.swift` (basic M3 tokens, 10 themes) | **Partial** | Add exact HCT math, terminal ANSI generation, contrast level adjustments |
| **Wallpaper Engine** | Cycling schedule, per-monitor, live blur shaders, Aqueous engine | Single desktop image URL extraction | **Partial** | Per-monitor wallpapers, cycling timer, blur overlays, transition animations |
| **File Browser** | Embedded M3 browser modal (columns, list, grid, previews, rubberband) | None (delegates to NSOpenPanel) | **Missing (0%)** | Build native embedded M3 file browser for full fidelity |
| **Notepad** | Multi-tab, autosave, chroma syntax highlighting, popout & window | Single text editor view, basic file list | **Partial** | Tab management, autosave debounce, syntax highlighting, popout window |
| **Process Monitor** | 4 views (Processes, Performance, Disks, System), kill signals, sparklines | Basic process list table | **Partial** | Sparkline history, disks view, system hardware summary, core breakdown |
| **Color Picker** | Screen sampler, loupe magnifier, format conversions, history | Basic NSColorSampler wrapper | **Partial** | Add loupe preview, hex/rgb/hsl/hsv/cmyk conversions, swatch history |
| **Screenshot Tool** | Interactive region selector with dimensions overlay, window, full, flags | Apple `screencapture` CLI call | **Partial** | Build custom overlay window with live crosshair and coordinate indicators |
| **Keybinds Engine** | 3,600-line action catalog, conflict detection, editor dialog, cheatsheet | Static Carbon register hotkey | **Partial** | Action catalog mapping, keybind editor modal, visual cheatsheet overlay |
| **Lock Screen** | PAM conversation, biometric auth, video screensaver, background sampler | None | **Missing (0%)** | Full-screen shield window with M3 clock, auth validation, and sleep locks |
| **Settings UI** | 96 QML files, search index, deep linking, live preview cards | 8 tabs in a single SwiftUI view | **Partial** | Expand to full tab coverage with dedicated controls and live binding |
| **CLI & Socket IPC** | Rich `dms` CLI, full socket router, subscription streams | Basic socket server with ~20 command strings | **Partial** | Wire protocol framing, event subscription bus, full CLI command parity |

---

## 3. Subsystem Decomposition & Specifications Directory

To guarantee that **nothing is missed** during reimplementation, the specification is broken down into **36 domain-specific documents** under `docs/spec/`, each authored with exhaustive detail, exact numerical values, settings schemas, IPC contracts, and macOS mapping strategies:

```
docs/spec/
├── 00-master-architecture-and-comparison.md  (This overarching master blueprint)
├── 01-theme.md                              (THEME: Design tokens, M3 HCT color math, Dank16, shaders)
├── 02-wallpaper.md                          (WALL: Wallpaper engine, blur shaders, cycling, Aqueous)
├── 03-settings-data.md                      (SETD: Complete 420+ settings schema, multi-instance, config include)
├── 04-session-i18n.md                       (SESS: Runtime session data, cache hierarchy, I18n translations)
├── 05-shell-root-ipc.md                     (SHELL: Shell root composition, startup flow, master IPC index)
├── 06-surfaces-popouts.md                   (SURF: Surface/popout framework, anchoring, corner geometry)
├── 07-widget-library.md                     (WIDG: M3 reusable component kit: DButton, DToggle, DSlider, etc.)
├── 08-file-browser-trash.md                 (FILE: Embedded M3 file browser modal, navigation, trash lifecycle)
├── 09-audio-osd.md                          (AUD: Audio routing, volume curves, feedback sounds, OSD HUDs)
├── 10-media.md                              (MEDIA: MPRIS media architecture, synchronized lyrics, album art)
├── 11-connectivity-qml.md                   (NET: Wi-Fi, Bluetooth, VPN, CUPS, Tailscale QML services & UI)
├── 12-connectivity-core.md                  (NETCORE: Network/Bluetooth/CUPS backend socket API & schemas)
├── 13-power-display.md                      (PWR: Battery health, brightness DDC/CI, night mode, display canvas)
├── 14-session-idle.md                       (IDLE: Idle timeouts, inhibitors, privacy indicators, power flows)
├── 15-compositor-workspaces.md              (COMP: Workspace & window models, overview overlays, window rules)
├── 16-keybinds.md                           (KEYB: Action catalog, keybind parser/serializer, editor UI)
├── 17-lock-greeter.md                       (LOCK: Lock screen, biometric authentication, video screensavers)
├── 18-launcher.md                           (LAUNCH: DLauncherV2, Scorer.js, tile/list modes, app editing, dmenu)
├── 19-bar-core.md                           (BAR: DankBar layout engine, horizontal/vertical, true center, roles)
├── 20-bar-widgets.md                        (BARW: Exhaustive spec of all 33 DankBar widgets & popouts)
├── 21-dock.md                               (DOCK: Desktop dock, bounce physics, grouping, trash, edit chrome)
├── 22-control-center.md                     (CC: Dynamic tile grid, reordering, all 12+ detail subpages)
├── 23-dash-weather-calendar.md              (DASH: DankDash 6 tabs, calendar engine, weather providers, wellbeing)
├── 24-island-surface-widgets.md             (ISLAND: Dynamic Island notch pill, morphing springs, activity bus)
├── 25-notifications.md                      (NOTIF: Notification daemon, popup stack, center, rules, swipe wheel)
├── 26-clipboard.md                          (CLIP: Clipboard history, rich mime types, secret masking, preview)
├── 27-notepad.md                            (NOTE: Tabbed markdown editor, autosave debounce, syntax highlight)
├── 28-processlist-powermenu-updates.md      (PROC: System monitor tabs, power menu dialogs, update daemon)
├── 29-colorpicker-screenshot-qr.md          (TOOLS: Screen color picker, region screenshot overlay, QR generator)
├── 30-plugins-desktop-widgets.md            (PLUG: Plugin manifests, registry, desktop widget canvas)
├── 31-settings-ui-a.md                      (SETUI-A: Settings framework, search index, appearance & theme tabs)
├── 32-settings-ui-b.md                      (SETUI-B: Settings tabs for Bar, Dock, Widgets, Launcher, Display)
├── 33-settings-ui-c.md                      (SETUI-C: Settings tabs for Audio, Network, Power, Keybinds, Lock)
├── 34-cli.md                                (CLI: `dms` command-line interface, subcommands, flags, output)
├── 35-core-server-protocol.md               (SRV: Unix socket server wire protocol, method catalog, events)
├── 36-install-packaging-tests.md            (INST: Installation, packaging, launchd daemons, test coverage)
└── 37-reimplementation-plan.md             (PLAN: Master 3-Step DMS Reimplementation & Alignment Plan)
```

---

## 4. Architectural Principles for macOS Reimplementation

To achieve genuine 1-to-1 parity while embracing macOS system conventions, the reimplementation must strictly follow these core engineering principles:

### 4.1. Zero Idle CPU & Event-Driven Architecture
- **Rule**: Background polling timers are strictly forbidden. The shell must consume ~0.0% CPU at idle.
- **macOS Event Sources**:
  - Window & Space changes: `NSWorkspace.didActivateApplicationNotification`, `NSWorkspace.activeSpaceDidChangeNotification`, and SkyLight display notifications.
  - Audio changes: `AudioObjectAddPropertyListener` for default output device and volume changes.
  - Network changes: `CWWiFiClient` event delegate and `SCDynamicStoreCreateRunLoopSource`.
  - Power / Battery: `IOPSNotificationCreateRunLoopSource`.
  - Display & Brightness: `CGDisplayRegisterReconfigurationCallback`.
  - File / Config changes: `DispatchSourceFileSystemObject`.

### 4.2. Precision Windowing (`ShellPanel`)
- All floating surfaces (DankBar, Dock, DIsland, ControlCenter, DLauncherV2, OSD, Toasts) must subclass `NSPanel` with:
  - `styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView]`
  - `level: .statusBar` or `.floating` (above standard windows)
  - `collectionBehavior: [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]`
  - `isOpaque = false`, `backgroundColor = .clear`
  - Correct window positioning math avoiding notch cutouts and menu bar conflicts.

### 4.3. Unified Material Design 3 Styling Token Engine
- Hardcoded colors, margins, and radii are forbidden in UI views.
- All views must bind to `ThemeStore.shared`, resolving colors from `ThemePalette` (Primary, Secondary, Tertiary, Surface, Containers, Outlines, Tonal elevations) and metrics from standard M3 tokens:
  - Corner Radii: ExtraSmall (4px), Small (8px), Medium (12px), Large (16px), ExtraLarge (28px), Full (9999px).
  - Spacing: XS (4px), S (8px), M (12px), L (16px), XL (24px), XXL (32px).
  - Elevations: 0 (flat) through 5 with corresponding tonal surface tint opacities.

### 4.4. IPC Protocol Parity
- The shell daemon must expose a Unix domain socket at `~/Library/Application Support/DMS/dms.sock`.
- Both JSON-RPC style method calls and line-delimited event streams must be supported, matching the CLI commands specified in `docs/spec/34-cli.md` and server methods in `docs/spec/35-core-server-protocol.md`.

---

## 5. Master Roadmap to 100% Parity

1. **Phase 1: Foundational Core & Configuration**
   - Expand `DMSCore/Config.swift` to support the full 427-key `SettingsSpec` and multi-instance bar/dock schemas (`docs/spec/03-settings-data.md`).
   - Implement complete HCT tonal palette generation in `DynamicThemeGenerator.swift` (`docs/spec/01-theme.md`).
   - Implement the `DCommon/Widgets` reusable SwiftUI component library (`docs/spec/07-widget-library.md`).
2. **Phase 2: DankBar Layout Engine & Complete Widget Set**
   - Refactor `DankBarController` into a multi-instance, multi-monitor bar manager supporting horizontal and vertical axes (`docs/spec/19-bar-core.md`).
   - Implement the remaining 27 DankBar widgets and popout sheets (`docs/spec/20-bar-widgets.md`).
3. **Phase 3: Dank Island & Surface Overlays**
   - Build the dedicated `DIsland` NSPanel with spring-physics morphing and activity routing (`docs/spec/24-island-surface-widgets.md`).
   - Implement the connected-mode popout anchoring and concave corner geometry (`docs/spec/06-surfaces-popouts.md`).
4. **Phase 4: Control Center & Dash Parity**
   - Rebuild `ControlCenterView` with dynamic grid editing and all 12+ detail subpages (`docs/spec/22-control-center.md`).
   - Rebuild `DashView` with the 6 tabbed views, calendar integration, and synchronized lyrics (`docs/spec/23-dash-weather-calendar.md`).
5. **Phase 5: Notification Daemon & File Browser**
   - Build the local notification daemon, popup stack, and rules manager (`docs/spec/25-notifications.md`).
   - Implement the embedded M3 file browser modal (`docs/spec/08-file-browser-trash.md`).
6. **Phase 6: Settings App, Lock Screen, and CLI Parity**
   - Expand `SettingsView` into the full multi-category configuration app with live search indexing (`docs/spec/31-settings-ui-a.md` through `33-settings-ui-c.md`).
   - Build full-screen lock screen shield and Touch ID / ODRecord validation (`docs/spec/17-lock-greeter.md`).
   - Implement all missing `dms` CLI commands and socket handlers (`docs/spec/34-cli.md`).

For the exhaustive, component-by-component 3-step actionable execution roadmap cataloging all mitigations, unique features, and platform adaptations across every subsystem, see the companion document:
👉 [`37-reimplementation-plan.md`](file:///Users/jonasnowak/Documents/repos/dms-shell/docs/spec/37-reimplementation-plan.md)
