#!/bin/sh
# Assemble DankMaterialShell.app from built binary and sign it.
set -eu

if [ $# -ne 2 ]; then
    echo "usage: $0 BINARY APP" >&2
    exit 2
fi

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BINARY=$1
APP=$2
PLIST="$ROOT/Support/Info.plist"

CERT_NAME="dms-cert"
IDENTITY=${SIGN_IDENTITY:-""}

if [ -z "$IDENTITY" ]; then
    # Auto-detect or create persistent code-signing identity to preserve macOS permissions
    if security find-identity -p codesigning -v 2>/dev/null | grep -q "\"$CERT_NAME\""; then
        IDENTITY="$CERT_NAME"
    elif security find-identity -p codesigning -v 2>/dev/null | grep -q "Apple Development"; then
        IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}')
    else
        echo "==> Creating persistent self-signed code signing certificate '$CERT_NAME' for permission persistence..."
        TMPDIR=$(mktemp -d)
        cat << 'EOF' > "$TMPDIR/cert.cnf"
[ req ]
distinguished_name = req_distinguished_name
prompt = no
x509_extensions = v3_ca

[ req_distinguished_name ]
CN = dms-cert

[ v3_ca ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF
        openssl req -x509 -newkey rsa:2048 -keyout "$TMPDIR/key.pem" -out "$TMPDIR/cert.pem" -days 3650 -nodes -config "$TMPDIR/cert.cnf" 2>/dev/null
        openssl pkcs12 -export -inkey "$TMPDIR/key.pem" -in "$TMPDIR/cert.pem" -out "$TMPDIR/cert.p12" -passout pass:dms -name "$CERT_NAME" 2>/dev/null
        security import "$TMPDIR/cert.p12" -k ~/Library/Keychains/login.keychain-db -P dms -T /usr/bin/codesign >/dev/null 2>&1 || true
        security add-trusted-cert -r trustRoot -p codeSign -k ~/Library/Keychains/login.keychain-db "$TMPDIR/cert.pem" >/dev/null 2>&1 || true
        rm -rf "$TMPDIR"
        IDENTITY="$CERT_NAME"
    fi
fi

BUILD_NUMBER=${BUILD_NUMBER:-$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)}

rm -rf "$APP"
BIN_DIR=$(dirname "$BINARY")

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/DankMaterialShell"
ln -sf "DankMaterialShell" "$APP/Contents/MacOS/DankMacShell"
cp "$PLIST" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
if [ -n "${BUNDLE_SHORT_VERSION:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $BUNDLE_SHORT_VERSION" "$APP/Contents/Info.plist"
fi

# Copy SPM resource bundle and companion CLIs if present
# On case-insensitive APFS, `dms` and `DMS` collide; only create the `DMS` symlink when `dms` isn't bundled.
if [ -f "$BIN_DIR/dms" ]; then
    cp "$BIN_DIR/dms" "$APP/Contents/MacOS/dms"
    chmod +x "$APP/Contents/MacOS/dms"
else
    ln -sf "DankMaterialShell" "$APP/Contents/MacOS/DMS"
fi
if [ -f "$BIN_DIR/dms-symbian" ]; then
    cp "$BIN_DIR/dms-symbian" "$APP/Contents/MacOS/dms-symbian"
    chmod +x "$APP/Contents/MacOS/dms-symbian"
fi
if [ -d "$BIN_DIR/DMS_DMS.bundle" ]; then
    cp -R "$BIN_DIR/DMS_DMS.bundle" "$APP/Contents/Resources/"
fi

# The app-embedded dms-symbian companion resolves its own resources via
# Bundle.main.resourceURL (Contents/Resources) — ship its bundle too,
# otherwise the companion crashes on launch with "unable to find bundle".
if [ -d "$BIN_DIR/DMS_DMSSymbian.bundle" ]; then
    cp -R "$BIN_DIR/DMS_DMSSymbian.bundle" "$APP/Contents/Resources/"
fi

# Copy media-bridge helper script to Resources
if [ -f "$ROOT/Support/media-bridge.swift" ]; then
    cp "$ROOT/Support/media-bridge.swift" "$APP/Contents/Resources/media-bridge.swift"
fi

# Ensure icon is up-to-date from repository assets
if [ -x "$ROOT/scripts/generate-icon.sh" ]; then
    "$ROOT/scripts/generate-icon.sh"
fi

if [ -f "$ROOT/Support/AppIcon.icns" ]; then
    cp "$ROOT/Support/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
elif [ -f "$ROOT/Sources/DMS/Resources/AppIcon.icns" ]; then
    cp "$ROOT/Sources/DMS/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleIconName AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || true

# Assemble the WidgetKit extension (DMSWidgets.appex) when its binary was built
if [ -f "$BIN_DIR/DMSWidgets" ]; then
    APPEX="$APP/Contents/PlugIns/DMSWidgets.appex"
    mkdir -p "$APPEX/Contents/MacOS"
    cp "$BIN_DIR/DMSWidgets" "$APPEX/Contents/MacOS/DMSWidgets"
    chmod +x "$APPEX/Contents/MacOS/DMSWidgets"
    cp "$ROOT/Support/DMSWidgets-Info.plist" "$APPEX/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APPEX/Contents/Info.plist"
    if [ -n "${BUNDLE_SHORT_VERSION:-}" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $BUNDLE_SHORT_VERSION" "$APPEX/Contents/Info.plist"
    fi
fi

echo "==> Signing $APP with identity: $IDENTITY (inside-out)..."
for nested in "$APP/Contents/MacOS/dms" "$APP/Contents/MacOS/dms-symbian"; do
    if [ -f "$nested" ]; then
        codesign --force --sign "$IDENTITY" "$nested"
    fi
done
for bundle in "$APP/Contents/Resources/"*.bundle; do
    # Codeless SwiftPM resource bundles cannot be signed directly on macOS 15;
    # their contents are sealed in the enclosing app's CodeResources when signing $APP.
    if [ -d "$bundle" ] && { [ -d "$bundle/Contents/MacOS" ] || /usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$bundle/Contents/Info.plist" >/dev/null 2>&1; }; then
        codesign --force --sign "$IDENTITY" "$bundle"
    fi
done
# Sign the widget extension inside-out, before the enclosing app
if [ -d "$APP/Contents/PlugIns/DMSWidgets.appex" ]; then
    codesign --force --sign "$IDENTITY" --entitlements "$ROOT/Support/DMSWidgets.entitlements" "$APP/Contents/PlugIns/DMSWidgets.appex"
fi
codesign --force --sign "$IDENTITY" "$APP"

# Register the app and its widget extension with LaunchServices / pluginkit (non-fatal)
if [ -d "$APP/Contents/PlugIns/DMSWidgets.appex" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true
    pluginkit -a "$APP/Contents/PlugIns/DMSWidgets.appex" 2>/dev/null || true
    pluginkit -e use -i io.github.jonasnowak.dms.widgets 2>/dev/null || true
fi
echo "Assembled and signed $APP"
