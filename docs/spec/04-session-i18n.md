# SESS — Session State, Cache Hierarchy, I18n & Logging Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Runtime Session State (`SessionData.qml`, `SessionSpec.js`, `SessionStore.js`), Cache Directories, Application Usage Ranking History (`AppUsageHistoryData.qml`), Paths Specification (`Paths.qml`), Internationalization Engine (`I18n.qml`, `poexports/`), RTL Handling, and Structured Logging (`Log.qml`).

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `quickshell/Common/SessionData.qml` | 1,952 | Active runtime session state, per-monitor wallpaper, DND timers, terminal resolution |
| `quickshell/Common/settings/SessionSpec.js` | 309 | Schema definitions and default values for session state keys |
| `quickshell/Common/settings/SessionStore.js` | 141 | Low-level JSON serializer and persistence for `session.json` |
| `quickshell/Common/CacheData.qml` | 309 | Ephemeral runtime cache (recently used emojis, icons, weather data) |
| `quickshell/Common/AppUsageHistoryData.qml` | 136 | Application launch counts, last launch timestamps, frecency decay model |
| `quickshell/Common/Paths.qml` | 204 | Standard directory paths and URL sanitation helpers |
| `quickshell/Common/I18n.qml` | 298 | Internationalization engine, locale candidate resolution, translation loading |
| `quickshell/Common/suncalc.js` | 243 | Astronomical solar position calculator (sunrise, sunset, twilight) |
| `quickshell/Common/Site.qml` | 11 | Official documentation and repository link constants |
| `quickshell/Common/Proc.qml` | 17 | Child process launcher wrapper |
| `quickshell/Common/DankSocket.qml` | 7 | Unix domain socket client connection |
| `quickshell/Common/QmlUtils.js` | 65 | Array, string, and object manipulation utility functions |
| `quickshell/Common/DateOnly.js` | 68 | Calendar date normalization (zeroing hours/minutes/seconds) |
| `quickshell/Common/htmlElide.js` | 99 | HTML/Pango markup truncation preserving valid tag nesting |
| `quickshell/Common/markdown2html.js` | 98 | Lightweight Markdown-to-HTML parser for tooltips and release notes |
| `quickshell/Services/Log.qml` | 226 | Scoped structured logging singleton |
| `quickshell/translations/` | 22 files | Locale catalogs (`en.json`, `de.json`, `fr.json`, `ja.json`, `zh_CN.json`, etc.) |
| `core/internal/log/` | 146 | Go-side structured logging system |

---

## 1. Purpose & User-Visible Behavior

1. **Separation of Concerns (Settings vs. Session)**:
   - **Settings** (`settings.json`): User preferences (what theme do I like, what widgets are on my bar).
   - **Session** (`session.json`): Dynamic state (is DND active until 5pm, what is the current wallpaper on monitor 2, what tabs are open in Notepad).
2. **Frecency Tracking**: The shell records every application launch with timestamps to train `Scorer.js` for predictive app launcher search results.
3. **True Internationalization (I18n)**:
   - Translates all user-visible strings into 20+ languages (`de`, `es`, `fr`, `it`, `ja`, `ko`, `nl`, `pl`, `pt`, `ru`, `tr`, `uk`, `zh_CN`, `zh_TW`, etc.).
   - Automatically handles Right-to-Left (RTL) layout mirroring for Hebrew, Arabic, Persian, and Urdu.
   - Interpolates arguments (`%1`, `%2`) and supports translation disambiguation contexts (`I18n.tr("Empty", "button label")`).
4. **Astronomical Solar Calculation**: Real-time solar zenith math computes sunrise, sunset, civil dawn, and nautical dusk for automatic light/dark mode transitions without network requests.

---

## 2. Directory Layout & Storage Hierarchy

```
~/Library/Application Support/DMS/   (or ~/.config/DankMaterialShell/)
├── settings.json                   (User preferences)
├── session.json                    (Dynamic runtime state)
└── config.d/                       (Included JSON config fragments)

~/Library/Caches/DMS/               (or ~/.cache/DankMaterialShell/)
├── app_frecency.json               (App launch history)
├── translations/                   (Downloaded or cached translation catalogs)
├── wallpaper_cache/                (Pre-rendered blurred wallpaper textures)
└── album_art/                      (Cached track album art images)
```

---

## 3. Detailed Requirements

### 3.1. Session Data State Model (`SessionData.qml`)
- `SESS-001`: `session.json` must store schema version `7` (`SessionData.qml:14`).
- `SESS-002`: Required session keys:
  - `isLightMode`: Boolean.
  - `doNotDisturb`: Boolean.
  - `doNotDisturbUntil`: Unix epoch timestamp in milliseconds (0 = indefinite).
  - `idleInhibited`: Boolean.
  - `idleInhibitedUntil`: Unix epoch timestamp in milliseconds.
  - `screenShareDndDismissed`: Boolean.
  - `terminalOverride`: String executable path.
  - `changelogSeenVersion`: String version tag.
  - `suppressOSD`: Boolean (suppresses HUD during initial startup settling frames).
  - `monitorWallpapers`: Dictionary mapping monitor name to file path string.
  - `monitorMaterialWallpapers`: Dictionary mapping monitor name to seed string.
  - `recentColors`: Array of hex color strings (max 20 items).
  - `notepadTabs`: Array of tab metadata objects.

### 3.2. Internationalization & Pluralization (`I18n.qml`)
- `SESS-003`: String translation syntax:
  - Signature: `I18n.tr(text, context)` (`I18n.qml:80`).
  - Argument substitution: `.arg(val1).arg(val2)` replacing `%1`, `%2`.
- `SESS-004`: RTL detection: If current language code is in `["ar", "he", "iw", "fa", "ur", "ps", "sd", "dv", "yi", "ku"]`, `I18n.isRtl` must be `true`, causing horizontal layouts to mirror direction (`I18n.qml:24`).
- `SESS-005`: Fallback resolution order:
  1. Exact locale (e.g. `zh_CN`)
  2. Language code (e.g. `zh`)
  3. Default English (`en.json`)

### 3.3. App Frecency Model (`AppUsageHistoryData.qml`)
- `SESS-006`: For every application launched:
  - Increment `launchCount`.
  - Update `lastLaunchTime` to `Date.now()`.
  - Calculate frecency score: `score = (launchCount * 10) / (1.0 + (now - lastLaunchTime) / 86400000)`.

### 3.4. Solar Calculation Math (`suncalc.js`)
- `SESS-007`: Given latitude, longitude, and current date, `SunCalc.getTimes(date, lat, lng)` must calculate exact times for:
  - `sunrise`, `sunset`, `solarNoon`, `nadir`, `dawn`, `dusk`, `nauticalDawn`, `nauticalDusk`.

---

## 4. Settings Keys

| Key | Type | Default | Effect | UI Location |
| :--- | :--- | :--- | :--- | :--- |
| `locale` | string | `""` | User locale override (empty = system default) | Locale Tab |
| `solarLatitude` | double | `0.0` | Manual latitude coordinate for sunrise calculation | Time & Weather Tab |
| `solarLongitude` | double | `0.0` | Manual longitude coordinate | Time & Weather Tab |
| `logLevel` | string | `"info"` | Minimum log verbosity (`debug`, `info`, `warn`, `error`)| Diagnostics Tab |

---

## 5. IPC / CLI / Socket API

| Command | Arguments | Return / Side Effect |
| :--- | :--- | :--- |
| `dms session get <key>` | `<key>` | Returns runtime session property value |
| `dms session set <key> <val>`| `<key> <val>` | Sets runtime session property (e.g. DND duration) |
| `dms locale set <lang>` | `<code>` | Switches active translation catalog live |

---

## 6. Wayland/Linux Mechanisms → macOS Mapping

1. **Locale Resolution**:
   - Upstream queries `Qt.locale().name`.
   - **macOS Approach**: Read `Locale.current.identifier` (e.g. `en_US`, `de_DE`, `zh_Hans_CN`).
2. **Application State Directory**:
   - Upstream uses `$XDG_STATE_HOME/DankMaterialShell/session.json`.
   - **macOS Approach**: Use `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` appending `/DMS/session.json`.
3. **Log Streaming**:
   - Upstream writes to `stderr` and systemd journal.
   - **macOS Approach**: Use Apple unified logging (`os.Logger(subsystem: "com.danklinux.dms", category: scope)`).

---

## 7. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| `SESS-001` - `002` | **Missing** | None | Port does not separate `session.json` from `config.json`. Ephemeral state (DND timer, OSD suppression, recent colors) is lost or mingled with user config. |
| `SESS-003` - `005` | **Missing** | None | **Zero localization exists in the port**. All UI strings are hardcoded in English; no translation catalogs or RTL mirroring exist. |
| `SESS-006` | **Partial** | `AppCatalogService.swift` | Basic in-memory counter exists, but does not persist frecency history to disk. |
| `SESS-007` | **Missing** | None | Solar angle calculations for automatic night shift / theme schedule do not exist. |

### Audit Verdict:
The port **completely lacks an I18n engine** and fails to separate dynamic session state from persistent configuration. All strings are hardcoded English, and runtime states (like DND timers) do not persist properly. Parity: **~10%**.

---

## 8. Reimplementation Checklist

- [ ] Implement `I18n.swift` reading bundled JSON catalogs with `%1`, `%2` interpolation and RTL mirroring.
- [ ] Implement `SessionStore.swift` managing `~/Library/Application Support/DMS/session.json`.
- [ ] Port `suncalc.js` to Swift for autonomous solar light/dark switching.
- [ ] Implement persistent application frecency logging in `AppUsageHistoryStore.swift`.
- [ ] Connect `os.Logger` for scoped subsystem diagnostics.
