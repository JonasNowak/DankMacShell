#!/bin/sh
# Build, assemble DankMaterialShell.app, install to ~/Applications and start it.
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

swift build -c release --product DMS --scratch-path "$SCRATCH"
BINARY=$(swift build -c release --scratch-path "$SCRATCH" --show-bin-path)/DMS

APP="$HOME/Applications/DankMaterialShell.app"
mkdir -p "$HOME/Applications"
pkill -x DMS 2>/dev/null || true
chmod +x scripts/assemble-app.sh
scripts/assemble-app.sh "$BINARY" "$APP"
open "$APP"
echo "Installed and started: $APP"
