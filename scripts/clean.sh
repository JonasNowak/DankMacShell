#!/bin/sh
# Clean build artifacts, SPM caches, and distribution files.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRATCH=${DMS_BUILD_DIR:-$HOME/Library/Caches/DMS/build}

echo "==> Cleaning DankMacShell build artifacts..."
rm -rf "$ROOT/.build"
rm -rf "$ROOT/dist"
rm -rf "$SCRATCH"

# Remove any stray macOS detritus in the repository
find "$ROOT" -name ".DS_Store" -delete 2>/dev/null || true

echo "==> Build artifacts and caches cleaned."
