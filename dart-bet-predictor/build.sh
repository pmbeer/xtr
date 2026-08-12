#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "=== Dart Bet Predictor — сборка ==="
swift build -c release

BIN="$(swift build -c release --show-bin-path)/DartBetPredictor"
APP_DIR="build/DartBetPredictor.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BIN" "$MACOS/DartBetPredictor"
cp Sources/DartBetPredictor/Info.plist "$CONTENTS/Info.plist"
cp Sources/DartBetPredictor/DartBetPredictor.entitlements "$CONTENTS/entitlements.plist"

chmod +x "$MACOS/DartBetPredictor"

echo ""
echo "Готово: $APP_DIR"
echo "Запуск: open $APP_DIR"
