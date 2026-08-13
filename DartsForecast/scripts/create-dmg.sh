#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/DartsForecast.app"
DIST="$ROOT/dist"
VERSION="${1:-2.0.0}"
DMG_NAME="DartsForecast-${VERSION}-macOS.dmg"
STAGE="$DIST/dmg-stage"

[[ -d "$APP" ]] || { echo "Missing $APP — run build-app.sh first"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE" "$DIST"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

DMG_PATH="$DIST/$DMG_NAME"
rm -f "$DMG_PATH"

hdiutil create \
  -volname "Darts Forecast" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG_PATH"

echo "==> DMG: $DMG_PATH"
ls -lh "$DMG_PATH"
