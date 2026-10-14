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
pkill -x DankMaterialShell 2>/dev/null || true
pkill -x DMS 2>/dev/null || true

chmod +x scripts/assemble-app.sh
scripts/assemble-app.sh "$APP_BINARY" "$APP"

# Install dms CLI to ~/.local/bin
mkdir -p "$HOME/.local/bin"
cp "$CLI_BINARY" "$HOME/.local/bin/dms"
chmod +x "$HOME/.local/bin/dms"
echo "==> Installed dms CLI to: $HOME/.local/bin/dms"

if [ "${1:-}" != "--no-launch" ]; then
    open "$APP"
    echo "==> Installed and started: $APP"
else
    echo "==> Installed: $APP"
fi
