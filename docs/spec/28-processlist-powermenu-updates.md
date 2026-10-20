# 28 — Process List, Power Menu & System Updates Specification (`PROC`)

## 0. Coverage Manifest
- `quickshell/Modules/ProcessList/ProcessListPopout.qml` (130 lines) & `ProcessListMetrics.qml` (25 lines) — Popout window host anchoring to DankBar pill, resizable geometry, and tab navigation.
- `quickshell/Modules/ProcessList/ProcessesView.qml` (380 lines) & `ProcessRow.qml` (185 lines) — Real-time process table with live CPU%, Memory MB/%, PID, User columns, sorting chips (CPU, Mem, Name, PID), and incremental search.
- `quickshell/Modules/ProcessList/ProcessContextMenu.qml` (340 lines) — Process context menu: Terminate (`SIGTERM`), Force Kill (`SIGKILL`), Suspend (`SIGSTOP`), Resume (`SIGCONT`), Renice priority slider (-20 to 19), Open application bundle, Copy PID/Path.
- `quickshell/Modules/ProcessList/ProcessFilterChips.qml` (30 lines) & `ProcessSummary.qml` (40 lines) — Category filters (`All`, `User`, `System`, `Roots`), total process count, active thread count, and zombie process warnings.
- `quickshell/Modules/ProcessList/PerformanceView.qml` (115 lines) & `PerformanceCard.qml` (160 lines) — Hardware performance graphs: per-core CPU sparklines, RAM vs Swap breakdown, Network I/O throughput (KB/s upload/download).
- `quickshell/Modules/ProcessList/DisksView.qml` (390 lines) — Mounted storage volumes, filesystem types, storage capacity bars (Used/Free), mount points, and read/write I/O bandwidth.
- `quickshell/Modules/ProcessList/SystemView.qml` (450 lines) — Hardware diagnostic dashboard: CPU model, core architecture, system uptime, kernel release, motherboard/device model, and thermal sensor gauges.
- `quickshell/Modules/PowerMenu/PowerMenuContent.qml` (427 lines) — Full-screen or modal power action grid featuring:
  - 6 core actions: Lock, Suspend, Hibernate, Reboot, Shutdown, Log Out.
  - "Hold to Confirm" safety mechanism (`holdProgress`, `holdDurationMs = 1500ms`) with radial countdown animation ring preventing accidental power-offs.
  - Arrow key navigation and Enter / Space hold detection.
- `quickshell/Modules/SystemUpdate/SystemUpdatePanel.qml` (440 lines) & `UpgradeLogText.qml` (27 lines) — Software update sheet: available updates counter, package name/version diffs, repository tags, changelog inspector, and streaming upgrade terminal output.
- `core/cmd/dms/commands_system.go` (310 lines) — CLI system subcommands (`dms system reboot`, `poweroff`, `suspend`, `lock`, `info`).
- `core/internal/server/sysupdate/*` (35 files) — Backend package management abstraction layer.

---

## 1. Purpose & User-Visible Behavior
This specification unites the host task manager (`ProcessList`), system state transitions (`PowerMenu`), and maintenance infrastructure (`SystemUpdate`).

Key user-visible behaviors include:
1. **Interactive Task Manager**:
   - Immediate visibility into hungry foreground and background processes.
   - One-click sorting by CPU or Memory usage.
   - Instant search filtering with process tree collapsing.
   - Right-click process management with signal sending (`SIGTERM`, `SIGKILL`) and priority renicing.
2. **Accident-Proof Power Menu**:
   - Power actions (Shutdown, Reboot) require holding the button or Spacebar for 1.5 seconds.
   - A circular stroke progress ring fills up during the hold; releasing early cancels the action safely.
3. **Software Update Center**:
   - Displays pending macOS system updates and package updates (Homebrew).
   - Shows detailed changelogs and version diffs (e.g. `1.2.3 -> 1.2.4`).
   - One-click "Update All" launches a live streaming terminal output card showing progress.

---

## 2. Layout & Visual Tokens
- **Process List Popout**:
  - `sheetWidth`: 600 pt (tabbed views) / 780 pt (detailed performance).
  - `sheetHeight`: 620 pt.
  - Row height: 40 pt with alternating subtle row tints.
- **Power Menu Grid**:
  - Centered modal dialog or island dropdown: 420 pt width, 320 pt height.
  - Action tile size: 100x100 pt rounded container with 48 pt icon.
  - Hold progress stroke: 4 pt primary color stroke around the active tile.
- **M3 Colors & Status Alerts**:
  - CPU > 80%: `Theme.error` badge.
  - Memory > 75%: `Theme.tertiary` badge.
  - Danger action (Shutdown): `Theme.errorContainer` fill.

---

## 3. Internal Logic & State Management
- **Process Sampling Engine**:
  - Background polling interval: 2,000 ms (active popout) / 10,000 ms (idle bar pill).
  - In macOS, uses `libproc` (`proc_listpids`, `proc_pidinfo`) and `sysctl` (`KERN_PROC`) to collect PID, parent PID, resident memory, CPU user/system times, and process paths.
- **Power Action Hold Timer**:
  - `CADisplayLink` or high-frequency timer tracks hold duration from `mouseDown` / `keyDown`.
  - Fires callback only when `holdProgress >= 1.0`.

---

## 4. Configuration Schema
| Settings Key | Type | Default | Description |
|---|---|---|---|
| `processList.pollIntervalMs` | int | `2000` | Process table refresh interval |
| `processList.defaultSort` | string | `"cpu"` | Default column (`cpu`, `memory`, `name`) |
| `processList.showSystemProcesses` | bool | `false` | Show root/kernel tasks by default |
| `powerMenu.holdToConfirm` | bool | `true` | Require hold duration to trigger action |
| `powerMenu.holdDurationSeconds`| real | `1.5` | Required hold duration |
| `systemUpdate.checkIntervalHours`| int | `24` | Update check schedule |
| `systemUpdate.backend` | string | `"auto"` | Update backend (`brew`, `softwareupdate`) |

---

## 5. IPC / CLI API
| Command | Arguments | Returns | Description |
|---|---|---|---|
| `dms system lock` | `none` | `void` | Locks display / triggers screensaver |
| `dms system suspend` | `none` | `void` | Enters system sleep |
| `dms system reboot` | `[--force]` | `void` | Restarts system |
| `dms system poweroff` | `[--force]` | `void` | Shuts down system |
| `process.kill` | `pid: int, signal?: int` | `bool` | Sends signal to PID |
| `process.renice` | `pid: int, priority: int`| `bool` | Adjusts process nice value |
| `systemUpdate.check` | `none` | `json` | Checks for pending updates |
| `systemUpdate.upgrade` | `none` | `stream`| Executes upgrade with streaming log |

---

## 6. macOS Mapping
- **Process Metrics**:
  - Query `proc_listpids(PROC_ALL_PIDS, 0, ...)` and `proc_pidinfo(pid, PROC_PIDTASKINFO, ...)` for memory footprint and CPU thread times.
  - Application mapping: Cross-reference PID with `NSRunningApplication(processIdentifier: pid)` for app icon and display name.
- **Power Actions**:
  - Lock: `SACLockScreenImmediate()` from `/System/Library/PrivateFrameworks/login.framework` or `IOPMAssertionCreateWithName`.
  - Sleep: `pmset sleepnow` or `IOPMSleepSystem()`.
  - Restart: AppleScript `tell app "System Events" to restart` or `reboot`.
  - Shutdown: AppleScript `tell app "System Events" to shut down` or `shutdown -h now`.
- **Software Updates**:
  - Integrate with `brew outdated --json` for package manager updates.
  - Integrate with `/usr/sbin/softwareupdate -l` for macOS operating system updates.

---

## 7. Port Audit
| Upstream File / Subsystem | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `quickshell/Modules/ProcessList/**` (12 files) | Partially Insp. | **Major Gap** | Port has a basic 218-line `ProcessListView.swift`. It lacks sorting chips, filter categories, context menus (kill/renice), PerformanceView graphs, DisksView, and SystemView diagnostics. |
| `PowerMenuContent.qml` (Hold-to-Confirm) | Partially Insp. | **Major Gap** | Port has a basic 156-line `PowerMenuView.swift` with immediate click actions. It lacks the safety "Hold to Confirm" radial progress ring and keyboard hold support. |
| `SystemUpdatePanel.qml` & Backend | Absent | **Missing (0%)** | Completely missing in port. No update checking, no Homebrew/softwareupdate integration, no streaming console log. |

---

## 8. Reimplementation Checklist
- [ ] Upgrade `ProcessService` using native `libproc` APIs to collect accurate memory, CPU, and running application associations.
- [ ] Build multi-tab `ProcessList` popout (Processes, Performance Graphs, Disks, System Info).
- [ ] Implement right-click context menu with `SIGTERM`/`SIGKILL` actions and renice priority slider.
- [ ] Add "Hold to Confirm" radial progress ring to `PowerMenuView` with configurable hold duration (1.5s).
- [ ] Implement `SystemUpdateService` integrating Homebrew (`brew outdated`) and macOS software updates with a live ANSI log viewer.
- [ ] Add `dms system [lock|suspend|reboot|poweroff]` to CLI.
