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

echo "==> Building DankMacShell, dms CLI, and dms-symbian in $BUILD_CONFIG mode..."
APP_PRODUCT="DankMacShell"
swift build -c "$BUILD_CONFIG" --product DankMacShell --scratch-path "$SCRATCH"
swift build -c "$BUILD_CONFIG" --product dms --scratch-path "$SCRATCH"
swift build -c "$BUILD_CONFIG" --product dms-symbian --scratch-path "$SCRATCH"

BIN_PATH=$(swift build -c "$BUILD_CONFIG" --scratch-path "$SCRATCH" --show-bin-path)
APP_BINARY="$BIN_PATH/$APP_PRODUCT"
CLI_BINARY="$BIN_PATH/dms"
SYMBIAN_BINARY="$BIN_PATH/dms-symbian"

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

# Install dms CLI and dms-symbian to ~/.local/bin and sign them
mkdir -p "$HOME/.local/bin"
cp "$CLI_BINARY" "$HOME/.local/bin/dms"
chmod +x "$HOME/.local/bin/dms"
if [ -f "$SYMBIAN_BINARY" ]; then
    cp "$SYMBIAN_BINARY" "$HOME/.local/bin/dms-symbian"
    chmod +x "$HOME/.local/bin/dms-symbian"
    # Ship the companion's resource bundle next to the binary; without it the
    # standalone dms-symbian crashes on launch ("unable to find bundle named DMS_DMSSymbian").
    if [ -d "$BIN_PATH/DMS_DMSSymbian.bundle" ]; then
        rm -rf "$HOME/.local/bin/DMS_DMSSymbian.bundle"
        cp -R "$BIN_PATH/DMS_DMSSymbian.bundle" "$HOME/.local/bin/DMS_DMSSymbian.bundle"
    fi
fi
CLI_IDENTITY=${SIGN_IDENTITY:-""}
if [ -n "$CLI_IDENTITY" ]; then
    codesign --force --sign "$CLI_IDENTITY" "$HOME/.local/bin/dms" 2>/dev/null || true
    if [ -f "$HOME/.local/bin/dms-symbian" ]; then
        codesign --force --sign "$CLI_IDENTITY" "$HOME/.local/bin/dms-symbian" 2>/dev/null || true
    fi
elif security find-identity -p codesigning -v 2>/dev/null | grep -q '"dms-cert"'; then
    codesign --force --sign "dms-cert" "$HOME/.local/bin/dms" 2>/dev/null || true
    if [ -f "$HOME/.local/bin/dms-symbian" ]; then
        codesign --force --sign "dms-cert" "$HOME/.local/bin/dms-symbian" 2>/dev/null || true
    fi
fi
echo "==> Installed dms CLI to: $HOME/.local/bin/dms"
echo "==> Installed dms-symbian to: $HOME/.local/bin/dms-symbian"

if [ "$LAUNCH" -eq 1 ]; then
    # Terminate any running instance before launching newly built app
    pkill -x DankMaterialShell 2>/dev/null || true
    pkill -x DankMacShell 2>/dev/null || true
    killall -CONT OSDUIHelper 2>/dev/null || true
    while pgrep -x DankMaterialShell >/dev/null 2>&1 || pgrep -x DankMacShell >/dev/null 2>&1; do
        sleep 0.1
    done
    sleep 0.2
    open "$APP"
    # Verify launch
    sleep 0.5
    if pgrep -x DankMacShell >/dev/null 2>&1 || pgrep -x DankMaterialShell >/dev/null 2>&1; then
        echo "==> Installed and started: $APP (PID $(pgrep -x DankMacShell || pgrep -x DankMaterialShell))"
    else
        echo "==> Installed: $APP"
    fi
else
    echo "==> Installed: $APP"
fi
