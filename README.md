# DankMaterialShell (DMS) for macOS

A modern, native desktop shell for macOS inspired by Google's **Material Design 3 (Material You)**, ported from [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell).

Built with Swift 6, AppKit, and SwiftUI with a focus on performance, aesthetics, and native macOS integration.

## Features

### DankBar (Status & Dock Bar)
- **Material 3 Design:** Rounded pill chips, elevation surfaces, and fluid animations.
- **Top or Bottom Docking:** Position as a top status bar or a bottom shelf/dock.
- **Launcher Button:** DMS pill button to toggle the Spotlight-style app launcher.
- **Active App Indicator:** Live display of the currently focused application name and icon.
- **Apps Dock / Taskbar:** Pinned and running applications with live running indicators, click-to-activate, and context menus (Pin/Unpin, Hide, Quit).
- **Dynamic Island / Clock:** Real-time clock with date tooltip and status pills.
- **Hardware Telemetry:** Real-time CPU usage, RAM usage, and battery indicators.
- **Quick Controls:** Direct toggles for Control Center, Power Menu, and Audio.

### DLauncherV2 (Spotlight App Launcher)
- **Spotlight-Style Search:** Centered overlay with instant fuzzy search across `/Applications`, `/System/Applications`, and `~/Applications`.
- **Integrated Calculator:** Evaluates mathematical expressions directly in the search bar (e.g. `24 * 1.15`, `sqrt(256)`, `1024 / 8`).
- **Keyboard Navigation:** Arrow keys to navigate, Enter to launch, Escape to dismiss.
- **Global Hotkey:** Press `⌥Space` (Option + Space) anywhere to toggle the launcher.

### Material 3 Control Center
- **Quick Action Tiles:** Rounded toggle chips for:
  - Wi-Fi (CoreWLAN status & toggle)
  - Bluetooth (IOBluetooth status & toggle)
  - Dark / Light Mode
  - Do Not Disturb (Focus)
  - Night Shift (CoreBrightness / `CBBlueLightClient`)
  - Screen Capture (`screencapture -i`)
  - macOS System Settings shortcut
- **Material 3 Sliders:**
  - Audio Volume with audio output device selector (CoreAudio)
  - Display Brightness (`DisplayServices`)
- **Theme Switcher:** Live switching between dynamic wallpaper-extracted theme and stock M3 themes (Purple, Blue, Green, Orange, Red, Yellow, Neutral).

### Dynamic Wallpaper Theming (Material You)
- Automatically samples the current desktop wallpaper using `CoreImage`.
- Mathematically generates full Material 3 tonal palettes (Primary, Secondary, Tertiary, Surface, Container, Outline, Error tones) for both Dark and Light modes.
- Updates the shell in real time whenever the wallpaper or display appearance changes.

### On-Screen Display (OSD) & Power Menu
- **OSD Pill:** Minimal floating Material 3 HUD for volume and brightness feedback.
- **Power Menu:** Quick dialog for Lock Screen, Sleep, Restart, Shut Down, and Log Out.

## Building and Running

### Requirements
- macOS 14+ (macOS 26+ compatible)
- Apple Command Line Tools or Xcode

### Build & Run
```bash
./build.sh
```

### Run Tests
```bash
./test.sh
```

## Configuration

Settings are stored at:
`~/Library/Application Support/DMS/config.json`

The file is automatically created with defaults on first launch and **hot-reloads immediately** upon saving changes:

```json
{
  "theme": "purple",
  "isLightMode": false,
  "barPosition": "bottom",
  "barAutoHide": false,
  "barTransparent": false,
  "showDock": true,
  "showTelemetry": true,
  "launcherHotkey": true,
  "pinnedApps": [
    "com.apple.Terminal",
    "com.apple.Safari",
    "com.apple.finder"
  ]
}
```

## URL Scheme

DMS registers the `dms://` URL scheme for system integration and scriptability:
- `open -g dms://toggleLauncher` - Toggle the DLauncherV2 overlay
- `open -g dms://toggleControlCenter` - Toggle the Control Center popout
- `open -g dms://powerMenu` - Open the Power Menu dialog
- `open -g "dms://setTheme?name=dynamic"` - Switch to dynamic wallpaper theme
- `open -g "dms://setTheme?name=blue"` - Switch to stock Blue theme
- `open -g dms://toggleThemeMode` - Toggle between Dark and Light mode
- `open -g dms://screenshot` - Trigger interactive screen capture
- `open -g dms://reloadConfig` - Force reload configuration from disk
