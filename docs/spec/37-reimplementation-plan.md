# 37 — Master 3-Step DMS Reimplementation & Alignment Plan (`PLAN`)

> **Upstream DMS Version**: `AvengeMedia/DankMaterialShell` (commit `699eb237751bc5d61fdf90e1709fb6cabe9896a4`)  
> **Current Port Target**: macOS Native Swift 6 / SwiftUI / AppKit (`dms-shell`)  
> **Master Architecture Reference**: [`00-master-architecture-and-comparison.md`](file:///Users/jonasnowak/Documents/repos/dms-shell/docs/spec/00-master-architecture-and-comparison.md)  
> **Coverage Goal**: 100% Upstream DMS Subsystems & Architecture cataloged across Specifications 01 through 36

---

## Executive Overview & Strategic Methodology

A comprehensive audit of the upstream DankMaterialShell (DMS) codebase (~218,000 lines across `quickshell/`, `core/`, and `dank-qml-common/`) against the current `dms-shell` macOS port (~12,300 lines across 96 Swift files) revealed that earlier port efforts produced **vaguely inspired approximations** rather than faithful implementations. Subsystems were either omitted, drastically flattened into static placeholders, or implemented without dynamic layout solvers, spring physics, or proper macOS framework bridges.

To achieve genuine 1-to-1 visual, behavioral, and architectural parity while embracing macOS system conventions, every upstream subsystem and architectural gap across specifications `01-theme.md` through `36-install-packaging-tests.md` is cataloged into exactly one of three strategic buckets:

1. **Step 1: Mitigations & Behavioral Corrections (Misaligned Features)**: Components already present in `dms-shell` that diverge from upstream mechanics (e.g., static SwiftUI bars missing dynamic centering math, hardcoded pills, missing spring physics, mock popouts without subpages). These require targeted refactoring to align with DMS algorithms.
2. **Step 2: Missing Non-Redundant Features (To Be Implemented)**: Iconic, high-value DMS capabilities absent from both `dms-shell` and macOS native features (e.g., M3 token engine with HCT math, morphing dynamic island surfaces, synchronized LRC lyric ticker, custom widget slots, embedded file browser).
3. **Step 3: Platform Delegations & Native Substitutions (Redundant / Linux-Specific Features)**: Upstream capabilities that are Linux/Wayland-specific, redundant with native macOS system features, or where macOS security boundaries (SIP, Secure Enclave, WindowServer, sandbox) prevent direct 1:1 porting, requiring clean bridges or intentional delegation.

---

## Step 1: Mitigations & Behavioral Corrections (Misaligned Features)

*Subsystems currently implemented in `dms-shell` that require refactoring and architectural realignment to achieve genuine fidelity with DMS mechanics.*

### MIT-THEME-001: Algorithmic Dynamic Theme Color Math
- **Upstream Reference**: `dank-qml-common/DCommon/Common/Tonal.js`, `ColorUtils.js` (`softContainer()`, CAM16/HCT color generation)
- **Current Port State**: `Sources/DMSCore/DynamicThemeGenerator.swift` and `Sources/DMSCore/ThemePalette.swift`. Uses fixed, hardcoded hex values across 10 static stock themes. Lacks HCT color space conversions, contrast levels, and tonal container derivation.
- **Mitigation Plan**:
  1. Implement native Swift CAM16/HCT color space mathematical engine.
  2. Implement `softContainer(accent, card, tint)` mixing formula:
     $$\text{softContainer} = \text{blend}(\text{blend}(card, accent, 0.08), tint, 0.04)$$
  3. Generate all 48 Material Design 3 tonal roles dynamically from any wallpaper image or user seed color.
  4. Support WCAG contrast modes (`standard`, `medium`, `high`).
- **Pragmatic macOS Compromise**: None required. Math operates natively in Swift 6.

### MIT-SETD-001: Hierarchical Multi-Instance Configuration Schema
- **Upstream Reference**: `quickshell/Common/SettingsSpec.js` (427 distinct keys, multi-bar and multi-dock arrays)
- **Current Port State**: `Sources/DMSCore/Config.swift` and `Sources/DMS/Services/ConfigStore.swift`. Implements a flat `DMSConfig` struct with only ~35 scalar keys (`barPosition`, `showDock`, etc.).
- **Mitigation Plan**:
  1. Rewrite `DMSConfig` to support hierarchical configuration structures matching `SettingsSpec.js`.
  2. Implement `barConfigs: [BarConfig]` and `dockConfigs: [DockConfig]` arrays allowing independent layouts per monitor.
  3. Add per-widget options dictionaries (`[String: AnyCodable]`).
  4. Support `$include` config fragment loading and schema version migrations (`version: 2`).
- **Pragmatic macOS Compromise**: Store primary settings in `~/Library/Application Support/DMS/settings.json` while maintaining symlink support for `~/.config/DankMaterialShell/settings.json`.

### MIT-SESS-001: Ephemeral Runtime Session Separation
- **Upstream Reference**: `quickshell/Common/SessionData.qml` (`session.json` schema version 7)
- **Current Port State**: `Sources/DMS/Services/ConfigStore.swift` mingles temporary UI states with persistent user settings.
- **Mitigation Plan**:
  1. Introduce discrete `SessionStore.swift` managing `~/Library/Application Support/DMS/session.json`.
  2. Persist dynamic runtime properties: `dndUntil`, `osdSuppressed`, `mutedStreams`, `recentColorSwatches`, and `activeDisplayId`.
  3. Ensure session writes are debounced at 300ms and never mutate user configuration files.
- **Pragmatic macOS Compromise**: None.

### MIT-SHELL-001: Material Design 3 In-Shell Toast Overhaul
- **Upstream Reference**: `quickshell/Modules/Toast.qml` (320px width, 16px corner radius, progress duration bar, hover-pause)
- **Current Port State**: `Sources/DMS/Toast/ToastView.swift` and `Sources/DMS/Toast/ToastController.swift`. Renders a plain SwiftUI capsule without M3 elevation tokens, duration progress stroke, or mouse interaction.
- **Mitigation Plan**:
  1. Refactor `ToastView` to 320px width, `surfaceContainerHigh` background, and 16px corner radius.
  2. Add level indicators: `info` (primary), `warn` (tertiary), `error` (error container).
  3. Implement active countdown progress line (2px height) along bottom edge.
  4. Add hover-pause timer tracking so inspection prevents auto-dismissal.
- **Pragmatic macOS Compromise**: None.

### MIT-SHELL-002: Master IPC Router Target Expansion
- **Upstream Reference**: `quickshell/DMSShellIPC.qml` (33 IPC targets, 90+ functions)
- **Current Port State**: `Sources/DMS/Services/IPCCommandExecutor.swift` and `Sources/DMSCore/IPCCommand.swift`. Implements only ~15 hardcoded string commands in a simple `switch` statement.
- **Mitigation Plan**:
  1. Expand `IPCCommand` enum to cover all 33 upstream targets (`bar`, `dock`, `island`, `dash`, `cc`, `launcher`, `notepad`, `clipboard`, `weather`, `media`, `power`, etc.).
  2. Implement parameter type validation and JSON-RPC compliant response structures.
  3. Provide human-readable error messages and integer exit codes.
- **Pragmatic macOS Compromise**: Protocol transported over macOS Unix domain socket (`~/Library/Application Support/DMS/dms.sock`).

### MIT-SURF-001: Connected Popout Anchoring & Spring Resizing
- **Upstream Reference**: `quickshell/Modules/Popout/PopoutSurface.qml`, `DBar/Widgets/BarPopout.qml`
- **Current Port State**: `Sources/DMS/ShellPanel.swift`. Basic borderless `NSPanel` with fixed window dimensions and hardcoded offsets.
- **Mitigation Plan**:
  1. Implement dynamic window frame animation (`AnimatedPanelFrame`) animating size and origin without glitching.
  2. Implement coordinate transformation converting Cocoa bottom-left origin to top-left screen anchors.
  3. Add hover grace zones (`HoverGraceZoneTracker`) allowing diagonal mouse travel between bar pill and popout without premature dismissal.
- **Pragmatic macOS Compromise**: Use `NSVisualEffectView` behind SwiftUI views to achieve silky smooth native macOS backdrop blurring.

### MIT-WIDG-001: M3 Standardized Component Kit Alignment
- **Upstream Reference**: `dank-qml-common/DCommon/Widgets/*` (`DButton`, `DToggle`, `DSlider`, `StateLayer`)
- **Current Port State**: Ad-hoc SwiftUI views throughout `Sources/DMS/` using standard Apple `Toggle()`, `Slider()`, and `.opacity()` click modifiers.
- **Mitigation Plan**:
  1. Build unified `DCommon` SwiftUI component library in `Sources/DMSCore/Widgets/`.
  2. Implement M3 interaction state layer with precise opacities: hover (0.08), focus (0.12), pressed (0.12), dragged (0.16).
  3. Implement `DToggle` with physical spring motion (`stiffness: 560`, `damping: 37`) and checkmark icon inside thumb.
  4. Implement `DSlider` with M3 track heights and floating value tooltip on drag.
- **Pragmatic macOS Compromise**: None.

### MIT-AUD-001: Full-Spectrum OSD HUD Suite
- **Upstream Reference**: `quickshell/Modules/OSD/*` (`VolumeOSD.qml`, `MicVolumeOSD.qml`, `BrightnessOSD.qml`, `CapsLockOSD.qml`, `AudioOutputOSD.qml`, etc.)
- **Current Port State**: `Sources/DMS/OSD/OSDView.swift` and `Sources/DMS/OSD/OSDController.swift`. Supports only 2 rudimentary HUDs (volume, brightness) in a fixed layout.
- **Mitigation Plan**:
  1. Implement all 10 OSD HUD kinds: Volume, Microphone, Display Brightness, Keyboard Backlight, CapsLock, Media Play/Pause, Audio Output Switch, Battery Charging, DND, and Privacy In-Use.
  2. Add interactive mouse scrubbing to volume/brightness OSDs.
  3. Add expandable audio output device selection sheet on hover.
  4. Implement 1000ms settling suppression timer on shell launch to prevent false-positive popups.
- **Pragmatic macOS Compromise**: Caps Lock monitored via `CGEventSource.flagsState(.combinedSessionState)`.

### MIT-AUD-002: Per-App Audio Mixing & Decibel Curves
- **Upstream Reference**: `quickshell/Services/AudioService.qml`, `core/internal/server/audio/`
- **Current Port State**: `Sources/DMS/Services/AudioService.swift` (152 lines). Only reads and writes the system master volume scalar.
- **Mitigation Plan**:
  1. Integrate CoreAudio Hardware Abstraction Layer (HAL) for logarithmic decibel-to-scalar curve translation:
     $$\text{scalar} = \left(\frac{\text{dB} - \text{minDB}}{\text{maxDB} - \text{minDB}}\right)^3$$
  2. Implement output sink device enumeration and default route switching (`kAudioHardwarePropertyDefaultOutputDevice`).
  3. Support audio over-amplification up to 150% with soft limiter.
- **Pragmatic macOS Compromise**: macOS CoreAudio requires private APIs or AudioServerPlugIns to control individual third-party app volumes independently. For unprivileged operation, provide master and device sink control, with an optional audio routing driver companion.

### MIT-MEDIA-001: Advanced Now Playing Controls & Metadata Bus
- **Upstream Reference**: `quickshell/Services/MediaService.qml`, `quickshell/Modules/DBar/Widgets/Media.qml`
- **Current Port State**: `Sources/DMS/Services/NowPlayingService.swift` and `Sources/DMSCore/NowPlayingModel.swift`. Basic track title and artist polling via AppleScript.
- **Mitigation Plan**:
  1. Integrate with `MRMediaRemote` private framework / `NowPlayingInfo` for zero-polling playback state, timeline scrub position, track duration, and album artwork extraction.
  2. Add playback rate detection and precise millisecond timeline calculation for lyric synchronization.
  3. Implement 4-bar animated equalizer in the DankBar media pill when playing.
- **Pragmatic macOS Compromise**: Bridge `MRMediaRemoteGetNowPlayingInfo` via dynamic runtime loading to avoid private framework linking issues.

### MIT-NET-001: Wi-Fi Discovery & Network Management
- **Upstream Reference**: `quickshell/Services/NetworkService.qml`, `quickshell/Modules/ControlCenter/Details/NetworkDetail.qml`
- **Current Port State**: `Sources/DMS/Services/WiFiService.swift` (59 lines). Only queries current SSID string.
- **Mitigation Plan**:
  1. Rewrite using `CoreWLAN` framework (`CWWiFiClient`, `CWInterface`).
  2. Implement network scanning (`scanForNetworks(withName:)`) on a 10s visibility-gated timer.
  3. Expose SSID, BSSID, RSSI signal strength bars, and security type (WPA2/WPA3 Personal/Enterprise).
  4. Implement WPA credential connection prompt modal.
- **Pragmatic macOS Compromise**: None. `CoreWLAN` provides complete native Wi-Fi capabilities.

### MIT-NET-002: Bluetooth Peripheral Device & Battery Management
- **Upstream Reference**: `quickshell/Services/BluetoothService.qml`, `quickshell/Modules/ControlCenter/Details/BluetoothDetail.qml`
- **Current Port State**: `Sources/DMS/Services/BluetoothService.swift` (44 lines). Only checks power state.
- **Mitigation Plan**:
  1. Rewrite using `IOBluetooth` and `CoreBluetooth` frameworks.
  2. Enumerate paired devices (`IOBluetoothDevice.pairedDevices()`) with connection states (`connected`, `paired`, `connecting`).
  3. Read peripheral battery percentages (AirPods case/buds, Magic Mouse, Magic Keyboard, third-party Bluetooth headsets).
  4. Provide connect / disconnect trigger actions from Control Center.
- **Pragmatic macOS Compromise**: Audio codec selection on macOS is handled by the OS Bluetooth daemon; display active codec (AAC/SBC/LDAC) read-only via `IOBluetoothDeviceInfo`.

### MIT-PWR-001: High-Fidelity Power Metrics & Discharge Modeling
- **Upstream Reference**: `quickshell/Services/BatteryService.qml`, `core/internal/server/battery/`
- **Current Port State**: `Sources/DMS/Services/BatteryService.swift` (65 lines). Reads basic percentage and AC flag.
- **Mitigation Plan**:
  1. Integrate `IOPowerSources` and IOKit `IOPSGetPowerSourceDescription`.
  2. Calculate instant wattage draw ($W = V \times A$), battery health health percentage, cycle count, temperature, and time-to-full / time-to-empty.
  3. Implement rolling 24-hour battery history buffer storing periodic readings.
- **Pragmatic macOS Compromise**: None. IOKit exposes full battery management hardware descriptors.

### MIT-PWR-002: Multi-Display Brightness & DDC/CI Control
- **Upstream Reference**: `quickshell/Services/BrightnessService.qml`, `core/internal/server/display/`
- **Current Port State**: `Sources/DMS/Services/BrightnessService.swift` (64 lines). Controls only built-in screen brightness.
- **Mitigation Plan**:
  1. Expand `BrightnessService` to enumerate all active displays (`NSScreen`).
  2. For Apple built-in displays: use `DisplayServicesSetBrightness`.
  3. For external monitors: implement DDC/CI VCP opcode `0x10` over IOKit I2C (`IOI2CInterfaceConnect`) to adjust hardware brightness and contrast directly.
- **Pragmatic macOS Compromise**: DDC/CI requires unhindered I2C bus access; fallback gracefully to software gamma table shading if monitor firmware rejects DDC packets.

### MIT-PWR-003: Night Shift Warmth & Astronomical Schedule
- **Upstream Reference**: `quickshell/Services/NightModeService.qml`
- **Current Port State**: `Sources/DMS/Services/NightShiftService.swift` (51 lines). Binary toggle only.
- **Mitigation Plan**:
  1. Integrate private `CBBlueLightClient` from `CoreBrightness.framework`.
  2. Support smooth warmth adjustments parameterized in Kelvin (2500K to 6500K).
  3. Link activation to `SunCalc` astronomical sunrise and sunset schedule.
- **Pragmatic macOS Compromise**: Dynamic runtime loading of `CBBlueLightClient` class.

### MIT-IDLE-001: Sleep Assertion Lifecycle & Timed Presets
- **Upstream Reference**: `quickshell/Services/InhibitService.qml`
- **Current Port State**: `Sources/DMS/Services/IdleInhibitService.swift` (49 lines). Simple indefinite assertion toggle.
- **Mitigation Plan**:
  1. Upgrade `IOPMAssertionCreateWithName` wrapper to support timed duration presets: 15m, 30m, 1h, 2h, 4h, until tomorrow, or indefinite.
  2. Implement automatic assertion release timer with countdown indicator.
  3. Provide quick toggle pill in DankBar and Control Center with remaining time label.
- **Pragmatic macOS Compromise**: None.

### MIT-COMP-001: Workspace Switcher Interaction & Urgency Dots
- **Upstream Reference**: `quickshell/Modules/DBar/Widgets/WorkspaceSwitcher.qml`
- **Current Port State**: `Sources/DMSCore/WorkspaceModel.swift` and `Sources/DMS/Services/WorkspaceService.swift`. Switcher renders numbered pills without scroll gesture cycling or attention indicators.
- **Mitigation Plan**:
  1. Add scroll wheel event handler cycling active spaces smoothly.
  2. Implement urgent notification state (`isUrgent` orange indicator pip) when an application in another workspace requests attention.
  3. Synchronize with OmniWM virtual workspace switcher events over socket IPC.
- **Pragmatic macOS Compromise**: On macOS native spaces, scroll-to-switch dispatches synthetic Mission Control key commands or OmniWM space switch RPCs.

### MIT-COMP-002: Active Window Pill & Window Context Menu
- **Upstream Reference**: `quickshell/Modules/DBar/Widgets/FocusedApp.qml`
- **Current Port State**: Hardcoded text in bar.
- **Mitigation Plan**:
  1. Build dedicated `FocusedAppView` showing active application's 20x20px icon and window title.
  2. Right-click triggers `FocusedWindowContextMenu`: Close Window (`Cmd+W`), Minimize (`Cmd+M`), Zoom/Toggle Fullscreen (`Ctrl+Cmd+F`), Move to Space.
- **Pragmatic macOS Compromise**: Window actions dispatched via Accessibility API (`AXUIElementPerformAction`) or synthetic keyboard shortcuts.

### MIT-KEYB-001: Dynamic User Keybinds Persistence & Rebinding
- **Upstream Reference**: `quickshell/Common/KeybindActions.js` (3,600 lines)
- **Current Port State**: `Sources/DMS/Services/HotkeyService.swift` (83 lines). Hardcodes 4 fixed Carbon hotkeys.
- **Mitigation Plan**:
  1. Create `KeybindStore.swift` serializing user shortcuts to `~/Library/Application Support/DMS/keybinds.json`.
  2. Implement runtime rebinding of Carbon `RegisterEventHotKey` without requiring app restart.
  3. Support multi-modifier combinations: Command, Option, Control, Shift.
- **Pragmatic macOS Compromise**: Global hotkeys require Accessibility permissions if intercepting media or function keys; fallback to Carbon hotkeys for alphanumeric chords.

### MIT-KEYB-002: Visual Keyboard Shortcut Cheatsheet
- **Upstream Reference**: `quickshell/Modals/CheatsheetModal.qml`
- **Current Port State**: `Sources/DMS/Keybinds/KeybindsView.swift` (175 lines). Static read-only table.
- **Mitigation Plan**:
  1. Bind cheatsheet dynamically to `KeybindStore.shared`.
  2. Add instant search filter and category tabs: Navigation, Window Management, Shell Surfaces, System Actions.
  3. Support one-click shortcut editing directly from cheatsheet items.
- **Pragmatic macOS Compromise**: None.

### MIT-LAUNCH-001: Frecency Scoring Algorithm (`Scorer.js`)
- **Upstream Reference**: `quickshell/Modals/DLauncherV2/Scorer.js`
- **Current Port State**: `Sources/DMSCore/AppSearch.swift`. Basic prefix and substring contains filter.
- **Mitigation Plan**:
  1. Port `Scorer.js` into Swift 6 (`LauncherScorer.swift`).
  2. Implement exact frecency score decay formula:
     $$\text{frecency} = \frac{\text{launchCount} \times 10}{1.0 + (\text{now} - \text{lastLaunchTime}) / 86400000}$$
  3. Include category weight boosts: Application (+1000), Calculation (+900), Bookmark (+850), File (+800), Action (+600).
  4. Clamp Levenshtein fuzzy distance $\le 2$.
- **Pragmatic macOS Compromise**: None.

### MIT-LAUNCH-002: DLauncherV2 Tile Mode & Dynamic Height
- **Upstream Reference**: `quickshell/Modals/DLauncherV2/SpotlightLauncherContent.qml`
- **Current Port State**: `Sources/DMS/Launcher/LauncherView.swift` (515 lines). Fixed single-column list with static modal frame.
- **Mitigation Plan**:
  1. Implement both `List` mode (52px row height with icons and subtitle) and `Tile` grid mode (4 to 6 columns with 48px icons).
  2. Toggle between modes via `Ctrl+Tab`.
  3. Implement fluid height expansion: 72px (input only) expanding up to 540px based on result count using spring animations.
- **Pragmatic macOS Compromise**: None.

### MIT-BAR-001: Multi-Axis Bar Engine (Horizontal & Vertical)
- **Upstream Reference**: `quickshell/Modules/DBar/DBar.qml`, `AxisContext.qml`
- **Current Port State**: `Sources/DMS/DankBar/DankBarView.swift` (horizontal only).
- **Mitigation Plan**:
  1. Refactor bar layout engine to support all 4 screen edges: `Top`, `Bottom`, `Left`, `Right`.
  2. For `Left` and `Right` vertical bars: rotate layout axis 90 degrees, stack pills vertically, set vertical thickness to 54px.
  3. Reposition popout anchor vectors according to active edge.
- **Pragmatic macOS Compromise**: None.

### MIT-BAR-002: CenterLayout Geometric Collision Avoidance
- **Upstream Reference**: `quickshell/Modules/DBar/CenterLayout.js`
- **Current Port State**: `Sources/DMS/DankBar/DankBarView.swift` uses SwiftUI `Spacer()`, causing center clock pill to shift off-center or collide with left/right widgets when segments expand.
- **Mitigation Plan**:
  1. Port `CenterLayout.js` into Swift (`BarCenterLayoutSolver.swift`).
  2. Compute available space:
     $$\text{maxHalfWidth} = \min(\text{centerPoint} - \text{leftEdge}, \text{rightEdge} - \text{centerPoint})$$
  3. If center segment width exceeds $2 \times \text{maxHalfWidth}$, dynamically compress center margins or switch to compact clock face.
- **Pragmatic macOS Compromise**: Implement via custom SwiftUI `Layout` protocol (`DMSCenterBarLayout: Layout`).

### MIT-BAR-003: Multi-Monitor Independent Bar Manager
- **Upstream Reference**: `quickshell/DMSShell.qml`, `BarManager.qml`
- **Current Port State**: `Sources/DMS/DankBar/DankBarController.swift` binds to primary `NSScreen` only.
- **Mitigation Plan**:
  1. Rewrite `DankBarController` as a multi-instance manager maintaining a dictionary of `[CGDirectDisplayID: ShellPanel]`.
  2. Listen to `NSApplication.didChangeScreenParametersNotification` to instantiate independent bars per connected monitor according to `barConfigs`.
- **Pragmatic macOS Compromise**: None.

### MIT-BARW-001: Customizable Bar Widget Options Engine
- **Upstream Reference**: `quickshell/Modules/DBar/BarWidgetDefaults.js`, `BarWidgetOptions/*`
- **Current Port State**: Hardcoded widget representations in `DankBarView.swift`.
- **Mitigation Plan**:
  1. Implement `BarWidgetOptions` model in Swift supporting per-widget settings (e.g. clock 12h/24h, show seconds, date format string, battery show percentage/wattage, CPU warning threshold).
  2. Bind each widget instance dynamically to its options payload from `barConfigs`.
- **Pragmatic macOS Compromise**: None.

### MIT-DOCK-001: Mathematical Magnification Curves
- **Upstream Reference**: `quickshell/Modules/Dock/DockConfig.js` (`magnificationFactor()`)
- **Current Port State**: `Sources/DMS/DankBar/DankBarView.swift` (static dock row).
- **Mitigation Plan**:
  1. Implement proximity distance calculation $d = |x_{\text{mouse}} - x_{\text{iconMidpoint}}|$.
  2. Implement all 3 mathematical profiles ($u = d / R$):
     - **Cosine**: $F(u) = 0.5 \times (1 + \cos(\pi u))$
     - **Gaussian**: $F(u) = \frac{\exp(-3 u^2) - \exp(-3)}{1 - \exp(-3)}$
     - **Parabolic**: $F(u) = 1 - u^2$
  3. Scale icon smoothly from $1.0\times$ to $1.3\times$ (configurable up to $1.6\times$) without frame hitching.
- **Pragmatic macOS Compromise**: Drive magnification via `NSEvent.addLocalMonitorForEvents(matching: .mouseMoved)`.

### MIT-DOCK-002: Dynamic Focus Dot-to-Pill Indicators
- **Upstream Reference**: `quickshell/Modules/Dock/DockAppButton.qml`
- **Current Port State**: Fixed static dots.
- **Mitigation Plan**:
  1. Implement animated indicator expansion: when an application receives focus, its running indicator dot expands $3\times$ into a rounded capsule.
  2. For multi-window apps: render up to 4 distinct dots representing open windows.
  3. Support both `"circle"` (dots) and `"line"` (bars) indicator styles.
- **Pragmatic macOS Compromise**: Window counts per application queried via Accessibility API (`AXUIElementCopyAttributeValues` for `kAXWindowsAttribute`).

### MIT-CC-001: 2D Bin-Packed Grid & Column Resizing
- **Upstream Reference**: `quickshell/Modules/ControlCenter/GridUtils.packCards`, `DPanelResizer.qml`
- **Current Port State**: `Sources/DMS/ControlCenter/ControlCenterView.swift`. Static 2-column list.
- **Mitigation Plan**:
  1. Implement 2D bin-packing layout algorithm (`GridUtils.packCards`) supporting tile dimensions: $1\times1$, $2\times1$, $4\times1$, and $4\times2$.
  2. Add `DPanelResizer` edge drag handle allowing live column resizing from 6 to 12 columns with 0.5-step quantization.
- **Pragmatic macOS Compromise**: None.

### MIT-CC-002: Slide-Over Detail Subpage Navigation
- **Upstream Reference**: `quickshell/Modules/ControlCenter/CcDetailPage.qml`
- **Current Port State**: Toggle buttons in `ControlCenterView.swift` do not navigate to subpages.
- **Mitigation Plan**:
  1. Implement `CcDetailPageHost` in SwiftUI supporting slide transitions, history breadcrumb stack, and Escape key dismissal.
  2. Wire up all Control Center tiles to drill down into detail views on click/secondary click.
- **Pragmatic macOS Compromise**: None.

### MIT-DASH-001: DDash Multi-Tab Architecture
- **Upstream Reference**: `quickshell/Modules/DDash/DDashPopout.qml`
- **Current Port State**: `Sources/DMS/Dash/DashView.swift` (220 lines). Single fixed card.
- **Mitigation Plan**:
  1. Refactor `DashView` into a full-bleed 6-tab overlay: Overview, Media Player, Weather, Wallpapers, Wellbeing, and Notifications.
  2. Support keyboard navigation (`Tab` / `Shift+Tab`) and edge swipe switching.
- **Pragmatic macOS Compromise**: None.

### MIT-DASH-002: Calendar ISO Week Numbers & EventKit Sync
- **Upstream Reference**: `quickshell/Modules/DDash/CalendarOverviewCard.qml`
- **Current Port State**: Simple month grid in `DashView.swift`.
- **Mitigation Plan**:
  1. Add ISO 8601 week numbers column to the monthly calendar view.
  2. Connect native Apple `EventKit` framework (`EKEventStore`) to display user's calendar events and color-coded indicator pips on days with scheduled events.
  3. Add event detail popup sheet.
- **Pragmatic macOS Compromise**: None. `EventKit` provides seamless access to macOS Calendar databases.

### MIT-NOTIF-001: External Notification Daemon Interface
- **Upstream Reference**: `quickshell/Services/NotificationService.qml`, `core/cmd/dms/commands_notify.go`
- **Current Port State**: `Sources/DMS/Services/ToastCenter.swift`. In-memory transient queue for internal shell alerts.
- **Mitigation Plan**:
  1. Upgrade `ToastCenter` to `NotificationDaemonService`.
  2. Accept incoming notification requests via Unix domain socket and `dms notify` CLI.
  3. Parse fields: summary, body Markdown, urgency, app name, icon, image attachment, and callback actions.
- **Pragmatic macOS Compromise**: Operates as shell-level notification server; forward alerts to `UNUserNotificationCenter` when configured.

### MIT-CLIP-001: SQLite Database Engine & SHA-256 Deduplication
- **Upstream Reference**: `core/internal/server/clipboard/manager.go` (2,365 lines)
- **Current Port State**: `Sources/DMSCore/ClipboardStore.swift` (117 lines). Transient JSON array.
- **Mitigation Plan**:
  1. Migrate clipboard storage to native SQLite (`~/Library/Application Support/DMS/clipboard.sqlite3`).
  2. Compute SHA-256 hashes of clipboard payloads to deduplicate entries.
  3. Store binary images in cached files with SQLite references and thumbnail generation.
- **Pragmatic macOS Compromise**: None.

### MIT-CLIP-002: Sensitive Password Masking & Auto-Wipe
- **Upstream Reference**: `quickshell/Modals/Clipboard/ClipboardItemDelegate.qml`
- **Current Port State**: Plain text display for all items.
- **Mitigation Plan**:
  1. Detect passwords copied from password managers (1Password, Bitwarden, KeePassXC, Apple Keychain) via bundle ID or entropy heuristics.
  2. Automatically mask sensitive text (`••••••••`).
  3. Schedule a 60-second self-destruct timer to purge sensitive items from history.
- **Pragmatic macOS Compromise**: None.

### MIT-NOTE-001: Multi-Tab Notepad Session Persistence
- **Upstream Reference**: `quickshell/Modules/Notepad/NotepadTabs.qml`, `NotepadData.qml`
- **Current Port State**: `Sources/DMS/Notepad/NotepadView.swift` and `Sources/DMSCore/NotepadStore.swift`. Single draft buffer.
- **Mitigation Plan**:
  1. Upgrade `NotepadStore` to support tab arrays with unique IDs, titles, dirty modify flags, and active index.
  2. Persist tab drafts to `~/Library/Application Support/DMS/notepad/tabs.json`.
  3. Implement tab bar with close buttons, "+" add tab, and keyboard shortcuts (`Cmd+T`, `Cmd+W`).
- **Pragmatic macOS Compromise**: None.

### MIT-NOTE-002: Line Numbers Gutter & Search/Replace Bar
- **Upstream Reference**: `quickshell/Modules/Notepad/NotepadEditor.qml`
- **Current Port State**: Standard SwiftUI `TextEditor` without line numbers or find bar.
- **Mitigation Plan**:
  1. Wrap `NSTextView` in `NSViewRepresentable` to unlock native Cocoa text system capabilities.
  2. Implement `NSRulerView` line number gutter.
  3. Implement in-situ Find & Replace banner with match count and keyboard navigation (`Cmd+F`, `Cmd+G`).
- **Pragmatic macOS Compromise**: None.

### MIT-PROC-001: Process Monitor Sorting & Signal Dispatching
- **Upstream Reference**: `quickshell/Modules/ProcessList/ProcessTable.qml`
- **Current Port State**: `Sources/DMS/ProcessList/ProcessListView.swift` (218 lines). Simple table.
- **Mitigation Plan**:
  1. Add sorting header chips: Process Name, PID, CPU %, Memory (MB).
  2. Add filter search bar with real-time text matching.
  3. Right-click context menu: `SIGTERM` (Gentle Kill), `SIGKILL` (Force Kill), and Renice priority slider (-20 to +19).
- **Pragmatic macOS Compromise**: Killing and renicing unprivileged user processes is permitted; system daemons require admin escalation.

### MIT-PROC-002: Safety Hold-to-Confirm Power Actions
- **Upstream Reference**: `quickshell/Modules/PowerMenu/PowerMenuContent.qml`
- **Current Port State**: `Sources/DMS/PowerMenu/PowerMenuView.swift` (156 lines). Immediate click triggers.
- **Mitigation Plan**:
  1. Implement radial progress ring requiring a 1.5-second continuous mouse press or Spacebar hold before dispatching Shutdown or Reboot.
  2. Provide animated tactile progress stroke and cancellation if released early.
- **Pragmatic macOS Compromise**: None.

### MIT-TOOLS-001: Interactive 8x Eyedropper Loupe
- **Upstream Reference**: `quickshell/Modules/ColorPicker/ColorPickerModal.qml`
- **Current Port State**: `Sources/DMS/ColorPicker/ColorPickerView.swift` (168 lines). Static color card.
- **Mitigation Plan**:
  1. Integrate native `NSColorSampler` or custom overlay window sampling screen pixels with an 8x magnifying glass cursor loupe.
  2. Display center pixel RGB, Hex, and HSL values.
  3. On click, copy color to clipboard and append to recent swatches.
- **Pragmatic macOS Compromise**: None. `NSColorSampler` provides pixel-perfect native sampling.

### MIT-TOOLS-002: Wi-Fi QR Code Modal & ANSI Rendering
- **Upstream Reference**: `quickshell/Modals/QRGeneratorModal.qml`
- **Current Port State**: `Sources/DMS/QRGenerator/QRGeneratorView.swift` (166 lines).
- **Mitigation Plan**:
  1. Build dedicated `WifiQRCodeModal` encoding active Wi-Fi credentials into standard `WIFI:T:WPA;S:SSID;P:PASSWORD;;` format.
  2. Support terminal ANSI block rendering in CLI (`dms qr --stdout`).
- **Pragmatic macOS Compromise**: None.

### MIT-PLUG-001: Declarative Plugin Settings Form Generator
- **Upstream Reference**: `quickshell/Modules/Plugins/PluginConfigItem.qml`
- **Current Port State**: `Sources/DMS/Services/PluginService.swift` and `Sources/DMSCore/PluginModel.swift`.
- **Mitigation Plan**:
  1. Implement dynamic SwiftUI form builder parsing plugin JSON schema definitions (`boolean`, `string`, `number`, `enum`).
  2. Render appropriate input controls: Toggles, text inputs, sliders, and picker dropdowns.
- **Pragmatic macOS Compromise**: None.

### MIT-SETUI-A-001: Settings Master-Detail Navigation Split & Search
- **Upstream Reference**: `quickshell/Modals/Settings/DModalMasterDetail.qml`, `settings_search_index.json`
- **Current Port State**: `Sources/DMS/Settings/SettingsView.swift` (simplified 8 tabs).
- **Mitigation Plan**:
  1. Refactor `SettingsView` into a `NavigationSplitView` master-detail layout.
  2. Implement settings search index searching titles, keys, and descriptions across all tabs.
  3. Support deep-linking to specific tabs and sections via `dms settings open <tab>`.
- **Pragmatic macOS Compromise**: None.

### MIT-SETUI-A-002: Live Surface Blur & Opacity Sliders
- **Upstream Reference**: `quickshell/Modules/Settings/ThemeSurfacesTab.qml`
- **Current Port State**: Fixed values.
- **Mitigation Plan**:
  1. Add live interactive sliders for popup surface transparency (0.0 to 1.0), floating window transparency, background blur radius (0 to 60pt), and corner rounding scaling (0% to 100%).
  2. Update shell surfaces in real time as sliders move.
- **Pragmatic macOS Compromise**: None.

### MIT-CLI-001: CLI Subcommand Framework Migration
- **Upstream Reference**: `core/cmd/dms/*` (53 Go source files)
- **Current Port State**: `Sources/DMSCLI/main.swift`. Rudimentary manual argument index checking.
- **Mitigation Plan**:
  1. Migrate `DMSCLI` to Apple's `swift-argument-parser` (`ParsableCommand`).
  2. Implement type-safe command hierarchies: `dms bar`, `dms dock`, `dms island`, `dms settings`, `dms notify`, `dms screenshot`, `dms color`, `dms clipboard`, `dms system`.
  3. Support `--json`, `--quiet`, and `--socket` global flags.
- **Pragmatic macOS Compromise**: None.

### MIT-CLI-002: Thorough `dms doctor` Health Inspection
- **Upstream Reference**: `core/cmd/dms/commands_doctor.go` (62,859 bytes)
- **Current Port State**: 20-line stub checking 3 file paths.
- **Mitigation Plan**:
  1. Expand `dms doctor` to audit macOS system state:
     - Accessibility API permissions (`AXIsProcessTrusted()`)
     - Screen Recording permissions
     - Socket connectivity and ping latency
     - Configuration file validity
     - Connected display count and geometries
     - CoreAudio default device status
     - CoreWLAN interface readiness
- **Pragmatic macOS Compromise**: None.

### MIT-SRV-001: Persistent Socket Streaming & Event Pub/Sub Broker
- **Upstream Reference**: `core/internal/server/subscription.go`
- **Current Port State**: `Sources/DMS/Services/IPCSocketServer.swift`. One-shot request/response only.
- **Mitigation Plan**:
  1. Upgrade socket server to maintain persistent client connections.
  2. Implement event publication/subscription broker (`SUBSCRIBE events.workspaces`, `SUBSCRIBE events.audio`, etc.).
  3. Stream line-delimited JSON events to subscribed clients whenever shell state changes.
- **Pragmatic macOS Compromise**: None.

### MIT-SRV-002: URL Path-Based API Router & Middleware
- **Upstream Reference**: `core/internal/server/router.go`
- **Current Port State**: Flat string switch in `IPCCommandExecutor.swift`.
- **Mitigation Plan**:
  1. Implement structured URL path router (`/api/v1/...`).
  2. Add request validation, error formatting, and logging middleware.
- **Pragmatic macOS Compromise**: None.

### MIT-INST-001: Automated Test Suite Expansion
- **Upstream Reference**: `quickshell/tests/*` (59 automated test suites, ~200 KB code)
- **Current Port State**: Single test file `Tests/DMSCoreTests/DMSCoreTests.swift` (259 lines).
- **Mitigation Plan**:
  1. Expand test suite to cover:
     - M3 CAM16 color conversion and tonal container math
     - Settings JSON encoding, decoding, and `$include` resolution
     - Frecency scoring decay calculations
     - Proximity magnification curve equations (parabolic, gaussian, cosine)
     - Center layout collision solver mathematics
     - IPC wire protocol serialization
- **Pragmatic macOS Compromise**: Use standard Swift unit tests compatible with macOS CommandLineTools.

---

## Step 2: Missing Non-Redundant Features (To Be Implemented)

*Iconic, high-value DMS capabilities absent from both `dms-shell` and native macOS features, providing distinct DMS identity and desktop empowerment.*

### FEAT-ISLAND-001: Dynamic Island Borderless NSPanel Host Window
- **Spec Reference**: `[ISLAND-001]` (`docs/spec/24-island-surface-widgets.md`)
- **Implementation Target**: AppKit `NSPanel` (`ShellPanel` subclass) with `.statusBar` level, `.nonactivatingPanel`, and transparent background.
- **Effort & Priority**: **P0 (Core shell UX)**
- **Scope**: Dedicated floating surface capable of bar-docked, notch-aligned, and free-floating placement.

### FEAT-ISLAND-002: Runge-Kutta 4th-Order VectorSpringMotion Physics
- **Spec Reference**: `[ISLAND-002]` (`docs/spec/24-island-surface-widgets.md`)
- **Implementation Target**: Swift 6 `VectorSpringEngine` driving an 8-DOF RK4 numerical simulation at display refresh rate (60/120/240 Hz).
- **Effort & Priority**: **P0 (Core shell UX)**
- **Scope**: Animates width, height, X/Y translation, and 4 corner radii independently with exact DMS spring tension (`stiffness: 560`, `damping: 37`).

### FEAT-ISLAND-003: Island Priority Activity Arbitration & 19 Faces
- **Spec Reference**: `[ISLAND-003]`, `[ISLAND-004]` (`docs/spec/24-island-surface-widgets.md`)
- **Implementation Target**: SwiftUI State Machine Controller & View hierarchy.
- **Effort & Priority**: **P0 (Core shell UX)**
- **Scope**: Strict arbitration hierarchy (OSD Level > Notification Alert > Media Playback > Idle Home) and all 19 activity face views.

### FEAT-ISLAND-004: MacBook Camera Notch Geometric Integration
- **Spec Reference**: `[ISLAND-005]` (`docs/spec/24-island-surface-widgets.md`)
- **Implementation Target**: AppKit `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` safe-area geometry calculator.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Anchors seamlessly against hardware camera notches with reverse-gothic corner smoothing.

### FEAT-ISLAND-005: Free-Floating Drag Gesture & Desktop Snapping
- **Spec Reference**: `[ISLAND-006]` (`docs/spec/24-island-surface-widgets.md`)
- **Implementation Target**: AppKit mouse drag tracking & SwiftUI gesture bridge.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Detaches island for free placement across displays with margin snapping.

### FEAT-MEDIA-001: Synchronized LRC Lyrics Real-Time Parser & Bar Ticker
- **Spec Reference**: `[MEDIA-001]`, `[MEDIA-002]`, `[MEDIA-003]` (`docs/spec/10-media.md`, `23-dash-weather-calendar.md`)
- **Implementation Target**: Swift 6 background actor & SwiftUI animated lyric ticker view.
- **Effort & Priority**: **P0 (Core shell UX)**
- **Scope**: Millisecond-accurate timestamp parsing, animated scrolling, and active vocal line highlight in DankBar media pill and DDash.

### FEAT-MEDIA-002: Online Lyrics Retrieval Engine (LRCLIB & NetEase)
- **Spec Reference**: `[MEDIA-004]` (`docs/spec/10-media.md`)
- **Implementation Target**: Swift asynchronous HTTP background service (`URLSession`).
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Automatic background fetching of time-synced lyrics based on track title and artist metadata.

### FEAT-MEDIA-003: 4-Bar Mini Equalizer Audio Visualizer
- **Spec Reference**: `[MEDIA-005]` (`docs/spec/10-media.md`)
- **Implementation Target**: SwiftUI Metal shader or CoreAnimation layer.
- **Effort & Priority**: **P2 (Advanced / Polish)**
- **Scope**: Animates in DankBar media pill when audio is actively playing.

### FEAT-DASH-001: DDash 6-Tab Ambient Dashboard Overlay
- **Spec Reference**: `[DASH-001]` (`docs/spec/23-dash-weather-calendar.md`)
- **Implementation Target**: AppKit full-screen / centered `NSPanel` hosting SwiftUI multi-tab view.
- **Effort & Priority**: **P0 (Core shell UX)**
- **Scope**: Master dashboard overlay with Overview, Media, Weather, Wallpapers, Wellbeing, and Notifications tabs.

### FEAT-DASH-002: WeatherEngine & Celestial Sky Arc (`WeatherSky`)
- **Spec Reference**: `[DASH-002]`, `[DASH-003]` (`docs/spec/23-dash-weather-calendar.md`)
- **Implementation Target**: Swift Open-Meteo REST client and SwiftUI Bezier trajectory canvas.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Real-time parabolic visualization of sun and moon across the horizon with astronomical phase calculations and 7-day temperature curves.

### FEAT-DASH-003: Digital Wellbeing Local Screen Time Tracker
- **Spec Reference**: `[DASH-004]` (`docs/spec/23-dash-weather-calendar.md`)
- **Implementation Target**: Background actor monitoring `NSWorkspace` with SQLite 92-day retention.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Tracks foreground app focus duration, produces weekly usage charts, and issues quota warnings.

### FEAT-DASH-004: Full-Bleed Bento Media Hub & Audio Sink Wheel
- **Spec Reference**: `[DASH-005]` (`docs/spec/23-dash-weather-calendar.md`)
- **Implementation Target**: SwiftUI view with CoreAudio output route picker.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Large album art backdrop, full synchronized lyrics stream, and rotary audio device selector.

### FEAT-DOCK-001: Two-Phase Directional Spring Hover Bounce
- **Spec Reference**: `[DOCK-BNC-001]` - `[DOCK-BNC-004]` (`docs/spec/21-dock.md`)
- **Implementation Target**: SwiftUI animation modifier using `emphasizedAccel` (150ms) and `emphasizedDecel` (150ms).
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Directional bounce toward screen center on icon hover.

### FEAT-DOCK-002: Drag-and-Drop Reordering with Midpoint Hysteresis
- **Spec Reference**: `[DOCK-DND-001]` - `[DOCK-DND-004]` (`docs/spec/21-dock.md`)
- **Implementation Target**: SwiftUI gesture tracking with animated slot shifts.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Live icon swap preview as dragged item crosses midpoint of neighboring slots.

### FEAT-DOCK-003: In-Situ Dock Edit Mode Chrome & Trash Slot
- **Spec Reference**: `[DOCK-CFG-004]`, `[DOCK-CFG-006]` (`docs/spec/21-dock.md`)
- **Implementation Target**: SwiftUI overlay toolbar and trash item delegate.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Interactive edit bar with widget adder, delete badges, and trash can slot.

### FEAT-CC-001: Suite of 10 Rich Control Center Detail Subpages
- **Spec Reference**: `[CC-001]` - `[CC-010]` (`docs/spec/22-control-center.md`)
- **Implementation Target**: SwiftUI slide-over detail views.
- **Effort & Priority**: **P0 (Core shell UX)**
- **Scope**: Network scanner, Bluetooth manager, Audio output router, Audio input selector, Display brightness/DDC, Battery discharge curves, DND presets, Idle inhibitor timer, Disk storage gauges, and Running apps monitor.

### FEAT-CC-002: Interactive Tile Grid Edit Mode with 50-Step Undo
- **Spec Reference**: `[CC-011]` (`docs/spec/22-control-center.md`)
- **Implementation Target**: SwiftUI drag reordering coordinator with undo stack.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Drag-to-reorder, drag-to-group into circular `QuickTilesGroup`, drag-to-trash swallow animation, and 50-step undo/redo.

### FEAT-BAR-001: Segmented Pill Grouping with SegmentRoles
- **Spec Reference**: `[BAR-001]` (`docs/spec/19-bar-core.md`)
- **Implementation Target**: Swift layout solver (`BarSegmentRoleSolver.swift`) and `M3SegmentedPill` shape.
- **Effort & Priority**: **P0 (Core shell UX)**
- **Scope**: Organic grouped pills (Launcher, Workspaces, Tasks, Status, Actions) with shared borders and inner dividers.

### FEAT-BARW-001: 27 Missing DankBar Widgets
- **Spec Reference**: `[BARW-001]` - `[BARW-005]` (`docs/spec/20-bar-widgets.md`)
- **Implementation Target**: Modular SwiftUI views in `Sources/DMS/DankBar/Widgets/`.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: AudioVisualizer, CapsLock, CPU temp, GPU monitor, DiskUsage, NetworkIO, Vpn, MediaLyricLine, SystemUpdate, etc.

### FEAT-BARW-002: 7 Integrated Bar Popout Sheets
- **Spec Reference**: `[BARW-006]` (`docs/spec/20-bar-widgets.md`)
- **Implementation Target**: Attached `NSPanel` popouts with concave fillets.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Battery, ColorPicker, Duration, PowerMenu, Vpn, Audio, and Network popout sheets.

### FEAT-WALL-001: Metal GPU Transition Shader Pipeline
- **Spec Reference**: `[WALL-004]`, `[WALL-005]`, `[WALL-006]` (`docs/spec/02-wallpaper.md`)
- **Implementation Target**: Metal Shading Language (`.metal`) pipeline inside desktop-level `NSPanel`.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Crossfade, Wipe with angle, Disc radial expansion, and alternating Stripes transitions.

### FEAT-WALL-002: Aqueous Procedural Live Shader Engine
- **Spec Reference**: `[WALL-009]`, `[WALL-010]` (`docs/spec/02-wallpaper.md`)
- **Implementation Target**: Metal compute/fragment shader rendering animated fluid dynamics and particle waves.
- **Effort & Priority**: **P2 (Advanced / Polish)**
- **Scope**: Live animated procedural wallpaper with real-time parameter tweaking.

### FEAT-FILE-001: Embedded Material Design 3 File Browser Modal
- **Spec Reference**: `[FILE-001]`, `[FILE-002]`, `[FILE-003]` (`docs/spec/08-file-browser-trash.md`)
- **Implementation Target**: SwiftUI modal panel with QuickLook thumbnail generation.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Column, List, and Grid views with rubberband multi-selection and Places sidebar.

### FEAT-FILE-002: Trash Monitor & Confirmation Lifecycle
- **Spec Reference**: `[FILE-004]`, `[FILE-005]` (`docs/spec/08-file-browser-trash.md`)
- **Implementation Target**: DispatchSource file watcher on `~/.Trash` and M3 confirmation dialog.
- **Effort & Priority**: **P2 (Advanced / Polish)**
- **Scope**: Real-time count badges and empty trash safety confirmation.

### FEAT-NOTIF-001: Notification Popup Stack with Swipe Physics
- **Spec Reference**: `[NOTIF-001]` (`docs/spec/25-notifications.md`)
- **Implementation Target**: Floating `NSPanel` stack on top-right screen corner.
- **Effort & Priority**: **P0 (Core shell UX)**
- **Scope**: Timeout countdown progress stroke, interactive horizontal swipe-to-dismiss with spring release, and action buttons.

### FEAT-NOTIF-002: Notification Center Slide-Over Panel & History
- **Spec Reference**: `[NOTIF-002]` (`docs/spec/25-notifications.md`)
- **Implementation Target**: AppKit slide-over sheet with JSON history persistence.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Historical log grouped by application with "Clear All" action.

### FEAT-CLIP-001: In-Situ Clipboard Editor Modal
- **Spec Reference**: `[CLIP-001]` (`docs/spec/26-clipboard.md`)
- **Implementation Target**: SwiftUI modal window.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Directly edit clipboard text buffer before pasting or saving to history.

### FEAT-CLIP-002: Synthetic Cmd+V Auto-Paste Event Injection
- **Spec Reference**: `[CLIP-002]` (`docs/spec/26-clipboard.md`)
- **Implementation Target**: CoreGraphics `CGEventCreateKeyboardEvent` synthesis.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Switches focus to previous active app and injects paste keystroke automatically.

### FEAT-NOTE-001: Live Split-Pane Markdown Preview
- **Spec Reference**: `[NOTE-001]` (`docs/spec/27-notepad.md`)
- **Implementation Target**: SwiftUI split-pane using `AttributedString` or WebKit.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Real-time formatted Markdown rendering alongside plain text editor.

### FEAT-NOTE-002: External File Watcher Conflict Banner
- **Spec Reference**: `[NOTE-002]` (`docs/spec/27-notepad.md`)
- **Implementation Target**: `DispatchSourceFileSystemObject` file descriptor watcher.
- **Effort & Priority**: **P2 (Advanced / Polish)**
- **Scope**: Detects when an open file is modified on disk by an external process and presents reload/overwrite banner.

### FEAT-PLUG-001: Desktop Widgets Transparent Canvas Window
- **Spec Reference**: `[PLUG-001]`, `[PLUG-002]` (`docs/spec/30-plugins-desktop-widgets.md`)
- **Implementation Target**: AppKit `NSWindow` at `kCGDesktopWindowLevel` with click-through support.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Hosts live interactive widgets directly on desktop wallpaper behind all application windows.

### FEAT-PLUG-002: On-Desktop Visual Drag-and-Drop Grid Customizer
- **Spec Reference**: `[PLUG-003]` (`docs/spec/30-plugins-desktop-widgets.md`)
- **Implementation Target**: Interactive overlay window with magnetic grid lines and resize handles.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Magnetic snap guidelines and visual widget positioning directly on the wallpaper.

### FEAT-TOOLS-001: Interactive Region Screenshot Selector HUD
- **Spec Reference**: `[TOOLS-001]` (`docs/spec/29-colorpicker-screenshot-qr.md`)
- **Implementation Target**: Fullscreen transparent `NSPanel` using ScreenCaptureKit.
- **Effort & Priority**: **P1 (Feature parity)**
- **Scope**: Live crosshair cursor, dimension tags (W x H), magnifying corner loupe, and instant copy to clipboard.

### FEAT-CLI-001: `dms dmenu` Drop-In Filter Mode
- **Spec Reference**: `[CLI-001]` (`docs/spec/34-cli.md`)
- **Implementation Target**: Standalone Swift executable reading stdin and writing to stdout.
- **Effort & Priority**: **P0 (Core shell UX)**
- **Scope**: Displays candidate lines in DMS launcher modal and outputs selected item upon confirmation.

### FEAT-CLI-002: `dms shell` Interactive REPL
- **Spec Reference**: `[CLI-002]` (`docs/spec/34-cli.md`)
- **Implementation Target**: Terminal line-reader with tab-completion and socket IPC queries.
- **Effort & Priority**: **P2 (Advanced / Polish)**
- **Scope**: Interactive management terminal for inspecting and toggling DMS state.

### FEAT-INST-001: macOS launchd Service Integration
- **Spec Reference**: `[INST-001]` (`docs/spec/36-install-packaging-tests.md`)
- **Implementation Target**: User LaunchAgent plist (`io.github.jonasnowak.dms.plist`) & CLI installer.
- **Effort & Priority**: **P0 (Core shell UX)**
- **Scope**: Automatic background launch on login, crash auto-recovery, and clean signal termination.

---

## Step 3: Platform Delegations & Native Substitutions (Redundant / Linux-Specific Features)

*Upstream Linux/Wayland-specific capabilities where macOS provides built-in system equivalents, security boundaries prevent direct porting, or clean architectural bridges must be established.*

### PLAT-COMP-001: Wayland Compositor Sockets vs. macOS Quartz & OmniWM
- **Upstream Reference**: `quickshell/Services/CompositorService.qml` (2,237 lines), `HyprlandService.qml`, `NiriService.qml`
- **Spec Reference**: `[COMP-001]` (`docs/spec/15-compositor-workspaces.md`)
- **macOS Native Reality**: macOS does not use Wayland or D-Bus; the display server is Apple's proprietary Quartz Compositor (`WindowServer`). Third-party window tiling is managed by dedicated tools like OmniWM, yabai, or native macOS 15 window tiling.
- **Architectural Boundary & Compromise**: Do NOT implement a custom window tiling manager in `dms-shell`. Instead, maintain a clean IPC bridge subscribing to OmniWM virtual workspace sockets and observing native macOS Mission Control Spaces via private SkyLight APIs (`CGSCopyManagedDisplaySpaces`).

### PLAT-LOCK-001: PAM / Greetd Display Manager vs. macOS LoginWindow & LocalAuthentication
- **Upstream Reference**: `quickshell/DMSGreeter.qml`, `GreeterTab.qml`, `pam-stack.test.mjs`
- **Spec Reference**: `[LOCK-001]` (`docs/spec/17-lock-greeter.md`)
- **macOS Native Reality**: macOS boot-up authentication and user login are owned exclusively by `loginwindow.app`, tightly integrated with FileVault, Apple Silicon Secure Enclave, and System Integrity Protection (SIP). Third-party apps cannot replace the boot greeter.
- **Architectural Boundary & Compromise**: Completely omit standalone login greeter functionality. Implement an in-session shell Lock Screen overlay using full-screen shielding panels at `CGShieldingWindowLevel()` with Touch ID and password validation via the native `LocalAuthentication` framework (`LAContext`).

### PLAT-AUD-001: PipeWire / WirePlumber Graph vs. Apple CoreAudio HAL
- **Upstream Reference**: `core/internal/server/audio/` (PipeWire SPA node graph manipulation)
- **Spec Reference**: `[AUD-001]` (`docs/spec/09-audio-osd.md`)
- **macOS Native Reality**: macOS audio is orchestrated by the CoreAudio Hardware Abstraction Layer (HAL). Third-party user-space applications cannot reconfigure low-level DSP graph connections without specialized kernel or AudioServerPlugIns.
- **Architectural Boundary & Compromise**: Restrict audio management to system master volume, input/output device enumeration, mute toggles, and default sink selection via CoreAudio `AudioObject` APIs. Omit low-level DSP audio node routing.

### PLAT-NET-001: NetworkManager & wpa_supplicant vs. Apple CoreWLAN & configd
- **Upstream Reference**: `quickshell/Services/NetworkService.qml`, `core/internal/server/network/`
- **Spec Reference**: `[NET-001]` (`docs/spec/11-connectivity-qml.md`, `12-connectivity-core.md`)
- **macOS Native Reality**: Network configuration files on macOS are managed internally by `configd` and `SystemConfiguration`. Direct manipulation of raw configuration files is forbidden.
- **Architectural Boundary & Compromise**: Delegate network scanning and credential association to Apple's native `CoreWLAN` framework (`CWWiFiClient`), and network reachability telemetry to `Network.framework` `NWPathMonitor`. Do not write raw network configuration files to disk.

### PLAT-PRINT-001: Embedded CUPS Administration UI vs. macOS AirPrint & System Dialogs
- **Upstream Reference**: `core/internal/server/cups/` (17 Go source files)
- **Spec Reference**: `[NETCORE-001]` (`docs/spec/12-connectivity-core.md`)
- **macOS Native Reality**: macOS has native CUPS built into the operating system alongside AirPrint and Bonjour zero-configuration discovery, accessible via standard Apple print panels.
- **Architectural Boundary & Compromise**: Provide a lightweight read-only printer queue card in Control Center using `lpstat` / `cupsGetDests()`. Omit complex printer driver installation and administration interfaces, deferring to macOS System Settings.

### PLAT-UPDATE-001: Linux Package Managers vs. Homebrew & Apple softwareupdate
- **Upstream Reference**: `quickshell/Modules/SystemUpdate/*` (35 files covering `pacman`, `dnf`, `apt`, `apk`, `nix`)
- **Spec Reference**: `[PROC-001]` (`docs/spec/28-processlist-powermenu-updates.md`)
- **macOS Native Reality**: macOS does not use apt or pacman; package management is split between Homebrew (`brew`) for developer tools and `/usr/sbin/softwareupdate` for macOS system updates.
- **Architectural Boundary & Compromise**: Bind the System Update panel exclusively to `brew outdated --json` and `softwareupdate -l`. Omit all Linux package manager drivers and root repository sync commands.

### PLAT-NOTIF-001: D-Bus Notification Interception vs. Apple UNUserNotificationCenter
- **Upstream Reference**: `quickshell/Services/NotificationService.qml` (`org.freedesktop.Notifications`)
- **Spec Reference**: `[NOTIF-001]` (`docs/spec/25-notifications.md`)
- **macOS Native Reality**: macOS does not permit third-party applications to intercept notifications dispatched by other applications without private system entitlements.
- **Architectural Boundary & Compromise**: Do NOT attempt global notification sniffing. DMS operates as a local notification server for shell-originated alerts, CLI `dms notify` requests, and external script dispatches over the socket, presenting them with full M3 styling while optionally echoing alerts to `UNUserNotificationCenter`.

### PLAT-THEME-001: Linux Pywal / Matugen vs. macOS Application Injection
- **Upstream Reference**: `quickshell/Services/MatugenService.qml`
- **Spec Reference**: `[THEME-001]` (`docs/spec/01-theme.md`)
- **macOS Native Reality**: Linux uses Xresources, pywal templates, and symlinks in `~/.config/`. macOS applications use `.plist` preference domains (`defaults write`) and sandboxed Application Support folders.
- **Architectural Boundary & Compromise**: Downstream theme injection targets macOS terminal emulators (Apple Terminal `.terminal` plists, iTerm2 profiles, Alacritty, Kitty) and VS Code settings, omitting Linux-only GTK/Qt configuration injectors.

### PLAT-DISPLAY-001: Wayland Output Management vs. macOS WindowServer & DisplayServices
- **Upstream Reference**: `quickshell/Modules/Settings/DisplayConfigTab.qml` (2,450 lines)
- **Spec Reference**: `[SETUI-B-001]` (`docs/spec/32-settings-ui-b.md`)
- **macOS Native Reality**: Display scaling, ProMotion refresh rates, True Tone, and multi-monitor relative layout on macOS are deeply integrated into WindowServer and System Settings.
- **Architectural Boundary & Compromise**: Provide visual display diagnostics, resolution/Hz switching, and identification overlays via `CGDisplay` APIs, while deferring complex multi-monitor virtual arrangement canvases to macOS System Settings.

### PLAT-INST-001: Systemd User Units & Linux Distros vs. macOS LaunchAgents & Homebrew
- **Upstream Reference**: `Makefile` systemd targets, `distro/` (Debian, Fedora, openSUSE, Void, FreeBSD)
- **Spec Reference**: `[INST-001]` (`docs/spec/36-install-packaging-tests.md`)
- **macOS Native Reality**: macOS uses `launchd` instead of `systemd`, and software is distributed via `.app` bundles, `.dmg` installers, or Homebrew Formulae.
- **Architectural Boundary & Compromise**: Replace all systemd service files with a single native LaunchAgent (`~/Library/LaunchAgents/io.github.jonasnowak.dms.plist`) and package the application as `DankMaterialShell.app` with Homebrew Formula support.

---

## 4. Traceability & Specification Index

Every module and specification document from `01` through `36` is accounted for in this execution blueprint:

| Spec # | Module ID & Title | Step 1 Mitigations | Step 2 Missing Features | Step 3 Platform Delegations |
|:---|:---|:---|:---|:---|
| **01** | `THEME` Theming & Tokens | `MIT-THEME-001` | `FEAT-THEME-001` - `003` | `PLAT-THEME-001` |
| **02** | `WALL` Wallpaper & Shaders | — | `FEAT-WALL-001`, `002` | `PLAT-WALL-001` |
| **03** | `SETD` Settings Data Schema | `MIT-SETD-001` | — | `PLAT-SETD-001` |
| **04** | `SESS` Session & I18n | `MIT-SESS-001` | — | `PLAT-SESS-001` |
| **05** | `SHELL` Shell Root & IPC | `MIT-SHELL-001`, `002` | — | `PLAT-SHELL-001` |
| **06** | `SURF` Surfaces & Popouts | `MIT-SURF-001` | — | `PLAT-SURF-001` |
| **07** | `WIDG` Widget Library | `MIT-WIDG-001` | — | `PLAT-WIDG-001` |
| **08** | `FILE` File Browser & Trash | — | `FEAT-FILE-001`, `002` | `PLAT-FILE-001` |
| **09** | `AUD` Audio & OSD | `MIT-AUD-001`, `002` | — | `PLAT-AUD-001` |
| **10** | `MEDIA` Media & Lyrics | `MIT-MEDIA-001` | `FEAT-MEDIA-001` - `003` | `PLAT-MEDIA-001` |
| **11** | `NET` Connectivity QML | `MIT-NET-001`, `002` | — | `PLAT-NET-001` |
| **12** | `NETCORE` Connectivity Core | — | — | `PLAT-PRINT-001` |
| **13** | `PWR` Power & Display | `MIT-PWR-001` - `003` | — | `PLAT-PWR-001` |
| **14** | `IDLE` Session & Idle | `MIT-IDLE-001` | — | `PLAT-IDLE-001` |
| **15** | `COMP` Compositor Workspaces | `MIT-COMP-001`, `002` | — | `PLAT-COMP-001` |
| **16** | `KEYB` Keybinds Engine | `MIT-KEYB-001`, `002` | — | `PLAT-KEYB-001` |
| **17** | `LOCK` Lock Screen & Greeter | — | — | `PLAT-LOCK-001` |
| **18** | `LAUNCH` DLauncherV2 | `MIT-LAUNCH-001`, `002` | — | `PLAT-LAUNCH-001` |
| **19** | `BAR` DankBar Core | `MIT-BAR-001` - `003` | `FEAT-BAR-001` | `PLAT-BAR-001` |
| **20** | `BARW` DankBar Widgets | `MIT-BARW-001` | `FEAT-BARW-001`, `002` | `PLAT-BARW-001` |
| **21** | `DOCK` Desktop Dock | `MIT-DOCK-001`, `002` | `FEAT-DOCK-001` - `003` | `PLAT-DOCK-001` |
| **22** | `CC` Control Center | `MIT-CC-001`, `002` | `FEAT-CC-001`, `002` | `PLAT-CC-001` |
| **23** | `DASH` DDash & Weather | `MIT-DASH-001`, `002` | `FEAT-DASH-001` - `004` | `PLAT-DASH-001` |
| **24** | `ISLAND` Dynamic Island | — | `FEAT-ISLAND-001` - `005` | `PLAT-ISLAND-001` |
| **25** | `NOTIF` Notifications | `MIT-NOTIF-001` | `FEAT-NOTIF-001`, `002` | `PLAT-NOTIF-001` |
| **26** | `CLIP` Clipboard Manager | `MIT-CLIP-001`, `002` | `FEAT-CLIP-001`, `002` | `PLAT-CLIP-001` |
| **27** | `NOTE` Notepad | `MIT-NOTE-001`, `002` | `FEAT-NOTE-001`, `002` | `PLAT-NOTE-001` |
| **28** | `PROC` Process Monitor | `MIT-PROC-001`, `002` | — | `PLAT-UPDATE-001` |
| **29** | `TOOLS` Tools & Screenshot | `MIT-TOOLS-001`, `002` | `FEAT-TOOLS-001` | `PLAT-TOOLS-001` |
| **30** | `PLUG` Plugins & Desktop | `MIT-PLUG-001` | `FEAT-PLUG-001`, `002` | `PLAT-PLUG-001` |
| **31** | `SETUI-A` Settings App Theme | `MIT-SETUI-A-001`, `002` | — | `PLAT-THEME-001` |
| **32** | `SETUI-B` Settings App Layout | — | — | `PLAT-DISPLAY-001` |
| **33** | `SETUI-C` Settings App System | — | — | `PLAT-COMP-001` |
| **34** | `CLI` DMS Command Line | `MIT-CLI-001`, `002` | `FEAT-CLI-001`, `002` | `PLAT-CLI-001` |
| **35** | `SRV` Socket Server & Broker | `MIT-SRV-001`, `002` | — | `PLAT-SRV-001` |
| **36** | `INST` Packaging & Tests | `MIT-INST-001` | `FEAT-INST-001` | `PLAT-INST-001` |

---

## 5. Phased Implementation Roadmap

```
Phase 1: Foundations & Behavioral Corrections (Step 1 Core)
├── 1.1 Expand Config.swift to 427-key hierarchy & barConfigs/dockConfigs arrays (MIT-SETD-001)
├── 1.2 Implement CAM16/HCT tonal color generator & softContainer formula (MIT-THEME-001)
├── 1.3 Upgrade IPCSocketServer with persistent connections & pub/sub broker (MIT-SRV-001, MIT-SRV-002)
├── 1.4 Port Scorer.js weighted frecency decay algorithm into Swift 6 (MIT-LAUNCH-001)
└── 1.5 Implement CenterLayout.js geometric center collision avoidance (MIT-BAR-002)

Phase 2: Core Shell Surfaces & Interaction Physics
├── 2.1 Multi-bar layout engine with vertical Left/Right edges & SegmentRoles (MIT-BAR-001, FEAT-BAR-001)
├── 2.2 Proximity magnification decay curves & active dot-to-pill elongation (MIT-DOCK-001, MIT-DOCK-002)
├── 2.3 Connected mode concave fillet geometry & animated panel frame resizing (MIT-SURF-001)
├── 2.4 Control Center 2D bin-packed grid and detail subpage navigation (MIT-CC-001, MIT-CC-002)
└── 2.5 Complete full-spectrum OSD HUD suite (10 HUD kinds) & hover-pause toasts (MIT-AUD-001, MIT-SHELL-001)

Phase 3: High-Value Iconic DMS Features (Step 2 Implementation)
├── 3.1 DIsland NSPanel host with 8-DOF VectorSpringMotion RK4 physics (FEAT-ISLAND-001, 002)
├── 3.2 Dynamic Island activity priority arbitration (OSD > Notif > Media > Home) & 19 faces (FEAT-ISLAND-003)
├── 3.3 Synchronized LRC lyric engine with bar ticker & LRCLIB fetching (FEAT-MEDIA-001, 002)
├── 3.4 DDash 6-tab ambient overlay with WeatherSky celestial arc & Wellbeing (FEAT-DASH-001, 002, 003)
└── 3.5 Floating notification popup stack with swipe physics & slide-over history (FEAT-NOTIF-001, 002)

Phase 4: Productivity Modules, Utilities & CLI
├── 4.1 SQLite clipboard database with SHA-256 deduplication & in-situ editor (MIT-CLIP-001, FEAT-CLIP-001)
├── 4.2 Multi-tab notepad with split Markdown preview & line numbers (MIT-NOTE-001, 002, FEAT-NOTE-001)
├── 4.3 ScreenCaptureKit screenshot selector HUD & 8x eyedropper loupe (FEAT-TOOLS-001, MIT-TOOLS-001)
├── 4.4 Desktop widgets transparent canvas & visual drag-and-drop editor (FEAT-PLUG-001, 002)
├── 4.5 dms dmenu drop-in filter mode & dms shell interactive REPL (FEAT-CLI-001, 002)
└── 4.6 Hold-to-confirm power menu radial progress ring (MIT-PROC-002)

Phase 5: Packaging, macOS LaunchAgent & Regression Verification
├── 5.1 Native launchd LaunchAgent daemon plist installer & CLI commands (FEAT-INST-001)
├── 5.2 Homebrew Formula recipe & self-contained signed macOS .app bundle
└── 5.3 Automated XCTest suite expansion matching upstream test coverage (MIT-INST-001)
```

---

## 7. Master Upstream DMS File Coverage Manifest (100% Inventory — 1,661 Files)

| # | Upstream File Path | Target Spec Document | Reimplementation Step | Subsystem Role |
|---|---|---|---|---|
| 1 | `.agents/skills/dms-plugin-dev/assets/templates/daemon/Daemon.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 2 | `.agents/skills/dms-plugin-dev/assets/templates/daemon/Settings.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 3 | `.agents/skills/dms-plugin-dev/assets/templates/dash-card/Card.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 4 | `.agents/skills/dms-plugin-dev/assets/templates/dash-tab/Tab.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 5 | `.agents/skills/dms-plugin-dev/assets/templates/desktop/Settings.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 6 | `.agents/skills/dms-plugin-dev/assets/templates/desktop/Widget.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 7 | `.agents/skills/dms-plugin-dev/assets/templates/launcher/Launcher.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 8 | `.agents/skills/dms-plugin-dev/assets/templates/launcher/Settings.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 9 | `.agents/skills/dms-plugin-dev/assets/templates/widget/Settings.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 10 | `.agents/skills/dms-plugin-dev/assets/templates/widget/Widget.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 11 | `core/cmd/dankinstall/main.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 12 | `core/cmd/dms/commands_auth.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 13 | `core/cmd/dms/commands_backup.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 14 | `core/cmd/dms/commands_blur.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 15 | `core/cmd/dms/commands_brightness.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 16 | `core/cmd/dms/commands_chroma.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 17 | `core/cmd/dms/commands_clipboard.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 18 | `core/cmd/dms/commands_colorpicker.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 19 | `core/cmd/dms/commands_common.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 20 | `core/cmd/dms/commands_config.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 21 | `core/cmd/dms/commands_dank16.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 22 | `core/cmd/dms/commands_dmenu.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 23 | `core/cmd/dms/commands_doctor.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 24 | `core/cmd/dms/commands_download.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 25 | `core/cmd/dms/commands_dpms.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 26 | `core/cmd/dms/commands_features.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 27 | `core/cmd/dms/commands_greeter.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 28 | `core/cmd/dms/commands_icc.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 29 | `core/cmd/dms/commands_keybinds.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 30 | `core/cmd/dms/commands_matugen.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 31 | `core/cmd/dms/commands_notify.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 32 | `core/cmd/dms/commands_open.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 33 | `core/cmd/dms/commands_qr.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 34 | `core/cmd/dms/commands_randr.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 35 | `core/cmd/dms/commands_registry.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 36 | `core/cmd/dms/commands_root.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 37 | `core/cmd/dms/commands_screenshot.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 38 | `core/cmd/dms/commands_session.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 39 | `core/cmd/dms/commands_setup.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 40 | `core/cmd/dms/commands_setup_headless.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 41 | `core/cmd/dms/commands_system.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 42 | `core/cmd/dms/commands_trash.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 43 | `core/cmd/dms/commands_windowrules.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 44 | `core/cmd/dms/dpms_client.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 45 | `core/cmd/dms/immutable_policy.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 46 | `core/cmd/dms/main.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 47 | `core/cmd/dms/main_distro.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 48 | `core/cmd/dms/randr_client.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 49 | `core/cmd/dms/server_client.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 50 | `core/cmd/dms/shell.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 51 | `core/cmd/dms/shellapp.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 52 | `core/cmd/dms/systemd_restart.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 53 | `core/cmd/dms/ui.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 54 | `core/cmd/dms/utils.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 55 | `core/internal/backup/backup.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 56 | `core/internal/blur/probe.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 57 | `core/internal/clipboard/clipboard.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 58 | `core/internal/clipboard/pastekey.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 59 | `core/internal/clipboard/store.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 60 | `core/internal/clipboard/watch.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 61 | `core/internal/clipboard/wl.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 62 | `core/internal/clipolicy/clipolicy.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 63 | `core/internal/colorpicker/color.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 64 | `core/internal/colorpicker/picker.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 65 | `core/internal/colorpicker/shm.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 66 | `core/internal/colorpicker/state.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 67 | `core/internal/config/deployer.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 68 | `core/internal/config/dms.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 69 | `core/internal/config/hyprland.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 70 | `core/internal/config/hyprland_lua.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 71 | `core/internal/config/hyprland_session_target.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 72 | `core/internal/config/mango.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 73 | `core/internal/config/mango_deploy.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 74 | `core/internal/config/niri.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 75 | `core/internal/config/terminals.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 76 | `core/internal/config/testpage.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 77 | `core/internal/configfrag/status.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 78 | `core/internal/configfrag/walk.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 79 | `core/internal/dank16/dank16.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 80 | `core/internal/dank16/terminals.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 81 | `core/internal/deps/detector.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 82 | `core/internal/distros/arch.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 83 | `core/internal/distros/base.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 84 | `core/internal/distros/debian.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 85 | `core/internal/distros/debian_obs.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 86 | `core/internal/distros/dsearch_service.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 87 | `core/internal/distros/factory.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 88 | `core/internal/distros/fedora.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 89 | `core/internal/distros/gentoo.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 90 | `core/internal/distros/interface.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 91 | `core/internal/distros/manual_packages.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 92 | `core/internal/distros/minimal_install.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 93 | `core/internal/distros/opensuse.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 94 | `core/internal/distros/osinfo.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 95 | `core/internal/distros/pgpkey.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 96 | `core/internal/distros/ubuntu.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 97 | `core/internal/distros/void.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 98 | `core/internal/dmenuipc/queue.go` | [`05-shell-root-ipc.md`](05-shell-root-ipc.md) | **Step 1** | Shell root and IPC router |
| 99 | `core/internal/dmenuipc/socket.go` | [`05-shell-root-ipc.md`](05-shell-root-ipc.md) | **Step 1** | Shell root and IPC router |
| 100 | `core/internal/errdefs/errdefs.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 101 | `core/internal/geolocation/client.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 102 | `core/internal/geolocation/client_geoclue.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 103 | `core/internal/geolocation/client_ip.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 104 | `core/internal/geolocation/types.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 105 | `core/internal/gpu/eglvendor.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 106 | `core/internal/headless/runner.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 107 | `core/internal/highlight/generate.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 108 | `core/internal/highlight/lexers/caddyfile.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 109 | `core/internal/highlight/lexers/cl.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 110 | `core/internal/highlight/lexers/emacs.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 111 | `core/internal/highlight/lexers/erb.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 112 | `core/internal/highlight/lexers/gemtext.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 113 | `core/internal/highlight/lexers/genshi.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 114 | `core/internal/highlight/lexers/go.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 115 | `core/internal/highlight/lexers/haxe.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 116 | `core/internal/highlight/lexers/html.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 117 | `core/internal/highlight/lexers/http.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 118 | `core/internal/highlight/lexers/lexers.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 119 | `core/internal/highlight/lexers/markdown.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 120 | `core/internal/highlight/lexers/markless.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 121 | `core/internal/highlight/lexers/php.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 122 | `core/internal/highlight/lexers/raku.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 123 | `core/internal/highlight/lexers/rst.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 124 | `core/internal/highlight/lexers/svelte.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 125 | `core/internal/highlight/lexers/typoscript.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 126 | `core/internal/highlight/lexers/yaml_jinja.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 127 | `core/internal/highlight/markdown.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 128 | `core/internal/highlight/styles/styles.go` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 129 | `core/internal/icc/parser.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 130 | `core/internal/keybinds/discovery.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 131 | `core/internal/keybinds/providers/aqueous.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 132 | `core/internal/keybinds/providers/aqueous_config.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 133 | `core/internal/keybinds/providers/hyprland.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 134 | `core/internal/keybinds/providers/hyprland_lua_expand.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 135 | `core/internal/keybinds/providers/hyprland_parser.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 136 | `core/internal/keybinds/providers/jsonfile.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 137 | `core/internal/keybinds/providers/mangowc.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 138 | `core/internal/keybinds/providers/mangowc_parser.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 139 | `core/internal/keybinds/providers/miracle.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 140 | `core/internal/keybinds/providers/miracle_parser.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 141 | `core/internal/keybinds/providers/niri.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 142 | `core/internal/keybinds/providers/niri_parser.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 143 | `core/internal/keybinds/providers/scroll.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 144 | `core/internal/keybinds/providers/sway.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 145 | `core/internal/keybinds/providers/sway_parser.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 146 | `core/internal/keybinds/registry.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 147 | `core/internal/keybinds/types.go` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 148 | `core/internal/log/filelogger.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 149 | `core/internal/log/log.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 150 | `core/internal/lowprio/lowprio.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 151 | `core/internal/lowprio/lowprio_linux.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 152 | `core/internal/lowprio/lowprio_other.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 153 | `core/internal/luaconfig/lua.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 154 | `core/internal/mangoconf/dialect.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 155 | `core/internal/mangoconf/migrate.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 156 | `core/internal/mangoconf/session.go` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 157 | `core/internal/matugen/matugen.go` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 158 | `core/internal/matugen/paletteinject.go` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 159 | `core/internal/matugen/qtengine.go` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 160 | `core/internal/matugen/queue.go` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 161 | `core/internal/matugen/seedcache.go` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 162 | `core/internal/matugen/signal_freebsd.go` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 163 | `core/internal/matugen/signal_linux.go` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 164 | `core/internal/matugen/sourcecolor.go` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 165 | `core/internal/matugen/spec.go` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 166 | `core/internal/matugen/svgsource.go` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 167 | `core/internal/netfetch/netfetch.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 168 | `core/internal/netfetch/release.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 169 | `core/internal/notify/notify.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 170 | `core/internal/pam/pam.go` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 171 | `core/internal/plugins/feedback.go` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 172 | `core/internal/plugins/lockfile.go` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 173 | `core/internal/plugins/lyrics.go` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 174 | `core/internal/plugins/manager.go` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 175 | `core/internal/plugins/manager_lockfile.go` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 176 | `core/internal/plugins/registry.go` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 177 | `core/internal/plugins/search.go` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 178 | `core/internal/privesc/privesc.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 179 | `core/internal/proto/keyboard_shortcuts_inhibit/keyboard_shortcuts_inhibit.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 180 | `core/internal/proto/linux_dmabuf/linux_dmabuf.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 181 | `core/internal/proto/virtual_keyboard/virtual_keyboard.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 182 | `core/internal/proto/wlr_gamma_control/gamma_control.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 183 | `core/internal/proto/wlr_layer_shell/layer_shell.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 184 | `core/internal/proto/wlr_output_management/output_management.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 185 | `core/internal/proto/wlr_output_power/output_power.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 186 | `core/internal/proto/wlr_screencopy/screencopy.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 187 | `core/internal/proto/wp_color_management/color_management.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 188 | `core/internal/proto/wp_color_management/query.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 189 | `core/internal/proto/wp_cursor_shape/cursor_shape.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 190 | `core/internal/proto/wp_viewporter/viewporter.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 191 | `core/internal/qrcode/qrcode.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 192 | `core/internal/qsipc/client.go` | [`05-shell-root-ipc.md`](05-shell-root-ipc.md) | **Step 1** | Shell root and IPC router |
| 193 | `core/internal/registries/registries.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 194 | `core/internal/screenshot/aqueous.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 195 | `core/internal/screenshot/aqueous_snapshot.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 196 | `core/internal/screenshot/cicp.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 197 | `core/internal/screenshot/compositor.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 198 | `core/internal/screenshot/encode.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 199 | `core/internal/screenshot/jpeg.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 200 | `core/internal/screenshot/niri_window.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 201 | `core/internal/screenshot/notify.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 202 | `core/internal/screenshot/png.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 203 | `core/internal/screenshot/region.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 204 | `core/internal/screenshot/region_input.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 205 | `core/internal/screenshot/region_render.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 206 | `core/internal/screenshot/screenshot.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 207 | `core/internal/screenshot/scroll.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 208 | `core/internal/screenshot/shm.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 209 | `core/internal/screenshot/state.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 210 | `core/internal/screenshot/stitch.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 211 | `core/internal/screenshot/theme.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 212 | `core/internal/screenshot/types.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 213 | `core/internal/server/apppicker/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 214 | `core/internal/server/apppicker/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 215 | `core/internal/server/apppicker/models.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 216 | `core/internal/server/bluez/agent.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 217 | `core/internal/server/bluez/broker.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 218 | `core/internal/server/bluez/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 219 | `core/internal/server/bluez/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 220 | `core/internal/server/bluez/player.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 221 | `core/internal/server/bluez/rfkill_freebsd.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 222 | `core/internal/server/bluez/rfkill_linux.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 223 | `core/internal/server/bluez/subscription_broker.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 224 | `core/internal/server/bluez/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 225 | `core/internal/server/bluez/watcher.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 226 | `core/internal/server/brightness/backlight_freebsd.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 227 | `core/internal/server/brightness/ddc.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 228 | `core/internal/server/brightness/ddc_filter.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 229 | `core/internal/server/brightness/devd_freebsd.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 230 | `core/internal/server/brightness/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 231 | `core/internal/server/brightness/logind.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 232 | `core/internal/server/brightness/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 233 | `core/internal/server/brightness/native_freebsd.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 234 | `core/internal/server/brightness/native_linux.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 235 | `core/internal/server/brightness/sysfs.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 236 | `core/internal/server/brightness/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 237 | `core/internal/server/brightness/udev_linux.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 238 | `core/internal/server/browser/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 239 | `core/internal/server/browser/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 240 | `core/internal/server/browser/models.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 241 | `core/internal/server/clipboard/handlers.go` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 242 | `core/internal/server/clipboard/manager.go` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 243 | `core/internal/server/clipboard/types.go` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 244 | `core/internal/server/cups/actions.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 245 | `core/internal/server/cups/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 246 | `core/internal/server/cups/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 247 | `core/internal/server/cups/pkhelper.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 248 | `core/internal/server/cups/subscription.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 249 | `core/internal/server/cups/subscription_dbus.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 250 | `core/internal/server/cups/test_connection.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 251 | `core/internal/server/cups/testing.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 252 | `core/internal/server/cups/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 253 | `core/internal/server/dbus/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 254 | `core/internal/server/dbus/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 255 | `core/internal/server/dbus/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 256 | `core/internal/server/dgop/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 257 | `core/internal/server/dgop/worker.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 258 | `core/internal/server/evdev/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 259 | `core/internal/server/evdev/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 260 | `core/internal/server/evdev/models.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 261 | `core/internal/server/files.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 262 | `core/internal/server/freedesktop/actions.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 263 | `core/internal/server/freedesktop/constants.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 264 | `core/internal/server/freedesktop/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 265 | `core/internal/server/freedesktop/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 266 | `core/internal/server/freedesktop/screensaver.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 267 | `core/internal/server/freedesktop/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 268 | `core/internal/server/location/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 269 | `core/internal/server/location/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 270 | `core/internal/server/location/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 271 | `core/internal/server/loginctl/actions.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 272 | `core/internal/server/loginctl/constants.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 273 | `core/internal/server/loginctl/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 274 | `core/internal/server/loginctl/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 275 | `core/internal/server/loginctl/monitor.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 276 | `core/internal/server/loginctl/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 277 | `core/internal/server/lyrics/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 278 | `core/internal/server/matugen_handler.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 279 | `core/internal/server/mime/detect.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 280 | `core/internal/server/mime/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 281 | `core/internal/server/models/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 282 | `core/internal/server/network/agent_iwd.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 283 | `core/internal/server/network/agent_networkmanager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 284 | `core/internal/server/network/backend.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 285 | `core/internal/server/network/backend_hybrid_iwd_networkd.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 286 | `core/internal/server/network/backend_iwd.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 287 | `core/internal/server/network/backend_iwd_signals.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 288 | `core/internal/server/network/backend_iwd_unimplemented.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 289 | `core/internal/server/network/backend_iwd_wifi.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 290 | `core/internal/server/network/backend_networkd.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 291 | `core/internal/server/network/backend_networkd_ethernet.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 292 | `core/internal/server/network/backend_networkd_signals.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 293 | `core/internal/server/network/backend_networkd_unimplemented.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 294 | `core/internal/server/network/backend_networkmanager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 295 | `core/internal/server/network/backend_networkmanager_cellular.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 296 | `core/internal/server/network/backend_networkmanager_ethernet.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 297 | `core/internal/server/network/backend_networkmanager_fortinet_saml.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 298 | `core/internal/server/network/backend_networkmanager_gp_saml.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 299 | `core/internal/server/network/backend_networkmanager_hotspot.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 300 | `core/internal/server/network/backend_networkmanager_modem.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 301 | `core/internal/server/network/backend_networkmanager_signals.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 302 | `core/internal/server/network/backend_networkmanager_state.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 303 | `core/internal/server/network/backend_networkmanager_vpn.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 304 | `core/internal/server/network/backend_networkmanager_wifi.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 305 | `core/internal/server/network/backend_wpa.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 306 | `core/internal/server/network/backend_wpa_ctrl.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 307 | `core/internal/server/network/backend_wpa_ethernet.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 308 | `core/internal/server/network/backend_wpa_events.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 309 | `core/internal/server/network/backend_wpa_unimplemented.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 310 | `core/internal/server/network/backend_wpa_wifi.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 311 | `core/internal/server/network/broker.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 312 | `core/internal/server/network/detect.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 313 | `core/internal/server/network/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 314 | `core/internal/server/network/helpers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 315 | `core/internal/server/network/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 316 | `core/internal/server/network/monitor.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 317 | `core/internal/server/network/openfortivpn_import.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 318 | `core/internal/server/network/priority.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 319 | `core/internal/server/network/qr_generator.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 320 | `core/internal/server/network/secret_service.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 321 | `core/internal/server/network/subscription_broker.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 322 | `core/internal/server/network/testing.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 323 | `core/internal/server/network/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 324 | `core/internal/server/network/wifi_qrcode.go` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 325 | `core/internal/server/network/wifi_saved.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 326 | `core/internal/server/notifyactions/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 327 | `core/internal/server/notifyactions/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 328 | `core/internal/server/plugins/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 329 | `core/internal/server/plugins/install.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 330 | `core/internal/server/plugins/list.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 331 | `core/internal/server/plugins/list_installed.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 332 | `core/internal/server/plugins/search.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 333 | `core/internal/server/plugins/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 334 | `core/internal/server/plugins/uninstall.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 335 | `core/internal/server/plugins/update.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 336 | `core/internal/server/plugins/utils.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 337 | `core/internal/server/registries/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 338 | `core/internal/server/router.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 339 | `core/internal/server/runtime.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 340 | `core/internal/server/server.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 341 | `core/internal/server/subscription.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 342 | `core/internal/server/sysupdate/backend.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 343 | `core/internal/server/sysupdate/backend_apt.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 344 | `core/internal/server/sysupdate/backend_dnf.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 345 | `core/internal/server/sysupdate/backend_flatpak.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 346 | `core/internal/server/sysupdate/backend_pacman.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 347 | `core/internal/server/sysupdate/backend_pkg.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 348 | `core/internal/server/sysupdate/backend_portage.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 349 | `core/internal/server/sysupdate/backend_rpmostree.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 350 | `core/internal/server/sysupdate/backend_shelly.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 351 | `core/internal/server/sysupdate/backend_xbps.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 352 | `core/internal/server/sysupdate/backend_zypper.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 353 | `core/internal/server/sysupdate/executor.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 354 | `core/internal/server/sysupdate/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 355 | `core/internal/server/sysupdate/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 356 | `core/internal/server/sysupdate/reboot.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 357 | `core/internal/server/sysupdate/releases.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 358 | `core/internal/server/sysupdate/shell.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 359 | `core/internal/server/sysupdate/targets.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 360 | `core/internal/server/sysupdate/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 361 | `core/internal/server/tailscale/client.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 362 | `core/internal/server/tailscale/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 363 | `core/internal/server/tailscale/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 364 | `core/internal/server/tailscale/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 365 | `core/internal/server/thememode/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 366 | `core/internal/server/thememode/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 367 | `core/internal/server/thememode/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 368 | `core/internal/server/themes/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 369 | `core/internal/server/themes/install.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 370 | `core/internal/server/themes/list.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 371 | `core/internal/server/themes/list_installed.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 372 | `core/internal/server/themes/search.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 373 | `core/internal/server/themes/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 374 | `core/internal/server/themes/uninstall.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 375 | `core/internal/server/themes/update.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 376 | `core/internal/server/trayrecovery/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 377 | `core/internal/server/trayrecovery/recovery.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 378 | `core/internal/server/trayrecovery/suspend_freebsd.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 379 | `core/internal/server/trayrecovery/suspend_linux.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 380 | `core/internal/server/wallpaper/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 381 | `core/internal/server/wallpaper/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 382 | `core/internal/server/wallpaper/state.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 383 | `core/internal/server/wallpaper/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 384 | `core/internal/server/wayland/gamma.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 385 | `core/internal/server/wayland/geolocation.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 386 | `core/internal/server/wayland/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 387 | `core/internal/server/wayland/iccconfig.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 388 | `core/internal/server/wayland/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 389 | `core/internal/server/wayland/suncalc.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 390 | `core/internal/server/wayland/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 391 | `core/internal/server/wellbeing/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 392 | `core/internal/server/wellbeing/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 393 | `core/internal/server/wellbeing/store.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 394 | `core/internal/server/wellbeing/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 395 | `core/internal/server/wlcontext/context.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 396 | `core/internal/server/wlroutput/handlers.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 397 | `core/internal/server/wlroutput/manager.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 398 | `core/internal/server/wlroutput/types.go` | [`35-core-server-protocol.md`](35-core-server-protocol.md) | **Step 1** | Core socket protocol & pub/sub broker |
| 399 | `core/internal/shellembed/embed_stub.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 400 | `core/internal/shellembed/embed_withshell.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 401 | `core/internal/shellembed/shellembed.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 402 | `core/internal/site/site.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 403 | `core/internal/systemd/notify.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 404 | `core/internal/systemd/timeout.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 405 | `core/internal/themes/manager.go` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 406 | `core/internal/themes/registry.go` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 407 | `core/internal/themes/search.go` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 408 | `core/internal/tui/app.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 409 | `core/internal/tui/banner.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 410 | `core/internal/tui/messages.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 411 | `core/internal/tui/states.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 412 | `core/internal/tui/styles.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 413 | `core/internal/tui/views_config.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 414 | `core/internal/tui/views_dependencies.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 415 | `core/internal/tui/views_gentoo_gcc.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 416 | `core/internal/tui/views_gentoo_use_flags.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 417 | `core/internal/tui/views_install.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 418 | `core/internal/tui/views_password.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 419 | `core/internal/tui/views_privesc.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 420 | `core/internal/tui/views_selection.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 421 | `core/internal/tui/views_welcome.go` | [`34-cli.md`](34-cli.md) | **Step 1 & 2** | CLI commands, dmenu filter, shell REPL |
| 422 | `core/internal/utils/dbus.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 423 | `core/internal/utils/exec.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 424 | `core/internal/utils/flatpak.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 425 | `core/internal/utils/greeter_setup.go` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 426 | `core/internal/utils/group.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 427 | `core/internal/utils/gsettings.go` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 428 | `core/internal/utils/instancelock.go` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 429 | `core/internal/utils/math.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 430 | `core/internal/utils/paths.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 431 | `core/internal/utils/slices.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 432 | `core/internal/version/version.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 433 | `core/internal/wayland/client/helpers.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 434 | `core/internal/wayland/keymap/keymap.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 435 | `core/internal/wayland/keymap/seat.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 436 | `core/internal/wayland/shm/buffer.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 437 | `core/internal/wayland/shm/fd_freebsd.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 438 | `core/internal/wayland/shm/fd_linux.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 439 | `core/internal/windowrules/providers/hyprland_parser.go` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 440 | `core/internal/windowrules/providers/mango_parser.go` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 441 | `core/internal/windowrules/providers/niri_parser.go` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 442 | `core/internal/windowrules/store.go` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 443 | `core/internal/windowrules/types.go` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 444 | `core/pkg/ipp/adapter-http.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 445 | `core/pkg/ipp/adapter.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 446 | `core/pkg/ipp/attribute.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 447 | `core/pkg/ipp/constants.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 448 | `core/pkg/ipp/cups-client.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 449 | `core/pkg/ipp/error.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 450 | `core/pkg/ipp/ipp-client.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 451 | `core/pkg/ipp/request.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 452 | `core/pkg/ipp/response.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 453 | `core/pkg/ipp/utils.go` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 454 | `dank-qml-common/Common/Anims.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 455 | `dank-qml-common/Common/CacheData.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 456 | `dank-qml-common/Common/I18n.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 457 | `dank-qml-common/Common/Paths.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 458 | `dank-qml-common/Common/SettingsData.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 459 | `dank-qml-common/Common/Theme.qml` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 460 | `dank-qml-common/DCommon/Common/Accents.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 461 | `dank-qml-common/DCommon/Common/Anims.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 462 | `dank-qml-common/DCommon/Common/Appearance.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 463 | `dank-qml-common/DCommon/Common/Compositor.qml` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 464 | `dank-qml-common/DCommon/Common/Contrast.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 465 | `dank-qml-common/DCommon/Common/DAnim.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 466 | `dank-qml-common/DCommon/Common/DColorAnim.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 467 | `dank-qml-common/DCommon/Common/DSocket.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 468 | `dank-qml-common/DCommon/Common/ElevationShadow.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 469 | `dank-qml-common/DCommon/Common/FocusNavigation.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 470 | `dank-qml-common/DCommon/Common/Fonts.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 471 | `dank-qml-common/DCommon/Common/Hct.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 472 | `dank-qml-common/DCommon/Common/Host.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 473 | `dank-qml-common/DCommon/Common/I18n.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 474 | `dank-qml-common/DCommon/Common/LayoutCodes.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 475 | `dank-qml-common/DCommon/Common/Log.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 476 | `dank-qml-common/DCommon/Common/MaterialWallpaper.js` | [`02-wallpaper.md`](02-wallpaper.md) | **Step 1** | Wallpaper engine and transition shaders |
| 477 | `dank-qml-common/DCommon/Common/Paths.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 478 | `dank-qml-common/DCommon/Common/Proc.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 479 | `dank-qml-common/DCommon/Common/Shape.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 480 | `dank-qml-common/DCommon/Common/SpringMotion.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 481 | `dank-qml-common/DCommon/Common/Style.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 482 | `dank-qml-common/DCommon/Common/Surface.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 483 | `dank-qml-common/DCommon/Common/TabNavigation.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 484 | `dank-qml-common/DCommon/Common/Tonal.js` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 485 | `dank-qml-common/DCommon/Common/WheelInput.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 486 | `dank-qml-common/DCommon/Common/fzf.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 487 | `dank-qml-common/DCommon/Common/settings/SharedSessionSpec.js` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 488 | `dank-qml-common/DCommon/Common/settings/SharedSettingsSpec.js` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 489 | `dank-qml-common/DCommon/Common/settings/SpecUtil.js` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 490 | `dank-qml-common/DCommon/FileBrowser/DirectoryModel.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 491 | `dank-qml-common/DCommon/FileBrowser/FileBrowserMetrics.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 492 | `dank-qml-common/DCommon/FileBrowser/FileBrowserModal.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 493 | `dank-qml-common/DCommon/FileBrowser/FileBrowserSettings.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 494 | `dank-qml-common/DCommon/FileBrowser/FileBrowserSidebar.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 495 | `dank-qml-common/DCommon/FileBrowser/FileBrowserView.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 496 | `dank-qml-common/DCommon/FileBrowser/FileColumnHeader.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 497 | `dank-qml-common/DCommon/FileBrowser/FileColumns.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 498 | `dank-qml-common/DCommon/FileBrowser/FileColumnsView.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 499 | `dank-qml-common/DCommon/FileBrowser/FileFormat.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 500 | `dank-qml-common/DCommon/FileBrowser/FileGridView.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 501 | `dank-qml-common/DCommon/FileBrowser/FileIcon.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 502 | `dank-qml-common/DCommon/FileBrowser/FileItemSurface.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 503 | `dank-qml-common/DCommon/FileBrowser/FileItemVisual.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 504 | `dank-qml-common/DCommon/FileBrowser/FileListView.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 505 | `dank-qml-common/DCommon/FileBrowser/FileMenu.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 506 | `dank-qml-common/DCommon/FileBrowser/FileMenuItem.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 507 | `dank-qml-common/DCommon/FileBrowser/FilePaths.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 508 | `dank-qml-common/DCommon/FileBrowser/FilePicker.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 509 | `dank-qml-common/DCommon/FileBrowser/FilePlaceRow.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 510 | `dank-qml-common/DCommon/FileBrowser/FilePlaceSection.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 511 | `dank-qml-common/DCommon/FileBrowser/FilePreviewPane.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 512 | `dank-qml-common/DCommon/FileBrowser/FileRow.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 513 | `dank-qml-common/DCommon/FileBrowser/FileSortButton.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 514 | `dank-qml-common/DCommon/FileBrowser/FileTile.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 515 | `dank-qml-common/DCommon/FileBrowser/FileViewBackground.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 516 | `dank-qml-common/DCommon/FileBrowser/FileViewBody.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 517 | `dank-qml-common/DCommon/FileBrowser/InlineRename.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 518 | `dank-qml-common/DCommon/FileBrowser/LoadingSkeleton.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 519 | `dank-qml-common/DCommon/FileBrowser/NavButtonPair.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 520 | `dank-qml-common/DCommon/FileBrowser/NavigationHistory.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 521 | `dank-qml-common/DCommon/FileBrowser/PathBar.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 522 | `dank-qml-common/DCommon/FileBrowser/PathPill.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 523 | `dank-qml-common/DCommon/FileBrowser/PathSuggestions.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 524 | `dank-qml-common/DCommon/FileBrowser/RubberBand.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 525 | `dank-qml-common/DCommon/FileBrowser/SearchModel.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 526 | `dank-qml-common/DCommon/FileBrowser/SelectionFooter.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 527 | `dank-qml-common/DCommon/FileBrowser/SelectionModel.qml` | [`08-file-browser-trash.md`](08-file-browser-trash.md) | **Step 1** | Embedded file browser & trash modal |
| 528 | `dank-qml-common/DCommon/Session/CustomButtonKeyboard.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 529 | `dank-qml-common/DCommon/Session/ExpressiveKeyboardKey.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 530 | `dank-qml-common/DCommon/Session/Keyboard.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 531 | `dank-qml-common/DCommon/Session/KeyboardController.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 532 | `dank-qml-common/DCommon/Session/LockActionButton.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 533 | `dank-qml-common/DCommon/Session/LockMetrics.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 534 | `dank-qml-common/DCommon/Session/LockNotificationCard.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 535 | `dank-qml-common/DCommon/Session/LockPowerMenu.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 536 | `dank-qml-common/DCommon/Session/PowerMenuView.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 537 | `dank-qml-common/DCommon/Widgets/AppIconRenderer.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 538 | `dank-qml-common/DCommon/Widgets/CachingImage.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 539 | `dank-qml-common/DCommon/Widgets/Carousel.js` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 540 | `dank-qml-common/DCommon/Widgets/DActionButton.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 541 | `dank-qml-common/DCommon/Widgets/DAnalogClock.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 542 | `dank-qml-common/DCommon/Widgets/DBadge.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 543 | `dank-qml-common/DCommon/Widgets/DBlink.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 544 | `dank-qml-common/DCommon/Widgets/DBottomSheet.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 545 | `dank-qml-common/DCommon/Widgets/DButton.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 546 | `dank-qml-common/DCommon/Widgets/DButtonGroup.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 547 | `dank-qml-common/DCommon/Widgets/DCard.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 548 | `dank-qml-common/DCommon/Widgets/DCarousel.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 549 | `dank-qml-common/DCommon/Widgets/DCarouselItem.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 550 | `dank-qml-common/DCommon/Widgets/DCircularImage.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 551 | `dank-qml-common/DCommon/Widgets/DClockFace.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 552 | `dank-qml-common/DCommon/Widgets/DClockWidget.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 553 | `dank-qml-common/DCommon/Widgets/DCollapsibleSection.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 554 | `dank-qml-common/DCommon/Widgets/DColorAnimation.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 555 | `dank-qml-common/DCommon/Widgets/DColorButton.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 556 | `dank-qml-common/DCommon/Widgets/DColorSwatch.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 557 | `dank-qml-common/DCommon/Widgets/DConfirmDialogContent.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 558 | `dank-qml-common/DCommon/Widgets/DDetailChip.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 559 | `dank-qml-common/DCommon/Widgets/DDialog.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 560 | `dank-qml-common/DCommon/Widgets/DDragHandle.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 561 | `dank-qml-common/DCommon/Widgets/DDropdown.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 562 | `dank-qml-common/DCommon/Widgets/DEdgeFade.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 563 | `dank-qml-common/DCommon/Widgets/DFab.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 564 | `dank-qml-common/DCommon/Widgets/DFilterChips.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 565 | `dank-qml-common/DCommon/Widgets/DFlickable.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 566 | `dank-qml-common/DCommon/Widgets/DGridView.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 567 | `dank-qml-common/DCommon/Widgets/DHeroCard.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 568 | `dank-qml-common/DCommon/Widgets/DIcon.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 569 | `dank-qml-common/DCommon/Widgets/DIconButton.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 570 | `dank-qml-common/DCommon/Widgets/DIconPicker.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 571 | `dank-qml-common/DCommon/Widgets/DKeycap.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 572 | `dank-qml-common/DCommon/Widgets/DLayer.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 573 | `dank-qml-common/DCommon/Widgets/DListHighlight.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 574 | `dank-qml-common/DCommon/Widgets/DListItem.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 575 | `dank-qml-common/DCommon/Widgets/DListRow.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 576 | `dank-qml-common/DCommon/Widgets/DListView.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 577 | `dank-qml-common/DCommon/Widgets/DLoadingIndicator.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 578 | `dank-qml-common/DCommon/Widgets/DLocationSearch.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 579 | `dank-qml-common/DCommon/Widgets/DLogoShape.js` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 580 | `dank-qml-common/DCommon/Widgets/DMaterialShape.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 581 | `dank-qml-common/DCommon/Widgets/DMaterialWallpaper.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 582 | `dank-qml-common/DCommon/Widgets/DMonthGrid.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 583 | `dank-qml-common/DCommon/Widgets/DNFIcon.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 584 | `dank-qml-common/DCommon/Widgets/DNavigationBar.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 585 | `dank-qml-common/DCommon/Widgets/DNumberStepper.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 586 | `dank-qml-common/DCommon/Widgets/DOrganicBlob.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 587 | `dank-qml-common/DCommon/Widgets/DOverlapClockFace.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 588 | `dank-qml-common/DCommon/Widgets/DPaletteSwatch.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 589 | `dank-qml-common/DCommon/Widgets/DRefreshButton.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 590 | `dank-qml-common/DCommon/Widgets/DReorderGroup.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 591 | `dank-qml-common/DCommon/Widgets/DReorderList.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 592 | `dank-qml-common/DCommon/Widgets/DRingGauge.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 593 | `dank-qml-common/DCommon/Widgets/DRipple.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 594 | `dank-qml-common/DCommon/Widgets/DSVGIcon.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 595 | `dank-qml-common/DCommon/Widgets/DSaturationValuePicker.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 596 | `dank-qml-common/DCommon/Widgets/DScrollbar.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 597 | `dank-qml-common/DCommon/Widgets/DSearchField.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 598 | `dank-qml-common/DCommon/Widgets/DSlider.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 599 | `dank-qml-common/DCommon/Widgets/DSparkline.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 600 | `dank-qml-common/DCommon/Widgets/DSpinner.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 601 | `dank-qml-common/DCommon/Widgets/DSplitButton.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 602 | `dank-qml-common/DCommon/Widgets/DTabBar.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 603 | `dank-qml-common/DCommon/Widgets/DTextCursor.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 604 | `dank-qml-common/DCommon/Widgets/DTextEdit.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 605 | `dank-qml-common/DCommon/Widgets/DTextField.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 606 | `dank-qml-common/DCommon/Widgets/DTimePicker.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 607 | `dank-qml-common/DCommon/Widgets/DToggle.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 608 | `dank-qml-common/DCommon/Widgets/DTone.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 609 | `dank-qml-common/DCommon/Widgets/DTooltipHost.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 610 | `dank-qml-common/DCommon/Widgets/DTooltipV2.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 611 | `dank-qml-common/DCommon/Widgets/DWindowHeader.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 612 | `dank-qml-common/DCommon/Widgets/FloatingWindowControls.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 613 | `dank-qml-common/DCommon/Widgets/FocusRing.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 614 | `dank-qml-common/DCommon/Widgets/M3WaveProgress.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 615 | `dank-qml-common/DCommon/Widgets/MaterialShapeData.js` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 616 | `dank-qml-common/DCommon/Widgets/MaterialShapes.js` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 617 | `dank-qml-common/DCommon/Widgets/NumericText.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 618 | `dank-qml-common/DCommon/Widgets/Reveal.js` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 619 | `dank-qml-common/DCommon/Widgets/ScrollConstants.js` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 620 | `dank-qml-common/DCommon/Widgets/StateLayer.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 621 | `dank-qml-common/DCommon/Widgets/StyledButton.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 622 | `dank-qml-common/DCommon/Widgets/StyledRect.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 623 | `dank-qml-common/DCommon/Widgets/StyledText.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 624 | `dank-qml-common/DCommon/Widgets/StyledTextMetrics.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 625 | `dank-qml-common/DCommon/Widgets/SystemLogo.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 626 | `dank-qml-common/DCommon/Widgets/WindowBlur.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 627 | `dank-qml-common/DCommon/Widgets/WindowCaptureGuard.qml` | [`07-widget-library.md`](07-widget-library.md) | **Step 1** | Material 3 widget primitives |
| 628 | `dank-qml-common/Services/FilesBackend.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 629 | `dank-qml-common/Services/Log.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 630 | `dank-qml-common/Services/SessionService.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 631 | `dank-qml-common/WidgetGallery.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 632 | `dank-qml-common/shell.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 633 | `quickshell/Common/AnimVariants.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 634 | `quickshell/Common/Anims.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 635 | `quickshell/Common/AppUsageHistoryData.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 636 | `quickshell/Common/Appearance.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 637 | `quickshell/Common/AqueousIpc.js` | [`05-shell-root-ipc.md`](05-shell-root-ipc.md) | **Step 1** | Shell root and IPC router |
| 638 | `quickshell/Common/BarWidgetCatalog.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 639 | `quickshell/Common/BlurStrength.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 640 | `quickshell/Common/CacheData.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 641 | `quickshell/Common/ConfigIncludeResolve.js` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 642 | `quickshell/Common/ConnectedModalChrome.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 643 | `quickshell/Common/ConnectedModeState.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 644 | `quickshell/Common/ConnectedSurfaceDescriptor.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 645 | `quickshell/Common/ConnectedSurfaceGeometry.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 646 | `quickshell/Common/ConnectedSurfaceLease.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 647 | `quickshell/Common/ConnectorGeometry.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 648 | `quickshell/Common/DankAnim.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 649 | `quickshell/Common/DankColorAnim.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 650 | `quickshell/Common/DankSocket.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 651 | `quickshell/Common/DateOnly.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 652 | `quickshell/Common/DeferredAction.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 653 | `quickshell/Common/Deprecation.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 654 | `quickshell/Common/ElevationShadow.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 655 | `quickshell/Common/FluidGeometry.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 656 | `quickshell/Common/Format.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 657 | `quickshell/Common/FrameTransitionState.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 658 | `quickshell/Common/GSettings.js` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 659 | `quickshell/Common/GridLayout.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 660 | `quickshell/Common/I18n.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 661 | `quickshell/Common/InstanceRegistry.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 662 | `quickshell/Common/KeyUtils.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 663 | `quickshell/Common/KeybindActions.js` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 664 | `quickshell/Common/KeyboardFocus.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 665 | `quickshell/Common/LayerShell.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 666 | `quickshell/Common/LayoutResolver.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 667 | `quickshell/Common/MediaOptions.qml` | [`10-media.md`](10-media.md) | **Step 2** | Now playing & synchronized lyrics |
| 668 | `quickshell/Common/ModalManager.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 669 | `quickshell/Common/MuxBackends.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 670 | `quickshell/Common/NotificationRuleExpiry.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 671 | `quickshell/Common/OSDManager.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 672 | `quickshell/Common/OutputModel.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 673 | `quickshell/Common/PamStack.js` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 674 | `quickshell/Common/Paths.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 675 | `quickshell/Common/PluginRanking.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 676 | `quickshell/Common/PopoutManager.qml` | [`06-surfaces-popouts.md`](06-surfaces-popouts.md) | **Step 1** | Connected popout surfaces |
| 677 | `quickshell/Common/PopoutMetrics.qml` | [`06-surfaces-popouts.md`](06-surfaces-popouts.md) | **Step 1** | Connected popout surfaces |
| 678 | `quickshell/Common/Proc.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 679 | `quickshell/Common/QmlUtils.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 680 | `quickshell/Common/RectSpringMotion.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 681 | `quickshell/Common/Ref.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 682 | `quickshell/Common/SessionData.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 683 | `quickshell/Common/SettingsData.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 684 | `quickshell/Common/SettingsTabs.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 685 | `quickshell/Common/SettingsUiState.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 686 | `quickshell/Common/ShellLayout.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 687 | `quickshell/Common/Site.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 688 | `quickshell/Common/SleepLock.js` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 689 | `quickshell/Common/SpringMotion.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 690 | `quickshell/Common/StockThemes.js` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 691 | `quickshell/Common/SurfaceRecovery.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 692 | `quickshell/Common/Theme.qml` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 693 | `quickshell/Common/ThemePalette.js` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 694 | `quickshell/Common/TrayMenuManager.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 695 | `quickshell/Common/UpgradeLog.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 696 | `quickshell/Common/WidgetPlacement.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 697 | `quickshell/Common/WindowModel.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 698 | `quickshell/Common/WindowRuleMerge.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 699 | `quickshell/Common/WindowRuleSize.js` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 700 | `quickshell/Common/WorkspaceModel.js` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 701 | `quickshell/Common/htmlElide.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 702 | `quickshell/Common/markdown2html.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 703 | `quickshell/Common/settings/BarWidgetDefaults.js` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 704 | `quickshell/Common/settings/DockConfig.js` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 705 | `quickshell/Common/settings/Lists.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 706 | `quickshell/Common/settings/Processes.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 707 | `quickshell/Common/settings/SessionSpec.js` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 708 | `quickshell/Common/settings/SessionStore.js` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 709 | `quickshell/Common/settings/SettingsSpec.js` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 710 | `quickshell/Common/settings/SettingsStore.js` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 711 | `quickshell/Common/suncalc.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 712 | `quickshell/DMSGreeter.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 713 | `quickshell/DMSShell.qml` | [`05-shell-root-ipc.md`](05-shell-root-ipc.md) | **Step 1** | Shell root and IPC router |
| 714 | `quickshell/DMSShellIPC.qml` | [`05-shell-root-ipc.md`](05-shell-root-ipc.md) | **Step 1** | Shell root and IPC router |
| 715 | `quickshell/Modals/AppPickerModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 716 | `quickshell/Modals/BluetoothPairingModal.qml` | [`11-connectivity-qml.md`](11-connectivity-qml.md) | **Step 1** | Connectivity layer |
| 717 | `quickshell/Modals/BrowserPickerModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 718 | `quickshell/Modals/Changelog/ChangelogContent.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 719 | `quickshell/Modals/Changelog/ChangelogFeatureCard.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 720 | `quickshell/Modals/Changelog/ChangelogModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 721 | `quickshell/Modals/Changelog/ChangelogUpgradeNote.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 722 | `quickshell/Modals/Clipboard/ClipboardActions.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 723 | `quickshell/Modals/Clipboard/ClipboardConstants.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 724 | `quickshell/Modals/Clipboard/ClipboardContent.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 725 | `quickshell/Modals/Clipboard/ClipboardContextMenu.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 726 | `quickshell/Modals/Clipboard/ClipboardEditor.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 727 | `quickshell/Modals/Clipboard/ClipboardEntry.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 728 | `quickshell/Modals/Clipboard/ClipboardHeader.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 729 | `quickshell/Modals/Clipboard/ClipboardHistoryContent.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 730 | `quickshell/Modals/Clipboard/ClipboardHistoryModal.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 731 | `quickshell/Modals/Clipboard/ClipboardHistoryPopout.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 732 | `quickshell/Modals/Clipboard/ClipboardImagePreview.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 733 | `quickshell/Modals/Clipboard/ClipboardKeyboardController.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 734 | `quickshell/Modals/Clipboard/ClipboardKeyboardHints.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 735 | `quickshell/Modals/Clipboard/ClipboardThumbnail.qml` | [`26-clipboard.md`](26-clipboard.md) | **Step 2** | Clipboard manager with in-situ editor |
| 736 | `quickshell/Modals/ColorPickerModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 737 | `quickshell/Modals/Common/ConfirmDialogContent.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 738 | `quickshell/Modals/Common/ConfirmDialogOverlay.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 739 | `quickshell/Modals/Common/ConfirmModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 740 | `quickshell/Modals/Common/DModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 741 | `quickshell/Modals/Common/DModalHost.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 742 | `quickshell/Modals/Common/DankModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 743 | `quickshell/Modals/Common/InputModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 744 | `quickshell/Modals/DLauncherV2/ActionPanel.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 745 | `quickshell/Modals/DLauncherV2/AppEditView.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 746 | `quickshell/Modals/DLauncherV2/ClipboardLauncherPreview.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 747 | `quickshell/Modals/DLauncherV2/Components/LauncherHighlight.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 748 | `quickshell/Modals/DLauncherV2/Components/LauncherMetrics.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 749 | `quickshell/Modals/DLauncherV2/Components/LauncherRow.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 750 | `quickshell/Modals/DLauncherV2/Components/LauncherSearchField.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 751 | `quickshell/Modals/DLauncherV2/Components/LauncherTile.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 752 | `quickshell/Modals/DLauncherV2/Controller.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 753 | `quickshell/Modals/DLauncherV2/ControllerUtils.js` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 754 | `quickshell/Modals/DLauncherV2/DLauncherV2Modal.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 755 | `quickshell/Modals/DLauncherV2/DLauncherV2ModalHost.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 756 | `quickshell/Modals/DLauncherV2/DLauncherV2ModalIsland.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 757 | `quickshell/Modals/DLauncherV2/ItemTransformers.js` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 758 | `quickshell/Modals/DLauncherV2/LauncherContent.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 759 | `quickshell/Modals/DLauncherV2/LauncherContextMenu.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 760 | `quickshell/Modals/DLauncherV2/NavigationHelpers.js` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 761 | `quickshell/Modals/DLauncherV2/ResultsList.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 762 | `quickshell/Modals/DLauncherV2/Scorer.js` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 763 | `quickshell/Modals/DLauncherV2/Section.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 764 | `quickshell/Modals/DLauncherV2/SectionHeader.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 765 | `quickshell/Modals/DLauncherV2/SourceBadge.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 766 | `quickshell/Modals/DLauncherV2/SpotlightLauncherContent.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 767 | `quickshell/Modals/DLauncherV2/TileItem.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 768 | `quickshell/Modals/DisplayConfirmationModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 769 | `quickshell/Modals/FileBrowser/FileBrowserModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 770 | `quickshell/Modals/FileBrowser/FileBrowserSurfaceModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 771 | `quickshell/Modals/Greeter/GreeterCompletePage.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 772 | `quickshell/Modals/Greeter/GreeterDoctorPage.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 773 | `quickshell/Modals/Greeter/GreeterDoctorResultItem.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 774 | `quickshell/Modals/Greeter/GreeterFeatureCard.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 775 | `quickshell/Modals/Greeter/GreeterModal.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 776 | `quickshell/Modals/Greeter/GreeterPluginsPage.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 777 | `quickshell/Modals/Greeter/GreeterQuickLink.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 778 | `quickshell/Modals/Greeter/GreeterSettingsCard.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 779 | `quickshell/Modals/Greeter/GreeterStatusCard.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 780 | `quickshell/Modals/Greeter/GreeterWelcomePage.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 781 | `quickshell/Modals/KeybindsContent.qml` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 782 | `quickshell/Modals/KeybindsModal.qml` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 783 | `quickshell/Modals/KeybindsModalOverlay.qml` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 784 | `quickshell/Modals/KeybindsModalWindow.qml` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 785 | `quickshell/Modals/MuxModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 786 | `quickshell/Modals/NetworkInfoModal.qml` | [`11-connectivity-qml.md`](11-connectivity-qml.md) | **Step 1** | Connectivity layer |
| 787 | `quickshell/Modals/NotificationModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 788 | `quickshell/Modals/PolkitAuthContent.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 789 | `quickshell/Modals/PolkitAuthModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 790 | `quickshell/Modals/PolkitAuthSurfaceModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 791 | `quickshell/Modals/PowerMenuModal.qml` | [`13-power-display.md`](13-power-display.md) | **Step 1** | Power and display management |
| 792 | `quickshell/Modals/PowerProfileModal.qml` | [`13-power-display.md`](13-power-display.md) | **Step 1** | Power and display management |
| 793 | `quickshell/Modals/ProcessListModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 794 | `quickshell/Modals/QRGeneratorModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 795 | `quickshell/Modals/Settings/SettingsContent.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 796 | `quickshell/Modals/Settings/SettingsModal.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 797 | `quickshell/Modals/Settings/SettingsPaneNavigation.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 798 | `quickshell/Modals/Settings/SettingsSidebar.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 799 | `quickshell/Modals/SwitchUserModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 800 | `quickshell/Modals/SystemUpdateModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 801 | `quickshell/Modals/WifiPasswordModal.qml` | [`11-connectivity-qml.md`](11-connectivity-qml.md) | **Step 1** | Connectivity layer |
| 802 | `quickshell/Modals/WifiQRCodeModal.qml` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 803 | `quickshell/Modals/WindowRuleModal.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 804 | `quickshell/Modals/WorkspaceRenameModal.qml` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 805 | `quickshell/Modules/AppDrawer/AppDrawerPopout.qml` | [`06-surfaces-popouts.md`](06-surfaces-popouts.md) | **Step 1** | Connected popout surfaces |
| 806 | `quickshell/Modules/BlurredWallpaperBackground.qml` | [`02-wallpaper.md`](02-wallpaper.md) | **Step 1** | Wallpaper engine and transition shaders |
| 807 | `quickshell/Modules/BlurredWallpaperLive.qml` | [`02-wallpaper.md`](02-wallpaper.md) | **Step 1** | Wallpaper engine and transition shaders |
| 808 | `quickshell/Modules/BuiltinDesktopPlugins/DesktopClockWidget.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 809 | `quickshell/Modules/BuiltinDesktopPlugins/SystemMonitorWidget.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 810 | `quickshell/Modules/ColorPicker/ColorPickerContent.qml` | [`29-colorpicker-screenshot-qr.md`](29-colorpicker-screenshot-qr.md) | **Step 2** | Color picker loupe, stitched screenshot HUD |
| 811 | `quickshell/Modules/ControlCenter/BuiltinPlugins/CupsWidget.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 812 | `quickshell/Modules/ControlCenter/BuiltinPlugins/DisplayProfilesWidget.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 813 | `quickshell/Modules/ControlCenter/BuiltinPlugins/TailscaleWidget.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 814 | `quickshell/Modules/ControlCenter/BuiltinPlugins/VpnWidget.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 815 | `quickshell/Modules/ControlCenter/CcMetrics.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 816 | `quickshell/Modules/ControlCenter/Components/CcDetailPage.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 817 | `quickshell/Modules/ControlCenter/Components/CcEditActions.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 818 | `quickshell/Modules/ControlCenter/Components/CcEditChrome.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 819 | `quickshell/Modules/ControlCenter/Components/CcTileGrid.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 820 | `quickshell/Modules/ControlCenter/Components/CcTileLoader.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 821 | `quickshell/Modules/ControlCenter/Components/CcTileSlot.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 822 | `quickshell/Modules/ControlCenter/Components/CcWidgetSheet.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 823 | `quickshell/Modules/ControlCenter/Components/PluginDetailShell.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 824 | `quickshell/Modules/ControlCenter/Components/QuickTilesGroup.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 825 | `quickshell/Modules/ControlCenter/Components/WidgetConfigOverlay.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 826 | `quickshell/Modules/ControlCenter/ControlCenterContent.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 827 | `quickshell/Modules/ControlCenter/ControlCenterPopout.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 828 | `quickshell/Modules/ControlCenter/Details/AudioInputDetail.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 829 | `quickshell/Modules/ControlCenter/Details/AudioOutputDetail.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 830 | `quickshell/Modules/ControlCenter/Details/AudioPortSelector.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 831 | `quickshell/Modules/ControlCenter/Details/BatteryDetail.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 832 | `quickshell/Modules/ControlCenter/Details/BluetoothCodecSelector.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 833 | `quickshell/Modules/ControlCenter/Details/BluetoothDetail.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 834 | `quickshell/Modules/ControlCenter/Details/BrightnessDetail.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 835 | `quickshell/Modules/ControlCenter/Details/DiskUsageDetail.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 836 | `quickshell/Modules/ControlCenter/Details/DoNotDisturbDetail.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 837 | `quickshell/Modules/ControlCenter/Details/IdleInhibitorDetail.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 838 | `quickshell/Modules/ControlCenter/Details/NetworkDetail.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 839 | `quickshell/Modules/ControlCenter/Details/RunningAppsDetail.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 840 | `quickshell/Modules/ControlCenter/Details/VpnDetailContent.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 841 | `quickshell/Modules/ControlCenter/Details/VpnProfileDelegate.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 842 | `quickshell/Modules/ControlCenter/Models/WidgetModel.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 843 | `quickshell/Modules/ControlCenter/Widgets/ActionTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 844 | `quickshell/Modules/ControlCenter/Widgets/AudioDeviceTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 845 | `quickshell/Modules/ControlCenter/Widgets/AudioSliderRow.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 846 | `quickshell/Modules/ControlCenter/Widgets/BatteryTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 847 | `quickshell/Modules/ControlCenter/Widgets/BluetoothTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 848 | `quickshell/Modules/ControlCenter/Widgets/BrightnessSliderRow.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 849 | `quickshell/Modules/ControlCenter/Widgets/CcAppIcon.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 850 | `quickshell/Modules/ControlCenter/Widgets/CcAudioDevices.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 851 | `quickshell/Modules/ControlCenter/Widgets/CcDurationActions.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 852 | `quickshell/Modules/ControlCenter/Widgets/CcEmptyState.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 853 | `quickshell/Modules/ControlCenter/Widgets/CcGroup.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 854 | `quickshell/Modules/ControlCenter/Widgets/CcListRow.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 855 | `quickshell/Modules/ControlCenter/Widgets/CcMenu.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 856 | `quickshell/Modules/ControlCenter/Widgets/CcPinChip.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 857 | `quickshell/Modules/ControlCenter/Widgets/CcSectionLabel.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 858 | `quickshell/Modules/ControlCenter/Widgets/CcSettingsButton.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 859 | `quickshell/Modules/ControlCenter/Widgets/CcSheetDialog.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 860 | `quickshell/Modules/ControlCenter/Widgets/CcSliderRow.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 861 | `quickshell/Modules/ControlCenter/Widgets/CcStatusDot.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 862 | `quickshell/Modules/ControlCenter/Widgets/CcTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 863 | `quickshell/Modules/ControlCenter/Widgets/CcTileActions.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 864 | `quickshell/Modules/ControlCenter/Widgets/CcTileContent.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 865 | `quickshell/Modules/ControlCenter/Widgets/CcToggleRow.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 866 | `quickshell/Modules/ControlCenter/Widgets/CcWidgetLibrary.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 867 | `quickshell/Modules/ControlCenter/Widgets/ColorPickerTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 868 | `quickshell/Modules/ControlCenter/Widgets/DarkModeTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 869 | `quickshell/Modules/ControlCenter/Widgets/DiskUsageTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 870 | `quickshell/Modules/ControlCenter/Widgets/DndTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 871 | `quickshell/Modules/ControlCenter/Widgets/IdleInhibitTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 872 | `quickshell/Modules/ControlCenter/Widgets/NetworkTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 873 | `quickshell/Modules/ControlCenter/Widgets/NightModeTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 874 | `quickshell/Modules/ControlCenter/Widgets/PluginInstanceHost.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 875 | `quickshell/Modules/ControlCenter/Widgets/PluginTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 876 | `quickshell/Modules/ControlCenter/Widgets/RunningAppsTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 877 | `quickshell/Modules/ControlCenter/Widgets/UserTile.qml` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 878 | `quickshell/Modules/ControlCenter/utils/sections.js` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 879 | `quickshell/Modules/ControlCenter/utils/widgets.js` | [`22-control-center.md`](22-control-center.md) | **Step 1** | Control Center grid and detail subpages |
| 880 | `quickshell/Modules/DBar/AxisContext.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 881 | `quickshell/Modules/DBar/BarMetrics.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 882 | `quickshell/Modules/DBar/BarOutline.js` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 883 | `quickshell/Modules/DBar/BarPillSurface.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 884 | `quickshell/Modules/DBar/BarScrollArea.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 885 | `quickshell/Modules/DBar/BarSection.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 886 | `quickshell/Modules/DBar/BarSegment.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 887 | `quickshell/Modules/DBar/BarSurface.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 888 | `quickshell/Modules/DBar/CenterLayout.js` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 889 | `quickshell/Modules/DBar/CenterSection.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 890 | `quickshell/Modules/DBar/DBar.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 891 | `quickshell/Modules/DBar/DBarBody.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 892 | `quickshell/Modules/DBar/DBarContent.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 893 | `quickshell/Modules/DBar/DBarHoverController.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 894 | `quickshell/Modules/DBar/DBarWindow.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 895 | `quickshell/Modules/DBar/LeftSection.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 896 | `quickshell/Modules/DBar/OverflowLayout.js` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 897 | `quickshell/Modules/DBar/Popouts/BatteryHistory.js` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 898 | `quickshell/Modules/DBar/Popouts/BatteryHistory.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 899 | `quickshell/Modules/DBar/Popouts/BatteryHistoryChart.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 900 | `quickshell/Modules/DBar/Popouts/BatteryPopout.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 901 | `quickshell/Modules/DBar/Popouts/BatteryPopoutContent.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 902 | `quickshell/Modules/DBar/Popouts/ColorPickerPopout.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 903 | `quickshell/Modules/DBar/Popouts/DWLLayoutPopout.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 904 | `quickshell/Modules/DBar/Popouts/DurationPopout.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 905 | `quickshell/Modules/DBar/Popouts/PowerMenuPopout.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 906 | `quickshell/Modules/DBar/Popouts/SystemUpdatePopout.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 907 | `quickshell/Modules/DBar/Popouts/VpnPopout.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 908 | `quickshell/Modules/DBar/RightSection.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 909 | `quickshell/Modules/DBar/SectionEntry.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 910 | `quickshell/Modules/DBar/SectionOverflow.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 911 | `quickshell/Modules/DBar/SectionSurface.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 912 | `quickshell/Modules/DBar/SectionWidget.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 913 | `quickshell/Modules/DBar/SegmentRoles.js` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 914 | `quickshell/Modules/DBar/SideSection.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 915 | `quickshell/Modules/DBar/WidgetModel.js` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 916 | `quickshell/Modules/DBar/Widgets/AppsDock.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 917 | `quickshell/Modules/DBar/Widgets/AudioVisualization.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 918 | `quickshell/Modules/DBar/Widgets/Battery.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 919 | `quickshell/Modules/DBar/Widgets/CapsLockIndicator.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 920 | `quickshell/Modules/DBar/Widgets/ClipboardButton.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 921 | `quickshell/Modules/DBar/Widgets/Clock.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 922 | `quickshell/Modules/DBar/Widgets/ColorPicker.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 923 | `quickshell/Modules/DBar/Widgets/ControlCenterButton.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 924 | `quickshell/Modules/DBar/Widgets/CpuMonitor.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 925 | `quickshell/Modules/DBar/Widgets/CpuTemperature.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 926 | `quickshell/Modules/DBar/Widgets/DWLLayout.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 927 | `quickshell/Modules/DBar/Widgets/DiskUsage.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 928 | `quickshell/Modules/DBar/Widgets/FocusedApp.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 929 | `quickshell/Modules/DBar/Widgets/FocusedWindowContextMenu.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 930 | `quickshell/Modules/DBar/Widgets/GpuTemperature.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 931 | `quickshell/Modules/DBar/Widgets/IdleInhibitPresets.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 932 | `quickshell/Modules/DBar/Widgets/IdleInhibitor.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 933 | `quickshell/Modules/DBar/Widgets/KeyboardLayoutLabels.js` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 934 | `quickshell/Modules/DBar/Widgets/KeyboardLayoutName.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 935 | `quickshell/Modules/DBar/Widgets/LauncherButton.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 936 | `quickshell/Modules/DBar/Widgets/Media.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 937 | `quickshell/Modules/DBar/Widgets/MediaLyricLine.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 938 | `quickshell/Modules/DBar/Widgets/MonitorPill.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 939 | `quickshell/Modules/DBar/Widgets/NetworkMonitor.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 940 | `quickshell/Modules/DBar/Widgets/NotepadButton.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 941 | `quickshell/Modules/DBar/Widgets/NotificationCenterButton.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 942 | `quickshell/Modules/DBar/Widgets/PowerMenuButton.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 943 | `quickshell/Modules/DBar/Widgets/PrivacyIndicator.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 944 | `quickshell/Modules/DBar/Widgets/RamMonitor.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 945 | `quickshell/Modules/DBar/Widgets/RunningApps.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 946 | `quickshell/Modules/DBar/Widgets/SystemTrayBar.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 947 | `quickshell/Modules/DBar/Widgets/SystemUpdate.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 948 | `quickshell/Modules/DBar/Widgets/TrayItemIcon.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 949 | `quickshell/Modules/DBar/Widgets/Vpn.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 950 | `quickshell/Modules/DBar/Widgets/Weather.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 951 | `quickshell/Modules/DBar/Widgets/WorkspaceSwitcher.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 952 | `quickshell/Modules/DDash/DDashPopout.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 953 | `quickshell/Modules/DDash/DashMetrics.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 954 | `quickshell/Modules/DDash/DashPageActions.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 955 | `quickshell/Modules/DDash/DashPageTitle.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 956 | `quickshell/Modules/DDash/DashRegistry.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 957 | `quickshell/Modules/DDash/DashSheetHandle.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 958 | `quickshell/Modules/DDash/DashTabHost.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 959 | `quickshell/Modules/DDash/DashWidgetGrid.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 960 | `quickshell/Modules/DDash/Media/BentoChrome.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 961 | `quickshell/Modules/DDash/Media/LyricsOverlay.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 962 | `quickshell/Modules/DDash/Media/LyricsVocal.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 963 | `quickshell/Modules/DDash/Media/MaterialChrome.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 964 | `quickshell/Modules/DDash/Media/MaterialSourceGroup.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 965 | `quickshell/Modules/DDash/Media/MaterialTransport.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 966 | `quickshell/Modules/DDash/Media/MediaArtSurface.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 967 | `quickshell/Modules/DDash/Media/MediaArtView.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 968 | `quickshell/Modules/DDash/Media/MediaChromeBase.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 969 | `quickshell/Modules/DDash/Media/MediaDeviceRow.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 970 | `quickshell/Modules/DDash/Media/MediaEmptyState.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 971 | `quickshell/Modules/DDash/Media/MediaPanel.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 972 | `quickshell/Modules/DDash/Media/MediaPanelRow.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 973 | `quickshell/Modules/DDash/Media/MediaPresentation.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 974 | `quickshell/Modules/DDash/Media/MediaSeekbar.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 975 | `quickshell/Modules/DDash/Media/MediaSinkWheel.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 976 | `quickshell/Modules/DDash/Media/MediaSourceGroup.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 977 | `quickshell/Modules/DDash/Media/MediaTransport.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 978 | `quickshell/Modules/DDash/Media/MediaTransportButton.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 979 | `quickshell/Modules/DDash/Media/MediaVolumeSlider.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 980 | `quickshell/Modules/DDash/Media/MediaVolumeWheel.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 981 | `quickshell/Modules/DDash/MediaPlayerTab.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 982 | `quickshell/Modules/DDash/NotificationsTab.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 983 | `quickshell/Modules/DDash/Overview/BatteryCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 984 | `quickshell/Modules/DDash/Overview/CalendarEventDetail.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 985 | `quickshell/Modules/DDash/Overview/CalendarEventEditor.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 986 | `quickshell/Modules/DDash/Overview/CalendarOverviewCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 987 | `quickshell/Modules/DDash/Overview/Card.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 988 | `quickshell/Modules/DDash/Overview/ClockCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 989 | `quickshell/Modules/DDash/Overview/CpuCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 990 | `quickshell/Modules/DDash/Overview/DashCardGrid.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 991 | `quickshell/Modules/DDash/Overview/DashCardSlot.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 992 | `quickshell/Modules/DDash/Overview/DashEditChrome.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 993 | `quickshell/Modules/DDash/Overview/DashEditControls.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 994 | `quickshell/Modules/DDash/Overview/DashOptionRow.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 995 | `quickshell/Modules/DDash/Overview/DashOptionsSheet.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 996 | `quickshell/Modules/DDash/Overview/DiskCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 997 | `quickshell/Modules/DDash/Overview/MediaOverviewCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 998 | `quickshell/Modules/DDash/Overview/MemoryCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 999 | `quickshell/Modules/DDash/Overview/MetricCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1000 | `quickshell/Modules/DDash/Overview/MetricGauge.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1001 | `quickshell/Modules/DDash/Overview/NetworkCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1002 | `quickshell/Modules/DDash/Overview/NotificationsOverviewCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1003 | `quickshell/Modules/DDash/Overview/SystemMonitorCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1004 | `quickshell/Modules/DDash/Overview/UserInfoCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1005 | `quickshell/Modules/DDash/Overview/WeatherOverviewCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1006 | `quickshell/Modules/DDash/Overview/WellbeingOverviewCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1007 | `quickshell/Modules/DDash/OverviewTab.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1008 | `quickshell/Modules/DDash/WallpaperCarousel.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1009 | `quickshell/Modules/DDash/WallpaperTab.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1010 | `quickshell/Modules/DDash/Weather/WeatherForecastCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1011 | `quickshell/Modules/DDash/Weather/WeatherForecastChart.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1012 | `quickshell/Modules/DDash/Weather/WeatherForecastWidget.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1013 | `quickshell/Modules/DDash/Weather/WeatherHero.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1014 | `quickshell/Modules/DDash/Weather/WeatherMetricCard.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1015 | `quickshell/Modules/DDash/Weather/WeatherSky.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1016 | `quickshell/Modules/DDash/Weather/WeatherVisuals.js` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1017 | `quickshell/Modules/DDash/WeatherTab.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1018 | `quickshell/Modules/DDash/Wellbeing/AppLimitSheet.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1019 | `quickshell/Modules/DDash/Wellbeing/AppUsageList.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1020 | `quickshell/Modules/DDash/Wellbeing/DurationSteppers.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1021 | `quickshell/Modules/DDash/Wellbeing/WeeklyChart.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1022 | `quickshell/Modules/DDash/Wellbeing/Wellbeing.js` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1023 | `quickshell/Modules/DDash/Wellbeing/WellbeingMetrics.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1024 | `quickshell/Modules/DDash/WellbeingTab.qml` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1025 | `quickshell/Modules/DDash/utils/cards.js` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1026 | `quickshell/Modules/DDash/utils/options.js` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1027 | `quickshell/Modules/DDash/utils/widgets.js` | [`23-dash-weather-calendar.md`](23-dash-weather-calendar.md) | **Step 2** | DDash multi-tab dashboard and weather sky |
| 1028 | `quickshell/Modules/DIsland/Activities/ClipboardExpanded.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1029 | `quickshell/Modules/DIsland/Activities/ControlCenterExpanded.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1030 | `quickshell/Modules/DIsland/Activities/DashTabFace.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1031 | `quickshell/Modules/DIsland/Activities/DestinationCompact.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1032 | `quickshell/Modules/DIsland/Activities/DotCompact.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1033 | `quickshell/Modules/DIsland/Activities/HomeCompact.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1034 | `quickshell/Modules/DIsland/Activities/HomeExpanded.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1035 | `quickshell/Modules/DIsland/Activities/IslandSlotHoverArea.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1036 | `quickshell/Modules/DIsland/Activities/LauncherExpanded.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1037 | `quickshell/Modules/DIsland/Activities/MediaCompact.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1038 | `quickshell/Modules/DIsland/Activities/MediaExpanded.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1039 | `quickshell/Modules/DIsland/Activities/NotificationCenterExpanded.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1040 | `quickshell/Modules/DIsland/Activities/NotificationCompact.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1041 | `quickshell/Modules/DIsland/Activities/NotificationExpanded.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1042 | `quickshell/Modules/DIsland/Activities/PowerMenuExpanded.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1043 | `quickshell/Modules/DIsland/Activities/SystemLevelCompact.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1044 | `quickshell/Modules/DIsland/Activities/SystemLevelExpanded.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1045 | `quickshell/Modules/DIsland/Activities/SystemStateCompact.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1046 | `quickshell/Modules/DIsland/Activities/WallpaperExpanded.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1047 | `quickshell/Modules/DIsland/Activities/WeatherExpanded.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1048 | `quickshell/Modules/DIsland/DIsland.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1049 | `quickshell/Modules/DIsland/DIslandHostWindow.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1050 | `quickshell/Modules/DIsland/DIslandSurface.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1051 | `quickshell/Modules/DIsland/IslandBarHost.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1052 | `quickshell/Modules/DIsland/IslandContentHost.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1053 | `quickshell/Modules/DIsland/IslandController.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1054 | `quickshell/Modules/DIsland/IslandFreeDragArea.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1055 | `quickshell/Modules/DIsland/IslandFreeHostWindow.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1056 | `quickshell/Modules/DIsland/IslandHostChrome.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1057 | `quickshell/Modules/DIsland/IslandHostRegistry.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1058 | `quickshell/Modules/DIsland/IslandMediaSource.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1059 | `quickshell/Modules/DIsland/IslandNotificationSource.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1060 | `quickshell/Modules/DIsland/IslandSystemSource.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1061 | `quickshell/Modules/DankBar/Widgets/AppsDock.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1062 | `quickshell/Modules/DankBar/Widgets/AudioVisualization.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1063 | `quickshell/Modules/DankBar/Widgets/Battery.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1064 | `quickshell/Modules/DankBar/Widgets/CapsLockIndicator.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1065 | `quickshell/Modules/DankBar/Widgets/ClipboardButton.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1066 | `quickshell/Modules/DankBar/Widgets/Clock.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1067 | `quickshell/Modules/DankBar/Widgets/ColorPicker.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1068 | `quickshell/Modules/DankBar/Widgets/ControlCenterButton.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1069 | `quickshell/Modules/DankBar/Widgets/CpuMonitor.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1070 | `quickshell/Modules/DankBar/Widgets/CpuTemperature.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1071 | `quickshell/Modules/DankBar/Widgets/DWLLayout.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1072 | `quickshell/Modules/DankBar/Widgets/DiskUsage.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1073 | `quickshell/Modules/DankBar/Widgets/FocusedApp.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1074 | `quickshell/Modules/DankBar/Widgets/FocusedWindowContextMenu.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1075 | `quickshell/Modules/DankBar/Widgets/GpuTemperature.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1076 | `quickshell/Modules/DankBar/Widgets/IdleInhibitor.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1077 | `quickshell/Modules/DankBar/Widgets/KeyboardLayoutName.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1078 | `quickshell/Modules/DankBar/Widgets/LauncherButton.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1079 | `quickshell/Modules/DankBar/Widgets/Media.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1080 | `quickshell/Modules/DankBar/Widgets/MediaLyricLine.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1081 | `quickshell/Modules/DankBar/Widgets/MonitorPill.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1082 | `quickshell/Modules/DankBar/Widgets/NetworkMonitor.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1083 | `quickshell/Modules/DankBar/Widgets/NotepadButton.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1084 | `quickshell/Modules/DankBar/Widgets/NotificationCenterButton.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1085 | `quickshell/Modules/DankBar/Widgets/PowerMenuButton.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1086 | `quickshell/Modules/DankBar/Widgets/PrivacyIndicator.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1087 | `quickshell/Modules/DankBar/Widgets/RamMonitor.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1088 | `quickshell/Modules/DankBar/Widgets/RunningApps.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1089 | `quickshell/Modules/DankBar/Widgets/SystemTrayBar.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1090 | `quickshell/Modules/DankBar/Widgets/SystemUpdate.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1091 | `quickshell/Modules/DankBar/Widgets/TrayItemIcon.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1092 | `quickshell/Modules/DankBar/Widgets/Vpn.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1093 | `quickshell/Modules/DankBar/Widgets/Weather.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1094 | `quickshell/Modules/DankBar/Widgets/WorkspaceSwitcher.qml` | [`20-bar-widgets.md`](20-bar-widgets.md) | **Step 1** | DankBar widget suite |
| 1095 | `quickshell/Modules/DankDash/DankDashPopout.qml` | [`06-surfaces-popouts.md`](06-surfaces-popouts.md) | **Step 1** | Connected popout surfaces |
| 1096 | `quickshell/Modules/DankDash/MediaPlayerTab.qml` | [`10-media.md`](10-media.md) | **Step 2** | Now playing & synchronized lyrics |
| 1097 | `quickshell/Modules/DankDash/Overview/CalendarEventDetail.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1098 | `quickshell/Modules/DankDash/Overview/CalendarEventEditor.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1099 | `quickshell/Modules/DankDash/Overview/CalendarOverviewCard.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1100 | `quickshell/Modules/DankDash/Overview/Card.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1101 | `quickshell/Modules/DankDash/Overview/ClockCard.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1102 | `quickshell/Modules/DankDash/Overview/MediaOverviewCard.qml` | [`10-media.md`](10-media.md) | **Step 2** | Now playing & synchronized lyrics |
| 1103 | `quickshell/Modules/DankDash/Overview/SystemMonitorCard.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1104 | `quickshell/Modules/DankDash/Overview/UserInfoCard.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1105 | `quickshell/Modules/DankDash/Overview/WeatherOverviewCard.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1106 | `quickshell/Modules/DankDash/OverviewTab.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1107 | `quickshell/Modules/DankDash/WallpaperTab.qml` | [`02-wallpaper.md`](02-wallpaper.md) | **Step 1** | Wallpaper engine and transition shaders |
| 1108 | `quickshell/Modules/DankDash/WeatherTab.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1109 | `quickshell/Modules/DesktopContextMenu.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1110 | `quickshell/Modules/DesktopWidgetEditor.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1111 | `quickshell/Modules/DesktopWidgetLayer.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1112 | `quickshell/Modules/Dock/Dock.qml` | [`21-dock.md`](21-dock.md) | **Step 1** | Desktop Dock surface and magnification |
| 1113 | `quickshell/Modules/Dock/DockAppButton.qml` | [`21-dock.md`](21-dock.md) | **Step 1** | Desktop Dock surface and magnification |
| 1114 | `quickshell/Modules/Dock/DockBody.qml` | [`21-dock.md`](21-dock.md) | **Step 1** | Desktop Dock surface and magnification |
| 1115 | `quickshell/Modules/Dock/DockContextMenu.qml` | [`21-dock.md`](21-dock.md) | **Step 1** | Desktop Dock surface and magnification |
| 1116 | `quickshell/Modules/Dock/DockContextMenuBase.qml` | [`21-dock.md`](21-dock.md) | **Step 1** | Desktop Dock surface and magnification |
| 1117 | `quickshell/Modules/Dock/DockEditChrome.qml` | [`21-dock.md`](21-dock.md) | **Step 1** | Desktop Dock surface and magnification |
| 1118 | `quickshell/Modules/Dock/DockGeometry.qml` | [`21-dock.md`](21-dock.md) | **Step 1** | Desktop Dock surface and magnification |
| 1119 | `quickshell/Modules/Dock/DockHoverBounce.qml` | [`21-dock.md`](21-dock.md) | **Step 1** | Desktop Dock surface and magnification |
| 1120 | `quickshell/Modules/Dock/DockLauncherButton.qml` | [`21-dock.md`](21-dock.md) | **Step 1** | Desktop Dock surface and magnification |
| 1121 | `quickshell/Modules/Dock/DockOverflowButton.qml` | [`21-dock.md`](21-dock.md) | **Step 1** | Desktop Dock surface and magnification |
| 1122 | `quickshell/Modules/Dock/DockTrashButton.qml` | [`21-dock.md`](21-dock.md) | **Step 1** | Desktop Dock surface and magnification |
| 1123 | `quickshell/Modules/Dock/DockTrashContextMenu.qml` | [`21-dock.md`](21-dock.md) | **Step 1** | Desktop Dock surface and magnification |
| 1124 | `quickshell/Modules/Dock/DockTrashMenuItem.qml` | [`21-dock.md`](21-dock.md) | **Step 1** | Desktop Dock surface and magnification |
| 1125 | `quickshell/Modules/Frame/Frame.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1126 | `quickshell/Modules/Frame/FrameBarHost.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1127 | `quickshell/Modules/Frame/FrameBorder.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1128 | `quickshell/Modules/Frame/FrameDockHost.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1129 | `quickshell/Modules/Frame/FrameExclusions.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1130 | `quickshell/Modules/Frame/FrameInstance.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1131 | `quickshell/Modules/Frame/FrameLauncherHoverZone.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 1132 | `quickshell/Modules/Frame/FrameWindow.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1133 | `quickshell/Modules/Greetd/GreetdEnv.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1134 | `quickshell/Modules/Greetd/GreetdMemory.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1135 | `quickshell/Modules/Greetd/GreetdSettings.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 1136 | `quickshell/Modules/Greetd/GreeterContent.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1137 | `quickshell/Modules/Greetd/GreeterState.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1138 | `quickshell/Modules/Greetd/GreeterSurface.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1139 | `quickshell/Modules/Greetd/GreeterUserPicker.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1140 | `quickshell/Modules/Greetd/GreeterUserTheme.qml` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 1141 | `quickshell/Modules/Lock/FadeOverlayWindow.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1142 | `quickshell/Modules/Lock/FadeToDpmsWindow.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1143 | `quickshell/Modules/Lock/FadeToLockWindow.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1144 | `quickshell/Modules/Lock/Lock.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1145 | `quickshell/Modules/Lock/LockBackgroundSampler.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1146 | `quickshell/Modules/Lock/LockPlacementPreparer.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1147 | `quickshell/Modules/Lock/LockScreenBackground.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1148 | `quickshell/Modules/Lock/LockScreenContent.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1149 | `quickshell/Modules/Lock/LockScreenDemo.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1150 | `quickshell/Modules/Lock/LockStatusRow.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1151 | `quickshell/Modules/Lock/LockSurface.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1152 | `quickshell/Modules/Lock/Pam.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1153 | `quickshell/Modules/Lock/VideoScreensaver.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1154 | `quickshell/Modules/Lock/VideoScreensaverPlayer.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1155 | `quickshell/Modules/Lock/Widgets/GreeterSessionWidget.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 1156 | `quickshell/Modules/Lock/Widgets/LockAuthWidget.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1157 | `quickshell/Modules/Lock/Widgets/LockDateWidget.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1158 | `quickshell/Modules/Lock/Widgets/LockNotificationsWidget.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1159 | `quickshell/Modules/Lock/Widgets/LockPowerWidget.qml` | [`13-power-display.md`](13-power-display.md) | **Step 1** | Power and display management |
| 1160 | `quickshell/Modules/Lock/Widgets/LockStatusWidget.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1161 | `quickshell/Modules/Network/WifiConnectionActions.qml` | [`11-connectivity-qml.md`](11-connectivity-qml.md) | **Step 1** | Connectivity layer |
| 1162 | `quickshell/Modules/Notepad/Notepad.qml` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 1163 | `quickshell/Modules/Notepad/NotepadPopoutWindow.qml` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 1164 | `quickshell/Modules/Notepad/NotepadSettings.qml` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 1165 | `quickshell/Modules/Notepad/NotepadTabs.qml` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 1166 | `quickshell/Modules/Notepad/NotepadTextEditor.qml` | [`27-notepad.md`](27-notepad.md) | **Step 2** | Notepad scratchpad & syntax highlighting |
| 1167 | `quickshell/Modules/Notifications/Center/HistoryNotificationCard.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1168 | `quickshell/Modules/Notifications/Center/HistoryNotificationList.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1169 | `quickshell/Modules/Notifications/Center/KeyboardNavigatedNotificationList.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1170 | `quickshell/Modules/Notifications/Center/NotificationCard.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1171 | `quickshell/Modules/Notifications/Center/NotificationCenterContent.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1172 | `quickshell/Modules/Notifications/Center/NotificationCenterPopout.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1173 | `quickshell/Modules/Notifications/Center/NotificationEmptyState.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1174 | `quickshell/Modules/Notifications/Center/NotificationHeader.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1175 | `quickshell/Modules/Notifications/Center/NotificationKeyboardController.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1176 | `quickshell/Modules/Notifications/Center/NotificationKeyboardHints.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1177 | `quickshell/Modules/Notifications/DndPresets.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1178 | `quickshell/Modules/Notifications/NotificationActions.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1179 | `quickshell/Modules/Notifications/NotificationCard.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1180 | `quickshell/Modules/Notifications/NotificationContextMenu.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1181 | `quickshell/Modules/Notifications/NotificationMetrics.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1182 | `quickshell/Modules/Notifications/NotificationSwipeGroup.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1183 | `quickshell/Modules/Notifications/NotificationSwipeRow.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1184 | `quickshell/Modules/Notifications/NotificationSwipeWheel.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1185 | `quickshell/Modules/Notifications/Popup/NotificationPopup.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1186 | `quickshell/Modules/Notifications/Popup/NotificationPopupManager.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1187 | `quickshell/Modules/OSD/AudioOutputOSD.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1188 | `quickshell/Modules/OSD/BrightnessOSD.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1189 | `quickshell/Modules/OSD/CapsLockOSD.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1190 | `quickshell/Modules/OSD/IdleInhibitorOSD.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1191 | `quickshell/Modules/OSD/LevelOSD.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1192 | `quickshell/Modules/OSD/MediaPlaybackOSD.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1193 | `quickshell/Modules/OSD/MediaVolumeOSD.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1194 | `quickshell/Modules/OSD/MicVolumeOSD.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1195 | `quickshell/Modules/OSD/OsdDetailSheet.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1196 | `quickshell/Modules/OSD/OsdIcon.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1197 | `quickshell/Modules/OSD/OsdLevelRow.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1198 | `quickshell/Modules/OSD/PowerProfileOSD.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1199 | `quickshell/Modules/OSD/VolumeOSD.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1200 | `quickshell/Modules/OSD/WorkspaceOSD.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1201 | `quickshell/Modules/Plugins/BasePill.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1202 | `quickshell/Modules/Plugins/ColorSetting.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1203 | `quickshell/Modules/Plugins/DashCardComponent.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1204 | `quickshell/Modules/Plugins/DashTabComponent.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1205 | `quickshell/Modules/Plugins/DesktopPluginComponent.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1206 | `quickshell/Modules/Plugins/DesktopPluginWrapper.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1207 | `quickshell/Modules/Plugins/DesktopWidgetContent.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1208 | `quickshell/Modules/Plugins/DesktopWidgetGeometry.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1209 | `quickshell/Modules/Plugins/DesktopWidgetGridHint.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1210 | `quickshell/Modules/Plugins/DesktopWidgetGridLines.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1211 | `quickshell/Modules/Plugins/ListSetting.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1212 | `quickshell/Modules/Plugins/ListSettingRemoveButton.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1213 | `quickshell/Modules/Plugins/ListSettingWithInput.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1214 | `quickshell/Modules/Plugins/PluginComponent.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1215 | `quickshell/Modules/Plugins/PluginPopout.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1216 | `quickshell/Modules/Plugins/PluginSettings.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1217 | `quickshell/Modules/Plugins/PopoutComponent.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1218 | `quickshell/Modules/Plugins/SelectionSetting.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1219 | `quickshell/Modules/Plugins/SliderSetting.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1220 | `quickshell/Modules/Plugins/StringSetting.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1221 | `quickshell/Modules/Plugins/ToggleSetting.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1222 | `quickshell/Modules/Plugins/WidgetEditItem.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1223 | `quickshell/Modules/Plugins/WidgetEditLayer.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1224 | `quickshell/Modules/Plugins/WidgetEditorOverlay.qml` | [`30-plugins-desktop-widgets.md`](30-plugins-desktop-widgets.md) | **Step 2** | Plugin system & desktop widget canvas |
| 1225 | `quickshell/Modules/PowerMenu/PowerMenuContent.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1226 | `quickshell/Modules/ProcessList/DisksView.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1227 | `quickshell/Modules/ProcessList/PerformanceCard.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1228 | `quickshell/Modules/ProcessList/PerformanceView.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1229 | `quickshell/Modules/ProcessList/ProcessContextMenu.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1230 | `quickshell/Modules/ProcessList/ProcessFilterChips.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1231 | `quickshell/Modules/ProcessList/ProcessListMetrics.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1232 | `quickshell/Modules/ProcessList/ProcessListPopout.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1233 | `quickshell/Modules/ProcessList/ProcessRow.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1234 | `quickshell/Modules/ProcessList/ProcessSummary.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1235 | `quickshell/Modules/ProcessList/ProcessSystemHeader.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1236 | `quickshell/Modules/ProcessList/ProcessesView.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1237 | `quickshell/Modules/ProcessList/SystemView.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1238 | `quickshell/Modules/Settings/AboutTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1239 | `quickshell/Modules/Settings/AudioTab.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1240 | `quickshell/Modules/Settings/AutoStartTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1241 | `quickshell/Modules/Settings/BarHubHeader.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1242 | `quickshell/Modules/Settings/BarWidgetOptions/AppsDockOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1243 | `quickshell/Modules/Settings/BarWidgetOptions/BatteryOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1244 | `quickshell/Modules/Settings/BarWidgetOptions/ClockOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1245 | `quickshell/Modules/Settings/BarWidgetOptions/ControlCenterOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1246 | `quickshell/Modules/Settings/BarWidgetOptions/FocusedWindowOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1247 | `quickshell/Modules/Settings/BarWidgetOptions/IslandOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1248 | `quickshell/Modules/Settings/BarWidgetOptions/KeyboardLayoutOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1249 | `quickshell/Modules/Settings/BarWidgetOptions/LauncherButtonOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1250 | `quickshell/Modules/Settings/BarWidgetOptions/MusicOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1251 | `quickshell/Modules/Settings/BarWidgetOptions/NetworkMonitorOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1252 | `quickshell/Modules/Settings/BarWidgetOptions/PrivacyOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1253 | `quickshell/Modules/Settings/BarWidgetOptions/RunningAppsOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1254 | `quickshell/Modules/Settings/BarWidgetOptions/SystemMonitorOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1255 | `quickshell/Modules/Settings/BarWidgetOptions/SystemTrayOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1256 | `quickshell/Modules/Settings/BarWidgetOptions/SystemUpdateOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1257 | `quickshell/Modules/Settings/BarWidgetOptions/WorkspaceSwitcherOptions.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1258 | `quickshell/Modules/Settings/BarWidgetTab.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1259 | `quickshell/Modules/Settings/BatteryTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1260 | `quickshell/Modules/Settings/ChangelogTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1261 | `quickshell/Modules/Settings/ClipboardTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1262 | `quickshell/Modules/Settings/ColorDropdownRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1263 | `quickshell/Modules/Settings/CompositorLayoutTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1264 | `quickshell/Modules/Settings/CreateUserTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1265 | `quickshell/Modules/Settings/DBarAppearanceTab.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1266 | `quickshell/Modules/Settings/DBarTab.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1267 | `quickshell/Modules/Settings/DDashTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1268 | `quickshell/Modules/Settings/DDotTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1269 | `quickshell/Modules/Settings/DefaultAppsTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1270 | `quickshell/Modules/Settings/DesktopWidgetBrowser.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1271 | `quickshell/Modules/Settings/DesktopWidgetGroupSection.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1272 | `quickshell/Modules/Settings/DesktopWidgetInstanceCard.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1273 | `quickshell/Modules/Settings/DesktopWidgetSettings/ClockSettings.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1274 | `quickshell/Modules/Settings/DesktopWidgetSettings/DesktopWidgetInstanceSettings.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1275 | `quickshell/Modules/Settings/DesktopWidgetSettings/DesktopWidgetTypeSettings.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1276 | `quickshell/Modules/Settings/DesktopWidgetSettings/PluginDesktopWidgetSettings.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1277 | `quickshell/Modules/Settings/DesktopWidgetSettings/SystemMonitorSettings.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1278 | `quickshell/Modules/Settings/DesktopWidgetTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1279 | `quickshell/Modules/Settings/DesktopWidgetsTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1280 | `quickshell/Modules/Settings/DigitalWellbeingTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1281 | `quickshell/Modules/Settings/DisplayConfig/DisplayConfigState.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1282 | `quickshell/Modules/Settings/DisplayConfig/HyprlandOutputSettings.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1283 | `quickshell/Modules/Settings/DisplayConfig/ICCProfileInfoModal.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1284 | `quickshell/Modules/Settings/DisplayConfig/MonitorCanvas.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1285 | `quickshell/Modules/Settings/DisplayConfig/MonitorIdentifyOverlay.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1286 | `quickshell/Modules/Settings/DisplayConfig/MonitorRect.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1287 | `quickshell/Modules/Settings/DisplayConfig/NiriOutputSettings.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1288 | `quickshell/Modules/Settings/DisplayConfig/NoBackendMessage.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1289 | `quickshell/Modules/Settings/DisplayConfig/OutputCard.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1290 | `quickshell/Modules/Settings/DisplayConfigTab.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1291 | `quickshell/Modules/Settings/DisplayWidgetsTab.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1292 | `quickshell/Modules/Settings/DockAdvancedTab.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1293 | `quickshell/Modules/Settings/DockAppearanceTab.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1294 | `quickshell/Modules/Settings/DockGeneralTab.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1295 | `quickshell/Modules/Settings/DockHubHeader.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1296 | `quickshell/Modules/Settings/DockWidgetsTab.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1297 | `quickshell/Modules/Settings/GammaControlTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1298 | `quickshell/Modules/Settings/GreeterAuthTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1299 | `quickshell/Modules/Settings/GreeterSyncFabBar.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1300 | `quickshell/Modules/Settings/GreeterTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1301 | `quickshell/Modules/Settings/KeybindEditorDialog.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1302 | `quickshell/Modules/Settings/KeybindRow.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1303 | `quickshell/Modules/Settings/KeybindsTab.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1304 | `quickshell/Modules/Settings/KeyboardTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1305 | `quickshell/Modules/Settings/LauncherTab.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1306 | `quickshell/Modules/Settings/LocaleTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1307 | `quickshell/Modules/Settings/LockScreenTab.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1308 | `quickshell/Modules/Settings/LockWidgetSettings/LockAuthSettings.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1309 | `quickshell/Modules/Settings/LockWidgetSettings/LockDateSettings.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1310 | `quickshell/Modules/Settings/LockWidgetSettings/LockNotificationsSettings.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1311 | `quickshell/Modules/Settings/LockWidgetSettings/LockPowerSettings.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1312 | `quickshell/Modules/Settings/LockWidgetSettings/LockStatusSettings.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1313 | `quickshell/Modules/Settings/MediaPlayerTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1314 | `quickshell/Modules/Settings/MouseTouchpadTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1315 | `quickshell/Modules/Settings/MuxTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1316 | `quickshell/Modules/Settings/NetworkCellularTab.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1317 | `quickshell/Modules/Settings/NetworkEthernetTab.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1318 | `quickshell/Modules/Settings/NetworkStatusTab.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1319 | `quickshell/Modules/Settings/NetworkVpnTab.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1320 | `quickshell/Modules/Settings/NetworkWifiTab.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1321 | `quickshell/Modules/Settings/NotificationRuleEditorDialog.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1322 | `quickshell/Modules/Settings/NotificationRulesTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1323 | `quickshell/Modules/Settings/NotificationsTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1324 | `quickshell/Modules/Settings/OSDTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1325 | `quickshell/Modules/Settings/PaletteInjectTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1326 | `quickshell/Modules/Settings/PluginBadge.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1327 | `quickshell/Modules/Settings/PluginBrowser.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1328 | `quickshell/Modules/Settings/PluginCard.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1329 | `quickshell/Modules/Settings/PluginSettingsPage.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1330 | `quickshell/Modules/Settings/PluginUpdatesDialog.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1331 | `quickshell/Modules/Settings/PluginsHubHeader.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1332 | `quickshell/Modules/Settings/PluginsManageTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1333 | `quickshell/Modules/Settings/PowerSleepTab.qml` | [`33-settings-ui-c.md`](33-settings-ui-c.md) | **Step 1** | Settings tab: Audio/Network/Power/Lock |
| 1334 | `quickshell/Modules/Settings/PrinterTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1335 | `quickshell/Modules/Settings/RegistryBrowserWindow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1336 | `quickshell/Modules/Settings/RunningAppsTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1337 | `quickshell/Modules/Settings/SettingsHubPage.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1338 | `quickshell/Modules/Settings/ShadowsTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1339 | `quickshell/Modules/Settings/SoftwareUpdatesTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1340 | `quickshell/Modules/Settings/SoundsTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1341 | `quickshell/Modules/Settings/ThemeAppsTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1342 | `quickshell/Modules/Settings/ThemeBrowser.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1343 | `quickshell/Modules/Settings/ThemeColorsTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1344 | `quickshell/Modules/Settings/ThemeScheduleTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1345 | `quickshell/Modules/Settings/ThemeSurfacesTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1346 | `quickshell/Modules/Settings/TimeWeatherTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1347 | `quickshell/Modules/Settings/TypographyMotionTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1348 | `quickshell/Modules/Settings/UserAccountsTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1349 | `quickshell/Modules/Settings/UsersTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1350 | `quickshell/Modules/Settings/WallpaperColorsTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1351 | `quickshell/Modules/Settings/WallpaperCyclingTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1352 | `quickshell/Modules/Settings/WeatherSettingsTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1353 | `quickshell/Modules/Settings/WidgetPickerWindow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1354 | `quickshell/Modules/Settings/WidgetSelectionPopup.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1355 | `quickshell/Modules/Settings/Widgets/AppBrowserPopup.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1356 | `quickshell/Modules/Settings/Widgets/AqueousAppearanceSettings.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1357 | `quickshell/Modules/Settings/Widgets/BarSelectionState.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1358 | `quickshell/Modules/Settings/Widgets/ConfigInclude.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1359 | `quickshell/Modules/Settings/Widgets/DeviceAliasRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1360 | `quickshell/Modules/Settings/Widgets/DockSelectionState.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1361 | `quickshell/Modules/Settings/Widgets/IncludeSetupBanner.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1362 | `quickshell/Modules/Settings/Widgets/IslandBehaviorCard.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1363 | `quickshell/Modules/Settings/Widgets/IslandHomeCard.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1364 | `quickshell/Modules/Settings/Widgets/IslandHomeLayoutEditor.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1365 | `quickshell/Modules/Settings/Widgets/IslandMotionCard.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1366 | `quickshell/Modules/Settings/Widgets/IslandNotificationsCard.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1367 | `quickshell/Modules/Settings/Widgets/IslandRouteRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1368 | `quickshell/Modules/Settings/Widgets/IslandSettingsStore.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1369 | `quickshell/Modules/Settings/Widgets/MaterialSeedPicker.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1370 | `quickshell/Modules/Settings/Widgets/MaterialWallpaperOptions.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1371 | `quickshell/Modules/Settings/Widgets/MaterialWallpaperPresets.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1372 | `quickshell/Modules/Settings/Widgets/PluginSettingsHost.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1373 | `quickshell/Modules/Settings/Widgets/SettingsButtonGroupRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1374 | `quickshell/Modules/Settings/Widgets/SettingsCard.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1375 | `quickshell/Modules/Settings/Widgets/SettingsColorPicker.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1376 | `quickshell/Modules/Settings/Widgets/SettingsControlledBy.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1377 | `quickshell/Modules/Settings/Widgets/SettingsDeleteButton.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1378 | `quickshell/Modules/Settings/Widgets/SettingsDisplayPicker.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1379 | `quickshell/Modules/Settings/Widgets/SettingsDivider.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1380 | `quickshell/Modules/Settings/Widgets/SettingsDropdownRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1381 | `quickshell/Modules/Settings/Widgets/SettingsFabBar.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1382 | `quickshell/Modules/Settings/Widgets/SettingsFontDropdownRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1383 | `quickshell/Modules/Settings/Widgets/SettingsGroup.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1384 | `quickshell/Modules/Settings/Widgets/SettingsHeroCard.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1385 | `quickshell/Modules/Settings/Widgets/SettingsInstanceRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1386 | `quickshell/Modules/Settings/Widgets/SettingsLayoutPicker.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1387 | `quickshell/Modules/Settings/Widgets/SettingsLinkRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1388 | `quickshell/Modules/Settings/Widgets/SettingsLocationSection.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1389 | `quickshell/Modules/Settings/Widgets/SettingsMetrics.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1390 | `quickshell/Modules/Settings/Widgets/SettingsNavRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1391 | `quickshell/Modules/Settings/Widgets/SettingsNoteRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1392 | `quickshell/Modules/Settings/Widgets/SettingsPage.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1393 | `quickshell/Modules/Settings/Widgets/SettingsRenameDialog.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1394 | `quickshell/Modules/Settings/Widgets/SettingsReorderGroup.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1395 | `quickshell/Modules/Settings/Widgets/SettingsReorderList.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1396 | `quickshell/Modules/Settings/Widgets/SettingsReorderPreview.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1397 | `quickshell/Modules/Settings/Widgets/SettingsReorderRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1398 | `quickshell/Modules/Settings/Widgets/SettingsRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1399 | `quickshell/Modules/Settings/Widgets/SettingsScreenPositionPicker.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1400 | `quickshell/Modules/Settings/Widgets/SettingsSearchRegistration.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1401 | `quickshell/Modules/Settings/Widgets/SettingsSectionLabel.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1402 | `quickshell/Modules/Settings/Widgets/SettingsSidebarItem.qml` | [`32-settings-ui-b.md`](32-settings-ui-b.md) | **Step 1** | Settings tab: Bar/Dock/Launcher/Display |
| 1403 | `quickshell/Modules/Settings/Widgets/SettingsSliderControl.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1404 | `quickshell/Modules/Settings/Widgets/SettingsSliderRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1405 | `quickshell/Modules/Settings/Widgets/SettingsSplitRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1406 | `quickshell/Modules/Settings/Widgets/SettingsSurfacePreview.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1407 | `quickshell/Modules/Settings/Widgets/SettingsSwatchGrid.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1408 | `quickshell/Modules/Settings/Widgets/SettingsTextFieldRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1409 | `quickshell/Modules/Settings/Widgets/SettingsTimeRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1410 | `quickshell/Modules/Settings/Widgets/SettingsToggleCard.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1411 | `quickshell/Modules/Settings/Widgets/SettingsToggleRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1412 | `quickshell/Modules/Settings/Widgets/SettingsToggleSliderRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1413 | `quickshell/Modules/Settings/Widgets/SettingsWallpaperThumb.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1414 | `quickshell/Modules/Settings/Widgets/SurfaceColorRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1415 | `quickshell/Modules/Settings/Widgets/TerminalPickerRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1416 | `quickshell/Modules/Settings/Widgets/WidgetBackgroundRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1417 | `quickshell/Modules/Settings/Widgets/WidgetBackgroundStrengthRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1418 | `quickshell/Modules/Settings/Widgets/WidgetTextStyleRow.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1419 | `quickshell/Modules/Settings/WidgetsTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1420 | `quickshell/Modules/Settings/WidgetsTabSection.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1421 | `quickshell/Modules/Settings/WindowRuleEditorDialog.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1422 | `quickshell/Modules/Settings/WindowRulesTab.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1423 | `quickshell/Modules/Settings/WorkspaceAppearanceBorderFields.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1424 | `quickshell/Modules/Settings/WorkspaceAppearanceCard.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1425 | `quickshell/Modules/Settings/WorkspaceAppearanceColorOptions.qml` | [`31-settings-ui-a.md`](31-settings-ui-a.md) | **Step 1** | Settings framework, appearance & theme |
| 1426 | `quickshell/Modules/SurfaceWidgets/ApplicationItem.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1427 | `quickshell/Modules/SurfaceWidgets/ApplicationModel.js` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1428 | `quickshell/Modules/SurfaceWidgets/ApplicationStrip.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1429 | `quickshell/Modules/SurfaceWidgets/BarPill.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1430 | `quickshell/Modules/SurfaceWidgets/GothCorner.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1431 | `quickshell/Modules/SurfaceWidgets/MediaActivity.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1432 | `quickshell/Modules/SurfaceWidgets/MediaActivityFace.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1433 | `quickshell/Modules/SurfaceWidgets/MediaActivitySource.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1434 | `quickshell/Modules/SurfaceWidgets/MorphSurface.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1435 | `quickshell/Modules/SurfaceWidgets/SurfaceContext.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1436 | `quickshell/Modules/SurfaceWidgets/SurfaceStrip.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1437 | `quickshell/Modules/SurfaceWidgets/SurfaceWidgetFactory.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1438 | `quickshell/Modules/SurfaceWidgets/SurfaceWidgetHost.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1439 | `quickshell/Modules/SurfaceWidgets/VectorSpringMotion.qml` | [`24-island-surface-widgets.md`](24-island-surface-widgets.md) | **Step 2** | Dynamic Island morphing surfaces and spring physics |
| 1440 | `quickshell/Modules/SystemUpdate/SystemUpdatePanel.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1441 | `quickshell/Modules/SystemUpdate/UpgradeLogText.qml` | [`28-processlist-powermenu-updates.md`](28-processlist-powermenu-updates.md) | **Step 1 & 2** | Process list, power menu, update viewer |
| 1442 | `quickshell/Modules/Toast.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1443 | `quickshell/Modules/WallpaperBackground.qml` | [`02-wallpaper.md`](02-wallpaper.md) | **Step 1** | Wallpaper engine and transition shaders |
| 1444 | `quickshell/Modules/WorkspaceOverlays/HyprlandOverview.qml` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 1445 | `quickshell/Modules/WorkspaceOverlays/NiriOverviewOverlay.qml` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 1446 | `quickshell/Modules/WorkspaceOverlays/OverviewWidget.qml` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 1447 | `quickshell/Modules/WorkspaceOverlays/OverviewWindow.qml` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 1448 | `quickshell/PLUGINS/AttachedPanelExample/AttachedPanelExample.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1449 | `quickshell/PLUGINS/ColorDemoPlugin/ColorDemoSettings.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 1450 | `quickshell/PLUGINS/ColorDemoPlugin/ColorDemoWidget.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1451 | `quickshell/PLUGINS/ControlCenterDetailExample/DetailExampleWidget.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1452 | `quickshell/PLUGINS/ControlCenterExample/ControlCenterExampleWidget.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1453 | `quickshell/PLUGINS/DashCardExample/ProgressCard.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1454 | `quickshell/PLUGINS/DashCounterExample/CounterCard.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1455 | `quickshell/PLUGINS/DashCounterExample/CounterTab.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1456 | `quickshell/PLUGINS/DashCounterExample/CounterWidget.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1457 | `quickshell/PLUGINS/DashTabExample/StopwatchTab.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1458 | `quickshell/PLUGINS/ExampleCompositePlugin/CompositeBarWidget.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1459 | `quickshell/PLUGINS/ExampleCompositePlugin/CompositeDaemon.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1460 | `quickshell/PLUGINS/ExampleCompositePlugin/CompositeDesktopWidget.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1461 | `quickshell/PLUGINS/ExampleCompositePlugin/CompositeSettings.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 1462 | `quickshell/PLUGINS/ExampleDesktopClock/DesktopClock.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1463 | `quickshell/PLUGINS/ExampleDesktopClock/DesktopClockSettings.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 1464 | `quickshell/PLUGINS/ExampleEmojiPlugin/EmojiSettings.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 1465 | `quickshell/PLUGINS/ExampleEmojiPlugin/EmojiWidget.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1466 | `quickshell/PLUGINS/ExampleStartupCheck/StartupCheck.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1467 | `quickshell/PLUGINS/ExampleStartupCheck/StartupCheckWidget.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1468 | `quickshell/PLUGINS/ExampleWithVariants/VariantSettings.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 1469 | `quickshell/PLUGINS/ExampleWithVariants/VariantWidget.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1470 | `quickshell/PLUGINS/LauncherExample/LauncherExampleLauncher.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 1471 | `quickshell/PLUGINS/LauncherExample/LauncherExampleSettings.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 1472 | `quickshell/PLUGINS/LauncherImageExample/LauncherImageExample.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 1473 | `quickshell/PLUGINS/PopoutControlExample/PopoutControlSettings.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 1474 | `quickshell/PLUGINS/PopoutControlExample/PopoutControlWidget.qml` | [`06-surfaces-popouts.md`](06-surfaces-popouts.md) | **Step 1** | Connected popout surfaces |
| 1475 | `quickshell/PLUGINS/QuickNotesExample/QuickNotesLauncher.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 1476 | `quickshell/PLUGINS/QuickNotesExample/QuickNotesSettings.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 1477 | `quickshell/PLUGINS/WallpaperWatcherDaemon/WallpaperWatcherDaemon.qml` | [`02-wallpaper.md`](02-wallpaper.md) | **Step 1** | Wallpaper engine and transition shaders |
| 1478 | `quickshell/PLUGINS/WallpaperWatcherDaemon/WallpaperWatcherSettings.qml` | [`02-wallpaper.md`](02-wallpaper.md) | **Step 1** | Wallpaper engine and transition shaders |
| 1479 | `quickshell/Services/AppSearchService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1480 | `quickshell/Services/AppleMusicArtService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1481 | `quickshell/Services/AqueousConfigService.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 1482 | `quickshell/Services/AqueousService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1483 | `quickshell/Services/AudioService.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1484 | `quickshell/Services/AudioSoundPlayers.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1485 | `quickshell/Services/BarWidgetService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1486 | `quickshell/Services/BatteryService.qml` | [`13-power-display.md`](13-power-display.md) | **Step 1** | Power and display management |
| 1487 | `quickshell/Services/BluetoothService.qml` | [`11-connectivity-qml.md`](11-connectivity-qml.md) | **Step 1** | Connectivity layer |
| 1488 | `quickshell/Services/BlurService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1489 | `quickshell/Services/BootEntries.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1490 | `quickshell/Services/BootEntryService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1491 | `quickshell/Services/BrightnessService.qml` | [`13-power-display.md`](13-power-display.md) | **Step 1** | Power and display management |
| 1492 | `quickshell/Services/CalendarDankBackend.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1493 | `quickshell/Services/CalendarKhalBackend.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1494 | `quickshell/Services/CalendarService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1495 | `quickshell/Services/CavaService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1496 | `quickshell/Services/ChangelogService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1497 | `quickshell/Services/ClipboardService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1498 | `quickshell/Services/CompositorService.qml` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 1499 | `quickshell/Services/CupsService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1500 | `quickshell/Services/DMSNetworkService.qml` | [`11-connectivity-qml.md`](11-connectivity-qml.md) | **Step 1** | Connectivity layer |
| 1501 | `quickshell/Services/DMSService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1502 | `quickshell/Services/DSearchService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1503 | `quickshell/Services/DesktopService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1504 | `quickshell/Services/DesktopWidgetRegistry.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1505 | `quickshell/Services/DgopService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1506 | `quickshell/Services/DisplayService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1507 | `quickshell/Services/FilesService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1508 | `quickshell/Services/FirstLaunchService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1509 | `quickshell/Services/GreeterService.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1510 | `quickshell/Services/GreeterUsersService.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1511 | `quickshell/Services/HyprlandService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1512 | `quickshell/Services/ICCService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1513 | `quickshell/Services/IconThemeIndex.js` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 1514 | `quickshell/Services/IconThemeService.qml` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 1515 | `quickshell/Services/IdleService.qml` | [`14-session-idle.md`](14-session-idle.md) | **Step 1 & 2** | Idle timeouts and sleep inhibitors |
| 1516 | `quickshell/Services/KeybindsService.qml` | [`16-keybinds.md`](16-keybinds.md) | **Step 1** | Keybind manager and Carbon hotkeys |
| 1517 | `quickshell/Services/KeyboardLayoutService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1518 | `quickshell/Services/LabwcService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1519 | `quickshell/Services/LocationService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1520 | `quickshell/Services/LockPlacementService.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1521 | `quickshell/Services/Log.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1522 | `quickshell/Services/LyricsController.qml` | [`10-media.md`](10-media.md) | **Step 2** | Now playing & synchronized lyrics |
| 1523 | `quickshell/Services/LyricsService.qml` | [`10-media.md`](10-media.md) | **Step 2** | Now playing & synchronized lyrics |
| 1524 | `quickshell/Services/LyricsSubscription.qml` | [`10-media.md`](10-media.md) | **Step 2** | Now playing & synchronized lyrics |
| 1525 | `quickshell/Services/MangoService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1526 | `quickshell/Services/MatugenPreviewService.qml` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 1527 | `quickshell/Services/MediaAccentService.qml` | [`10-media.md`](10-media.md) | **Step 2** | Now playing & synchronized lyrics |
| 1528 | `quickshell/Services/MprisController.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1529 | `quickshell/Services/MultimediaProbe.qml` | [`10-media.md`](10-media.md) | **Step 2** | Now playing & synchronized lyrics |
| 1530 | `quickshell/Services/MultimediaService.qml` | [`10-media.md`](10-media.md) | **Step 2** | Now playing & synchronized lyrics |
| 1531 | `quickshell/Services/MuxService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1532 | `quickshell/Services/NetworkService.qml` | [`11-connectivity-qml.md`](11-connectivity-qml.md) | **Step 1** | Connectivity layer |
| 1533 | `quickshell/Services/NightModeService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1534 | `quickshell/Services/NiriOutputCycle.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1535 | `quickshell/Services/NiriService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1536 | `quickshell/Services/NotepadStorageService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1537 | `quickshell/Services/NotificationService.qml` | [`25-notifications.md`](25-notifications.md) | **Step 2 & 3** | Notification stack & UNUserNotificationCenter bridge |
| 1538 | `quickshell/Services/OutputCycleState.js` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1539 | `quickshell/Services/PaletteInjectService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1540 | `quickshell/Services/PipewireAudioBackend.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1541 | `quickshell/Services/PluginService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1542 | `quickshell/Services/PolkitAgentInstance.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1543 | `quickshell/Services/PolkitService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1544 | `quickshell/Services/PopoutService.qml` | [`06-surfaces-popouts.md`](06-surfaces-popouts.md) | **Step 1** | Connected popout surfaces |
| 1545 | `quickshell/Services/PortalService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1546 | `quickshell/Services/PowerProfileWatcher.qml` | [`13-power-display.md`](13-power-display.md) | **Step 1** | Power and display management |
| 1547 | `quickshell/Services/PrivacyService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1548 | `quickshell/Services/RefreshRateService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1549 | `quickshell/Services/SessionService.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 1550 | `quickshell/Services/SessionsService.qml` | [`04-session-i18n.md`](04-session-i18n.md) | **Step 1** | Session state and translation catalogs |
| 1551 | `quickshell/Services/SettingsSearchService.qml` | [`03-settings-data.md`](03-settings-data.md) | **Step 1** | Hierarchical settings schema |
| 1552 | `quickshell/Services/ShellVersionService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1553 | `quickshell/Services/SystemUpdateService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1554 | `quickshell/Services/TailscaleService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1555 | `quickshell/Services/ThemeAutoService.qml` | [`01-theme.md`](01-theme.md) | **Step 1** | Material 3 CAM16 theme generator |
| 1556 | `quickshell/Services/ToastService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1557 | `quickshell/Services/TrackArtService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1558 | `quickshell/Services/TrashService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1559 | `quickshell/Services/UmbrielService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1560 | `quickshell/Services/UserInfoService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1561 | `quickshell/Services/UsersService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1562 | `quickshell/Services/VPNService.qml` | [`11-connectivity-qml.md`](11-connectivity-qml.md) | **Step 1** | Connectivity layer |
| 1563 | `quickshell/Services/WallpaperCyclingService.qml` | [`02-wallpaper.md`](02-wallpaper.md) | **Step 1** | Wallpaper engine and transition shaders |
| 1564 | `quickshell/Services/WeatherService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1565 | `quickshell/Services/WellbeingService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1566 | `quickshell/Services/WlrOutputService.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1567 | `quickshell/ShellCore.qml` | [`05-shell-root-ipc.md`](05-shell-root-ipc.md) | **Step 1** | Shell root and IPC router |
| 1568 | `quickshell/Widgets/AppIconRenderer.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1569 | `quickshell/Widgets/BackdropBlur.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1570 | `quickshell/Widgets/BatteryMeter.qml` | [`13-power-display.md`](13-power-display.md) | **Step 1** | Power and display management |
| 1571 | `quickshell/Widgets/CachingImage.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1572 | `quickshell/Widgets/ClockContent.qml` | [`17-lock-greeter.md`](17-lock-greeter.md) | **Step 3** | Lock screen overlay & Touch ID auth |
| 1573 | `quickshell/Widgets/DAnimatedAlbumArt.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1574 | `quickshell/Widgets/DBackdrop.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1575 | `quickshell/Widgets/DContextMenu.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1576 | `quickshell/Widgets/DEditableGrid.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1577 | `quickshell/Widgets/DEditableGridSlot.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1578 | `quickshell/Widgets/DFloatingWindow.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1579 | `quickshell/Widgets/DFocusGrab.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1580 | `quickshell/Widgets/DGridEditChrome.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1581 | `quickshell/Widgets/DKeyHints.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1582 | `quickshell/Widgets/DOSD.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1583 | `quickshell/Widgets/DOSDSheet.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1584 | `quickshell/Widgets/DPanelResizer.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1585 | `quickshell/Widgets/DPopout.qml` | [`06-surfaces-popouts.md`](06-surfaces-popouts.md) | **Step 1** | Connected popout surfaces |
| 1586 | `quickshell/Widgets/DPopoutHost.qml` | [`06-surfaces-popouts.md`](06-surfaces-popouts.md) | **Step 1** | Connected popout surfaces |
| 1587 | `quickshell/Widgets/DResizeGrip.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1588 | `quickshell/Widgets/DSeekbar.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1589 | `quickshell/Widgets/DSlideout.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1590 | `quickshell/Widgets/DTooltip.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1591 | `quickshell/Widgets/DankActionButton.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1592 | `quickshell/Widgets/DankAnimatedAlbumArt.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1593 | `quickshell/Widgets/DankBackdrop.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1594 | `quickshell/Widgets/DankBlink.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1595 | `quickshell/Widgets/DankButton.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1596 | `quickshell/Widgets/DankButtonGroup.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1597 | `quickshell/Widgets/DankCircularImage.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1598 | `quickshell/Widgets/DankCollapsibleSection.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1599 | `quickshell/Widgets/DankColorAnimation.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1600 | `quickshell/Widgets/DankColorSwatch.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1601 | `quickshell/Widgets/DankDropdown.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1602 | `quickshell/Widgets/DankFilterChips.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1603 | `quickshell/Widgets/DankFlickable.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1604 | `quickshell/Widgets/DankFloatingWindow.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1605 | `quickshell/Widgets/DankFocusGrab.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1606 | `quickshell/Widgets/DankGridView.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1607 | `quickshell/Widgets/DankIcon.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1608 | `quickshell/Widgets/DankIconPicker.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1609 | `quickshell/Widgets/DankKeycap.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1610 | `quickshell/Widgets/DankListView.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1611 | `quickshell/Widgets/DankLocationSearch.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1612 | `quickshell/Widgets/DankNFIcon.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1613 | `quickshell/Widgets/DankNumberStepper.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1614 | `quickshell/Widgets/DankOSD.qml` | [`09-audio-osd.md`](09-audio-osd.md) | **Step 1** | Audio engine & OSD suite |
| 1615 | `quickshell/Widgets/DankPopout.qml` | [`06-surfaces-popouts.md`](06-surfaces-popouts.md) | **Step 1** | Connected popout surfaces |
| 1616 | `quickshell/Widgets/DankRefreshButton.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1617 | `quickshell/Widgets/DankRipple.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1618 | `quickshell/Widgets/DankSVGIcon.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1619 | `quickshell/Widgets/DankScrollbar.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1620 | `quickshell/Widgets/DankSeekbar.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1621 | `quickshell/Widgets/DankSlideout.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1622 | `quickshell/Widgets/DankSlider.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1623 | `quickshell/Widgets/DankSpinner.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1624 | `quickshell/Widgets/DankTabBar.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1625 | `quickshell/Widgets/DankTextCursor.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1626 | `quickshell/Widgets/DankTextEdit.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1627 | `quickshell/Widgets/DankTextField.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1628 | `quickshell/Widgets/DankToggle.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1629 | `quickshell/Widgets/DankTooltip.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1630 | `quickshell/Widgets/DankTooltipV2.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1631 | `quickshell/Widgets/DismissZone.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1632 | `quickshell/Widgets/EdgeExclusion.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1633 | `quickshell/Widgets/FloatingWindowControls.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1634 | `quickshell/Widgets/FocusRing.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1635 | `quickshell/Widgets/HoverDismissTracker.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1636 | `quickshell/Widgets/LauncherLogo.qml` | [`18-launcher.md`](18-launcher.md) | **Step 1** | DLauncherV2 frecency launcher |
| 1637 | `quickshell/Widgets/M3WaveProgress.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1638 | `quickshell/Widgets/MaterialWallpaper.qml` | [`02-wallpaper.md`](02-wallpaper.md) | **Step 1** | Wallpaper engine and transition shaders |
| 1639 | `quickshell/Widgets/MediaArtBackdrop.qml` | [`10-media.md`](10-media.md) | **Step 2** | Now playing & synchronized lyrics |
| 1640 | `quickshell/Widgets/MediaArtwork.qml` | [`10-media.md`](10-media.md) | **Step 2** | Now playing & synchronized lyrics |
| 1641 | `quickshell/Widgets/MediaBlobHalo.qml` | [`10-media.md`](10-media.md) | **Step 2** | Now playing & synchronized lyrics |
| 1642 | `quickshell/Widgets/NumericText.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1643 | `quickshell/Widgets/PluginGlobalVar.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1644 | `quickshell/Widgets/PointerOverflowMarker.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1645 | `quickshell/Widgets/PopoutHoverBodyTracker.qml` | [`06-surfaces-popouts.md`](06-surfaces-popouts.md) | **Step 1** | Connected popout surfaces |
| 1646 | `quickshell/Widgets/PopoutHoverDismiss.qml` | [`06-surfaces-popouts.md`](06-surfaces-popouts.md) | **Step 1** | Connected popout surfaces |
| 1647 | `quickshell/Widgets/ReleaseNotesCard.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1648 | `quickshell/Widgets/ScrollingText.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1649 | `quickshell/Widgets/StateLayer.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1650 | `quickshell/Widgets/StyledButton.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1651 | `quickshell/Widgets/StyledRect.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1652 | `quickshell/Widgets/StyledText.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1653 | `quickshell/Widgets/StyledTextMetrics.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1654 | `quickshell/Widgets/SurfaceContentClip.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1655 | `quickshell/Widgets/SystemLogo.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1656 | `quickshell/Widgets/TransientSurfaceTracker.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1657 | `quickshell/Widgets/UserIdentity.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1658 | `quickshell/Widgets/WindowBlur.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
| 1659 | `quickshell/Widgets/WorkspacePager.qml` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 1660 | `quickshell/Widgets/WorkspaceSwitcherModel.qml` | [`15-compositor-workspaces.md`](15-compositor-workspaces.md) | **Step 3** | Compositor & window rules bridge |
| 1661 | `quickshell/shell.qml` | [`36-install-packaging-tests.md`](36-install-packaging-tests.md) | **Step 1** | Packaging, daemons, and system testing |
