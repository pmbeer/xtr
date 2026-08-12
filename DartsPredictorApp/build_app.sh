#!/bin/bash
# Сборка DartsPredictor.app и DartsPredictor.dmg.
# Запускать на macOS с установленными Xcode Command Line Tools:
#   xcode-select --install   (если ещё не установлены)
#   ./build_app.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Компиляция (universal: Apple Silicon + Intel)..."
swift build -c release --arch arm64 --arch x86_64

BINARY=".build/apple/Products/Release/DartsPredictor"
if [ ! -f "$BINARY" ]; then
    # Fallback: сборка только под текущую архитектуру
    swift build -c release
    BINARY=".build/release/DartsPredictor"
fi

APP="build/DartsPredictor.app"
echo "==> Сборка bundle $APP..."
rm -rf build
mkdir -p "$APP/Contents/MacOS"
cp "$BINARY" "$APP/Contents/MacOS/DartsPredictor"
cp Info.plist "$APP/Contents/Info.plist"

echo "==> Ad-hoc подпись..."
codesign --force --deep --sign - "$APP"

echo "==> Создание DMG..."
hdiutil create -volname "Darts Predictor" -srcfolder "$APP" -ov -format UDZO build/DartsPredictor.dmg

echo ""
echo "Готово:"
echo "  build/DartsPredictor.app"
echo "  build/DartsPredictor.dmg"
