# LOCK — Lock Screen, Authentication, Screensavers & Greeter Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Session Lock (`Lock.qml`, `LockSurface.qml`, `LockScreenContent.qml`), PAM Conversation (`Pam.qml`, `core/internal/pam/`), Biometric/Fingerprint/U2F Flow, Video Screensaver (`VideoScreensaver.qml`), Fade-to-Lock Overlay (`FadeToLockWindow.qml`), and Greetd Login Manager (`Modules/Greetd/*`, `DMSGreeter.qml`).

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `quickshell/Modules/Lock/Lock.qml` | 180 | Session lock coordinator, Wayland session-lock protocol integration |
| `quickshell/Modules/Lock/LockSurface.qml` | 220 | Per-monitor secure lock surface window |
| `quickshell/Modules/Lock/LockScreenContent.qml` | 650 | Lock screen UI (avatar, user name, password input, clock, weather, media) |
| `quickshell/Modules/Lock/LockScreenBackground.qml` | 310 | Background rendering, wallpaper blur sampler, dimming scrim |
| `quickshell/Modules/Lock/Pam.qml` | 420 | PAM conversation state machine: password, fingerprint, U2F tokens |
| `quickshell/Modules/Lock/LockStatusRow.qml` | 140 | Status indicators: Caps Lock, battery, network, charging pulse |
| `quickshell/Modules/Lock/VideoScreensaver.qml` | 195 | Video screensaver controller (MP4 / WebM looped playback) |
| `quickshell/Modules/Lock/VideoScreensaverPlayer.qml` | 110 | Hardware-accelerated video surface |
| `quickshell/Modules/Lock/FadeToLockWindow.qml` | 120 | Pre-lock dimming overlay window |
| `quickshell/Modules/Lock/FadeToDpmsWindow.qml` | 110 | Pre-DPMS monitor sleep fading window |
| `quickshell/Modules/Greetd/` | 8 files | Greetd login manager UI: session picker, user switcher, theme sync |
| `quickshell/DMSGreeter.qml` | 120 | Standalone greeter mode root |
| `core/internal/pam/` | 986 | Go backend PAM authentication wrapper |

---

## 1. Purpose & User-Visible Behavior

1. **Material Design 3 Lock Screen**:
   - A secure, full-screen lock screen displayed across all monitors.
   - Large hero clock (`DM Serif Display`), current date, and active weather conditions.
   - User profile card: Avatar picture, full user name, host name.
   - Password field: Rounded capsule with password reveal toggle, caps lock warning badge, and an authentic **shake animation** on authentication failure.
2. **Multi-Factor / Biometric Authentication**:
   - Fingerprint recognition prompt: Displays fingerprint icon that lights up green on match or shakes red on mismatch.
   - Security Key (U2F/FIDO2): Prompts "Touch your security key to unlock".
3. **Media Controls on Lock**:
   - If audio is playing when locked, an interactive compact media card appears on the lock screen with playback controls and track title.
4. **Video Screensaver**:
   - After a configured period of inactivity on the lock screen, plays seamless 4K video aerials or animations until user touches a key.

---

## 2. Detailed Requirements

### 2.1. Visual Hierarchy & Dimensions (`LockScreenContent.qml`)
- `LOCK-001`: Center Auth Card:
  - Width: 360px, padding 32px (`Theme.spacingXXL`), corner radius 28px (`Shape.corners.xl`).
  - Avatar: Circular 80x80px photo (`Theme.surfaceContainerHigh` placeholder if no image).
  - Password Input: Height 48px, background `Theme.surfaceContainerHighest`, radius 24px.
  - Wrong password response: Card executes horizontal spring shake ($\pm 16\text{px}$, 3 oscillations over 350ms) and displays error message in `Theme.error`.
- `LOCK-002`: Multi-Monitor Behavior:
  - Interactive auth card displays exclusively on the primary or focused monitor.
  - Secondary displays render the blurred wallpaper backdrop, ambient clock, and screensaver video without input fields.

---

## 3. Wayland/Linux Mechanisms → macOS Mapping

1. **Wayland `ext-session-lock-v1`**:
   - Linux compositors provide a dedicated protocol that blocks all other windows and screenshots.
   - **macOS Approach**:
     - System Lockwindow cannot be fully replaced by third-party apps for boot-up login.
     - **In-Session Shell Lock**: Create full-screen borderless `NSPanel` on all connected `NSScreen`s at `CGShieldingWindowLevel()` (above all normal windows and Dock).
     - Capture keyboard focus with `[NSApp activateIgnoringOtherApps:YES]` and `CGAssociateMouseAndMouseCursorPosition(true)`.
     - Touch ID & Password Authentication: Use Apple `LocalAuthentication` framework:
       ```swift
       let context = LAContext()
       context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock DMS") { success, error in
           if success { DispatchQueue.main.async { unlockScreen() } }
       }
       ```
     - For fallback or system lock: Call `/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession -suspend`.
2. **Greetd (Display Manager)**:
   - Linux uses Greetd for initial user login.
   - **macOS Approach**: Marked **N/A on macOS** (macOS `loginwindow` is proprietary and SIP-protected). The in-session lock screen satisfies the user-facing visual and security requirement.

---

## 4. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| `LOCK-001` - `002` | **Missing** | None | **Zero lock screen implementation exists in the port**. The port only triggers system sleep or logout, with no in-shell lock UI. |
| Biometrics / Touch ID | **Missing** | None | Touch ID authentication does not exist. |
| Video Screensaver | **Missing** | None | Video playback screensaver does not exist. |
| Greetd | **N/A** | N/A | Incompatible with macOS architecture (expected). |

### Audit Verdict:
The port **completely lacks the Lock Screen subsystem and video screensaver**. Parity: **0%**.

---

## 5. Reimplementation Checklist

- [ ] Implement `LockScreenWindowController.swift` hosting `CGShieldingWindowLevel` shielding windows on all displays.
- [ ] Build `LockScreenContentView.swift` in SwiftUI with M3 hero clock, avatar, and password field with shake animations.
- [ ] Connect `LocalAuthentication` for instant Touch ID biometrics unlock.
- [ ] Implement `AVPlayerView` backing for optional video screensavers.
