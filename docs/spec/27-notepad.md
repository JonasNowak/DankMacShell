# 27 — Notepad Specification (`NOTE`)

## 0. Coverage Manifest
- `quickshell/Modules/Notepad/Notepad.qml` (680 lines) — Master notepad module, slideout surface integration, popout window detachment, external file sync coordinator, file dialog open/save workflow, and external edit conflict banner.
- `quickshell/Modules/Notepad/NotepadTabs.qml` (410 lines) — Multi-tab management bar, tab creation (+), drag reordering, tab close actions, modified/dirty indicator dots, temporary draft vs saved file tab states.
- `quickshell/Modules/Notepad/NotepadTextEditor.qml` (1,305 lines) — High-performance text editor engine:
  - Line numbers gutter with synchronized scrolling
  - Incremental search & replace bar with match counter (`currentMatchIndex`, `matchCount`)
  - Live split/full Markdown preview (`previewMode: "split" | "full"`)
  - Syntax highlighting integration via plugin
  - File system watcher (`FileWatcher`) detecting external modifications and displaying reload/overwrite conflict banners
  - Auto-save engine flushing dirty buffers to session storage
- `quickshell/Modules/Notepad/NotepadSettings.qml` (580 lines) — Dedicated configuration sheet (font family, font size, tab stop spaces, line wrapping, line numbers, auto-save delay).
- `quickshell/Modules/Notepad/NotepadPopoutWindow.qml` (48 lines) — Floating window wrapper allowing the notepad to detach from the shell slideout into an independent desktop window.

---

## 1. Purpose & User-Visible Behavior
Notepad is an ambient scratchpad, code editor, and Markdown writing surface integrated directly into DMS. It provides frictionless note-taking, file editing, and auto-saving without needing to launch heavy external editors.

Key user-visible behaviors include:
1. **Multi-Tab Workspace**:
   - Users can open dozens of tabs simultaneously.
   - Tabs can be transient scratch drafts (auto-saved into session state) or bound directly to files on disk.
   - Dirty tabs display a distinct Material dot indicator.
2. **Markdown Live Preview**:
   - Toggleable split-pane or full-bleed Markdown preview rendering headers, code blocks, lists, links, and tables in real time.
3. **External Change Conflict Detection**:
   - If an open file is edited by an external program (e.g. VS Code or git), Notepad detects the timestamp change via file system watcher and displays a conflict resolution banner ("File modified on disk: Reload | Overwrite").
4. **Search and Replace**:
   - Pressing `Ctrl+F` reveals an inline search toolbar with case-sensitivity toggle, match index ("3 of 12"), and Find Next / Previous navigation.
5. **Detachable Popout Window**:
   - Users can click the "Pop out" icon in the header to detach the notepad from the shell edge into an independent movable window that floats above active applications.

---

## 2. Layout & Visual Tokens
- **Slideout / Popout Geometry**:
  - `defaultWidth`: 480 pt (compact) / 720 pt (split markdown).
  - `defaultHeight`: 640 pt.
- **Typography & Font**:
  - Monospace font family: `"JetBrains Mono"`, `"Fira Code"`, or system monospace (`SF Mono`).
  - Default font size: 13 pt.
  - Line height multiplier: 1.45.
- **M3 Colors & Styling**:
  - Editor background: `Theme.surfaceContainerLowest`.
  - Line number gutter: `Theme.surfaceContainerLow` with `Theme.outlineVariant` divider.
  - Active line highlight: `Theme.surfaceContainerHigh` (alpha 0.4).
  - Selection highlight: `Theme.primaryContainer`.
  - Search match highlight: `Theme.tertiaryContainer`.

---

## 3. Internal Logic & State Management
- **Storage Service (`NotepadStorageService`)**:
  - Maintains `tabs.json` in `~/.local/share/dms/notepad/tabs.json`.
  - Drafts stored under `~/.local/share/dms/notepad/drafts/`.
- **Auto-Save Engine**:
  - Debounced auto-save timer (default: 1,000 ms) writes buffer changes to local draft files.
- **File System Watcher**:
  - Uses `kqueue` / `FSEvents` to observe open file descriptors on disk.

---

## 4. Configuration Schema
| Settings Key | Type | Default | Description |
|---|---|---|---|
| `notepad.fontSize` | int | `13` | Editor text size in points |
| `notepad.fontFamily` | string | `"monospace"` | Editor font family |
| `notepad.tabSize` | int | `4` | Indentation spaces per tab |
| `notepad.wordWrap` | bool | `true` | Soft wrap long lines |
| `notepad.lineNumbers` | bool | `true` | Show line number gutter |
| `notepad.autoSave` | bool | `true` | Automatically save drafts |
| `notepad.autoSaveDelayMs` | int | `1000` | Inactivity delay before saving |
| `notepad.previewMode` | string | `"split"` | Markdown preview layout (`none`, `split`, `full`) |

---

## 5. IPC / CLI API
| Command | Arguments | Returns | Description |
|---|---|---|---|
| `notepad.open` | `[filePath?: string]` | `void` | Opens notepad, optionally with a file |
| `notepad.toggle` | `none` | `bool` | Toggles slideout visibility |
| `notepad.newTab` | `[title?: string]` | `string` | Creates new draft tab |
| `notepad.closeTab` | `tabId: string` | `void` | Closes specified tab |
| `notepad.saveCurrent`| `none` | `bool` | Saves active file to disk |

---

## 6. macOS Mapping
- **Editor Implementation**:
  - Upstream uses QML `TextArea` with custom line numbering and JavaScript formatting.
  - In macOS, map to `NSTextView` wrapped in SwiftUI (`NSViewRepresentable`) to leverage native macOS text layout, Cocoa undo manager (`NSUndoManager`), spell checking, and typography features.
- **File Monitoring**:
  - Use `DispatchSourceFileSystemObject` with `.write` and `.delete` flags or `FSEventStreamCreate` to monitor opened files.
- **Detached Window**:
  - `NotepadPopoutWindow` maps to a standalone `NSWindow` with `.titled`, `.closable`, `.miniaturizable`, and `.resizable` styles.

---

## 7. Port Audit
| Upstream File / Subsystem | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `quickshell/Modules/Notepad/**` (5 files, 3,023 lines) | Partially Insp. | **Major Gap** | Port has a simple 175-line `NotepadView.swift` and 149-line `NotepadStore.swift`. |
| Multi-Tab Architecture (`NotepadTabs.qml`) | Absent | **Missing (0%)** | Port only supports a single flat note or simple string list; no multi-tab bar, no drag reordering, no dirty indicators. |
| Split/Full Markdown Live Preview | Absent | **Missing (0%)** | No Markdown rendering engine or split-pane view in port. |
| Line Number Gutter & Search/Replace Bar | Absent | **Missing (0%)** | Port uses standard SwiftUI `TextEditor` without line numbers or search/replace toolbar. |
| File Watching & External Edit Detection | Absent | **Missing (0%)** | Port does not watch file changes or handle file collision banners. |
| Detachable Floating Window Mode | Absent | **Missing (0%)** | Port only embeds notepad in a fixed panel. |

---

## 8. Reimplementation Checklist
- [ ] Upgrade `NotepadStore` to support multi-tab data model with disk persistence in `~/Library/Application Support/dms-shell/notepad/`.
- [ ] Implement `NotepadTabsView` with tab switching, new tab button, and dirty modified indicator dots.
- [ ] Build `NSTextView` wrapper supporting line numbers gutter, tab indentation, and word wrapping.
- [ ] Implement live split-pane Markdown preview using `AttributedString` or `WKWebView`.
- [ ] Add Search and Replace bar with match count and navigation hotkeys (`Cmd+F`, `Cmd+G`).
- [ ] Implement file system watcher via `DispatchSource` for external file modification banners.
- [ ] Support detaching the notepad into a floating `NSWindow`.
