#!/bin/sh
# Run the Core tests (Swift Testing).
set -eu
cd "$(dirname "$0")"

SCRATCH=${DMS_BUILD_DIR:-$HOME/Library/Caches/DMS/build}

if [ -z "${SDKROOT:-}" ]; then
    if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]; then
        SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
    else
        SDKROOT=$(xcrun --show-sdk-path 2>/dev/null || true)
    fi
    export SDKROOT
fi

CLT=/Library/Developer/CommandLineTools
FW=$CLT/Library/Developer/Frameworks
LIB=$CLT/Library/Developer/usr/lib

xattr -cr "$SCRATCH" 2>/dev/null || true
xattr -cr Sources Support scripts 2>/dev/null || true

if [ ! -d "$FW/Testing.framework" ]; then
    exec swift test --scratch-path "$SCRATCH" "$@"
fi

swift test --scratch-path "$SCRATCH" \
    -Xswiftc -F"$FW" \
    -Xswiftc -plugin-path -Xswiftc "$CLT/usr/lib/swift/host/plugins" \
    -Xswiftc -plugin-path -Xswiftc "$CLT/usr/lib/swift/host/plugins/testing" \
    -Xlinker -F"$FW" \
    -Xlinker -rpath -Xlinker "$FW" \
    -Xlinker -rpath -Xlinker "$LIB" \
    "$@"
