# WIDG — Reusable Material Design 3 Widget Library Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Complete M3 Component Library in `dank-qml-common/DCommon/Widgets/` (Buttons, Sliders, Toggles, TextFields, Steppers, Dropdowns, Cards, Gauges, WaveProgress, StateLayer, and Ripple Effects).

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `DCommon/Widgets/StateLayer.qml` | 150 | Hover, focus, pressed state layer with alpha opacities |
| `DCommon/Widgets/DRipple.qml` | 135 | Radial expansion ink ripple with pointer origin tracking |
| `DCommon/Widgets/DButton.qml` | 170 | Standard M3 Button (Filled, Tonal, Outlined, Text, Elevated) |
| `DCommon/Widgets/DActionButton.qml` | 80 | Compact icon action button with circular state layer |
| `DCommon/Widgets/DToggle.qml` | 280 | Material 3 Switch with spring-animated expanding thumb & icons |
| `DCommon/Widgets/DSlider.qml` | 740 | Continuous and discrete slider with value tooltip pill and wave track |
| `DCommon/Widgets/DDropdown.qml` | 850 | Select menu with scrollable popover, search filtering, and checkmarks |
| `DCommon/Widgets/DTextField.qml` | 720 | Filled & Outlined text input with floating label, clear button, error text |
| `DCommon/Widgets/DTextEdit.qml` | 180 | Multi-line text area with line wrapping and scroll integration |
| `DCommon/Widgets/DNumberStepper.qml` | 85 | Numeric stepper (- / + buttons) with interval repeat on hold |
| `DCommon/Widgets/DFilterChips.qml` | 195 | Horizontal scrolling chip row with selected checkmark badges |
| `DCommon/Widgets/DRingGauge.qml` | 110 | Circular ring progress gauge with gradient stroke and center value |
| `DCommon/Widgets/DSparkline.qml` | 210 | High-performance CPU/RAM/IO historical sparkline canvas |
| `DCommon/Widgets/M3WaveProgress.qml` | 75 | Sine-wave oscillating progress indicator for audio and seekbars |
| `DCommon/Widgets/DAnalogClock.qml` | 185 | Analog clock face with smooth ticking sweep hands |
| `DCommon/Widgets/DTimePicker.qml` | 550 | Material 3 radial dial time picker modal |
| `DCommon/Widgets/DMonthGrid.qml` | 280 | Calendar month grid with day-of-week headers and today highlight |
| `DCommon/Widgets/DCard.qml` | 140 | Elevation container card with optional interactive state layers |
| `DCommon/Widgets/DHeroCard.qml` | 95 | Large prominent feature card with leading icon and action buttons |
| `DCommon/Widgets/DLocationSearch.qml` | 320 | Geolocation search input with auto-complete suggestions list |
| `DCommon/Widgets/DIconPicker.qml` | 290 | Material Symbols icon browser with category filters |
| `DCommon/Widgets/DSaturationValuePicker.qml` | 160 | 2D color picker canvas for saturation/value coordinates |
| `DCommon/Widgets/DColorSwatch.qml` | 45 | Circular color preview swatch with checkerboard alpha backing |
| `DCommon/Widgets/DTooltipV2.qml` | 185 | Floating tooltip pill with auto-placement and arrow anchor |

---

## 1. Purpose & User-Visible Behavior

All UI components across DMS strictly adhere to Google's **Material Design 3 specifications**. Rather than using generic system controls, every widget implements custom state layers, spring animations, and tokenized M3 styling.

---

## 2. Component Specifications

### 2.1. State Layer (`StateLayer.qml`)
- `WIDG-001`: Opacity tokens for interaction states:
  - Hover: `0.08` (8% opacity)
  - Focus: `0.12` (12% opacity)
  - Pressed: `0.12` (12% opacity)
  - Dragged: `0.16` (16% opacity)
- `WIDG-002`: Transition duration between states must be 150ms using `emphasizedDecel`.

### 2.2. Switch / Toggle (`DToggle.qml`)
- `WIDG-003`: Dimensions:
  - Track: 52px width, 32px height, corner radius 16px (full pill).
  - Unchecked Thumb: 16px diameter, centered at 16px from left.
  - Checked Thumb: 24px diameter, centered at 36px from left.
  - Pressed State: Thumb expands to 28px diameter while held down.
- `WIDG-004`: Thumb icon: Inside the thumb, render a 16px Material Symbol icon (`check` when checked, optional `close` or empty when unchecked).
- `WIDG-005`: Animation: Thumb position and size must animate using physical spring physics (`islandSpringStiffness: 560`, `islandSpringDamping: 37`).

### 2.3. Slider (`DSlider.qml`)
- `WIDG-006`: Dimensions & Layout:
  - Track Height: 16px pill-shaped container (`surfaceContainerHighest`).
  - Active Track: Fills from left to current value in `primary`.
  - Thumb: 4px wide, 24px high vertical pill (or circular 20px knob), centered on value.
  - Stop Indicator: Discrete ticks render as 2px dots in `outlineVariant`.
- `WIDG-007`: Floating Value Tooltip: While dragging, a floating pill displays the formatted value above the thumb and auto-fades 400ms after release.

### 2.4. Buttons (`DButton.qml`, `DActionButton.qml`)
- `WIDG-008`: Button Variants:
  - `Filled`: Background `primary`, text `onPrimary`, height 40px, corner radius 20px.
  - `Tonal`: Background `secondaryContainer`, text `onSecondaryContainer`.
  - `Outlined`: Background transparent, 1px border `outline`, text `primary`.
  - `Text`: Background transparent, 0px border, text `primary`.
  - `Elevated`: Background `surfaceContainerLow`, shadow elevation 1.
- `WIDG-009`: Action Button: Circular 36x36px button for toolbar and popout triggers.

### 2.5. Wave Progress (`M3WaveProgress.qml`)
- `WIDG-010`: Continuous sine-wave displacement along the leading edge of active progress bars:
  - Wave amplitude: 3px.
  - Wave frequency: 0.08.
  - Oscillation speed: 1.5 cycles per second.

---

## 3. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| `WIDG-001` - `002` | **Missing** | None | No shared `StateLayer` exists. SwiftUI buttons use generic `.opacity()` modifiers on click without M3 state opacities. |
| `WIDG-003` - `005` | **Divergent** | Views | Port uses standard Apple `Toggle()` or ad-hoc custom toggles lacking M3 expanding thumb physics and checkmark icons. |
| `WIDG-006` - `007` | **Divergent** | Views | Port uses standard Apple `Slider()` or simple rectangles; floating value tooltip and M3 track heights are missing. |
| `WIDG-008` - `009` | **Partial** | `ControlCenterView.swift`, etc. | Ad-hoc SwiftUI capsule buttons exist, but no centralized `DButton` with Filled/Tonal/Outlined variants exists. |
| `WIDG-010` | **Missing** | None | Wave progress shader is absent; standard linear progress bars are used. |

### Audit Verdict:
The port **has no shared widget library**. Every view reinvents its own buttons, sliders, and toggles using stock SwiftUI controls, resulting in visual inconsistency and complete divergence from M3 design standards. Parity: **~15%**.

---

## 4. Reimplementation Checklist

- [ ] Create `DMSCore/UI/` and build the complete `DCommon` SwiftUI component kit:
  - `M3Button` (Filled, Tonal, Outlined, Text)
  - `M3Toggle` (with spring expanding thumb and checkmark)
  - `M3Slider` (with value tooltip pill and discrete ticks)
  - `M3TextField` (with floating label and clear button)
  - `M3Dropdown` (with searchable popover)
  - `M3WaveProgress` (Metal-backed sine wave)
  - `M3StateLayer` (hover, focus, pressed overlay)
- [ ] Refactor all shell views to consume this unified widget library.
