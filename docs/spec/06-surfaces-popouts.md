# SURF — Surface, Popout, Modal & Connected Frame Framework Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Popout Architecture (`DPopoutHost.qml`, 2,192 lines), Popout Manager (`PopoutManager.qml`), Modal Manager (`ModalManager.qml`), Connected Mode Concave Corner Geometry (`ConnectedSurfaceGeometry.js`, `ConnectorGeometry.js`), Slideouts (`DSlideout.qml`), Hover Dismissal (`PopoutHoverDismiss.qml`), Backdrop Blurring (`WindowBlur.qml`, `BackdropBlur.qml`), Screen Frame Anchoring (`Frame/`), and Focus Grab (`DFocusGrab.qml`).

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `quickshell/Widgets/DPopoutHost.qml` | 2,192 | Popout window host, positioning algorithms, resize animations, connected surfaces |
| `quickshell/Widgets/DPopout.qml` | 443 | Declarative popout definition attached to bar widgets |
| `quickshell/Widgets/DSlideout.qml` | 399 | Edge-attached sliding panel surface (e.g. Notepad, side panels) |
| `quickshell/Common/PopoutManager.qml` | 409 | Global popout coordinator, single-active-popout policy, hover tracking |
| `quickshell/Common/ModalManager.qml` | 59 | Global modal coordinator, scrim layering, modal stacking |
| `quickshell/Common/ConnectedModeState.qml` | 301 | Connected mode runtime state (whether bar and popout are physically merged) |
| `quickshell/Common/ConnectedSurfaceLease.qml` | 168 | Surface lease arbiter between Frame and popout windows |
| `quickshell/Common/ConnectedSurfaceGeometry.js` | 206 | Mathematical projection of animated bounding boxes and DPR pixel snapping |
| `quickshell/Common/ConnectorGeometry.js` | 58 | Concave arc fillet connector coordinates and sweep orientations |
| `quickshell/Common/ConnectedModalChrome.qml` | 75 | Styling chrome for connected modals |
| `quickshell/Modules/Frame/Frame.qml` | 450 | Screen edge decorative frame and exclusionary host |
| `quickshell/Modules/Frame/FrameWindow.qml` | 320 | Layer-shell window hosting the screen edge frame |
| `quickshell/Modules/SurfaceWidgets/GothCorner.qml` | 110 | Concave fillet corner canvas renderer ("gothic corners") |
| `quickshell/Widgets/DFocusGrab.qml` | 55 | Modal keyboard and pointer focus trapping |
| `quickshell/Widgets/DBackdrop.qml` | 114 | Dimming scrim backdrop with click-to-dismiss behavior |
| `quickshell/Widgets/PopoutHoverDismiss.qml` | 97 | Auto-dismiss popout when cursor leaves trigger area |
| `quickshell/Widgets/HoverDismissTracker.qml` | 30 | Coordinates tracking between trigger button and popout body |
| `quickshell/Widgets/WindowBlur.qml` | 178 | Background blur coordinator for popout surfaces |
| `quickshell/Widgets/DPanelResizer.qml` | 87 | Interactive resize handle for popouts and floating windows |
| `quickshell/Widgets/DResizeGrip.qml` | 45 | Corner resize grip indicator |
| `quickshell/Widgets/DFloatingWindow.qml` | 44 | Draggable and resizable standalone window chrome |

---

## 1. Purpose & User-Visible Behavior

In DMS, panels are not crude floating boxes. They are **architecturally integrated surfaces**:
1. **Connected Mode ("Gothic Corners")**: When a popout (Control Center, Audio device selector, Battery history) opens from a DankBar, it can physically merge into the bar's body. The sharp right-angled intersection is bridged by **concave fillet arcs** (`ConnectorGeometry.js`), creating a continuous organic Material 3 shell surface.
2. **Precision Alignment & Collision Avoidance**:
   - Anchors to the trigger button's exact center or edge.
   - Snaps to device pixels (`snap(value, dpr)`).
   - If a popout would overflow the display edge, it flips or clamps with padding (`popupGapsManual` / `spacing`).
3. **Fluid Motion & Resizing**: When switching subpages (e.g. Wi-Fi tile -> Wi-Fi network list), the window does not flicker; it smoothly animates its width and height using M3 Bezier curves (`resizeDuration: 250ms`, `emphasizedDecel`).
4. **Hover Dismissal & Grace Zones**: When a popout is configured to close on cursor exit, a triangular or rectangular "grace zone" bridges the button and the popout, preventing accidental dismissal while moving the cursor across the gap.

---

## 2. Connected Mode Geometry & Concave Fillets

```
      +-----------------------------------------+
      |               DANKBAR                   |
  ----+---------+---------------------+---------+----
      | Concave |      POPOUT         | Concave |
      | Arc L   |      BODY           | Arc R   |
      +---------+                     +---------+
                |                     |
                |                     |
                +---------------------+
```

### Concave Arc Mathematical Definition (`ConnectorGeometry.js`)
- Given bar edge `barSide` (`top`, `bottom`, `left`, `right`), spacing $S$, and fillet radius $R$:
  - `connectorWidth`: if vertical bar, $S + R$; if horizontal bar, $R$.
  - `connectorHeight`: if vertical bar, $R$; if horizontal bar, $S + R$.
  - Concave fillet path sweeps an arc from $(x_0, y_0)$ to $(x_1, y_1)$ with center offset by radius, creating a smooth tangent transition between bar and popout.

---

## 3. Detailed Requirements

### 3.1. Popout Host Life Cycle (`DPopoutHost.qml`)
- `SURF-001`: Popout window instantiation must use non-activating panels (`NSPanel`) that never steal key window status unless explicit text input is required.
- `SURF-002`: Entrance and exit animations:
  - Enter: Scale from `animationScaleCollapsed` (0.92) to 1.0, opacity 0.0 to 1.0, and translation of `animationOffset` (16px) over 250ms (`Theme.durShort`) with `emphasizedDecel`.
  - Exit: Scale to 0.95, opacity to 0.0 over 180ms with `emphasizedAccel`.
- `SURF-003`: Resizing choreography: When content size changes, the panel frame geometry must animate synchronously (`popoutHandle.resizeMotion = true`) using Bezier `[0.05, 0.7, 0.1, 1.0]`.

### 3.2. Hover & Click Dismissal
- `SURF-004`: If `autoDismissOnMouseLeave` is active:
  - Track global mouse coordinates via `NSEvent.addLocalMonitorForEvents(matching: .mouseMoved)`.
  - Dismissal triggers only if the cursor remains outside both the trigger button bounds and the popout bounds for greater than `hoverCloseDelay` (150ms).
- `SURF-005`: Background Scrim (`DBackdrop.qml`):
  - Modals and full overlays instantiate a dimming scrim with color `#000000` at opacity `0.45`.
  - Clicking the scrim immediately invokes `dismiss()`.

---

## 4. Settings Keys

| Key | Type | Default | Effect | UI Location |
| :--- | :--- | :--- | :--- | :--- |
| `popupTransparency` | double | `1.0` | Opacity of popout surfaces (0.0 to 1.0) | Theme Surfaces Tab |
| `popupGapsAuto` | bool | `true` | Automatically match popout distance to bar spacing | DBar Appearance Tab |
| `popupGapsManual` | int | `4` | Manual pixel gap between bar and popout | DBar Appearance Tab |
| `floatingWindowTransparency` | double | `1.0` | Opacity of detached floating windows | Theme Surfaces Tab |
| `gothCornersEnabled` | bool | `true` | Enables concave fillet arcs in connected mode | DBar Appearance Tab |

---

## 5. Wayland/Linux Mechanisms → macOS Mapping

1. **Layer-Shell Surface Positioning (`zwlr_layer_surface_v1`)**:
   - Upstream positions popouts using layer-shell anchors and margins.
   - **macOS Approach**: Position `NSPanel` using `setFrameOrigin()` calculated relative to the screen frame and target bar pill coordinates. Convert from Cocoa bottom-left coordinate system to top-left coordinate system.
2. **Concave Corner Rendering**:
   - Upstream draws fillets using a custom QML Canvas or shader item.
   - **macOS Approach**: Render concave fillets in SwiftUI using a custom `Shape` with `path.addQuadCurve(to:control:)` or `CGContext.addArc()`, painted with `theme.surfaceContainerHigh`.
3. **Window Blurring**:
   - Upstream binds to compositor blur (`WindowBlur.qml`).
   - **macOS Approach**: Set `NSPanel.backgroundColor = .clear` and host an `NSVisualEffectView(material: .popover, blendingMode: .behindWindow)` behind the SwiftUI view.

---

## 6. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| `SURF-001` - `003` | **Partial** | `ShellPanel.swift`, `ControlCenterController.swift` | Basic `NSPanel` exists, but has fixed sizing; fluid animated content resizing does not exist. |
| `SURF-004` - `005` | **Partial** | Controllers | Panels toggle on click, but hover grace zones, hover close delays, and unified modal backdrops do not exist. |
| Concave Fillets | **Missing** | None | Connected mode ("gothic corners") and concave arc bridges are completely absent. Popouts look like generic floating boxes. |
| Frame Module | **Missing** | None | Upstream's screen-edge decorative `Frame` module does not exist in the port. |

### Audit Verdict:
The port implements basic detached AppKit windows, but **lacks DMS's signature connected-mode geometry** (concave fillet arcs) and dynamic window frame resizing animations. Parity: **~25%**.

---

## 7. Reimplementation Checklist

- [ ] Create `ConnectedFilletShape.swift` in SwiftUI to render concave fillet bridges tangent to bar edges.
- [ ] Implement `AnimatedPanelFrame.swift` supporting smooth NSPanel dimension animations without frame dropping.
- [ ] Implement `HoverGraceZoneTracker.swift` calculating geometric convex hulls between triggers and popout bodies.
- [ ] Add `NSVisualEffectView` backdrops with dynamic Material 3 tinting.
