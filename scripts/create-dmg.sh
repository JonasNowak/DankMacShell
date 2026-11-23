#!/bin/sh
# Build release app and package into a compressed, distributable .dmg disk image.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

if [ $# -ge 1 ]; then
    VERSION=$1
else
    VERSION=$(sed -n 's/.*public static let current = "\([^"]*\)".*/\1/p' "$ROOT/Sources/DMSCore/DMSVersion.swift" 2>/dev/null | head -n 1 || true)
    VERSION=${VERSION:-"0.9.9"}
fi
APP_PATH=${2:-"$HOME/Applications/DankMacShell.app"}
OUTPUT_DMG="$ROOT/dist/DankMacShell-$VERSION.dmg"

# Ensure app is built if missing
if [ ! -d "$APP_PATH" ]; then
    echo "==> Building DankMacShell.app first..."
    ./build.sh --no-launch
fi

echo "==> Packaging DMG for DankMacShell $VERSION..."
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

STAGE="$TMPDIR/DankMacShell"
mkdir -p "$STAGE" "$ROOT/dist"

cp -R "$APP_PATH" "$STAGE/DankMacShell.app"
ln -s /Applications "$STAGE/Applications"

if [ -f "$ROOT/Support/AppIcon.icns" ]; then
    cp "$ROOT/Support/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
    SetFile -a C "$STAGE" 2>/dev/null || true
fi

# Clean detritus attributes
xattr -cr "$STAGE" 2>/dev/null || true

rm -f "$OUTPUT_DMG"
hdiutil create -volname "DankMacShell" -srcfolder "$STAGE" -ov -format UDZO "$OUTPUT_DMG"

echo "==> Created disk image: $OUTPUT_DMG ($(ls -lh "$OUTPUT_DMG" | awk '{print $5}'))"
shasum -a 256 "$OUTPUT_DMG"
