# FILE — Embedded File Browser & Trash Management Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Embedded M3 File Browser Modal (`dank-qml-common/DCommon/FileBrowser/*`, 45 components), Views (List, Grid, Columns), Places Sidebar, Navigation History, Search, Previews, Inline Renaming, Rubber Band Selection, Trash Service (`TrashService.qml`), and Dock Trash Integration.

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `DCommon/FileBrowser/FileBrowserModal.qml` | 185 | Top-level floating window modal, mode switching (open, save, folder) |
| `DCommon/FileBrowser/FileBrowserView.qml` | 320 | Main container coordinating sidebar, breadcrumbs, search, and body |
| `DCommon/FileBrowser/FileBrowserSidebar.qml` | 210 | Places sidebar (Home, Desktop, Documents, Downloads, Music, Videos, Disks) |
| `DCommon/FileBrowser/FileListView.qml` | 280 | Detailed list view table (Name, Size, Modified Date, Permissions) |
| `DCommon/FileBrowser/FileGridView.qml` | 240 | Grid icon view with dynamic thumbnail generation |
| `DCommon/FileBrowser/FileColumnsView.qml` | 310 | Multi-column cascading miller-columns view (macOS Finder style) |
| `DCommon/FileBrowser/FilePreviewPane.qml` | 220 | Side inspection pane with image, text, audio metadata preview |
| `DCommon/FileBrowser/PathBar.qml` | 160 | Clickable breadcrumb path bar with manual editable text entry |
| `DCommon/FileBrowser/RubberBand.qml` | 95 | Interactive mouse drag selection rectangle |
| `DCommon/FileBrowser/InlineRename.qml` | 75 | In-place file rename text field with extension preservation |
| `DCommon/FileBrowser/NavigationHistory.qml` | 65 | Back / Forward navigation stack manager |
| `DCommon/FileBrowser/DirectoryModel.qml` | 190 | File system directory scanner, sorting, and hidden file filters |
| `quickshell/Services/TrashService.qml` | 159 | Trash directory monitoring, item count, empty trash confirmation |
| `core/internal/server/mime/` | 337 | MIME type detector and default application associations |
| `core/cmd/dms/commands_trash.go` | 120 | `dms trash list`, `dms trash empty` CLI commands |

---

## 1. Purpose & User-Visible Behavior

1. **Embedded M3 File Browser**:
   - Rather than kicking out to external OS dialogs for wallpaper or profile photo selection, DMS provides a **fully embedded Material 3 file picker** (`FileBrowserModal`).
   - Supports 3 view modes: **List** (compact table), **Grid** (large icon cards), and **Columns** (Miller columns).
   - Features real-time search, breadcrumbs, places sidebar, in-place renaming, and quick previews.
2. **Desktop Trash Management**:
   - Tracks the number of items in the Trash in real time (`TrashService.count`).
   - The Dock's trash icon displays full vs. empty states and opens a context menu with "Open Trash" and "Empty Trash".
   - "Empty Trash" prompts a Material 3 `ConfirmModal` before permanent deletion.

---

## 2. Detailed Requirements

### 2.1. File Browser Modal (`FileBrowserModal.qml`)
- `FILE-001`: Modal dimensions:
  - Width: 880px, Height: 580px (adaptive fullscreen on displays < 1024px width).
  - Corner radius: 28px (`Shape.corners.xl`).
  - Scrim: Dimming backdrop with click-to-dismiss.
- `FILE-002`: Modes supported:
  - `open`: Single file selection.
  - `openMultiple`: Multi-select via Command-click, Shift-click, or rubberband box.
  - `save`: File name input row at bottom with overwrite confirmation prompt.
  - `openFolder`: Restricts selection to directories only.
- `FILE-003`: Places Sidebar items:
  - Quick access: `Home` (`~`), `Desktop`, `Documents`, `Downloads`, `Pictures`, `Music`, `Videos`.
  - Mounted volumes: Dynamically lists all mounted disks and removable drives.

### 2.2. Trash Service (`TrashService.qml`)
- `FILE-004`: Real-time item count monitoring:
  - Monitors `~/.Trash` (or freedesktop `Trash/files`).
  - Updates `isEmpty: count === 0` immediately on file deletion/restoration.
- `FILE-005`: Empty Trash Confirmation:
  - Must display `ConfirmModal` with:
    - Title: `"Empty Trash"`
    - Message: `"Permanently delete %1 item(s)? This cannot be undone."`
    - Confirm button: `"Empty"` in `theme.error` color.

---

## 3. Wayland/Linux Mechanisms → macOS Mapping

1. **Trash Directory**:
   - Linux: `$XDG_DATA_HOME/Trash/files` and `info`.
   - **macOS Approach**: Target `~/.Trash`. To delete files to Trash, use `FileManager.default.trashItem(at:resultingItemURL:)` or `NSWorkspace.shared.recycle([url])`. To monitor Trash count, observe `~/.Trash` via `DispatchSource.makeFileSystemObjectSource`.
2. **File Previews**:
   - Linux uses custom thumbnail caches.
   - **macOS Approach**: Use QuickLook thumbnail generation (`QLThumbnailGenerator.shared.generateBestRepresentation(for:)`).

---

## 4. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| `FILE-001` - `003` | **Missing** | None | The embedded M3 File Browser does not exist in the port. Any file picking is either unhandled or delegates to `NSOpenPanel`. |
| `FILE-004` - `005` | **Missing** | None | Trash monitoring and empty trash confirmation do not exist in the port. |

### Audit Verdict:
The port **completely lacks the embedded File Browser module and Trash service**. Parity: **0%**.

---

## 5. Reimplementation Checklist

- [ ] Implement `TrashService.swift` observing `~/.Trash` with count updates and `recycle()` integration.
- [ ] Build `FileBrowserModalView.swift` implementing List, Grid, and Column views in SwiftUI.
- [ ] Connect `QLThumbnailGenerator` for high-performance file previews.
