# DankMaterialShell (DMS) for macOS: Port Plan

This repository (`dms-shell`) is the native macOS edition of
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) (`AvengeMedia/DankMaterialShell`).
The upstream project is a modern, unified desktop shell built for Wayland compositors (Niri, Hyprland, Sway, etc.)
using Quickshell (QtQuick/QML) and Go.

**Quickshell and Wayland protocols do not run on macOS.**
This project is an architectural port and reconstruction: same Material Design 3 visual language,
same components (DankBar, DLauncherV2, Control Center, OSD, Power Menu), same dynamic wallpaper theming,
rebuilt as a native Swift 6 macOS application (AppKit + SwiftUI).

## 1. Principles

- **Material Design 3 (Material You):** Full M3 color tokens, dynamic tonal generation from desktop wallpaper, pill-shaped action buttons, rounded container cards, and elevation surfaces.
- **Zero Idle CPU (~0%):** Purely event-driven using system notifications and run-loop sources (`NSWorkspace`, `CoreAudio`, `CoreWLAN`, `IOKit`, `DisplayServices`). No polling timers.
- **KISS & Self-Contained:** Zero third-party dependencies. Pure Swift Package Manager, no CocoaPods or Carthage.
- **macOS Native:** Public APIs first (`NSPanel`, `CoreWLAN`, `IOBluetooth`, `CoreAudio`, `CoreImage`). Private APIs only via dynamic lookup (`dlopen`/`dlsym`) with graceful fallbacks.
- **Modular Architecture:**
  - `DMSCore`: UI-free logic, M3 theme generator, config, fuzzy app search catalog, calculator, telemetry models, and IPC command parser. Fully unit-tested.
  - `DMS`: Application target with `ShellPanel`, `DankBar`, `ControlCenter`, `DLauncherV2`, `OSD`, `PowerMenu`, `ToastCenter`, and system services.

## 2. Feature Mapping

| Upstream DMS (Wayland / Linux) | macOS Implementation | Technical Notes |
| :--- | :--- | :--- |
| **DankBar / DBar** (`PanelWindow`, layer-shell) | `ShellPanel` (`NSPanel`, `.statusBar` level, `canJoinAllSpaces`, borderless, non-activating). Configurable top or bottom position. | Smooth auto-hide option with hover tracking. Dock coexistence or auto-hide. |
| **Apps Dock / Running Apps** (`ToplevelManager`) | Pinned apps + running apps from `NSWorkspace` notifications (`didLaunchApplication`, `didTerminateApplication`, `didActivateApplication`). | Context menu for Pin/Unpin, Hide, Quit. Active app dot indicators. |
| **Dynamic M3 Theming** (Matugen / `dank16`) | `DynamicThemeGenerator` in `DMSCore` sampling `NSWorkspace.shared.desktopImageURL` with `CoreImage`. | Generates full M3 dark & light palettes (Primary, Secondary, Tertiary, Surface, Containers, Outline, Errors). |
| **Stock M3 Themes** (`StockThemes.js`) | Purple (default), Blue, Green, Orange, Red, Yellow, Neutral. | Instant switching and persistence. |
| **DLauncherV2** (Spotlight App Launcher) | Centered overlay `ShellPanel` with fuzzy app catalog, quick math evaluator (`2+2`, `sqrt(144)`), and keyboard navigation. | Global hotkey via Carbon `RegisterEventHotKey` (default `⌥Space`). |
| **Control Center** (`ControlCenterContent`) | Material 3 Quick Settings popout anchored to the bar: Wi-Fi, Bluetooth, Dark/Light Mode, DND, Night Shift, Screen Capture, System Settings, Volume & Brightness sliders. | CoreWLAN, IOBluetooth, CoreAudio, DisplayServices, CoreBrightness. |
| **OSD HUD** (Volume / Brightness) | Floating Material 3 HUD pill that displays on level adjustments and auto-fades. | Non-intrusive floating HUD. |
| **Power Menu** | Material 3 dialog for Lock Screen, Sleep, Restart, Shut Down, and Log Out. | System Events Apple events & `pmset`. |
| **In-Shell Toasts** | Floating toast notifications for theme changes, screenshot saves, and battery alerts. | Queue-based toast manager. |
| **Configuration** (`config.json`) | `~/Library/Application Support/DMS/config.json`. | Hot-reload via `DispatchSourceFileSystemObject` file watcher. |
| **IPC / URL Scheme** (`dms://`) | Registered URL scheme: `dms://toggleLauncher`, `dms://toggleControlCenter`, `dms://powerMenu`, `dms://setTheme?name=...`. | Triggerable from Terminal (`open -g "dms://..."`), Raycast, or Shortcuts. |
