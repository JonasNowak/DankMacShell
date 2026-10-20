# 29 — Color Picker, Screenshot Engine & QR Generator Specification (`UTIL`)

## 0. Coverage Manifest
- `quickshell/Modules/ColorPicker/ColorPickerContent.qml` (444 lines) & `quickshell/Modals/ColorPickerModal.qml` (180 lines) — In-shell color management modal: color spectrum wheel, HSV/RGB sliders, hex input field, recent color swatch history, and one-click copy to clipboard.
- `quickshell/Modals/QRGeneratorModal.qml` (210 lines) & `quickshell/Modals/WifiQRCodeModal.qml` (230 lines) — Text and Wi-Fi QR code dialogs: live matrix preview, ECC level selector, one-click clipboard copy, and PNG export.
- `core/internal/screenshot/screenshot.go` (420 lines) — Full-screen, window, and rectangular region capture engine; multi-monitor coordinate stitching, cursor inclusion/exclusion, and metadata serialization (`screenshotMetadata`).
- `core/internal/colorpicker/*` (190 lines) — Eyedropper magnifying loupe (8x magnification, pixel grid crosshair, RGB/Hex HUD) sampling desktop surfaces.
- `core/internal/qrcode/qrcode.go` (360 lines) — QR generation engine: supports error correction levels L/M/Q/H, Wi-Fi credentials serialization (`WIFI:S:ssid;T:auth;P:password;;`), ANSI colored terminal rendering, and PNG rasterizer with rounded module dots and custom foreground/background colors.
- `core/cmd/dms/commands_screenshot.go` (580 lines) — Comprehensive `dms screenshot` CLI supporting region selection, window targeting, direct clipboard injection, delayed capture, format selection (PNG/JPEG/WebP), and HUD overlays.
- `core/cmd/dms/commands_colorpicker.go` (180 lines) — `dms color pick` CLI for interactive terminal and desktop eyedropper sampling.
- `core/cmd/dms/commands_qr.go` (270 lines) — `dms qr` CLI for piping text or Wi-Fi configurations into terminal or image QR codes.

---

## 1. Purpose & User-Visible Behavior
This specification details DMS's built-in developer and utility toolchain: pixel-perfect color picking, region/window desktop screenshotting, and instant QR code sharing.

Key user-visible behaviors include:
1. **Interactive Screen Eyedropper**:
   - Launching eyedropper dims the screen and attaches an 8x magnifying glass loupe to the cursor.
   - The loupe displays a 9x9 zoomed pixel grid with the center pixel highlighted.
   - Live color tags (Hex, RGB, HSL) float adjacent to the cursor.
   - Left-clicking captures the color, copies it to the system clipboard, and presents an OSD notification.
2. **Screenshot HUD & Workflow**:
   - Area mode presents crosshair guidelines and real-time bounding box dimensions (e.g. `1280 × 720 px`).
   - Releasing the selection immediately captures the region, plays a camera shutter sound, copies the image to the clipboard, and saves the file into `~/Pictures/Screenshots/`.
   - A floating toast preview appears with actions: "Annotate", "Open", "Copy Path", "Delete".
3. **Wi-Fi QR Sharing**:
   - In Control Center or Settings, clicking "Share Wi-Fi" opens `WifiQRCodeModal` displaying a scannable QR code encoded with the current SSID and WPA password for effortless mobile pairing.
4. **ANSI Terminal QR**:
   - Running `dms qr "hello"` renders a readable 2-color ASCII/Unicode block QR directly inside the terminal.

---

## 2. Layout & Visual Tokens
- **Color Picker Loupe**:
  - Diameter: 120 pt circular glass.
  - Magnification: 8x zoom.
  - Border: 2 pt `Theme.primary` with subtle outer drop shadow.
- **Color Picker Modal**:
  - `sheetWidth`: 440 pt, `sheetHeight`: 520 pt.
  - Palette swatches: 16 recent color chips (28x28 pt rounded squares).
- **Screenshot HUD**:
  - Selection border: 1.5 pt dashed stroke (`Theme.primary`).
  - Dimmed scrim: `rgba(0, 0, 0, 0.45)`.
  - Dimension badge: 12 pt pill (`Theme.inverseSurface`).

---

## 3. Internal Logic & State Management
- **Eyedropper Sampling**:
  - Reads screen buffer under cursor via CoreGraphics Display Services (`CGWindowListCreateImage` or `ScreenCaptureKit`).
- **QR Encoding Algorithm**:
  - ISO/IEC 18004 standard QR generation.
  - Configurable quiet zone margin (default: 4 modules).
- **Screenshot Path Convention**:
  - Saved to `~/Pictures/Screenshots/Screenshot_YYYY-MM-DD_HH-MM-SS.png`.

---

## 4. Configuration Schema
| Settings Key | Type | Default | Description |
|---|---|---|---|
| `screenshot.outputDir` | string | `"~/Pictures/Screenshots"` | Screenshot destination folder |
| `screenshot.format` | string | `"png"` | Format (`png`, `jpg`, `webp`) |
| `screenshot.quality` | int | `95` | JPEG/WebP compression quality |
| `screenshot.copyToClipboard`| bool | `true` | Copy captured image automatically |
| `colorPicker.format` | string | `"hex"` | Default format (`hex`, `rgb`, `hsl`) |
| `colorPicker.autoCopy` | bool | `true` | Copy picked color automatically |

---

## 5. IPC / CLI API
| Command | Arguments | Returns | Description |
|---|---|---|---|
| `dms screenshot [mode]` | `--format`, `--quality`, `--output-dir`, `--no-clipboard` | `string (path)` | Captures screen, window, or area |
| `dms color pick` | `--hex`, `--rgb`, `--hsl`, `--no-copy` | `string (color)`| Launches interactive screen eyedropper |
| `dms qr [text]` | `--wifi-ssid`, `--wifi-pass`, `--stdout`, `--png` | `string` | Generates text or Wi-Fi QR code |
| `colorPicker.toggle` | `none` | `bool` | Toggles in-shell color modal |

---

## 6. macOS Mapping
- **Desktop & Window Capture**:
  - ScreenCaptureKit (`SCShareableContent`, `SCScreenshotManager`) on macOS 12.3+ for zero-lag hardware-accelerated screen and window capturing.
  - Fallback to `CGWindowListCreateImage` for instantaneous fullscreen snapshotting.
- **Screen Eyedropper**:
  - AppKit `NSColorSampler` (native macOS eyedropper loupe) or custom fullscreen overlay `NSPanel` sampling display pixels via `CGDisplayCreateImageForRect`.
- **QR Matrix Generation**:
  - CoreImage `CIFilter(name: "CIQRCodeGenerator")` with `inputCorrectionLevel: "M"`, rendered to `CGImage` or ASCII blocks (`█`, `▀`, `▄`, ` `).

---

## 7. Port Audit
| Upstream File / Subsystem | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `commands_screenshot.go` & `core/internal/screenshot` | Absent | **Missing (0%)** | Screenshot engine is 100% missing in port. No screen, window, or area capture exists. |
| `ColorPickerModal.qml` & Eyedropper Loupe | Partially Insp. | **Major Gap** | Port has a static 168-line `ColorPickerView.swift` without the interactive screen eyedropper loupe, format conversion, or swatch history. |
| `QRGeneratorModal.qml` & `commands_qr.go` | Partially Insp. | **Major Gap** | Port has a static 166-line `QRGeneratorView.swift`. It lacks Wi-Fi sharing modal, terminal ANSI rendering, custom logo embedding, and CLI commands. |

---

## 8. Reimplementation Checklist
- [ ] Implement `ScreenshotService` utilizing ScreenCaptureKit for area, window, and fullscreen captures.
- [ ] Build interactive area selection HUD panel with dimension tags and magnifying loupe.
- [ ] Implement `ColorSampler` with 8x magnifying glass loupe and format switching (`hex`, `rgb`, `hsl`).
- [ ] Build `WifiQRCodeModal` converting active Wi-Fi credentials into a scannable QR card.
- [ ] Add `dms screenshot`, `dms color pick`, and `dms qr` to `DMSCLI`.
