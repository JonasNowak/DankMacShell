# AUD — Audio Subsystem, Event Feedback Sounds & OSD HUD Specification

> **Upstream Reference**: Commit `699eb23`  
> **Scope**: Audio Subsystem (`AudioService.qml`, 1,959 lines), PipeWire/CoreAudio Abstraction, Device Routing, Over-Amplification Limits, Sound Themes (`assets/sounds/`), and the Complete On-Screen Display Suite (`quickshell/Modules/OSD/*`, 14 components).

---

## 0. Coverage Manifest

| Upstream Path | Lines | Role |
| :--- | :--- | :--- |
| `quickshell/Services/AudioService.qml` | 1,959 | Audio sink/source device model, volumes, muting, stream management |
| `quickshell/Services/AudioSoundPlayers.qml` | 58 | Sound effect event player (login, notifications, volume pops) |
| `quickshell/Services/PipewireAudioBackend.qml` | 41 | Linux PipeWire node scanner and volume bindings |
| `quickshell/Services/CavaService.qml` | 94 | Audio visualizer FFT spectrum analyzer integration |
| `quickshell/Modules/OSD/LevelOSD.qml` | 185 | Master base OSD HUD pill with progress bar and auto-fade timer |
| `quickshell/Modules/OSD/VolumeOSD.qml` | 80 | Audio output volume HUD with mute indicator and detail sheet trigger |
| `quickshell/Modules/OSD/MicVolumeOSD.qml` | 75 | Microphone volume HUD and mute toggle |
| `quickshell/Modules/OSD/BrightnessOSD.qml` | 80 | Display backlight brightness HUD |
| `quickshell/Modules/OSD/AudioOutputOSD.qml` | 70 | Audio output device switch notification pill |
| `quickshell/Modules/OSD/CapsLockOSD.qml` | 45 | Caps Lock status change HUD |
| `quickshell/Modules/OSD/IdleInhibitorOSD.qml` | 40 | Sleep inhibitor toggle HUD |
| `quickshell/Modules/OSD/MediaPlaybackOSD.qml` | 240 | Media play/pause and track change HUD with album art |
| `quickshell/Modules/OSD/MediaVolumeOSD.qml` | 65 | Application-specific stream volume HUD |
| `quickshell/Modules/OSD/PowerProfileOSD.qml` | 55 | Power profile switch indicator (Power Saver, Balanced, Performance) |
| `quickshell/Modules/OSD/WorkspaceOSD.qml` | 160 | Workspace transition indicator HUD |
| `quickshell/Modules/OSD/OsdDetailSheet.qml` | 140 | Expandable bottom sheet attached to OSD for instant device switching |
| `quickshell/Common/OSDManager.qml` | 54 | Global OSD lifecycle coordinator, screen mapping |
| `quickshell/assets/sounds/` | 10 files | Freedesktop & Plasma system audio files (`audio-volume-change.wav`, `desktop-login.wav`, etc.) |

---

## 1. Purpose & User-Visible Behavior

1. **Audio Device & Volume Management**:
   - Master volume slider with support for **over-amplification** up to 150% (`maxVolumePercent`).
   - Default output sink and input source switching with user aliases (renaming confusing hardware names).
   - Per-application volume mixer (controlling individual application streams).
2. **On-Screen Display (OSD) HUDs**:
   - Whenever hardware keys (volume, mute, mic, brightness, caps lock) are pressed, a sleek Material 3 floating pill appears on screen, displaying the active icon, progress level, and text label.
   - **Interactive OSD**: The OSD is interactive! Users can click the mute icon directly on the OSD, scrub the volume level, or tap the detail sheet arrow to immediately switch audio output devices without opening Control Center.
   - Auto-fade: Dismisses after 1,800ms of inactivity (`SettingsData.osdTimeout`).
3. **Sound Effects**:
   - Distinct audio cues play for login (`desktop-login.wav`), volume adjustments (`audio-volume-change.wav`), power connect/disconnect (`power-plug.wav`, `power-unplug.wav`), and incoming notifications.

---

## 2. Detailed Requirements

### 2.1. Audio Service Architecture (`AudioService.qml`)
- `AUD-001`: Volume normalization: Volumes are stored internally as floats (0.0 to 1.5), mapped to integer percentages (0% to 150%).
- `AUD-002`: Volume stepping: Hardware keys and scroll wheel adjust volume by `SettingsData.volumeStep` (default 5%).
- `AUD-003`: Volume feedback: When adjusting output volume, play `audio-volume-change.wav` debounced at 100ms.
- `AUD-004`: Over-amplification safety: Volumes above 100% render the progress bar in `theme.error` color to warn of clipping.

### 2.2. Master OSD Specification (`LevelOSD.qml`)
- `AUD-005`: OSD dimensions & styling:
  - Width: 260px, Height: 48px, Corner radius: 24px (`full` pill).
  - Background: M3 `surfaceContainerHigh` at `popupTransparency` opacity, with 1px `outlineVariant` border.
  - Position: Screen edge or center depending on `SettingsData.osdPosition` (`top`, `bottom`, `center`).
- `AUD-006`: OSD types and triggers:
  - `VolumeOSD`: Listens to default sink volume and mute changes.
  - `MicVolumeOSD`: Listens to default source volume and mute changes.
  - `BrightnessOSD`: Listens to screen brightness changes.
  - `CapsLockOSD`: Triggers on Caps Lock key down, showing "CAPS LOCK ON" or "CAPS LOCK OFF".
  - `AudioOutputOSD`: Displays device name when headphones/Bluetooth connect.

---

## 3. Wayland/Linux Mechanisms → macOS Mapping

1. **PipeWire Audio Engine**:
   - Linux uses PipeWire / PulseAudio via D-Bus / C libraries.
   - **macOS Approach**: Use native `CoreAudio` HAL APIs:
     - Default output device: `kAudioHardwarePropertyDefaultOutputDevice`.
     - Volume: `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`.
     - Device change listener: `AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject), ...)`.
2. **Audio Event Playback**:
   - Linux uses libcanberra / paplay.
   - **macOS Approach**: Play bundled WAV files using `NSSound` or `AVAudioPlayer` on dedicated audio cues thread.
3. **Caps Lock State Tracking**:
   - Linux uses evdev or compositor key events.
   - **macOS Approach**: Query `CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)` and monitor `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)`.

---

## 4. Port Audit (Current macOS Port vs. Upstream)

| Requirement ID | Status | Port File(s) | Audit Findings / Deficiencies |
| :--- | :--- | :--- | :--- |
| `AUD-001` - `003` | **Partial** | `AudioService.swift` | Implements basic CoreAudio volume read/write, but lacks over-amplification (>100%), per-app stream control, and volume feedback sounds. |
| `AUD-005` - `006` | **Partial** | `OSDController.swift`, `OSDView.swift` | Simple floating box exists for volume and brightness, but lacks: CapsLock OSD, Mic OSD, MediaPlayback OSD, AudioOutput switch OSD, interactive scrubbing, and the expandable detail sheet. |
| Feedback Sounds | **Missing** | None | No system sound playback exists for volume changes or login. |

### Audit Verdict:
The port implements basic CoreAudio volume adjustments and a rudimentary OSD, but **omits 8 out of the 10 OSD HUD types**, lacks interactive OSD capabilities, and has no sound feedback engine. Parity: **~30%**.

---

## 5. Reimplementation Checklist

- [ ] Complete `OSDController.swift` to support all 10 OSD HUD kinds (Volume, Mic, Brightness, CapsLock, Media, OutputSwitch, etc.).
- [ ] Add interactive touch/scrubbing and expandable device selector sheet to `OSDView.swift`.
- [ ] Implement `SoundFeedbackService.swift` playing bundled WAV sounds for login, volume, and power events.
- [ ] Implement Caps Lock state monitoring via `CGEventSource.flagsState`.
