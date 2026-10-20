# LAUNCH — DLauncherV2, App Search, Scorer & DMenu IPC Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: DLauncherV2 Modal Suite (`quickshell/Modals/DLauncherV2/*`, 19 files, 8.9k lines), Weighted Scoring Engine (`Scorer.js`), Search Modes, Tile/Grid vs. List Layouts, In-Launcher App Editor (`AppEditView.qml`), Action Panel (`ActionPanel.qml`), and DMenu IPC Mode.

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `quickshell/Modals/DLauncherV2/Controller.qml` | 2,540 | Master launcher controller, search debouncing, section aggregator |
| `quickshell/Modals/DLauncherV2/Scorer.js` | 230 | Weighted frecency and fuzzy string scoring algorithm |
| `quickshell/Modals/DLauncherV2/LauncherContent.qml` | 740 | Main visual layout (search input, category filter chips, results container) |
| `quickshell/Modals/DLauncherV2/SpotlightLauncherContent.qml` | 480 | Centered Spotlight floating search window chrome |
| `quickshell/Modals/DLauncherV2/DLauncherV2ModalHost.qml` | 1,480 | Window management, positioning relative to screen or island |
| `quickshell/Modals/DLauncherV2/ResultsList.qml` | 690 | Vertically scrollable results list with keyboard selection tracking |
| `quickshell/Modals/DLauncherV2/TileItem.qml` | 165 | Grid/Tile mode item delegate (large icon, label below) |
| `quickshell/Modals/DLauncherV2/ActionPanel.qml` | 215 | Trailing action sidebar for selected app (Pin, Open With, Terminal, Edit) |
| `quickshell/Modals/DLauncherV2/AppEditView.qml` | 245 | In-launcher application desktop entry and tag editor |
| `quickshell/Modals/DLauncherV2/LauncherContextMenu.qml` | 225 | Right-click action context menu |
| `quickshell/Modals/DLauncherV2/SectionHeader.qml` | 185 | Section divider (Apps, Settings, Files, Calculator, Emojis, Plugins) |
| `quickshell/Modals/DLauncherV2/SourceBadge.qml` | 35 | Small category source badge pill |
| `quickshell/Modules/AppDrawer/AppDrawerPopout.qml` | 144 | Fullscreen or edge-attached application drawer variant |
| `quickshell/Services/AppSearchService.qml` | 1,150 | Application desktop entry indexer, category parsing, icon resolution |
| `quickshell/Services/DSearchService.qml` | 194 | File indexer integration (locate / fd / baloo) |
| `core/internal/dmenuipc/` | 266 | DMenu wire protocol server |
| `core/cmd/dms/commands_dmenu.go` | 190 | `dms dmenu` CLI utility |

---

## 1. Purpose & User-Visible Behavior

DLauncherV2 is a unified command palette and application launcher:
1. **Adaptive Presentation**:
   - **Spotlight Mode**: Centered floating modal with rounded M3 card.
   - **Drawer Mode**: Edge-attached or full-screen grid of applications.
   - **Island Mode**: Expands directly downward out of the Dynamic Island notch pill.
2. **Search Capabilities**:
   - Applications: Fuzzy matching on app name, generic name, keywords, and executable name.
   - Calculator: Instant math evaluation (e.g. `128 * 4.5`, `sin(pi/2)`, `0x10 + 15`).
   - Files: Fast search across user directories.
   - Emojis: Search by name/keyword with instant clipboard copy.
   - System Settings: Deep-link directly to DMS settings tabs.
3. **Frecency Scoring (`Scorer.js`)**:
   - Adapts to user habits over time, prioritizing frequently and recently launched apps.
4. **App Actions & In-Place Editing**:
   - Pressing `Tab` or right-clicking reveals the `ActionPanel`: Pin to Bar, Pin to Dock, Run in Terminal, Launch as Root, or Edit Desktop Entry.

---

## 2. Mathematical Scoring Specification (`Scorer.js`)

Each candidate receives a score based on strict mathematical weights:
```
Weights:
  exactMatch:       10,000
  prefixMatch:       5,000
  wordBoundary:      3,000
  genericPrefix:       800
  substring:           500
  generic:             400
  id:                  350
  fuzzy:               100
  frecencyMax:       2,000

Type Bonuses:
  App:       +1,000
  Plugin:      +900
  Setting:     +850
  Clipboard:   +825
  File:        +800
  Action:      +600
```
- Levenshtein distance is calculated for fuzzy queries; if distance $> 2$, fuzzy score is 0.
- Frecency score decays with half-life formula: $\text{frecency} = \frac{\text{launchCount} \times 10}{1.0 + (\text{now} - \text{lastLaunch}) / 86400000}$, capped at 2,000 points.

---

## 3. Detailed Requirements

### 3.1. Visual Layout & Dimensions (`SpotlightLauncherContent.qml`)
- `LAUNCH-001`: Dimensions:
  - Width: 680px (or user setting `launcherWidth`).
  - Height: Dynamic, expanding from 72px (input only) up to 540px based on results count.
  - Corner radius: 28px (`Shape.corners.xl`).
  - Input field height: 56px, background `surfaceContainerHigh`.
- `LAUNCH-002`: View Modes:
  - `List`: Single-column rows (height 52px) with 36px icon, bold title, subtitle, and source badge.
  - `Grid / Tile`: Multi-column grid (4 to 6 columns) with 48px icon and centered label below.

### 3.2. DMenu IPC Compatibility (`Controller.qml`)
- `LAUNCH-003`: When `dms dmenu` executes:
  - Launcher opens in DMenu mode displaying stdin choices.
  - User selection prints to stdout upon Return, and launcher closes.

---

## 4. Wayland/Linux Mechanisms → macOS Mapping

1. **Application Discovery (`.desktop` files)**:
   - Linux scans `/usr/share/applications` and `~/.local/share/applications`.
   - **macOS Approach**: Scan `/Applications`, `/System/Applications`, `/System/Applications/Utilities`, and `~/Applications`. Read `Info.plist` for `CFBundleDisplayName`, `CFBundleName`, `CFBundleIdentifier`, and document icons.
2. **File Search Backend (`fd` / `locate`)**:
   - Linux executes CLI search binaries.
   - **macOS Approach**: Use native Apple Spotlight metadata search via `MDQuery` or `NSMetadataQuery` for sub-millisecond file querying.
3. **Calculator Engine**:
   - Use `NSExpression(format: ...)` or JavaScriptCore context for arithmetic and trigonometric calculations.

---

## 5. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| `LAUNCH-001` - `002` | **Partial** | `LauncherView.swift` (515 lines) | Simple list view exists. **Lacks Grid/Tile mode, Island attachment mode, dynamic height expansion, and ActionPanel sidebar.** |
| Scoring Engine | **Divergent** | `AppSearch.swift` | Implements basic prefix/contains matching. **Completely lacks the weighted Scorer.js algorithm and frecency decay model.** |
| Context Menu & Edit | **Missing** | None | Right-click context menu (Pin to Dock, Pin to Bar) and in-launcher app editing do not exist. |
| DMenu Protocol | **Missing** | None | DMenu socket integration does not exist in port. |

### Audit Verdict:
The port implements a basic search bar that filters apps, but **lacks the core intelligence of DLauncherV2** (frecency scoring, grid view, action sidebar, island mode, and dmenu IPC). Parity: **~30%**.

---

## 6. Reimplementation Checklist

- [ ] Port `Scorer.js` into Swift 6 (`LauncherScorer.swift`) with exact mathematical weights and frecency decay.
- [ ] Implement Tile/Grid view layout alongside List view in `LauncherView.swift`.
- [ ] Build the trailing `ActionPanel` sidebar for selected applications.
- [ ] Integrate Apple `MDQuery` for fast native file search results.
- [ ] Add DMenu socket mode to `dms` CLI.
