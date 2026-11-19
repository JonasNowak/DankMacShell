# Security Policy

DankMacShell (DMS) is a native macOS shell that runs with elevated user-level capabilities (Accessibility, Input Monitoring, system-wide event taps, local IPC). Security reports are welcome and handled confidentially.

This policy follows the guidance of **ISO/IEC 29147** (vulnerability disclosure) and **ISO/IEC 30111** (vulnerability handling process); our internal practices are informed by **ISO/IEC 27001:2022** Annex A controls. We are not ISO-certified — these standards guide how we receive, triage, fix, and disclose vulnerabilities.

## Reporting a vulnerability

**Please do not open a public issue for security vulnerabilities.**

Use GitHub Private Vulnerability Reporting:

👉 https://github.com/JonasNowak/DankMacShell/security/advisories/new

Include, where possible:

- Affected version / commit and install method (DMG, Homebrew cask, Nix, source build) (make sure you are using the latest version!)
- Step-by-step reproduction or proof of concept
- Impact assessment (e.g. unauthorized IPC commands, reading clipboard history, keylogging via event taps, command execution through the `dms://` URL scheme)
- A suggested fix, if you have one

### What to expect

| Stage | Timeline |
| --- | --- |
| Acknowledgement of your report | within 72 hours |
| Initial triage and severity assessment | within 7 days |
| Fix developed and released | severity-dependent; critical issues prioritized |
| Public disclosure | coordinated with you, typically within 90 days |

We can request a **CVE** through GitHub's CNA and will credit you in the published advisory unless you prefer to remain anonymous.

### Safe harbor

Good-faith security research conducted in accordance with this policy is authorized. We will not pursue legal action against researchers who avoid privacy violations, data destruction, and service interruption, and who give us reasonable time to fix an issue before public disclosure.

## Scope

### In scope

| Area | Notes |
| --- | --- |
| `dms://` URL scheme handling | `AppDelegate.handleGetURL` — strict allowlist of benign UI navigation/toggle commands (destructive/mutating commands rejected) |
| Local IPC | Unix socket `~/Library/Application Support/DMS/dms.sock` (`0600` inside `0700` DMS dir) and the `dms-gop` REST API on `127.0.0.1:63484` |
| Clipboard history | Reading/storing pasteboard contents (`0600`); sensitive-app filtering (Apple Passwords, Keychain Access, 1Password, Bitwarden, KeePassXC, Proton Pass, …) |
| Input interception | CGEventTap media-key swallowing and synthetic key injection (auto-paste) |
| Plugin registry & lockfile | `plugins.lock.json` and registry metadata with `repoURL`s |
| Build & distribution | `build.sh`, `scripts/assemble-app.sh`, DMG packaging, release checksums |
| Network egress | Weather (Open-Meteo), lyrics (LRCLIB), IP geolocation |

### Out of scope
- Third party libraries not maintained by us.
- Anything requiring the Accessibility / Input Monitoring permissions DMS requests — those permissions are DMS's trust boundary, not a vulnerability by themselves
- The fact that the release DMG is unsigned (see Known limitations) — but substituted or tampered release artifacts are in scope

## Supported versions

Security fixes are applied to the **latest release** and the **`main`** branch only.

| Version | Supported |
| --- | --- |
| Latest release (v0.9.x) | Yes |
| `main` branch | Yes |
| Older releases | No |

DMS is pre-1.0: the config format and IPC surface may change between minor versions, so please test against the latest release.

## Known limitations (publicly documented)

- The release DMG is **not signed or notarized** — verify the SHA-256 in `checksums.txt` on the release page before installing.
- The geolocation fallback uses HTTPS (`https://get.geojs.io/v1/ip/geo.json`) only when `weatherLocation` is `auto`.
- IPC socket `dms.sock` is explicitly `chmod 0600` inside a `0700` `~/Library/Application Support/DMS` directory, and `dms-gop` binds `127.0.0.1:63484`.
- The app is intentionally **not sandboxed** — it is a shell and needs system-wide access.

## Security practices

- **Secrets:** none are stored in the repository. The self-signed `dms-cert` used by `scripts/assemble-app.sh` is generated locally at build time and never committed.
- **Dependencies:** Swift packages are pinned via `Package.resolved`; updates are reviewed before merging.
- **CI:** releases are built from source in GitHub Actions (`.github/workflows/build.yml`) on Apple-hosted runners, and every release publishes a `checksums.txt` (SHA-256) next to the DMG.
- **Permissions:** Accessibility and Input Monitoring are requested only for features that need them; `dms doctor` shows the current permission state.
