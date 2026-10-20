# KEYB — Universal Keybinds Engine, Action Catalog & Editor Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Master Action Catalog (`KeybindActions.js`, 3,627 lines), Keybinds Service (`KeybindsService.qml`, 1,056 lines), Go Keybind Parser (`core/internal/keybinds/`, 7.8k lines), Visual Cheatsheet (`DKeyHints.qml`), and Keybind Editor Dialog (`KeybindEditorDialog.qml`, 1,294 lines).

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `quickshell/Common/KeybindActions.js` | 3,627 | Master action catalog: action IDs, English labels, categories, commands |
| `quickshell/Common/KeyUtils.js` | 574 | Keycode normalization, modifier bitmasking, visual glyph rendering |
| `quickshell/Services/KeybindsService.qml` | 1,056 | Active keybinds state, parser interface, conflict validator |
| `quickshell/Modules/Settings/KeybindsTab.qml` | 907 | Keybind management settings tab with category filters and search |
| `quickshell/Modules/Settings/KeybindEditorDialog.qml` | 1,294 | Interactive keybind recorder dialog, key listener, conflict warnings |
| `quickshell/Modules/Settings/KeybindRow.qml` | 86 | Keybind row delegate rendering M3 keycaps (`DKeycap`) |
| `quickshell/Widgets/DKeyHints.qml` | 88 | Floating cheatsheet overlay rendering active shortcuts |
| `core/internal/keybinds/` | 7,840 | Go parsers/serializers for Niri, Hyprland, Sway, DWL configurations |
| `core/cmd/dms/commands_keybinds.go` | 310 | `dms keybinds list`, `dms keybinds set` CLI commands |

---

## 1. Purpose & User-Visible Behavior

1. **Master Action Catalog**:
   - DMS defines over **120 first-class shell actions** (`DMS_ACTIONS`) categorized into: Launcher, Dynamic Island, Control Center, DDash, Notepad, Clipboard, Power Menu, Audio/Mic, Brightness, Workspaces, and Screenshots.
2. **Interactive Keybind Recorder (`KeybindEditorDialog.qml`)**:
   - When editing a shortcut, users press the desired key combination.
   - Live visual feedback shows modifier badges: `⌘ Command`, `⌥ Option`, `⌃ Control`, `⇧ Shift` + keycap.
   - **Conflict Detection**: Warns the user immediately if the chosen combination conflicts with an existing shell or system binding.
3. **Visual Cheatsheet Overlay**:
   - Pressing a dedicated hotkey (or running `dms keybinds`) displays an aesthetic, categorized Material 3 grid of all registered shortcuts.

---

## 2. Master DMS Action Catalog (Core Excerpt)

| Action ID | Default Keybind | Description |
| :--- | :--- | :--- |
| `spotlight.toggle` | `⌥Space` | Toggle DLauncherV2 (Spotlight Mode) |
| `controlcenter.toggle` | `⌥C` | Toggle Quick Settings Control Center |
| `dash.toggle` | `⌥D` | Toggle DankDash Dashboard Overlay |
| `notepad.toggle` | `⌥N` | Toggle Floating Notepad |
| `clipboard.toggle` | `⌥V` | Toggle Clipboard Manager Modal |
| `processlist.toggle` | `⌥Escape` | Toggle Process List & System Monitor |
| `colorpicker.pick` | `⌥P` | Activate Screen Color Eyedropper |
| `screenshot.region` | `⇧⌘4` (or `⌥S`) | Interactive Region Screenshot Selector |
| `island.cycle` | `⌥I` | Cycle Active Dynamic Island Card |
| `volume.mute.toggle` | `Mute` key | Toggle Default Audio Output Mute |
| `mic.mute.toggle` | `⌥M` | Toggle Microphone Mute State |
| `inhibit.toggle` | `⌥K` | Toggle Sleep Inhibition |

---

## 3. Wayland/Linux Mechanisms → macOS Mapping

1. **Compositor Config File Manipulation**:
   - Linux reads/writes `~/.config/hypr/hyprland.conf` or `niri/config.kdl`.
   - **macOS Approach**: Store user shortcuts in `~/Library/Application Support/DMS/keybinds.json`. Register global shortcuts using Carbon `RegisterEventHotKey` (for simple combinations) or `CGEvent.tapCreate` (for universal modifiers and media keys with Accessibility permission).
2. **Key Capture during Recording**:
   - Linux uses evdev or Quickshell key event filters.
   - **macOS Approach**: In `KeybindEditorDialog`, attach a local `NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged])` to capture keystrokes, translate `event.modifierFlags` and `event.charactersIgnoringModifiers`, and format display strings.

---

## 4. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| Global Shortcuts | **Partial** | `HotkeyService.swift` (83 lines) | Hardcodes 4 static Carbon hotkeys (`⌥Space` for launcher, `⌥D` for dash, etc.). **Does not allow user customization.** |
| Keybinds Editor | **Missing** | None | `KeybindEditorDialog.qml` (1,294 lines) does not exist. No key recording, conflict checking, or persistence exists. |
| Visual Cheatsheet | **Partial** | `KeybindsView.swift` (175 lines) | Shows a hardcoded static SwiftUI list of 10 shortcuts; lacks live binding, search, or category filtering. |

### Audit Verdict:
The port hardcodes a few fixed Carbon hotkeys and shows a static read-only list. **The interactive keybind recorder, conflict detector, and customizable keybinds engine are completely missing**. Parity: **~15%**.

---

## 5. Reimplementation Checklist

- [ ] Implement `KeybindStore.swift` serializing user shortcuts to `keybinds.json`.
- [ ] Build `KeybindRecorderView.swift` with live modifier capture and conflict warnings.
- [ ] Wire up dynamic Carbon / CGEventTap hotkey rebinding without app restarts.
- [ ] Implement categorized cheatsheet search in `KeybindsView.swift`.
