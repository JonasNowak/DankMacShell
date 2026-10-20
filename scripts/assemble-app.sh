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

if [ -z "$IDENTITY" ] || [ "$IDENTITY" = "-" ]; then
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
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/DankMaterialShell"
ln -sf "DankMaterialShell" "$APP/Contents/MacOS/DMS"
cp "$PLIST" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"

if [ -f "$ROOT/Support/AppIcon.icns" ]; then
    cp "$ROOT/Support/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> Signing $APP with identity: $IDENTITY..."
codesign --force --sign "$IDENTITY" "$APP"
echo "Assembled and signed $APP"
