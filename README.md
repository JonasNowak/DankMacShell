<h1 align="center">DankMacShell</h1>

<p align="center">
  <em>A Material 3 shell for macOS — the tiling window-manager adjacent shell experience, natively on your Mac.</em>
</p>

<p align="center">
  <a href="https://github.com/JonasNowak/DankMacShell/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/JonasNowak/DankMacShell/build.yml?branch=main&style=for-the-badge&label=build" alt="CI build status"></a>
  <a href="https://github.com/JonasNowak/DankMacShell/releases"><img src="https://img.shields.io/github/v/release/JonasNowak/DankMacShell?style=for-the-badge&label=release" alt="Latest release"></a>
  <a href="https://github.com/JonasNowak/DankMacShell/blob/main/LICENSE"><img src="https://img.shields.io/github/license/JonasNowak/DankMacShell?style=for-the-badge&color=2ea44f" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B%20(App%2026%2B)-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-6-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/OmniWM-optional-7A5AF8?style=for-the-badge" alt="Optional OmniWM integration">
</p>

<p align="center">
  <img src="docs/dankmacshell-screenshot.jpg" width="1100" alt="DankMacShell desktop screenshot">
</p>

---

## 📑 Contents

- [What is DankMacShell?](#what-is-dankmacshell)
- [Features](#features)
- [SymbianOS Plugin (WIP)](#symbianos-plugin-wip)
- [Quick Start](#quick-start)
- [Global Hotkeys](#global-hotkeys)
- [DMS CLI (`dms`)](#dms-cli)
- [Terminal Theme Sync & home-manager](#terminal-themes)
- [Configuration](#configuration)
- [URL Scheme (`dms://`)](#url-scheme)
- [License](#license)

<a id="what-is-dankmacshell"></a>

## ✨ What is DankMacShell?

This is built as an adaptation of [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) for macOS. This project has not been endorsed nor is it related to DankMaterialShell or AvengeMedia.

DankMacShell is a native Swift/SwiftUI shell for macOS with optional [OmniWM](https://github.com/OmniNull/OmniWM) integration (and native SkyLight Spaces fallback). It adds the features that make macOS feel more akin to the typical WM experience on Linux systems.

> [!WARNING]
> Everything in this repository will change, some LLM-written parts will be stripped out. There are major bugs.

<a id="features"></a>

## 🧩 Features

At a glance:

| Component | Hotkey | TL;DR |
| --- | --- | --- |
| DankBar | — | Multi-edge Material 3 status bar |
| Dynamic Island (`DIsland`) | — | Spring-animated notch / floating pill |
| DLauncherV2 | `⌥Space` | App launcher, calculator, file search & `dmenu` |
| DankDash | `⌥D` | Dashboard: weather, calendar, media, lyrics, wellbeing |
| Control Center | — | Drag-and-drop grid tiles, sliders & detail pages |
| Native OSD | — | Floating volume/brightness pill with bezel suppression |
| Wallpaper Picker & Sync | `⌃⌥⇧⌘W` | Slanted carousel switcher & OmniWM border sync |
| Notepad | `⌥N` | Multi-note window with Markdown preview & Find/Replace |
| Clipboard History | `⌥V` | Searchable clipboard store with sensitive filtering |
| ProcessList | — | Activity-monitor-style task manager |
| ColorPicker | — | Screen eyedropper (`NSColorSampler`) |
| QR Generator | — | QR codes from text, URLs, or current Wi-Fi |
| Keybinds Cheatsheet | — | Searchable shortcuts reference dialog |
| Plugins & Applets | — | Built-in registry, lockfile (`plugins.lock.json`) & bar toggles |
| Settings | — | 20-tab configuration window across 7 categories |
| Dynamic Theming | — | Rust-backed M3 Expressive palettes from wallpaper or seed |

### 📊 1. DankBar (Multi-Edge Status Bar)
- **Material 3 Expressive Design:** Segmented pill chips, dynamic tonal surfaces (`surface`, `glass`, `transparent`, `island`), and corner styles (`capsule`, `gothic` concave fillets, `rounded`, `square`).
- **4-Edge & Multi-Instance Layout:** Position on `top`, `bottom`, `left`, or `right` screen edges across multiple monitors via `barConfigs`.
- **Notch Awareness & Smart Auto-Hide:** Automatic safe-zone splitting around MacBook hardware notches (or simulated notches), fullscreen/occlusion-aware `smartAutoHide`, and hover reveal.
- **35+ Catalog Widgets:** Launcher button, virtual workspace switcher (`omniwmctl subscribe` + SkyLight native fallback), running & focused app pills, clock, media controls, live LRC lyric ticker (`mediaLyricLine`), audio visualizer, weather, CPU/RAM/GPU/disk/network monitors, CPU/GPU temperatures, battery, Wi-Fi, volume, microphone, idle inhibitor, keyboard layout, caps lock, privacy indicator, VPN, system updates, system tray, notification center, control center, power menu, and applet triggers (Notepad, Clipboard, Color Picker, Symbian).

### 🏝️ 2. Dynamic Island (`DIsland`) & Floating OSD
- **Spring-Physics Surface:** 8-DOF spring solver supporting `mainBar`, `notch`, `float`, and `off` modes with concave Gothic fillets and hover expansion.
- **Live Compact & Expanded Activities:** Inline pills and expandable panels for Home (CPU/RAM/Battery), Media (with lyrics), Weather, Audio/OSD, Notifications, Clipboard, Power Menu, Control Center, and DankDash.
- **Native OSD & Media Key Interception:** Replaces the macOS system volume/brightness bezel (`SystemOSDManager` suspending `OSDUIHelper` + `MediaKeyInterceptor`) using active `CGEventTap` swallowing (Accessibility / Device Control), passive Input Monitoring, or a zero-permission CoreAudio fallback.

### 🔍 3. DLauncherV2 (Launcher, Calculator, File Search & `dmenu`)
- **List & Grid/Tile Views:** Switchable list or 5-column tile layout with frecency scoring (`LauncherFrecencyStore`), running/hidden state badges, and configurable placement (`center` or Dynamic Island notch-attached).
- **Integrated Calculator & Web Fallback:** Evaluates math expressions inline (`24 * 60`, `sqrt(144)`, hex literals, trig/log/rounding functions) and falls back to web search (`google`, `duckduckgo`, `bing`, `kagi`).
- **File Search:** Prefix queries with `file:`, `files:`, `f:`, `/`, or `~` to search via `DankSearchClient` with timeout-protected Spotlight (`mdfind`) and shallow directory fallbacks.
- **Action Panel (`Tab`) & App Editor (`AppEditView`):** Focus, unhide (foreground or background), hide, quit, reveal in Finder, copy bundle ID/path, or edit per-app display names, launch arguments, tags, and launcher visibility (`apps.perApp`).
- **Scriptable `dmenu` Mode:** Powers `dms dmenu` to filter arbitrary stdin lines in the launcher UI.
- **Global Hotkey:** Press `⌥Space` (customizable) anywhere to toggle the launcher.

### 📈 4. DankDash (Dashboard Overview)
Six dedicated tabs (`Overview`, `Media`, `Wallpapers`, `Weather`, `Wellbeing`, `Settings`):
- **Overview Grid:** Live clock & uptime, CPU/thermal/RAM vertical gauges, weather summary, user host card, interactive month calendar, wellbeing summary, and circular media card with organic visualizer ring.
- **Media Hub & Synchronized Lyrics:** Universal playback detection and seeking for Apple Music, Spotify, VLC, and MediaRemote/web players (`media-bridge.swift`), switchable `Bento` and `Material` layouts, squiggly waveform scrubber, and 10 Hz synchronized LRC lyrics fetched from LRCLIB with LRU + disk caching and timing offset (`lyricsOffsetMs`).
- **Weather v2 & Celestial Engine:** Open-Meteo REST API forecasts (current, 24h hourly, and 7-day daily), IP geolocation or city/coordinate lookup, sunrise/sunset sky arc, moon phases, pressure, UV index, and precipitation probability.
- **Digital Wellbeing:** Local screen-time tracking synchronized with macOS Screen Time (`ScreenTimeAgent`), active app breakdown, daily app quotas, 7-day comparison bar chart, and 92-day retention pruning.
- **Global Hotkey:** Press `⌥D` (customizable) anywhere to toggle DankDash.

### 🎛️ 5. Material 3 Control Center
- **Modular Drag-and-Drop Grid:** Rearrange, resize (`1x1`, `2x1`, `4x1`), add/remove tiles via the Tile Library sheet with a 50-step undo/redo stack.
- **12 Expressive Avatar Shapes:** Cycle user avatar masks (`circle`, `cookie4`, `cookie7`, `cookie12`, `clover4`, `clover8`, `sunny`, `pentagon`, `arch`, `slanted`, `gem`, `square`) via `MaterialShapes`.
- **6 Expandable Detail Pages:** Dedicated detail views for Wi-Fi (`CoreWLAN`), Bluetooth (`IOBluetooth`), Audio (`CoreAudio` output/input device switching), Battery, Do Not Disturb (timed focus presets), and Idle Inhibit (caffeinate presets).
- **Quick Tiles & Dual Sliders:** Master Volume and Display Brightness (`DisplayServices` dynamic lookup) sliders, Night Shift (`CBBlueLightClient`), Dark/Light mode, Color Picker, Disk Storage, and Theme switcher.

### 🖼️ 6. Wallpaper Browser, Slanted Switcher & OmniWM Sync
- **Wallpapers Tab & Slanted Picker (`⌃⌥⇧⌘W`):** Browse `~/Pictures`, `/System/Library/Desktop Pictures`, custom folders, and gradient presets in DankDash/Settings or in the slanted slice carousel (`F` folder filter, `R` shuffle, `Esc` revert).
- **OmniWM Window Border Sync:** Surgically updates `~/.config/omniwm/settings.toml` (creating a `.dms-backup`) with Material 3 gradient colors (`dms omniwm ...`).

### 📝 7. Notepad (Scratchpad & Markdown Window)
- **Standard macOS Window:** Resizable, movable, and tileable titled window (`⌘W` to close) with multi-note sidebar and word/character counters.
- **Markdown Live Preview:** Cycle between editor-only (`none`), side-by-side (`split`), and rendered (`full`) preview modes (`notepadPreviewMode`).
- **Find & Replace (`⌘F`):** Case-sensitive toggle (`Aa`), next/previous match jumping, single replace, and replace-all.
- **Persistent Storage & Hotkey:** Saved in `~/Library/Application Support/DMS/notes.json`; press `⌥N` (customizable) anywhere to toggle.

### 📋 8. Clipboard History Manager
- **Pasteboard Store & Auto-Paste:** Searchable text/URL history in `~/Library/Application Support/DMS/clipboard_history.json` (default `clipboardMaxItems: 200`), keyboard navigation (`↑↓`, `↵`, `Esc`), and optional synthetic `⌘V` auto-paste into the previous app (`clipboardAutoPaste`, requires Accessibility).
- **Sensitive-Content Filtering:** Automatically ignores concealed, transient, and auto-generated pasteboard items (`org.nspasteboard.ConcealedType`, `AutoGeneratedType`, `TransientType`) as well as copies from 1Password, Bitwarden, and KeePassXC (`clipboardFilterSensitive`).
- **Global Hotkey:** Press `⌥V` (customizable) anywhere to toggle.

### ⚙️ 9. ProcessList, Power Menu, ColorPicker, QR Generator & Keybinds
- **ProcessList:** Live PID, CPU %, RAM (MB), and user listing with search filtering, CPU/RAM sorting, and `SIGTERM`/`SIGKILL` termination.
- **Power Menu & Toasts:** Quick session actions (`Lock`, `Sleep`, `Restart`, `Shut Down`, `Log Out`) and floating M3 status toasts.
- **ColorPicker:** Native `NSColorSampler` pixel eyedropper with HEX, RGB, and HSL click-to-copy rows and recent swatches.
- **QR Generator:** Real-time `CIQRCodeGenerator` codes with one-click current Wi-Fi QR formatting, copy, and PNG export.
- **Keybinds Cheatsheet:** Searchable reference modal displaying configured shell and macOS shortcuts.

### 🧩 10. Plugins, Applets & 20-Tab Settings Window
- **Plugins & Applets:** Browse the plugin registry, install/enable/disable plugins, lock/restore `plugins.lock.json`, and toggle DankBar applets.
- **Settings Window:** Searchable sidebar organizing **20 tabs across 7 categories** (*Personalization*, *Primary Bar*, *Widgets & Notifications*, *Keyboard Shortcuts*, *Power & Sleep*, *Plugins*, *About*) with live subsystem diagnostics.

### 🌈 11. Dynamic & Expressive Theming
- Powered by the Rust-backed **`DankThemeEngine`** (`dank-theme-engine`) and **`MaterialMacLibrary`** (`MaterialTokens` / `MaterialShapes`).
- Generates full dark and light Material 3 tonal palettes from the active desktop wallpaper or a custom hex seed using selectable Matugen schemes (`tonalSpot`, `vibrant`, `expressive`, `fidelity`, `neutral`, `monochrome`) and contrast levels.
- Includes **7 stock themes** (`purple`, `blue`, `green`, `orange`, `red`, `yellow`, `neutral`) and **6 community themes** (`catppuccin-mocha`, `catppuccin-latte`, `nord`, `gruvbox`, `tokyo-night`, `everforest`).

<a id="symbianos-plugin-wip"></a>

## 📱 SymbianOS Plugin — Nokia Belle USB Sync (WIP)

DankMacShell ships a standalone, crash-isolated companion app — `dms-symbian` (bundled inside `DankMacShell.app/Contents/MacOS/` and installed to `~/.local/bin/dms-symbian`) — for syncing Nokia Belle / Symbian OS phones (like the Nokia C7-00) over USB Mass Storage mode. This shipped with **v0.5.1, the "hello hello belle update"**.

Quick feature overview:

- **Device Overview:** Live device hero card with the real Nokia C7 photo, firmware (Symbian OS v9.5 / Belle Refresh), drive letter, 8 GB mass memory, 3.5" AMOLED display and USB 2.0 High Speed badges.
- **MP3 Sync:** Scan local music folders and push tracks to the phone over USB mass storage, with live on-phone track counts.
- **App Installer:** Stage `.sis` / `.sisx` packages onto the phone's install drive for one-tap installation on the device.
- **Storage & Tools:** Storage overview by category (Music, Photos & Video, Apps (SISX), System, Other), dotfile cleanup, and safe eject.
- **DankBar Widget & CLI:** Dedicated Symbian pill in DankBar (`showSymbianApplet`) and `dms symbian` CLI commands (`open`, `status`, `sync`, `install`, `clean`, `eject`).

<p align="center">
  <img src="docs/symbian-usb-sync.png" width="1100" alt="Nokia Belle USB Sync window on macOS">
</p>

> [!NOTE]
> The SymbianOS plugin is a work in progress (WIP) — expect rough edges while it matures.
>
> For all future releases, I plan to improve the SymbianOS support for Mac.

<a id="quick-start"></a>

## 🚀 Quick Start

### 🍺 1. Homebrew (`brew` / `brew services` / `Brewfile`)

Install the full **DankMacShell** stack (`DankMacShell.app`, `dms`, `dms-symbian`, `dms-gop` / `dgop`, and `dank-theme-engine` / `dte`) via the built-in tap:

```bash
brew tap jonasnowak/dankmac https://github.com/JonasNowak/DankMacShell.git
brew install --cask jonasnowak/dankmac/dankmacshell
brew services start dms-gop

# Optional: persist Accessibility & Input Monitoring TCC permissions across updates
dms setup-cert
```

Or install everything and start services in one command from a checkout using [`Brewfile`](Brewfile):

```bash
brew bundle
# or: make brew
```

### ❄️ 2. Nix (`nix-darwin` / Home Manager — Single Import)

Import `github:JonasNowak/DankMacShell` to install `DankMacShell.app`, `dms`, `dms-symbian`, `dms-gop` (`dgop`), and `dank-theme-engine` (`dte`) along with their `launchd` LaunchAgents:

**`nix-darwin` (`flake.nix`):**
```nix
{
  inputs.dankmacshell.url = "github:JonasNowak/DankMacShell";

  outputs = { self, nix-darwin, dankmacshell, ... }: {
    darwinConfigurations."my-mac" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        dankmacshell.darwinModules.default
        {
          programs.dankmacshell = {
            enable = true;
            launchd.enable = true;              # Auto-start DankMacShell.app in Aqua session
            dmsGop.server.enable = true;        # Auto-start dms-gop REST API (:63484)
            themeEngine.launchd.enable = false; # Optional background `dte watch` agent
          };
        }
      ];
    };
  };
}
```

**Home Manager:**
```nix
{
  imports = [ inputs.dankmacshell.homeManagerModules.default ];

  programs.dankmacshell = {
    enable = true;
    themeEngine.targets = {
      kitty.enable = true;
      ghostty.enable = true;
      tmux.enable = true;
      neovim.enable = true;
    };
  };
}
```

### ⬇️ 3. Prebuilt DMG

Download the prebuilt `.dmg` from [Releases](https://github.com/JonasNowak/DankMacShell/releases).
Note that it does not have all features, like native OSD supression. 

### 🔨 4. Build from Source

#### Requirements
- macOS (`Package.swift` targets macOS 14+; `Support/Info.plist` currently sets `LSMinimumSystemVersion` to `26.0`)
- Apple Command Line Tools or Xcode (Swift 6 toolchain)
- Optional: [OmniWM](https://github.com/OmniNull/OmniWM) for tiling-WM workspace & border sync (DMS uses native SkyLight spaces automatically if OmniWM is not running)

#### Build & Run
```bash
./build.sh
# Or using make:
make build

# Full stack (DankMacShell + dms-gop + dte + launchd LaunchAgents):
./build.sh --with-companions --install-services
# Or:
make install-all
```
This builds all three release binaries (`DankMacShell`, `dms`, and `dms-symbian`), packages `~/Applications/DankMacShell.app` (embedding `dms`, `dms-symbian`, and `DMS_DMSSymbian.bundle`), signs with a persistent `dms-cert` identity (to preserve macOS permissions across rebuilds), installs `dms` and `dms-symbian` into `~/.local/bin/`, and launches the application.

Other build & dev commands:
```bash
./build.sh --no-launch                    # or: make build-no-launch
./build.sh --with-companions --no-launch  # also install dms-gop (dgop) and dte
./build.sh --install-services --no-launch # or: make services
./build.sh --uninstall-services           # or: make uninstall-services
./build.sh --debug --no-launch            # or: make debug
./test.sh                                 # or: make test
./scripts/create-dmg.sh [version]         # or: make dmg (outputs to dist/)
make icon                                 # regenerate AppIcon.icns from Support/appicon.svg
./build.sh --clean                        # or: make clean
```

<a id="global-hotkeys"></a>

## ⌨️ Global Hotkeys

All 5 global hotkeys are customizable in **Settings → Keyboard Shortcuts** (with `Hyper Key` `⌃⌥⇧⌘` and `Meh` presets):

| Action | Default Hotkey |
| --- | --- |
| Toggle DLauncherV2 (Spotlight launcher) | `⌥Space` |
| Toggle DankDash | `⌥D` |
| Toggle Notepad | `⌥N` |
| Toggle Clipboard History | `⌥V` |
| Toggle Slanted Wallpaper Picker | `⌃⌥⇧⌘W` (`Hyper+W`) |

<a id="dms-cli"></a>

## 🖥️ DMS CLI (`dms`)

A dedicated command-line utility is installed to `~/.local/bin/dms` for controlling the shell via Unix domain socket (`~/Library/Application Support/DMS/dms.sock`):

<details>
<summary><b>Full command reference</b></summary>

```bash
# General Management
dms start                        # Start DankMacShell app (alias: run)
dms run                          # Alias for 'dms start'
dms stop                         # Stop running DankMacShell
dms restart                      # Restart DankMacShell
dms status                       # Show running status of DMS daemon and socket
dms doctor                       # Run diagnostics check on permissions and subsystems
dms permission                   # Open Accessibility / Device Control settings to grant event swallowing
dms reload                       # Reload configuration from disk
dms version                      # Show version info

# Windows, Overlays & App Control
dms spotlight [toggle|open|close]
dms launcher [toggle|open|close]
dms dash [toggle|open|close]
dms control-center [toggle|open|close]
dms powermenu [open|lock|sleep|restart|shutdown|logout]
dms notepad [toggle|open|close|get|set <text>|append <text>]
dms clipboard [toggle|open|list|clear|copy <text>]
dms processlist [toggle|open|list|kill <pid>]
dms unhide <bundleID> [--background]
dms unhide-all [--background]
dms hide <bundleID>
dms activate <bundleID>
dms colorpicker [pick]
dms qr [text]
dms keybinds [toggle|open|close]
dms settings [toggle|open [tab]|close|get <key>|set <key> <val>|dump]

# Bar, Island & Workspaces
dms bar [reveal|hide|toggle|status|setposition <top|bottom|left|right>]
dms island [toggle|open [activity]|close|expand [activity]|collapse|media|weather|status]
dms workspace [status|switch <num>|next|prev]

# Hardware, Media, Lyrics & Weather
dms audio [status|setvolume <0-100>|increment|decrement|mute|unmute|toggle|list-devices|set-device <name>]
dms mic [status|mute|unmute|toggle]
dms brightness [get|set <0-100>|increment|decrement]
dms inhibit [toggle|enable|disable|status]
dms mpris [status|play|pause|toggle|next|prev|seek <sec>|lyrics]
dms lyrics [status|current|refresh|clear-cache|offset <ms>]
dms weather [status|refresh|location <city|lat,lon>]
dms wellbeing [status|enable|disable|toggle|sync [true|false]|open-system|check]

# Themes, Wallpapers, OmniWM, Plugins & Companion
dms theme [get|set <name>|list|toggle-mode]
dms wallpaper [get|set <path>|list|picker|next|prev|random]
dms omniwm [get|sync|mode <mode>|direction <dir>|toggle]
dms plugins [search [query]|list|install <id>|uninstall <id>|enable <id>|disable <id>|lock|restore [path]]
dms applets [list|toggle <name>]
dms danksearch [status|diagnostics|reset|search <query>]
dms symbian [open|close|toggle|status|clean|eject|install <path>|sync]
dms screenshot [region|full|window]
dms toast <info|warn|error> <message>
dms ipc call <target> <action> [args...]

# CLI Pipelines (v0.7)
dms dmenu [--prompt <text>]     # Read candidates from stdin, pick one in the launcher, print it to stdout
                                 # (exit 0 on selection, exit 1 on Esc/cancel, exit 3 if daemon unreachable)
dms listen [topic]               # Stream newline-delimited JSON events from the daemon (default topic: *)
                                 # topics: events.audio, events.battery, events.wifi, events.workspaces,
                                 #         events.media, events.theme
dms shell                        # Interactive IPC REPL (dms> prompt, history in ~/.dms_shell_history,
                                 # tab-completion over the CLI vocabulary)
```

</details>

### `dms dmenu` — scriptable picker

```bash
printf 'alpha\nbeta\ngamma\n' | dms dmenu --prompt "Pick one"
# -> shows the launcher in filter mode; the chosen line is printed to stdout
```

Candidates are staged in `~/Library/Application Support/DMS/dmenu/<requestID>.txt` and only the
path + request ID travel over the socket, so the line protocol stays intact. The daemon writes the
selection back on the same connection (and to `<requestID>.result` as a fallback).

### `dms listen` — event stream

```bash
dms listen events.audio    # prints one JSON object per line until Ctrl-C
```

### `dms shell` — interactive IPC REPL

```bash
dms shell
dms> theme get
dms> audio setvolume 50
```

`dms.sock` also accepts `SUBSCRIBE <topic>` / `UNSUBSCRIBE <topic>` and single-line REST commands (`GET /api/v1/audio/volume`, `POST /api/v1/audio/volume`, `GET|POST /api/v1/audio/sinks`, `GET /api/v1/network/wifi/scan`, `POST /api/v1/network/wifi/connect`, `GET /api/v1/bluetooth/devices`, `POST /api/v1/brightness/set`, `GET /api/v1/settings`, `POST /api/v1/settings`).

<a id="terminal-themes"></a>

## 🖥️ Terminal Theme Sync & home-manager (v0.7)

When the DMS theme changes, the shell live-exports the current palette to your terminal emulators
(master switch `terminalThemeSync`, per-emulator toggles in **Settings → Theme & Colors**; Ghostty, Kitty and
Alacritty default ON, iTerm2 OFF):

| Emulator | File written |
| --- | --- |
| Ghostty | `$XDG_CONFIG_HOME/ghostty/themes/dms` (or `~/.config/ghostty/themes/dms`) |
| Kitty | `$XDG_CONFIG_HOME/kitty/dms-theme.conf` |
| Alacritty | `$XDG_CONFIG_HOME/alacritty/dms-theme.toml` |
| iTerm2 | `~/Library/Application Support/iTerm2/DynamicProfiles/dms.json` |

Config dirs resolve via `XDG_CONFIG_HOME` when set, else `~/.config` — never hardcoded.

In addition, DMS always writes a canonical machine-readable document to
`~/Library/Application Support/DMS/theme.json` (full `ThemePalette` + `Dank16Palette` + theme name
+ dark/light flag, atomic tmp+rename write). This is the read-only interface for
home-manager / stylix-style setups.

### home-manager / Nix compatibility

DMS never writes a file that home-manager manages: before writing, each target is resolved and if
it is a symlink into `/nix/store` (read-only), that emulator is skipped with a warning in the
unified log and the remaining emulators are still exported. Instead, let home-manager own the
wrapper config and include the DMS-written file:

```nix
# kitty — home-manager owns kitty.conf, DMS owns the included theme.
# The include MUST come after any theme include so DMS colors win:
programs.kitty.extraConfig = "include dms-theme.conf";
# ~/.config/kitty/dms-theme.conf is written by DMS (not declared by home-manager)

# ghostty
programs.ghostty.settings.config-file = "themes/dms"; # DMS writes ~/.config/ghostty/themes/dms

# alacritty
programs.alacritty.settings.import = [ "dms-theme.toml" ]; # DMS writes ~/.config/alacritty/dms-theme.toml
```

Note on kitty: kitty's auto-reload watcher only watches its *top-level* config file, never
`include`d files — and under home-manager that top-level `kitty.conf` is a read-only `/nix/store`
symlink that never changes, so kitty would never reload on its own. After writing `dms-theme.conf`,
DMS therefore sends `SIGUSR1` (kitty's own config-reload signal) to every running kitty process,
and logs a warning if your `kitty.conf` does not include `dms-theme.conf`.

iTerm2 Dynamic Profiles work natively — that directory is not home-manager managed, so DMS writes
`dms.json` there directly and iTerm2 picks it up as a dynamic profile.

For stylix-style pipelines, read `~/Library/Application Support/DMS/theme.json` — it always exists
and is always writable, regardless of which emulator targets are managed.

<a id="configuration"></a>

## ⚙️ Configuration

Settings are stored at:
`~/Library/Application Support/DMS/settings.json`

*(Legacy `~/Library/Application Support/DMS/config.json` files are automatically migrated on first launch and mirrored on save. Config fragment composition via `"$include": [...]` is also supported.)*

The configuration file is automatically created with defaults (`version: 2`) on first launch and hot-reloads immediately upon disk changes:

```json
{
  "version": 2,
  "theme": "purple",
  "isLightMode": false,
  "barConfigs": [
    {
      "id": "primary-bar",
      "name": "Primary Bar",
      "position": "bottom",
      "autoHide": false,
      "smartAutoHide": false,
      "backgroundStyle": "surface",
      "cornerStyle": "gothic",
      "adaptToNotch": true
    }
  ],
  "weatherLocation": "auto",
  "weatherUnits": "celsius",
  "webSearchProvider": "google",
  "launcherAttachment": "center",
  "clipboardFilterSensitive": true,
  "clipboardAutoPaste": false,
  "clipboardMaxItems": 200,
  "notepadPreviewMode": "none",
  "enableLyrics": true,
  "mediaPlayerLayout": "bento",
  "autoThemeOmniWM": true,
  "terminalThemeSync": true,
  "terminalThemeGhostty": true,
  "terminalThemeKitty": true,
  "terminalThemeAlacritty": true,
  "terminalThemeITerm2": false
}
```

<a id="url-scheme"></a>

## 🔗 URL Scheme (`dms://`)

DMS registers the `dms://` URL scheme for system integration:
- `open -g dms://toggleLauncher` (supports `?action=open&q=...`)
- `open -g dms://dash` (supports `?tab=overview|media|wallpapers|weather|wellbeing|settings`)
- `open -g dms://toggleControlCenter`
- `open -g dms://powerMenu` (supports `?action=lock|sleep|restart|shutdown|logout`)
- `open -g dms://notepad` (`open`, `close`, `get`, `set`, `append`)
- `open -g dms://clipboard` (`open`, `list`, `clear`, `copy`)
- `open -g dms://processlist` (`open`, `list`, `kill`)
- `open -g dms://colorpicker` (`pick`)
- `open -g dms://qr` (supports `?text=...`)
- `open -g dms://keybinds`
- `open -g dms://settings` (supports `?tab=...`, `?key=...`, `?value=...`, `dump`)
- `open -g dms://bar/toggle` (`reveal`, `hide`, `setposition`)
- `open -g dms://island/toggle` (`expand?activity=home|media|notification|osd|dash|clipboard|weather`, `collapse`, `media`, `weather`)
- `open -g "dms://setTheme?name=dynamic"` (`dms://theme/list`, `dms://toggleThemeMode`)
- `open -g dms://wallpaper/picker` (`get`, `set`, `list`, `next`, `prev`, `random`)
- `open -g dms://omniwm/sync` (`get`, `mode`, `direction`, `toggle`)
- `open -g dms://mpris/play` / `open -g dms://lyrics/current`
- `open -g dms://wellbeing/status` / `open -g dms://symbian/open`
- `open -g dms://plugins/list` / `open -g dms://weather/status`
- `open -g dms://screenshot` (`region`, `full`, `window`)
- `open -g dms://reloadConfig`

<a id="license"></a>

## 📜 License

Released under the [MIT License](LICENSE) © 2026 Jonas Nowak.

---

<p align="center">
  <sub>Made with SwiftUI for macOS · Inspired by <a href="https://github.com/AvengeMedia/DankMaterialShell">DankMaterialShell</a> — not affiliated with AvengeMedia</sub>
</p>
