# 31 — Settings UI Part A: Framework, Appearance & Theme Specification (`SET-A`)

## 0. Coverage Manifest
- `quickshell/Modals/Settings/SettingsModal.qml` (469 lines) — Master modal window frame, responsive layout switching (split master-detail vs compact sheet), escape key dismissal, and window chrome.
- `quickshell/Modals/Settings/SettingsSidebar.qml` (473 lines) — Collapsible navigation sidebar grouped into categories (Appearance, Desktop, Hardware, System), search input filter, unread update badge, and category icons.
- `quickshell/Modals/Settings/SettingsContent.qml` (632 lines) — Detail pane host managing tab loading, smooth slide transitions, deep-link breadcrumbs, and search highlight scrolling.
- `quickshell/Modals/Settings/SettingsPaneNavigation.qml` (153 lines) — Breadcrumb navigation bar, back/forward history stack, and deep-link router.
- `quickshell/Modules/Settings/Widgets/*` (45 widget components):
  - `SettingsRow.qml` (382 lines) & `SettingsCard.qml` (80 lines) — Base container row with title, description, badge, and trailing accessory.
  - `SettingsGroup.qml` (172 lines) & `SettingsSectionLabel.qml` (118 lines) — Visual grouping card with rounded corners and dividing separators.
  - `SettingsColorPicker.qml` (110 lines) & `ColorDropdownRow.qml` (216 lines) — Inline color swatch button opening spectrum picker dialog.
  - `SettingsSliderRow.qml` (58 lines) & `SettingsSliderControl.qml` (87 lines) — Continuous slider with value bubble and step snap.
  - `SettingsToggleRow.qml` (51 lines) & `SettingsToggleCard.qml` (113 lines) — Material Design 3 switch with icon morphing.
  - `SettingsSwatchGrid.qml` (162 lines) & `MaterialSeedPicker.qml` (68 lines) — Tonal palette swatches and seed color grid.
  - `SettingsDropdownRow.qml` (55 lines), `SettingsTextFieldRow.qml` (76 lines), `SettingsFontDropdownRow.qml` (34 lines).
- `quickshell/Modules/Settings/ThemeColorsTab.qml` (899 lines) — Seed color picker, dynamic Material Design 3 palette generator (Primary, Secondary, Tertiary, Neutral, Neutral Variant), contrast modes (Standard, Medium, High), and custom hex color overrides.
- `quickshell/Modules/Settings/ThemeSurfacesTab.qml` (687 lines) — Surface tone modifiers, window background opacity (0.0 - 1.0), blur strength, surface corner radii, border widths, and outline opacity.
- `quickshell/Modules/Settings/ThemeAppsTab.qml` (551 lines) — Downstream application theme generation: GTK 3/4 CSS generation, Qt Kvantum, Firefox, Vesktop/Discord, and terminal themes.
- `quickshell/Modules/Settings/ThemeScheduleTab.qml` (124 lines) — Automatic light/dark mode schedule based on astronomical sunrise/sunset (`SunCalc`) or custom fixed time intervals.
- `quickshell/Modules/Settings/PaletteInjectTab.qml` (162 lines) — Direct live template file injection and hot-reloading for external app configurations.
- `quickshell/Modules/Settings/ShadowsTab.qml` (408 lines) — Multi-tier elevation shadow system: Key shadow vs Ambient shadow blur, spread, Y-offset, and color tinting.
- `quickshell/Modules/Settings/TypographyMotionTab.qml` (370 lines) — Font family pickers (UI, Display, Monospace), font scale multiplier, animation duration scale, and reduced motion override.
- `quickshell/Modules/Settings/WallpaperColorsTab.qml` (1,129 lines) & `WallpaperCyclingTab.qml` (284 lines) — Wallpaper-derived theme extraction, dominant color analysis, and automatic timed wallpaper carousel cycling.

---

## 1. Purpose & User-Visible Behavior
The DMS Settings application is a comprehensive control center for the desktop environment. Part A specifies the core settings navigation shell and the exhaustive visual theming and styling engine.

Key user-visible behaviors include:
1. **Master-Detail Navigation with Deep Linking**:
   - Sidebar provides categorized navigation across all 25+ settings tabs with keyboard shortcuts and search.
   - Any setting can be deep-linked from CLI or IPC (e.g. `dms settings open appearance.theme`).
   - Unified search indexes every configuration key, subtitle, and keyword with instant filtering.
2. **Material Design 3 Dynamic Color System**:
   - Users pick a single seed color or let the wallpaper automatically generate one.
   - The engine instantly calculates a complete 48-tone M3 palette with mathematically verified contrast ratios.
   - Contrast mode toggle (Standard, Medium, High) guarantees accessibility compliance.
3. **Surfaces & Glassmorphism Customization**:
   - Real-time sliders for shell opacity (e.g. 85%), background blur radius (e.g. 32 pt), corner rounding (e.g. 16 pt), and border highlights.
   - Changes take effect instantaneously across all bars, docks, islands, and popouts without restarting.
4. **Astronomical Theme Scheduling**:
   - Automatic switching between Light and Dark mode synced with local astronomical sunrise and sunset times.
5. **Downstream Application Injection**:
   - Generates matching color schemes for terminal emulators, code editors, and third-party apps via dynamic template injection.

---

## 2. Layout & Visual Tokens
- **Window Geometry**:
  - `windowWidth`: 980 pt (standard) / 1120 pt (expanded).
  - `windowHeight`: 720 pt.
  - `sidebarWidth`: 260 pt.
- **Component Styling**:
  - Settings Card: Rounded container (`Theme.cornerRadiusL = 16 pt`), fill `Theme.surfaceContainerLow`.
  - Divider: 1 pt line `Theme.outlineVariant` (alpha 0.12).
  - Row height: Minimum 52 pt.
- **M3 Elevation**:
  - Modal surface: `Theme.surface` with level 2 drop shadow.

---

## 3. Internal Logic & State Management
- **Search Indexer (`settings_search_index.json`)**:
  - Pre-computed index mapping tokens to tab IDs and section anchors.
- **Dirty State Tracking**:
  - Live comparison between runtime values and persisted `SettingsData` disk state.
  - Floating action bar appears when unsaved changes exist (with Discard / Apply buttons).

---

## 4. Configuration Schema
| Settings Key | Type | Default | Description |
|---|---|---|---|
| `theme.mode` | string | `"dark"` | Theme mode (`light`, `dark`, `system`, `schedule`) |
| `theme.seedColor` | string | `"#6750A4"` | Hex seed color for M3 palette |
| `theme.contrast` | string | `"standard"`| Contrast level (`standard`, `medium`, `high`) |
| `theme.surfaceOpacity`| real | `0.85` | Shell surface alpha transparency |
| `theme.blurRadius` | int | `24` | Background Gaussian blur radius |
| `theme.cornerRadius` | int | `16` | Standard shell corner rounding |
| `theme.fontFamily` | string | `"Inter"` | Primary UI font family |
| `theme.fontFamilyMono`| string | `"JetBrains Mono"` | Monospace font family |

---

## 5. IPC / CLI API
| Command | Arguments | Returns | Description |
|---|---|---|---|
| `dms settings open [tab]` | `tab?: string` | `void` | Opens settings window directly to tab |
| `dms settings search <term>` | `term: string` | `json` | Searches settings keys |
| `dms theme set <mode>` | `mode: string` | `void` | Changes theme (`light`, `dark`) |
| `dms theme setSeed <hex>` | `hex: string` | `void` | Sets custom seed color |

---

## 6. macOS Mapping
- **Settings Window**:
  - Standard macOS Preferences window (`NSWindow` with `.titled`, `.closable`, `.resizable`, `.miniaturizable` styles).
  - Use `NavigationSplitView` in SwiftUI or standard `NSSplitViewController`.
- **System Theme Integration**:
  - Bind `theme.mode = "system"` to `NSApp.effectiveAppearance` (`NSAppearance.Name.darkAqua` vs `aqua`).
- **Template Injection on macOS**:
  - Write generated themes to macOS apps: Terminal (`.terminal` plist), iTerm2 (`com.googlecode.iterm2.plist`), Alacritty, Kitty, VS Code.

---

## 7. Port Audit
| Upstream File / Subsystem | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `quickshell/Modals/Settings/**` (4 files, 1,727 lines) | Partially Insp. | **Major Gap** | Port has a simplified 8-tab `SettingsView.swift`. It lacks deep linking, search indexing, breadcrumb history, and responsive layout splitting. |
| `ThemeColorsTab.qml` (899 lines) & M3 Generator | Partially Insp. | **Major Gap** | Port has a rudimentary `DynamicThemeGenerator.swift` with fixed color arrays; lacks contrast modes, full 48-tone M3 palette, and seed picker. |
| `ThemeSurfacesTab.qml`, `ShadowsTab.qml`, `TypographyMotionTab.qml` | Absent | **Missing (0%)** | Real-time surface opacity, blur sliders, corner radii, shadow layers, and font configurations are completely absent in port's settings UI. |
| `ThemeAppsTab.qml` & `PaletteInjectTab.qml` | Absent | **Missing (0%)** | No downstream app theming or configuration template injection exists in the port. |

---

## 8. Reimplementation Checklist
- [ ] Implement split master-detail `SettingsWindowController` with search bar and categorized navigation.
- [ ] Build search index engine searching settings titles, keys, and descriptions.
- [ ] Rebuild `ThemeColorsView` with seed color picker, full M3 palette generator, and contrast mode selector.
- [ ] Build `ThemeSurfacesView` with live sliders for opacity, blur radius, corner radii, and border widths.
- [ ] Build `ThemeScheduleView` syncing light/dark mode with astronomical sunrise/sunset.
- [ ] Add `dms settings open [tab]` and `dms theme [set|setSeed]` to CLI.
