# 25 — Notifications & Notification Center Specification (`NOTIF`)

## 0. Coverage Manifest
- `quickshell/Services/NotificationService.qml` (1,554 lines) — Master notification daemon service, D-Bus org.freedesktop.Notifications host, rate limiting (`maxIngressPerSecond: 20`), deduplication window (`notificationDedupBurstMs: 5000`), persistent history (`notification_history.json`), image thumbnail caching (`notification_images`), rule evaluator (app matching, sound overrides, urgency levels, priority whitelist).
- `quickshell/Modules/Notifications/Popup/NotificationPopupManager.qml` (574 lines) — Multi-screen popup window manager, screen edge anchoring, stack order calculations, and layout compaction.
- `quickshell/Modules/Notifications/Popup/NotificationPopup.qml` (1,042 lines) — Individual floating popup toast banner, spring enter/exit transitions, timeout countdown progress bar, interactive swipe-to-dismiss physics, and expanded action trays.
- `quickshell/Modules/Notifications/NotificationCard.qml` (435 lines) — Shared card component with rich Markdown-to-HTML body formatting, app icon, timestamp, category badges, and image attachments.
- `quickshell/Modules/Notifications/NotificationActions.qml` (120 lines) — Action button strip (default action, custom app actions, reply inputs, file openers).
- `quickshell/Modules/Notifications/NotificationContextMenu.qml` (51 lines) — Right-click contextual actions (Mute app, Create notification rule, Copy text, Clear all from app).
- `quickshell/Modules/Notifications/NotificationSwipeRow.qml` (153 lines) & `NotificationSwipeWheel.qml` (77 lines) — Gesture-driven horizontal swipe dismiss with rubber-banding and velocity flick thresholds.
- `quickshell/Modules/Notifications/NotificationSwipeGroup.qml` (34 lines) & `NotificationMetrics.qml` (70 lines) — Spacing metrics, corner radii, maximum visible count (`maxVisibleNotifications = 4`).
- `quickshell/Modules/Notifications/DndPresets.qml` (59 lines) — Do Not Disturb timers (15m, 1h, 2h, 8h, until tomorrow, indefinite).
- `quickshell/Modules/Notifications/Center/NotificationCenterPopout.qml` (245 lines) — Slide-over panel host for historical notification center.
- `quickshell/Modules/Notifications/Center/NotificationCenterContent.qml` (154 lines) & `NotificationHeader.qml` (164 lines) — Header bar with unread badge counter, DND toggle switch, and "Clear All" button.
- `quickshell/Modules/Notifications/Center/HistoryNotificationList.qml` (365 lines) & `HistoryNotificationCard.qml` (69 lines) — Grouped history view partitioned by date and application.
- `quickshell/Modules/Notifications/Center/KeyboardNavigatedNotificationList.qml` (337 lines) & `NotificationKeyboardController.qml` (518 lines) — Full keyboard navigation (Vim `j`/`k`, arrows, Enter to trigger action, Delete to dismiss).
- `quickshell/Modules/Notifications/Center/NotificationKeyboardHints.qml` (83 lines) & `NotificationEmptyState.qml` (33 lines) — Keyboard shortcut legend and "No notifications" placeholder.
- `core/cmd/dms/commands_notify.go` — Comprehensive `dms notify` CLI implementing standard `notify-send` syntax with `--urgency`, `--app-name`, `--icon`, `--file`, `--action`, and `--wait`.
- `core/internal/server/notifyactions/*` — IPC socket protocol dispatching action invocation callbacks back to notification publishers.

---

## 1. Purpose & User-Visible Behavior
The notification subsystem provides a complete, high-fidelity notification server that intercepts, displays, logs, and manages desktop alerts with Material Design 3 physics and styling.

Key user-visible behaviors include:
1. **Interactive Popup Stacking**:
   - Up to 4 alerts appear simultaneously stacked on the chosen screen corner (`top-right`, `top-center`, `bottom-right`, etc.).
   - Excess alerts queue up in memory (`maxQueueSize: 32`) and dequeue smoothly as active cards are dismissed or expire.
   - Each card features an optional timeout progress bar smoothly depleting over its lifetime (default 5000 ms, configurable per urgency).
2. **Gesture & Swipe Physics**:
   - Users can swipe cards left or right to dismiss them with natural momentum and spring rebound.
   - Dragging past the dismiss threshold triggers a fade and exit slide; releasing before snaps back.
3. **Rich Media & File Actions**:
   - Notifications support embedded images, large thumbnails, app icons, and inline action buttons (e.g., "Reply", "Open File", "Open Containing Folder").
4. **Notification Center & History**:
   - Clicking the bell/notif icon in the bar opens the Notification Center popout.
   - History logs previous notifications up to a retention cap, grouped by application and relative time ("5m ago", "Earlier today").
   - A single click on "Clear All" executes a cascading dismiss animation.
5. **Rules Engine & Do Not Disturb**:
   - Per-app rules allow muting sounds, forcing silent delivery, overriding popup duration, or bypassing DND.
   - DND modes allow silencing popups while continuing to log alerts to the history center.

---

## 2. Layout & Visual Tokens
- **Popup Dimensions**:
  - `popupWidth`: 360 pt.
  - `popupMinHeight`: 80 pt, `popupMaxHeight`: 240 pt.
  - `popupGap`: 8 pt.
  - `popupRadius`: 16 pt (M3 Medium Shape).
- **History Center Dimensions**:
  - `sheetWidth`: 420 pt.
  - `sheetHeight`: 680 pt or screen height minus bar.
- **M3 Elevation & Colors**:
  - Popup surface: `Theme.surfaceContainerHigh` with 1 pt border `Theme.outlineVariant` (alpha 0.16).
  - Urgency Low: subtle badge, no sound.
  - Urgency Normal: standard surface, gentle chime.
  - Urgency Critical: `Theme.errorContainer` border tint, persistent (does not auto-expire), overrides DND.

---

## 3. Internal Logic & State Management
- **Deduplication Engine**:
  - Incoming alerts with identical `(appName, summary, body)` within a 5-second burst window are merged into an incremented badge (`" (2)"`) rather than spawning multiple popups.
- **Rate Limiting**:
  - Ingress throttled at 20 alerts/sec to prevent spam attacks from crashing the compositor.
- **Persistence**:
  - Notification history serialized to `~/.cache/dms/notification_history.json`.
  - Image attachments cached to `~/.cache/dms/notification_images/`.

---

## 4. Configuration Schema
| Settings Key | Type | Default | Description |
|---|---|---|---|
| `notifications.enabled` | bool | `true` | Master notification system switch |
| `notifications.popupLocation` | string | `"top-right"` | Corner anchor (`top-right`, `bottom-right`, `top-center`) |
| `notifications.timeoutLowMs` | int | `3000` | Expiration time for low urgency |
| `notifications.timeoutNormalMs`| int | `5000` | Expiration time for normal urgency |
| `notifications.timeoutCriticalMs`| int | `0` | Expiration time for critical (0 = persistent) |
| `notifications.maxVisible` | int | `4` | Max active popups displayed simultaneously |
| `notifications.soundEnabled` | bool | `true` | Play alert sounds on incoming notification |
| `notifications.dndEnabled` | bool | `false` | Do Not Disturb active status |
| `notifications.dndUntil` | string | `""` | ISO timestamp when DND automatically turns off |
| `notifications.rules` | array | `[]` | List of rule objects `[{app, mute, bypassDnd, sound}]` |

---

## 5. IPC / CLI API
| Command | Arguments | Returns | Description |
|---|---|---|---|
| `dms notify <summary> [body]` | `--urgency`, `--app-name`, `--icon`, `--file`, `--action`, `--wait` | `int (id)` | Sends notification via CLI |
| `notifications.clearAll` | `none` | `void` | Clears all active and historical alerts |
| `notifications.dismiss` | `id: int` | `void` | Dismisses specific notification ID |
| `notifications.toggleCenter`| `none` | `bool` | Toggles Notification Center sheet |
| `notifications.setDnd` | `enabled: bool, durationMinutes?: int` | `void` | Activates DND with optional timer |

---

## 6. macOS Mapping
- **System Notification Interception**: macOS does not allow third-party apps to intercept other apps' `UNUserNotificationCenter` alerts without private system extensions. However, DMS can act as:
  1. A standalone local notification daemon accepting alerts via `dms notify` CLI, Unix domain socket, and AppleScript/DistributedNotifications.
  2. Integration with `NSUserNotificationCenter` / `UNUserNotificationCenter` to publish native macOS notifications when requested.
- **Popup Presentation**: Native floating `NSPanel` stack placed at the top-right corner of the active display with level `.statusBar + 1`.
- **Haptic & Sound Feedback**: `NSSound` playback using macOS system chimes (`Ping`, `Tink`, `Hero`) mapped to M3 sound assets.

---

## 7. Port Audit
| Upstream File / Subsystem | Status in Port | Verdict | Details of Gap |
|---|---|---|---|
| `NotificationService.qml` (1,554 lines) | Absent | **Missing (0%)** | Port only contains an internal transient `ToastCenter.swift` for internal shell messages. No external notification daemon or queue exists. |
| `Popup/NotificationPopupManager.qml` & `NotificationPopup.qml` | Absent | **Missing (0%)** | No notification popups with countdown progress bars, swipe physics, or multi-action trays exist. |
| `Center/NotificationCenterPopout.qml` & History | Absent | **Missing (0%)** | No Notification Center sheet, no history log, no persistence in JSON, and no per-app grouping. |
| `commands_notify.go` | Absent | **Missing (0%)** | `dms notify` CLI command is absent in the port's CLI. |

---

## 8. Reimplementation Checklist
- [ ] Implement `NotificationDaemonService` listening on Unix socket for incoming notifications.
- [ ] Build `NotificationPopupManager` managing an `NSPanel` popup stack on the top-right screen corner.
- [ ] Build `NotificationCardView` supporting title, body Markdown, app icon, image thumbnails, and action buttons.
- [ ] Implement interactive horizontal drag-to-dismiss gesture with spring physics.
- [ ] Build slide-over `NotificationCenterPanel` with historical notification log grouped by app.
- [ ] Implement JSON persistence for notification history in `~/Library/Caches/dms/notification_history.json`.
- [ ] Add `dms notify` command to `dms` CLI supporting standard options (`--urgency`, `--app-name`, `--icon`, `--file`, `--action`).
