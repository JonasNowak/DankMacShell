# 34 — CLI & Automation Specification (`CLI`)

## 0. Coverage Manifest
- `core/cmd/dms/main.go` (1,200 lines) & `commands_root.go` (400 lines) — Master Cobra command router, root flags (`--socket`, `--timeout`, `--json`, `--verbose`), and execution context.
- `core/cmd/dms/shell.go` (8,753 bytes) & `shellapp.go` (2,944 bytes) — Interactive DMS REPL shell (`dms shell`) with prompt, tab-completion, command history, and stateful socket session.
- `core/cmd/dms/commands_dmenu.go` (18,273 bytes) & `commands_dmenu_test.go` — Complete `dmenu` / `rofi` drop-in replacement (`dms dmenu`) reading line items from stdin, displaying fuzzy-searchable launcher modal, and emitting selected item to stdout.
- `core/cmd/dms/commands_doctor.go` (62,859 bytes) & `commands_doctor_test.go` — Exhaustive system health diagnostic suite:
  - Compositor & display server health
  - Screen resolution and refresh rates
  - Font availability & rendering validation (`commands_doctor_fonts_test.go`)
  - Audio daemon (PipeWire/CoreAudio) connectivity
  - Bluetooth & Network status
  - Socket permissions and IPC latency benchmarks
- `core/cmd/dms/commands_config.go` (8,642 bytes) & `commands_config_test.go` — CLI configuration inspector: `dms config get <key>`, `set <key> <val>`, `reset [key]`, `dump`, `diff`, and schema validation.
- `core/cmd/dms/commands_features.go` (15,212 bytes) — Feature flag inspector and hardware capability reporter.
- `core/cmd/dms/commands_clipboard.go` (25,231 bytes) — Deep clipboard commands (`copy`, `paste`, `list`, `pin`, `delete`, `clear`, `edit`, `wipe`, `monitor`).
- `core/cmd/dms/commands_screenshot.go` (19,041 bytes) — Screenshot capture engine (`area`, `screen`, `window`, formats, quality, copy/save).
- `core/cmd/dms/commands_notify.go` (8,103 bytes) — Full `notify-send` compliant notification publisher.
- `core/cmd/dms/commands_colorpicker.go` (4,846 bytes) — Interactive screen eyedropper CLI.
- `core/cmd/dms/commands_qr.go` (8,074 bytes) — QR code generator CLI with ANSI terminal rendering and PNG export.
- `core/cmd/dms/commands_system.go` (10,623 bytes) — Power and system state transitions (`lock`, `suspend`, `reboot`, `poweroff`).
- `core/cmd/dms/commands_keybinds.go` (11,814 bytes) — Hotkey listing, rebinding, and conflict checking.
- `core/cmd/dms/commands_windowrules.go` (10,292 bytes) — Window placement, opacity, and workspace assignment rules.
- `core/cmd/dms/commands_setup.go` (16,395 bytes) & `commands_setup_headless.go` — Interactive first-run wizard.
- `core/cmd/dms/commands_matugen.go` (9,133 bytes) & `commands_dank16.go` (4,664 bytes) — Material theme generator and 16-color ANSI palette generator.
- `core/cmd/dms/server_client.go` (3,284 bytes) — Low-level Unix domain socket client with connection pooling and timeouts.

---

## 1. Purpose & User-Visible Behavior
The `dms` CLI is the command-line command center of the desktop environment. It serves as both an administrative tool for users and a high-performance IPC bridge for script automation, terminal workflows, window managers, and third-party integrations.

Key user-visible behaviors include:
1. **Interactive Shell Mode (`dms shell`)**:
   - Launches an interactive terminal prompt (`dms> `) with tab-completion for all shell actions, live status queries, and instant hot-reloading.
2. **Standard dmenu Filter (`dms dmenu`)**:
   - Acts as a drop-in dmenu replacement: pipe any newline-delimited list via stdin (e.g. `cat file.txt | dms dmenu`), display the high-fidelity DMS launcher modal, and return the chosen line to stdout.
3. **Comprehensive Doctor Diagnostics (`dms doctor`)**:
   - Scans system dependencies, permissions, font metrics, audio subsystems, display configurations, and socket latency.
   - Outputs color-coded pass/fail tables with actionable troubleshooting tips.
4. **Scriptable Configuration & Theme Engine**:
   - Scriptable reading and writing of any of the 427 settings keys (`dms config set bar.edge bottom`).
   - Generation of matching terminal and editor themes directly from the CLI (`dms matugen run`).

---

## 2. CLI Architecture & Command Matrix
```
dms
├── run / stop / restart / status
├── doctor
├── shell                     [Interactive REPL]
├── dmenu                     [STDIN -> UI -> STDOUT]
├── config [get|set|reset|dump|diff]
├── features [list|toggle]
├── clipboard [copy|paste|list|pin|delete|clear|edit|wipe]
├── screenshot [area|screen|window]
├── color pick [--hex|--rgb|--hsl]
├── qr [text] [--wifi-ssid]
├── notify <summary> [body]
├── theme [get|set|mode|seed]
├── matugen [run|template]
├── bar [list|toggle|reveal|hide]
├── dock [list|toggle|reveal|hide]
├── island [toggle|open|close|move|center]
├── dash [toggle|openTab]
├── controlcenter [toggle|openSection]
├── launcher [toggle|query]
├── keybinds [list|set]
├── windowrules [list|add|remove]
├── system [lock|suspend|reboot|poweroff|info]
└── audio / mic / brightness / inhibit / mpris
```

---

## 3. Input & Output Formats
- **Standard Flag Conventions**:
  - `--json`: Format all command output as clean, parseable JSON.
  - `--quiet` / `-q`: Suppress informational banners; output only results or exit codes.
  - `--timeout <ms>`: Socket connection and response timeout (default: 2000 ms).
  - `--socket <path>`: Override Unix domain socket location.
- **Exit Codes**:
  - `0`: Success.
  - `1`: General error / command failure.
  - `2`: Invalid arguments or flags.
  - `3`: IPC daemon unreachable (DMS not running).
  - `4`: Action timed out.

---

## 4. Configuration Schema
CLI commands directly manipulate `SettingsData` via socket IPC.

---

## 5. IPC / CLI API
All CLI commands map to discrete IPC messages dispatched over the Unix domain socket (`/tmp/dms.sock` or `~/Library/Application Support/DMS/dms.sock`).

---

## 6. macOS Mapping
- **Binary Target**: Standalone Swift executable `dms` installed to `/usr/local/bin/dms` or `~/.local/bin/dms`.
- **Command Argument Parser**: Utilize Apple's `swift-argument-parser` library (`ParsableCommand`) for type-safe subcommands, flags, option validation, and automatic help generation.
- **dmenu Emulation**:
  - `dms dmenu` reads `FileHandle.standardInput`, dispatches an IPC modal open request to `DMS.app` with the candidate lines, and blocks until the selection response is received over the socket, then writes to `FileHandle.standardOutput`.

---

## 7. Port Audit
| Upstream File / Subsystem | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `commands_dmenu.go` (18,273 bytes) | Absent | **Missing (0%)** | `dms dmenu` stdin/stdout filter mode is completely absent in the port. |
| `shell.go` (Interactive REPL) | Absent | **Missing (0%)** | `dms shell` interactive session is completely absent. |
| `commands_doctor.go` (62,859 bytes) | Partially Insp. | **Major Gap** | Port has a tiny 20-line `doctor` print routine checking only 3 hardcoded file paths. |
| `commands_config.go` (JSON path get/set/diff) | Partially Insp. | **Major Gap** | Port only allows dumping the entire raw JSON; lacks deep key get/set, validation, and diffing. |
| `commands_windowrules.go`, `commands_features.go`, `commands_matugen.go` | Absent | **Missing (0%)** | Window rules CLI, feature toggles, and matugen theme generator CLI commands are completely absent. |

---

## 8. Reimplementation Checklist
- [ ] Migrate `DMSCLI` to `swift-argument-parser` for robust subcommand structure and validation.
- [ ] Implement `dms dmenu` pipe mode bridging stdin items to the macOS launcher modal and returning the selection to stdout.
- [ ] Implement `dms shell` interactive REPL with command completion.
- [ ] Expand `dms doctor` into a thorough diagnostics tool checking macOS permissions (Accessibility, Screen Recording), socket latency, and display topology.
- [ ] Implement `dms config [get|set|reset|diff]` supporting dot-separated key paths (`bar.segments.center`).
- [ ] Add `dms screenshot`, `dms color pick`, `dms qr`, and `dms notify` subcommands.
