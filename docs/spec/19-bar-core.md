# BAR — DankBar Structural Engine, Multi-Axis Layout & Segment Roles Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: DankBar Structural Engine (`quickshell/Modules/DBar/*`), True Center Algorithm (`CenterLayout.js`), Segment Roles & Pill Merging (`SegmentRoles.js`), Overflow Handling (`OverflowLayout.js`), Multi-Axis Support (Horizontal & Vertical), Multi-Monitor Configurations, and Auto-Hide Hover Controller (`BarHoverController.qml`).

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `quickshell/Modules/DBar/DBar.qml` | 420 | Master bar component coordinating Left, Center, and Right sections |
| `quickshell/Modules/DBar/DBarWindow.qml` | 380 | Layer-shell window surface host, exclusive zone management |
| `quickshell/Modules/DBar/DBarBody.qml` | 260 | Visual background surface, margin padding, floating vs edge styling |
| `quickshell/Modules/DBar/LeftSection.qml` | 190 | Left/top anchored widget container |
| `quickshell/Modules/DBar/CenterSection.qml` | 280 | Center container implementing true-center layout and collision avoidance |
| `quickshell/Modules/DBar/RightSection.qml` | 190 | Right/bottom anchored widget container |
| `quickshell/Modules/DBar/CenterLayout.js` | 65 | Geometric true-center mathematical solver with boundary confinement |
| `quickshell/Modules/DBar/SegmentRoles.js` | 48 | Pill segment grouping solver (`solo`, `first`, `middle`, `last`) |
| `quickshell/Modules/DBar/OverflowLayout.js` | 95 | Dynamic widget overflow collapse when screen width is constrained |
| `quickshell/Modules/DBar/BarHoverController.qml` | 140 | Auto-hide hover gesture detector and debounce timers |
| `quickshell/Modules/DBar/BarSegment.qml` | 165 | Visual container clipping corners based on calculated segment role |
| `quickshell/Modules/DBar/AxisContext.qml` | 85 | Coordinates orientation (horizontal vs vertical axes) |
| `quickshell/Services/BarWidgetService.qml` | 299 | Bar widget registry, screen targeting, instance mapping |

---

## 1. Purpose & User-Visible Behavior

1. **Multi-Axis Layout Engine**:
   - DankBar can run horizontally along the **Top** or **Bottom** screen edge, or vertically along the **Left** or **Right** screen edge.
   - All child widgets automatically adapt their aspect ratios, text truncation, and popout anchor sides based on the active axis.
2. **True Geometric Center**:
   - The Center section (Clock, Media, or Status) is mathematically centered relative to the **physical display**, not merely centered between Left and Right sections.
   - If large Left or Right sections expand, `CenterLayout.js` gracefully nudges the center widgets to avoid visual overlap without clipping.
3. **Segment Roles & Organic Pill Grouping (`SegmentRoles.js`)**:
   - Adjacent widgets dynamically coalesce into cohesive segmented pills:
     - `solo`: Fully rounded capsule (corner radius 9999px).
     - `first`: Outer corners rounded, inner boundary flat.
     - `middle`: All 4 corners square, separated by a subtle 1px divider.
     - `last`: Inner boundary flat, outer corners rounded.
   - Spacers and separators cleanly break segment runs.
4. **Auto-Hide & Intellihide**:
   - Hides off-screen when inactive or when windows overlap the bar area.
   - Moving the cursor to the screen edge immediately reveals the bar with smooth M3 spring translation.

---

## 2. Mathematical Algorithms

### 2.1. True Center Layout (`CenterLayout.js`)
```javascript
// Given screen length L, widget sizes S, spacing G, and Left/Right boundary limits [min, max]:
totalSize = sum(S) + (count - 1) * G;
idealStart = L / 2 - totalSize / 2;
actualStart = Math.min(Math.max(idealStart, bounds.min), bounds.max - totalSize);
```

### 2.2. Segment Role Resolution (`SegmentRoles.js`)
```javascript
// Iterates through visible widgets in a section:
// Contiguous runs of active widgets receive:
// Run length 1: ["solo"]
// Run length 2: ["first", "last"]
// Run length 3+: ["first", "middle"..., "last"]
```

---

## 3. Detailed Requirements

### 3.1. Bar Dimensions & Styling (`DBarBody.qml`)
- `BAR-001`: Dimensions:
  - Horizontal bar thickness: Default 48px (configurable 32px to 72px).
  - Vertical bar thickness: Default 54px.
  - Floating margin: Default 8px from screen edges.
  - Corner radius: 24px (`Shape.corners.xl`) when floating; 0px when edge-attached.
- `BAR-002`: Background: M3 `surfaceContainerLow` at `barTransparency` opacity, with optional 1px `outlineVariant` border.

### 3.2. Auto-Hide Timing (`BarHoverController.qml`)
- `BAR-003`: Reveal trigger: Cursor within 2px of screen edge triggers reveal after 80ms delay.
- `BAR-004`: Hide trigger: Cursor leaving bar area triggers auto-hide after 350ms grace delay.

---

## 4. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| Multi-Axis Layout | **Divergent** | `DankBarView.swift` | Implements a single horizontal bar. **Vertical orientation (Left/Right edges) is completely unsupported.** |
| True Center Algorithm| **Missing** | `DankBarView.swift` | Uses standard SwiftUI `Spacer()` between Left, Center, and Right. Center section is not geometrically centered and collides when Left/Right expand. |
| `SegmentRoles.js` | **Missing** | None | **Segmented pill grouping is completely absent**. All pills in the port are either hardcoded capsules or independent rectangles. |
| Multi-Bar / Multi-Screen| **Missing** | `DankBarController.swift` | Only creates a single bar instance on the primary screen. Multi-bar arrays (`barConfigs`) and per-monitor bars do not exist. |

### Audit Verdict:
The port implements a simple static SwiftUI `HStack`, but **completely lacks the dynamic layout engine, true geometric centering, vertical axis support, and organic pill segment grouping that define DankBar**. Parity: **~20%**.

---

## 5. Reimplementation Checklist

- [ ] Port `CenterLayout.js` into Swift (`BarCenterLayoutSolver.swift`).
- [ ] Port `SegmentRoles.js` into Swift (`BarSegmentRoleSolver.swift`) and create `M3SegmentedPill` shape.
- [ ] Refactor `DankBarController` into a multi-instance bar manager instantiating independent bars per display.
- [ ] Add vertical bar orientation support for Left and Right screen edges.
