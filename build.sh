#!/bin/sh
# Build, assemble DankMaterialShell.app, install CLI to ~/.local/bin and start app.
set -eu
cd "$(dirname "$0")"

if [ -z "${SDKROOT:-}" ]; then
    if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]; then
        SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
    else
        SDKROOT=$(xcrun --show-sdk-path 2>/dev/null || true)
    fi
    export SDKROOT
fi

SCRATCH=${DMS_BUILD_DIR:-$HOME/Library/Caches/DMS/build}

echo "==> Building DankMaterialShell and dms CLI in release mode..."
swift build -c release --product DankMaterialShell --scratch-path "$SCRATCH"
swift build -c release --product dms --scratch-path "$SCRATCH"

BIN_PATH=$(swift build -c release --scratch-path "$SCRATCH" --show-bin-path)
APP_BINARY="$BIN_PATH/DankMaterialShell"
CLI_BINARY="$BIN_PATH/dms"

APP="$HOME/Applications/DankMaterialShell.app"
mkdir -p "$HOME/Applications"

# Gracefully terminate previous running instance and wait for exit
pkill -x DankMaterialShell 2>/dev/null || true
pkill -f DankMaterialShell 2>/dev/null || true
pkill -x DMS 2>/dev/null || true
for i in 1 2 3 4 5 6 7 8 9 10; do
    if ! pgrep -f DankMaterialShell >/dev/null 2>&1 && ! pgrep -x DMS >/dev/null 2>&1; then
        break
    fi
    sleep 0.15
done
pkill -9 -x DankMaterialShell 2>/dev/null || true
pkill -9 -f DankMaterialShell 2>/dev/null || true
pkill -9 -x DMS 2>/dev/null || true

chmod +x scripts/assemble-app.sh
scripts/assemble-app.sh "$APP_BINARY" "$APP"

# Install dms CLI to ~/.local/bin and sign it
mkdir -p "$HOME/.local/bin"
cp "$CLI_BINARY" "$HOME/.local/bin/dms"
chmod +x "$HOME/.local/bin/dms"
if security find-identity -p codesigning -v 2>/dev/null | grep -q '"dms-cert"'; then
    codesign --force --sign "dms-cert" "$HOME/.local/bin/dms" 2>/dev/null || true
fi
echo "==> Installed dms CLI to: $HOME/.local/bin/dms"

if [ "${1:-}" != "--no-launch" ]; then
    open "$APP"
    # Verify launch
    sleep 0.5
    if pgrep -x DankMaterialShell >/dev/null 2>&1; then
        echo "==> Installed and started: $APP (PID $(pgrep -x DankMaterialShell))"
    else
        echo "==> Direct launching $APP..."
        "$APP/Contents/MacOS/DankMaterialShell" >/dev/null 2>&1 &
        sleep 0.5
        echo "==> Installed and started: $APP (PID $(pgrep -x DankMaterialShell || echo 'running'))"
    fi
else
    echo "==> Installed: $APP"
fi
