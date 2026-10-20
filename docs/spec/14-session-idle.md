# IDLE — Session Idle Management, Power Actions & Privacy Indicators Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Idle Timeouts Chain (`IdleService.qml`), Session Management (`SessionService.qml`, 1,057 lines), Sleep Inhibitors, Hardware Privacy Detection (`PrivacyService.qml`), Keyboard Layout Switching (`KeyboardLayoutService.qml`), and Privacy Bar Indicators.

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `quickshell/Services/IdleService.qml` | 201 | Master idle timeout coordinator (Dim -> Lock -> DPMS -> Suspend) |
| `quickshell/Services/SessionService.qml` | 1,057 | Power actions (Lock, Suspend, Hibernate, Reboot, Shutdown, Logout) |
| `quickshell/Services/PrivacyService.qml` | 195 | Real-time surveillance detection (Microphone, Camera, Screen Sharing) |
| `quickshell/Services/KeyboardLayoutService.qml` | 206 | Keyboard input source detection and layout switching |
| `quickshell/Services/UsersService.qml` | 481 | System user account manager (avatars, full names, uid) |
| `quickshell/Services/BootEntryService.qml` | 137 | Systemd-boot / GRUB EFI bootloader entries and reboot-to-firmware |
| `quickshell/Modules/DBar/Widgets/PrivacyIndicator.qml` | 110 | DankBar privacy dot indicator (Green=Cam, Orange=Mic, Blue=Screen) |
| `quickshell/Modules/DBar/Widgets/IdleInhibitor.qml` | 95 | DankBar coffee-cup sleep inhibitor toggle pill |
| `quickshell/Modules/DBar/Widgets/KeyboardLayoutName.qml` | 80 | DankBar active keyboard layout badge (e.g. "US", "DE") |
| `core/internal/server/loginctl/` | 1,260 | Go backend logind session manager and inhibitor locks |

---

## 1. Purpose & User-Visible Behavior

1. **Cascading Idle Timeout Chain**:
   - Handles the entire power-saving lifecycle with distinct thresholds for AC Power vs. Battery:
     $$\text{User Inactive} \xrightarrow{\text{dimTimeout}} \text{Fade to Lock} \xrightarrow{\text{lockTimeout}} \text{Lock Screen} \xrightarrow{\text{dpmsTimeout}} \text{Screen Off} \xrightarrow{\text{suspendTimeout}} \text{System Sleep}$$
2. **Sleep Inhibitor ("Caffeine" Mode)**:
   - Users can temporarily inhibit idle sleep via the DankBar coffee cup widget or CLI.
   - Supports duration presets: 30 mins, 1 hour, 2 hours, 4 hours, or indefinite.
3. **Hardware Privacy Indicators**:
   - Immediately alerts the user whenever hardware sensors are tapped:
     - 🟢 **Green Dot**: Camera is actively streaming video.
     - 🟠 **Orange Dot**: Microphone is capturing audio.
     - 🔵 **Blue Pill**: Screen recording or screen share is broadcasting.
   - Automatic DND: If `notificationDndWhileScreenSharing` is enabled, notification banners are suppressed while screen sharing to prevent private message leaks.

---

## 2. Detailed Requirements

### 2.1. Idle Engine Architecture (`IdleService.qml`)
- `IDLE-001`: AC vs Battery timeout profiles:
  - Defaults on AC: Lock after 10 mins, Display Off after 15 mins, Suspend after 30 mins.
  - Defaults on Battery: Lock after 5 mins, Display Off after 7 mins, Suspend after 15 mins.
- `IDLE-002`: Smooth Fade-to-Lock: 15 seconds before the screen locks, the display opacity smoothly interpolates down (`FadeToLockWindow.qml`). Any mouse movement immediately cancels the fade.

### 2.2. Privacy Engine (`PrivacyService.qml`)
- `IDLE-003`: Microphone recording detection: Monitors all system audio capture streams. When active, sets `microphoneActive = true`.
- `IDLE-004`: Camera recording detection: Monitors all video capture devices. When streaming, sets `cameraActive = true`.
- `IDLE-005`: Screen capture detection: Sets `screenSharingActive = true` when active screen sharing sessions exist.

---

## 3. Wayland/Linux Mechanisms → macOS Mapping

1. **Idle Timeouts (`ext_idle_notifier_v1`)**:
   - Upstream binds to Wayland idle notifier protocol.
   - **macOS Approach**: Read idle seconds using `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .any)` or IOKit `IOHIDGetIdleTime()`. Manage sleep inhibitors via `IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep, ...)`.
2. **Power Actions**:
   - Linux uses `loginctl poweroff`, `systemctl suspend`.
   - **macOS Approach**:
     - Lock: Execute `/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession -suspend` or `SACLockScreenImmediate()`.
     - Sleep: `pmset sleepnow`.
     - Restart: AppleScript `tell application "System Events" to restart`.
     - Shutdown: AppleScript `tell application "System Events" to shut down`.
     - Logout: AppleScript `tell application "System Events" to log out`.
3. **Privacy Monitoring**:
   - Linux inspects PipeWire stream node classes.
   - **macOS Approach**: Use `AVCaptureDevice` notifications and CoreMediaIO device property listeners (`kCMIODevicePropertyDeviceIsRunningSomewhere`).

---

## 4. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| `IDLE-001` - `002` | **Missing** | None | The cascading idle timeout chain (Dim -> Lock -> DPMS -> Suspend) and Fade-to-Lock window do not exist in the port. |
| Sleep Inhibitor | **Partial** | `IdleInhibitService.swift` (49 lines) | Creates an `IOPMAssertion`, but lacks duration presets, countdown timers, and automatic release. |
| `IDLE-003` - `005` | **Missing** | None | **Privacy detection does not exist in the port**. Camera, microphone, and screen share monitoring are completely absent. |
| Power Menu | **Partial** | `PowerMenuController.swift`, `PowerMenuView.swift` | Simple 5-button dialog exists, but lacks hold-to-confirm options and keyboard shortcuts. |

### Audit Verdict:
The port implements a basic sleep assertion toggle and a simple power dialog, but **completely lacks the cascading idle timeout engine, fade-to-lock animations, and privacy hardware monitoring**. Parity: **~20%**.

---

## 5. Reimplementation Checklist

- [ ] Implement `IdleEngineService.swift` evaluating `IOHIDGetIdleTime` against AC/Battery timeout thresholds.
- [ ] Build `FadeToLockWindowController.swift` with smooth screen dimming.
- [ ] Implement `PrivacyService.swift` using `CoreMediaIO` and `CoreAudio` to detect active camera/mic recording.
- [ ] Build `PrivacyIndicatorView.swift` for DankBar with Green/Orange/Blue status dots.
