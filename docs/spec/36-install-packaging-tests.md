# 36 — Installation, Packaging, Daemon Services & Test Architecture (`PACK`)

## 0. Coverage Manifest
- `Makefile` (6,922 bytes) — Root build orchestrator providing unified build targets (`make build`, `dev`, `run`, `clean`, `lint-qml`, `test-qml`, `install-bin`, `install-desktop`, `install-systemd`, `uninstall`).
- `flake.nix` (10,634 bytes) & `flake.lock` — Nix flake definition with pinned C/C++ toolchains, Qt 6.7+ QML dependencies, Go compiler, and reproducible container packaging.
- `distro/*` (11 packaging definitions: Debian/Ubuntu `.deb`, Fedora `.rpm`, openSUSE OBS, Void `xbps`, FreeBSD ports, Nix derivations).
- `.github/workflows/*` — Automated GitHub Actions CI pipeline running linters (`qmllint`, `golangci-lint`), unit tests, and multi-architecture build matrix (x86_64, aarch64).
- `quickshell/tests/*` (59 test suites, ~200 KB code) — End-to-end integration and unit testing suite executed via Node.js test runner:
  - `island-routing.test.mjs` (38 KB) & `layout-resolver.test.mjs` (18 KB)
  - `workspace-model.test.mjs` (25 KB) & `window-model.test.mjs` (14 KB)
  - `bluez-codec.test.mjs` (22 KB) & `battery-history.test.mjs` (3 KB)
  - `bar-content.test.mjs`, `bar-ipc.test.mjs`, `bar-overflow.test.mjs`
  - `settings-cc-grid.test.mjs`, `settings-dock-magnification.test.mjs`
  - `pam-stack.test.mjs`, `plugin-reload.test.mjs`, `wellbeing-model.test.mjs`
- `core/*_test.go` — Go unit test suite (`router_test.go`, `subscribe_test.go`, `manager_test.go`, `commands_doctor_test.go`, `commands_config_test.go`).

---

## 1. Purpose & Packaging Strategy
This specification establishes the build system, distribution packaging, daemon life-cycle management, and automated test harness required for continuous delivery and zero-regression maintenance.

Key user-visible behaviors include:
1. **One-Command Build & Run**:
   - Compiling the entire shell and CLI from source with a single command (`./build.sh` or `swift build -c release`).
2. **Native macOS Application Bundle (`DankMaterialShell.app`)**:
   - Generates a fully signed, self-contained macOS `.app` bundle containing `DMS.app`, helper daemons, asset icons, sound packs, and the `dms` CLI binary in `Contents/MacOS/`.
3. **LaunchAgent Daemon Management**:
   - Registers a `launchd` user agent (`~/Library/LaunchAgents/io.github.jonasnowak.dms.plist`) for automatic startup on login, auto-restart on unexpected crashes, and clean signal trapping on logout.
4. **Automated Test Validation**:
   - Comprehensive test suite covering state transitions, layout mathematics, IPC socket serialization, and UI model updates.

---

## 2. macOS Application Structure & Assets
```
DankMaterialShell.app/
└── Contents/
    ├── Info.plist                     # Bundle metadata, URL schemes (dms://)
    ├── MacOS/
    │   ├── DMS                        # Main Cocoa shell executable
    │   └── dms                        # Standalone CLI executable
    ├── Resources/
    │   ├── AppIcon.icns               # High-DPI macOS icon
    │   ├── Sounds/                    # Material 3 sound theme chimes
    │   ├── Fonts/                     # JetBrains Mono, Inter TTF
    │   └── Assets.car                 # Compiled asset catalog
    └── Library/
        └── LaunchAgents/
            └── io.github.dms.plist    # launchd background service
```

---

## 3. launchd Service Configuration (`LaunchAgent`)
Path: `~/Library/LaunchAgents/io.github.jonasnowak.dms.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>io.github.jonasnowak.dms</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/DankMaterialShell.app/Contents/MacOS/DMS</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/dms.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/dms.stderr.log</string>
</dict>
</plist>
```

---

## 4. Test Suite Architecture
- **Unit Tests**:
  - `DMSCoreTests`: Configuration decoding, IPC command parsing, M3 dynamic palette generation, clipboard store hashing.
- **Integration Tests**:
  - `DMSShellTests`: Multi-window panel life cycle, hotkey registration, socket IPC command dispatch, screen layout geometry calculations.
- **UI Snapshot Tests**:
  - Snapshot assertions verifying pixel-perfect SwiftUI view rendering against Material Design 3 baselines.

---

## 5. Port Audit
| Upstream File / Subsystem | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| Packaging & Distribution | Partially Insp. | **Partial** | Port has basic `build.sh` creating `.app` bundle, but lacks Homebrew Formula, DMG generation, and LaunchAgent installer. |
| launchd Daemon Integration | Absent | **Missing (0%)** | No `io.github.dms.plist` or `dms service install/start/stop` commands. |
| Test Coverage (59 suites in upstream vs 1 in port) | Minimal | **Major Gap** | Upstream has 59 automated test suites; port has only 1 basic 259-line test file (`DMSCoreTests.swift`). |

---

## 6. Reimplementation Checklist
- [ ] Create `scripts/install-launchagent.sh` and CLI `dms service [install|enable|disable|status]`.
- [ ] Create Homebrew Cask / Formula recipe for effortless installation (`brew install dms-shell`).
- [ ] Add `.dmg` disk image creation script with background artwork and `/Applications` symlink.
- [ ] Expand Swift test suite from 1 file to dedicated test targets: `DMSCoreTests`, `DMSIPCTests`, `DMSLayoutTests`, and `DMSSettingsTests`.
- [ ] Set up GitHub Actions CI workflow building Swift package and running `swift test` on macOS-14 (Apple Silicon) and macOS-13 (Intel).
