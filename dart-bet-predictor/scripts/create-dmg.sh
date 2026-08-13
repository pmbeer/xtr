#!/bin/bash
# Создаёт .dmg установщик с перетаскиванием в Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="1.1.0"
APP_NAME="DartBetPredictor"
DMG_NAME="${APP_NAME}-${VERSION}-macOS-Universal"
STAGING="$ROOT/build/dmg-staging"
DMG_PATH="$ROOT/dist/${DMG_NAME}.dmg"
APP_PATH="$ROOT/build/${APP_NAME}.app"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Ошибка: DMG создаётся только на macOS."
    exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "Сначала запустите scripts/build-app.sh"
    exit 1
fi

echo "=== Создание установщика ${DMG_NAME}.dmg ==="

rm -rf "$STAGING"
mkdir -p "$STAGING" "$ROOT/dist"

cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Фон DMG (опционально)
if [[ -f "$ROOT/Assets/dmg-background.png" ]]; then
    mkdir -p "$STAGING/.background"
    cp "$ROOT/Assets/dmg-background.png" "$STAGING/.background/background.png"
fi

rm -f "$DMG_PATH"

# Создание DMG
hdiutil create \
    -volname "Dart Bet Predictor" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Подпись DMG
codesign --force --sign - "$DMG_PATH" 2>/dev/null || true

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo ""
echo "✓ Установщик готов!"
echo "  Файл: $DMG_PATH"
echo "  Размер: $DMG_SIZE"
echo ""
echo "Установка:"
echo "  1. Откройте ${DMG_NAME}.dmg"
echo "  2. Перетащите DartBetPredictor в папку Applications"
echo "  3. Запустите из Программ (Приложения)"
