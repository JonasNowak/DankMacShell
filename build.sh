#!/bin/sh
# Build, assemble DankMacShell.app, install CLI to ~/.local/bin and start app.
set -eu
cd "$(dirname "$0")"

LAUNCH=1
BUILD_CONFIG="release"
WITH_COMPANIONS=0
INSTALL_SERVICES=0
UNINSTALL_SERVICES=0
NO_LOAD_SERVICES=0

for arg in "$@"; do
    case "$arg" in
        --no-launch)
            LAUNCH=0
            ;;
        --with-companions)
            WITH_COMPANIONS=1
            ;;
        --install-services)
            INSTALL_SERVICES=1
            ;;
        --uninstall-services)
            UNINSTALL_SERVICES=1
            ;;
        --no-load-services)
            NO_LOAD_SERVICES=1
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
            echo "  --no-launch            Build and install without launching the application"
            echo "  --with-companions      Also build/install dms-gop (dgop) and dank-theme-engine (dte)"
            echo "  --install-services     Install launchd LaunchAgents for DankMacShell, dms-gop, and dte"
            echo "  --uninstall-services   Remove launchd LaunchAgents and exit"
            echo "  --debug                Build in debug configuration (default: release)"
            echo "  --release              Build in release configuration"
            echo "  --clean                Clean build artifacts and caches, then exit"
            echo "  -h, --help             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1
            ;;
    esac
done

if [ "$UNINSTALL_SERVICES" -eq 1 ]; then
    chmod +x scripts/install-services.sh
    if [ "$NO_LOAD_SERVICES" -eq 1 ]; then
        ./scripts/install-services.sh --uninstall --no-load
    else
        ./scripts/install-services.sh --uninstall
    fi
    exit 0
fi

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
swift build -c "$BUILD_CONFIG" --scratch-path "$SCRATCH"

BIN_PATH=$(swift build -c "$BUILD_CONFIG" --scratch-path "$SCRATCH" --show-bin-path)
APP_BINARY="$BIN_PATH/$APP_PRODUCT"
CLI_BINARY="$BIN_PATH/dms"
SYMBIAN_BINARY="$BIN_PATH/dms-symbian"

APP="$HOME/Applications/DankMacShell.app"
ALT_APP="$HOME/Applications/DankMaterialShell.app"
mkdir -p "$HOME/Applications"

# Gracefully terminate previous running instance and wait for exit
pkill -x DankMacShell 2>/dev/null || true
pkill -f "DankMacShell.app/Contents/MacOS" 2>/dev/null || true
pkill -x DankMaterialShell 2>/dev/null || true
pkill -f "DankMaterialShell.app/Contents/MacOS" 2>/dev/null || true
pkill -x DMS 2>/dev/null || true
for i in 1 2 3 4 5 6 7 8 9 10; do
    if ! pgrep -x DankMacShell >/dev/null 2>&1 && ! pgrep -x DankMaterialShell >/dev/null 2>&1 && ! pgrep -x DMS >/dev/null 2>&1; then
        break
    fi
    sleep 0.15
done
pkill -9 -x DankMacShell 2>/dev/null || true
pkill -9 -f "DankMacShell.app/Contents/MacOS" 2>/dev/null || true
pkill -9 -x DankMaterialShell 2>/dev/null || true
pkill -9 -f "DankMaterialShell.app/Contents/MacOS" 2>/dev/null || true
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

if [ "$WITH_COMPANIONS" -eq 1 ]; then
    echo "==> Installing companion tools (dms-gop & dank-theme-engine)..."
    if [ -d "../dms-gop" ]; then
        if [ -f "../dms-gop/bin/dms-gop" ]; then
            cp "../dms-gop/bin/dms-gop" "$HOME/.local/bin/dms-gop"
            chmod +x "$HOME/.local/bin/dms-gop"
            ln -sf "dms-gop" "$HOME/.local/bin/dgop"
            echo "==> Installed dms-gop (and dgop alias) to: $HOME/.local/bin/dms-gop"
        elif command -v go >/dev/null 2>&1; then
            (cd "../dms-gop" && make build && make install)
        else
            echo "==> Warning: Go not found and ../dms-gop/bin/dms-gop not prebuilt; skipping dms-gop." >&2
        fi
    fi

    if [ -d "../dank-theme-engine" ]; then
        DTE_PREBUILT=""
        for candidate in "../dank-theme-engine/target/release/dte" "../dank-theme-engine/target/aarch64-apple-darwin/release/dte"; do
            if [ -f "$candidate" ]; then
                DTE_PREBUILT="$candidate"
                break
            fi
        done
        if [ -n "$DTE_PREBUILT" ]; then
            cp "$DTE_PREBUILT" "$HOME/.local/bin/dte"
            chmod +x "$HOME/.local/bin/dte"
            echo "==> Installed dte to: $HOME/.local/bin/dte"
        elif command -v cargo >/dev/null 2>&1; then
            (cd "../dank-theme-engine" && cargo build --release -p dte-cli && cp "target/release/dte" "$HOME/.local/bin/dte" && chmod +x "$HOME/.local/bin/dte")
            echo "==> Built and installed dte to: $HOME/.local/bin/dte"
        else
            echo "==> Warning: Cargo not found and dte not prebuilt; skipping dank-theme-engine." >&2
        fi
    fi
fi

if [ "$INSTALL_SERVICES" -eq 1 ]; then
    chmod +x scripts/install-services.sh
    if [ "$NO_LOAD_SERVICES" -eq 1 ]; then
        ./scripts/install-services.sh --install --no-load
    else
        ./scripts/install-services.sh --install
    fi
fi

if [ "$LAUNCH" -eq 1 ]; then
    # Terminate any running instance before launching newly built app
    pkill -x DankMaterialShell 2>/dev/null || true
    pkill -x DankMacShell 2>/dev/null || true
    killall -CONT OSDUIHelper 2>/dev/null || true
    wait_i=0
    while pgrep -x DankMaterialShell >/dev/null 2>&1 || pgrep -x DankMacShell >/dev/null 2>&1; do
        wait_i=$((wait_i + 1))
        if [ "$wait_i" -ge 20 ]; then
            pkill -9 -x DankMaterialShell 2>/dev/null || true
            pkill -9 -x DankMacShell 2>/dev/null || true
            break
        fi
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
