# Contributing to DankMacShell

Thank you for wanting to contribute! Every contribution is highly welcome — that means not only code, but also issues, discussions, documentation, and testing.

For security issues, please see [our secure disclosure policy](SECURITY.md).

## Ways to contribute

- **Code** — bug fixes and features via pull requests (see below)
- **Issues** — bug reports and feature ideas in the [issue tracker](https://github.com/JonasNowak/DankMacShell/issues)
- **Discussions** — questions, ideas, and showing off your setup
- **Docs** — fixing typos or clarifying the README and `docs/` is always appreciated

## Build and run

Requirements: **macOS 14+** with Xcode or the Command Line Tools (Swift 6 toolchain). DankMacShell is a Swift Package, so plain `swift build` works too.

```bash
git clone https://github.com/JonasNowak/DankMacShell.git
cd DankMacShell
./build.sh              # build, install to ~/Applications, install dms CLI, launch
./build.sh --no-launch  # same, but don't launch the app
make debug              # debug build without launching
```

`./build.sh` builds the app plus the `dms` CLI and `dms-symbian` companion, assembles `~/Applications/DankMacShell.app`, installs the CLIs to `~/.local/bin`, and starts the app. Useful flags:

| Flag | Effect |
| --- | --- |
| `--no-launch` | Build and install without starting the app |
| `--debug` / `--release` | Build configuration (default: release) |
| `--with-companions` | Also build/install `dms-gop` and `dank-theme-engine` from sibling checkouts (`../dms-gop`, `../dank-theme-engine`) |
| `--install-services` / `--uninstall-services` | Install/remove the launchd LaunchAgents |
| `--clean` | Remove build artifacts and caches |

Run `make help` for all targets (`make test`, `make dmg`, `make clean`, ...).

On first launch, grant **Accessibility** and **Input Monitoring** when prompted — DMS needs them for global hotkeys and OSD suppression. `dms doctor` runs a diagnostics check on permissions and subsystems; `dms permission` opens the right System Settings pane.

Handy while developing: the config at `~/Library/Application Support/DMS/settings.json` hot-reloads on every disk change, so you can tweak settings in an editor and watch the shell react live.

## Tests

```bash
./test.sh     # or: make test
```

Tests use Swift Testing and live in `Tests/DMSCoreTests`. CI runs `./test.sh` on every PR to `main`, so please run it locally before submitting.

## Project layout

| Path | What lives there |
| --- | --- |
| `Sources/DMSCore` | Pure logic (no AppKit): theming, config, search, IPC, stores — most tests target this |
| `Sources/DMS` | The macOS app: SwiftUI views, NSPanels, system event services, socket server |
| `Sources/DMSCLI` | The `dms` command-line utility |
| `Sources/DMSSymbian` | Standalone Symbian phone-sync companion |
| `Tests/DMSCoreTests` | Swift Testing suite for DMSCore |
| `scripts/` | Build / assemble / packaging shell scripts |
| `docs/spec/` | Architecture specs |

Prefer putting logic in `DMSCore` where possible — it's testable without a GUI.

## Code style

There is no enforced formatter; match the code around you. In practice:

- Keep PRs and contributions small
- Anything more than a few lines warrants an issue or discussion first
- Communicate what you're working on to prevent redundant work
- Swift 5 language mode (`swiftLanguageModes: [.v5]` in `Package.swift`)

## Pull requests

1. Fork the repo and create a branch from `main` (e.g. `fix/launcher-crash`, `feat/new-widget`)
2. Make your changes and run `./test.sh`
3. Open a PR against `main` with a clear description of the what and why
4. CI (`.github/workflows/build.yml`) runs the tests and a release build — both must pass

For anything larger than a small fix, open an issue first so we can align on direction before you invest the work.

## LLMs

You are fully free to use LLMs — nevertheless, you are fully responsible for the code you submit. Please don't contribute anything you don't understand; be ready to explain every line of your PR.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE), same as the project.
