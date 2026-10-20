# 26 — Clipboard Manager Specification (`CLIP`)

## 0. Coverage Manifest
- `quickshell/Modals/Clipboard/ClipboardModal.qml` & `ClipboardHistoryModal.qml` (178 lines) — Modal window surface hosts, screen centering, dismiss handlers, and blur backdrop.
- `quickshell/Modals/Clipboard/ClipboardContent.qml` (365 lines) & `ClipboardHistoryContent.qml` (368 lines) — Master clipboard views, search filter bar, tab switcher (All, Pinned, Images, Text, Code), and virtualized entry list.
- `quickshell/Modals/Clipboard/ClipboardEntry.qml` (240 lines) — Item delegate displaying text snippets with syntax detection, image thumbnails, character/byte counters, timestamp, pin badge, and action buttons.
- `quickshell/Modals/Clipboard/ClipboardEditor.qml` (520 lines) — Dedicated in-situ editor modal enabling inline modification of clipboard text before pasting or storing.
- `quickshell/Modals/Clipboard/ClipboardImagePreview.qml` (140 lines) & `ClipboardThumbnail.qml` (260 lines) — Async thumbnail generation, high-DPI image viewer with dimension overlay and aspect-ratio preservation.
- `quickshell/Modals/Clipboard/ClipboardContextMenu.qml` (135 lines) — Contextual menu: Pin/Unpin, Edit, Delete, Clear All Unpinned, Generate QR Code, Set Self-Destruct Timer.
- `quickshell/Modals/Clipboard/ClipboardKeyboardController.qml` (290 lines) & `ClipboardKeyboardHints.qml` (78 lines) — Rich keyboard shortcuts: Vim navigation (`j`/`k`), quick filter (`/`), pin toggle (`p`), edit entry (`e`), delete (`d`/`Backspace`), paste directly (`Enter`).
- `quickshell/Modals/Clipboard/ClipboardActions.qml` (88 lines), `ClipboardHeader.qml` (26 lines), `ClipboardConstants.qml` (38 lines), `ClipboardHistoryPopout.qml` (145 lines) — Popout anchor support and metric constants.
- `core/internal/server/clipboard/manager.go` (2,365 lines) — High-performance clipboard daemon engine utilizing `bbolt` embedded database:
  - Deduplication & hashing (SHA-256)
  - Multi-MIME type storage (`text/plain`, `text/html`, `image/png`, `image/jpeg`, `image/webp`)
  - Password / sensitive content heuristic detection (1Password, Bitwarden, KeePassxc suppression)
  - Configurable retention limits (item count, max byte size)
  - Self-destruct wipe timers (e.g. clear after 60s)
  - Pinned item persistence immune to eviction
- `core/internal/server/clipboard/handlers.go` (448 lines) & `types.go` (195 lines) — IPC endpoints for list, get, copy, delete, pin, edit.
- `core/cmd/dms/commands_clipboard.go` (~800 lines) — Full CLI command tree: `dms clipboard copy`, `paste`, `list`, `pin`, `delete`, `clear`, `edit`, `wipe`, `monitor`.

---

## 1. Purpose & User-Visible Behavior
The DMS Clipboard Manager is a robust, persistent clipboard history modal with rich content previews, sensitive data detection, in-place text editing, and powerful search.

Key user-visible behaviors include:
1. **Rich Content Rendering**:
   - Plain text with automatic whitespace normalization and line count tags.
   - Code snippets with automatic language heuristic syntax highlighting.
   - Images (PNG, JPEG, GIF, WebP) displayed as crisp thumbnails with dimensions and file size.
   - Hex color codes rendered with inline circular color preview chips.
2. **In-Situ Clipboard Editor**:
   - Pressing `e` or clicking "Edit" opens a modal text editor allowing the user to modify text directly in the history buffer before copying or pasting.
3. **Sensitive Content & Password Shield**:
   - Passwords copied from password managers (detected via window title or `x-kde-passwordManagerHint`) are masked by default (`••••••••`) and auto-deleted after a configurable timer (default: 60s).
4. **Pinning & Organization**:
   - Users can pin frequently used snippets (code templates, signatures, addresses) so they are never purged during history cleanup.
   - Filter tabs: All, Pinned, Images, Text.
5. **Instant QR Code Sharing**:
   - Any text item can be instantly converted into a high-res QR code for mobile scanning with one click.
6. **Vim & Fast Keyboard Navigation**:
   - Full keyboard navigation with number quick-picks (1-9 to immediately paste item).

---

## 2. Layout & Visual Tokens
- **Modal Dimensions**:
  - `modalWidth`: 580 pt.
  - `modalHeight`: 620 pt.
  - `entryHeight`: 64 pt (text) / 96 pt (image).
  - `entryRadius`: 12 pt.
- **Search Header**:
  - Search bar height: 48 pt with leading magnifying glass and trailing clear button.
  - Filter chip bar height: 36 pt (`All`, `Pinned`, `Images`, `Text`, `Code`).
- **M3 Colors & Elevation**:
  - Surface: `Theme.surfaceContainer` with 1 pt border `Theme.outlineVariant` (alpha 0.16).
  - Pinned badge: `Theme.primary` pill with contrast pin icon.
  - Sensitive mask: `Theme.errorContainer` subtle tint.

---

## 3. Internal Logic & State Management
- **Persistence & Storage**:
  - Utilizes embedded key-value database (`bbolt` in Go / SQLite in macOS port) stored at `~/.local/share/dms/clipboard.db`.
  - Binary blobs (images > 64 KB) saved to disk cache `~/.cache/dms/clipboard_images/` with UUID references in the database.
- **Deduplication**:
  - Content SHA-256 hash checked on every copy event. If content exists, it is moved to the top of the history list with an updated timestamp rather than duplicated.
- **Eviction Policy**:
  - Default maximum items: 200 (configurable).
  - When limit is reached, oldest unpinned item is evicted. Pinned items are never auto-evicted.

---

## 4. Configuration Schema
| Settings Key | Type | Default | Description |
|---|---|---|---|
| `clipboard.enabled` | bool | `true` | Master clipboard manager switch |
| `clipboard.maxItems` | int | `200` | Maximum history items retained |
| `clipboard.storeImages` | bool | `true` | Enable saving copied images |
| `clipboard.maxImageBytes` | int | `10485760` | Max image file size (10 MB) |
| `clipboard.wipeSensitiveAfter` | int | `60` | Seconds before auto-deleting sensitive items |
| `clipboard.autoPaste` | bool | `true` | Automatically paste on item selection |
| `clipboard.keyboardNavigation`| bool| `true` | Enable Vim / arrow shortcuts |

---

## 5. IPC / CLI API
| Command | Arguments | Returns | Description |
|---|---|---|---|
| `dms clipboard copy [text]` | `stdin or arg` | `void` | Copies text to clipboard |
| `dms clipboard paste` | `[index: int]` | `string` | Outputs clipboard content |
| `dms clipboard list` | `--limit, --json` | `json` | Lists recent clipboard items |
| `dms clipboard pin <id>` | `id: string` | `void` | Pins an item |
| `dms clipboard delete <id>` | `id: string` | `void` | Deletes an item |
| `dms clipboard clear` | `--all` | `void` | Clears unpinned (or all) history |
| `dms clipboard edit <id>` | `id: string, text: string`| `void` | Modifies an item's content |

---

## 6. macOS Mapping
- **System Pasteboard Monitoring**:
  - Monitor `NSPasteboard.general` change count (`changeCount`) via background timer (polling every 250ms) or `NSEvent` paste notifications.
  - Read types: `.string`, `.rtf`, `.html`, `.png`, `.tiff`, `.fileURL`.
- **Automatic Paste Injection**:
  - When auto-paste is enabled, close the clipboard modal, switch focus to the previous active application (`NSRunningApplication.activate()`), and synthesize `Cmd+V` using `CGEventCreateKeyboardEvent(nil, 0x09, true)` with `kCGEventFlagMaskCommand`.
- **Database Engine**:
  - Use SQLite (`GRDB.swift` or native `sqlite3`) stored at `~/Library/Application Support/dms-shell/clipboard.sqlite3`.

---

## 7. Port Audit
| Upstream File / Subsystem | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `quickshell/Modals/Clipboard/**` (14 files, 2,807 lines) | Partially Insp. | **Major Gap** | Port has a rudimentary 174-line `ClipboardView.swift` and 117-line `ClipboardStore.swift`. |
| `ClipboardEditor.qml` (In-situ text editor) | Absent | **Missing (0%)** | No ability to edit clipboard text before pasting or storing. |
| Sensitive password masking & wipe timers | Absent | **Missing (0%)** | No detection of password manager copies, no masking (`••••••••`), and no 60s auto-wipe. |
| Persistent DB (`manager.go`, 2,365 lines) | Minimal | **Divergent** | Port keeps an in-memory or transient JSON array instead of a robust SQLite/bbolt database with image caching. |
| Full CLI interface (`commands_clipboard.go`) | Absent | **Missing (0%)** | No `dms clipboard` subcommands in port CLI. |

---

## 8. Reimplementation Checklist
- [ ] Upgrade `ClipboardStore` to SQLite database with binary image storage and SHA-256 deduplication.
- [ ] Implement sensitive data detection and automatic self-destruct timers.
- [ ] Build `ClipboardEditorView` modal for editing clipboard text before pasting.
- [ ] Build rich filter chips (All, Pinned, Images, Text, Code) and instant search filtering.
- [ ] Implement synthetic `Cmd+V` event injection via CoreGraphics for seamless auto-paste into the prior active app.
- [ ] Add `dms clipboard [copy|paste|list|pin|delete|clear|edit]` CLI subcommands.
