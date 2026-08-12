#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="DartsAssistant"
VERSION="1.0.0"
APP_PATH="$ROOT/build/${APP_NAME}.app"
STAGING_DIR="$ROOT/build/dmg-staging"
DMG_PATH="$ROOT/dist/${APP_NAME}-${VERSION}-macOS-universal.dmg"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "The DMG installer must be created on macOS."
    exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "Application bundle not found. Run scripts/build-app.sh first."
    exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$ROOT/dist"
ditto "$APP_PATH" "$STAGING_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"

hdiutil create \
    -volname "Darts Assistant" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -ov \
    "$DMG_PATH"

codesign --force --sign - "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"
hdiutil verify "$DMG_PATH"

echo "Installer created: $DMG_PATH"
shasum -a 256 "$DMG_PATH"
