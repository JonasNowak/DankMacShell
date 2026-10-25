#!/bin/sh
# Build, assemble DankMacShell.app, install CLI to ~/.local/bin and start app.
set -eu
cd "$(dirname "$0")"

LAUNCH=1
BUILD_CONFIG="release"

for arg in "$@"; do
    case "$arg" in
        --no-launch)
            LAUNCH=0
            ;;
        --clean)
            ./scripts/clean.sh
            exit 0
            ;;
        --debug)
            BUILD_CONFIG="debug"
            ;;
        --release)
            BUILD_CONFIG="release"
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-launch    Build and install without launching the application"
            echo "  --debug        Build in debug configuration (default: release)"
            echo "  --release      Build in release configuration"
            echo "  --clean        Clean build artifacts and caches, then exit"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1
            ;;
    esac
done

if [ -z "${SDKROOT:-}" ]; then
    if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]; then
        SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
    else
        SDKROOT=$(xcrun --show-sdk-path 2>/dev/null || true)
    fi
    export SDKROOT
fi

SCRATCH=${DMS_BUILD_DIR:-$HOME/Library/Caches/DMS/build}

# Automatically ensure application icon is generated from repository assets
chmod +x scripts/generate-icon.sh
scripts/generate-icon.sh
xattr -cr Sources Support scripts "$SCRATCH" 2>/dev/null || true

echo "==> Building DankMacShell and dms CLI in $BUILD_CONFIG mode..."
if swift build -c "$BUILD_CONFIG" --product DankMacShell --scratch-path "$SCRATCH" 2>/dev/null; then
    APP_PRODUCT="DankMacShell"
else
    swift build -c "$BUILD_CONFIG" --product DankMaterialShell --scratch-path "$SCRATCH"
    APP_PRODUCT="DankMaterialShell"
fi
swift build -c "$BUILD_CONFIG" --product dms --scratch-path "$SCRATCH"

BIN_PATH=$(swift build -c "$BUILD_CONFIG" --scratch-path "$SCRATCH" --show-bin-path)
APP_BINARY="$BIN_PATH/$APP_PRODUCT"
CLI_BINARY="$BIN_PATH/dms"

APP="$HOME/Applications/DankMacShell.app"
ALT_APP="$HOME/Applications/DankMaterialShell.app"
mkdir -p "$HOME/Applications"

# Gracefully terminate previous running instance and wait for exit
pkill -x DankMacShell 2>/dev/null || true
pkill -f DankMacShell 2>/dev/null || true
pkill -x DankMaterialShell 2>/dev/null || true
pkill -f DankMaterialShell 2>/dev/null || true
pkill -x DMS 2>/dev/null || true
for i in 1 2 3 4 5 6 7 8 9 10; do
    if ! pgrep -f DankMacShell >/dev/null 2>&1 && ! pgrep -f DankMaterialShell >/dev/null 2>&1 && ! pgrep -x DMS >/dev/null 2>&1; then
        break
    fi
    sleep 0.15
done
pkill -9 -x DankMacShell 2>/dev/null || true
pkill -9 -f DankMacShell 2>/dev/null || true
pkill -9 -x DankMaterialShell 2>/dev/null || true
pkill -9 -f DankMaterialShell 2>/dev/null || true
pkill -9 -x DMS 2>/dev/null || true

chmod +x scripts/assemble-app.sh
scripts/assemble-app.sh "$APP_BINARY" "$APP"
rm -rf "$ALT_APP"
ln -sf "DankMacShell.app" "$ALT_APP"

# Install dms CLI to ~/.local/bin and sign it
mkdir -p "$HOME/.local/bin"
cp "$CLI_BINARY" "$HOME/.local/bin/dms"
chmod +x "$HOME/.local/bin/dms"
if security find-identity -p codesigning -v 2>/dev/null | grep -q '"dms-cert"'; then
    codesign --force --sign "dms-cert" "$HOME/.local/bin/dms" 2>/dev/null || true
fi
echo "==> Installed dms CLI to: $HOME/.local/bin/dms"

if [ "$LAUNCH" -eq 1 ]; then
    open "$APP"
    # Verify launch
    sleep 0.5
    if pgrep -x DankMacShell >/dev/null 2>&1 || pgrep -x DankMaterialShell >/dev/null 2>&1; then
        echo "==> Installed and started: $APP (PID $(pgrep -x DankMacShell || pgrep -x DankMaterialShell))"
    else
        echo "==> Direct launching $APP..."
        "$APP/Contents/MacOS/DankMaterialShell" >/dev/null 2>&1 &
        sleep 0.5
        echo "==> Installed and started: $APP (PID $(pgrep -x DankMacShell || pgrep -x DankMaterialShell || echo 'running'))"
    fi
else
    echo "==> Installed: $APP"
fi
