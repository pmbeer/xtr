#!/bin/bash
# Собирает DartBetPredictor.app из исходников (только macOS).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="1.0.0"
BUNDLE_ID="com.dartbet.predictor"
APP_NAME="DartBetPredictor"
APP_DIR="$ROOT/build/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_BIN="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "=== Сборка ${APP_NAME} v${VERSION} ==="

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Ошибка: сборка возможна только на macOS."
    exit 1
fi

# Сборка release-бинарника
echo "→ Компиляция Swift..."
swift build -c release 2>&1

BIN="$(swift build -c release --show-bin-path)/${APP_NAME}"
if [[ ! -f "$BIN" ]]; then
    echo "Ошибка: бинарник не найден: $BIN"
    exit 1
fi

echo "→ Создание .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_BIN" "$RESOURCES"

cp "$BIN" "$MACOS_BIN/${APP_NAME}"
chmod +x "$MACOS_BIN/${APP_NAME}"

# Info.plist
cp Sources/DartBetPredictor/Info.plist "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$CONTENTS/Info.plist" 2>/dev/null || true

# PkgInfo (требуется для macOS app bundle)
echo -n "APPL????" > "$CONTENTS/PkgInfo"

# Иконка приложения
if [[ -f "$ROOT/Assets/app-icon.png" ]]; then
    echo "→ Генерация иконки..."
    ICONSET="$ROOT/build/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"

    for size in 16 32 128 256 512; do
        sips -z $size $size "$ROOT/Assets/app-icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        double=$((size * 2))
        sips -z $double $double "$ROOT/Assets/app-icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done

    iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$CONTENTS/Info.plist"
fi

# Ad-hoc подпись (чтобы macOS не блокировал сразу)
echo "→ Подпись приложения..."
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "  (codesign пропущен — не критично)"

echo ""
echo "✓ Готово: $APP_DIR"
echo "  Запуск: open \"$APP_DIR\""
