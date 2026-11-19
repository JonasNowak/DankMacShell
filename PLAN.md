# DankMaterialShell (DMS) for macOS: Port Plan

This repository (`DankMacShell`) is the native macOS edition of
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) (`AvengeMedia/DankMaterialShell`).
The upstream project is a modern, unified desktop shell built for Wayland compositors (Niri, Hyprland, Sway, etc.)
using Quickshell (QtQuick/QML) and Go.

**Quickshell and Wayland protocols do not run on macOS.**
This project is an architectural port and reconstruction: same Material Design 3 visual language,
same components (DankBar, Dynamic Island, DLauncherV2, DankDash, Control Center, OSD, Power Menu, Desktop Widgets), same dynamic wallpaper theming,
rebuilt as a native macOS application (AppKit + SwiftUI, built with the Swift 6 toolchain in Swift 5 language mode targeting macOS 14+).

## 1. Principles

- **Material Design 3 (Material You):** Full M3 color tokens, dynamic tonal generation from desktop wallpaper, pill-shaped action buttons, rounded container cards, and elevation surfaces.
- **Zero Idle CPU (~0%):** Purely event-driven using system notifications and run-loop sources (`NSWorkspace`, `CoreAudio`, `CoreWLAN`, `IOKit`, `DisplayServices`, `SCDynamicStore`). No unnecessary polling timers.
- **Modular & Focused Dependencies:** Pure Swift Package Manager using `MaterialMacLibrary` (M3 Expressive tokens/shapes/components) and `dank-theme-engine` (Rust FFI palette generator & terminal exporter).
- **macOS Native:** Public APIs first (`NSPanel`, `CoreWLAN`, `IOBluetooth`, `CoreAudio`, `CoreImage`). Private APIs only via dynamic lookup (`dlopen`/`dlsym`) with graceful fallbacks.
- **Modular Architecture:**
  - `DMSCore`: UI-free logic, M3 theme generator adapters, config, fuzzy app search catalog, calculator, telemetry models, IPC, clipboard/notepad stores, wellbeing, and Symbian sync parsers. Fully unit-tested (`DMSCoreTests`).
  - `DMS`: Application target (`DankMacShell.app`) with `ShellPanel`, `DankBar`, `DIsland`, `ControlCenter`, `DankDash`, `DLauncherV2`, `Notepad`, `Clipboard`, `DesktopWidgets`, `OSD`, `PowerMenu`, `ToastCenter`, and system services.
  - `DMSCLI`: Native `dms` CLI utility (`start`/`stop`/`status`/`doctor`/`setup-cert`/`dmenu`/`listen`/`shell`/`ipc`).
  - `DMSSymbian`: Standalone Nokia Belle USB sync companion (`dms-symbian`).

## 2. Feature Mapping

| Upstream DMS (Wayland / Linux) | macOS Implementation | Technical Notes |
| :--- | :--- | :--- |
| **DankBar / DBar** (`PanelWindow`, layer-shell) | `ShellPanel` (`NSPanel`, `.statusBar` level, `canJoinAllSpaces`, borderless, non-activating). Configurable top, bottom, left, or right position. | Smooth auto-hide and fullscreen-aware `smartAutoHide`. |
| **Running Apps** (`ToplevelManager`) | Workspace running apps inside DankBar via `WorkspaceService`. (Standalone Desktop Dock intentionally omitted; macOS provides the native Dock.) | Active app dot indicators and click-to-activate. |
| **Dynamic M3 Theming** (Matugen / `dank16`) | `DynamicThemeGenerator` in `DMSCore` backed by `DankThemeEngine` (Rust FFI) + `MaterialMacLibrary`. | Generates full M3 dark & light palettes (Primary, Secondary, Tertiary, Surface, Containers, Outline, Errors) and syncs Ghostty/Kitty/Alacritty/iTerm2/OmniWM. |
| **Stock & Community M3 Themes** | Purple (default), Blue, Green, Orange, Red, Yellow, Neutral + Catppuccin Mocha/Latte, Nord, Gruvbox, Tokyo Night, Everforest. | Instant switching and persistence. |
| **DLauncherV2** (Spotlight App Launcher) | Centered or Island-attached `ShellPanel` with fuzzy app catalog, safe recursive math evaluator (`2+2`, `sqrt(144)`), file search, and `dms dmenu`. | Global hotkey via Carbon `RegisterEventHotKey` (default `⌥Space`). |
| **Control Center & DankDash** | Material 3 Quick Settings grid (drag-and-drop, detail pages) and 6-tab DankDash (Overview, Media + LRC lyrics, Weather, Wallpapers, Wellbeing, Settings). | CoreWLAN, IOBluetooth, CoreAudio, DisplayServices, CoreBrightness, EventKit. |
| **OSD HUD** (Volume / Brightness) | Dynamic Island + floating Material 3 HUD pill that displays on level adjustments and auto-fades. | Non-intrusive floating HUD with `OSDUIHelper` suppression. |
| **Power Menu** | Material 3 dialog & popout for Lock Screen (`SACLockScreenImmediate`), Sleep, Restart, Shut Down, and Log Out. | Native login framework & System Events Apple events. |
| **In-Shell Toasts & Desktop Widgets** | Floating toast queue and optional `.desktopIconWindow`-level M3 desktop clock/telemetry card (`DesktopWidgets`). | Respects Do Not Disturb and Reduced Motion. |
| **Configuration** (`settings.json`) | `~/Library/Application Support/DMS/settings.json` (migrates legacy `config.json`). | Atomic saves, `$include` fragment composition, hot-reload via `DispatchSourceFileSystemObject`. |
| **IPC / CLI / URL Scheme** (`dms.sock`, `dms://`) | `0600` local Unix socket (`dms` CLI) and allowlisted `dms://` UI-navigation URL scheme. | Destructive/state-mutating actions scoped strictly to local socket IPC. |
