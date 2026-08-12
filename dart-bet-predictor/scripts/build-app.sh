#!/bin/bash
# Собирает DartBetPredictor.app — Universal Binary (Intel + Apple Silicon).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="1.0.1"
BUNDLE_ID="com.dartbet.predictor"
APP_NAME="DartBetPredictor"
APP_DIR="$ROOT/build/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_BIN="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
BUILD_DIR="$ROOT/.build"

echo "=== Сборка ${APP_NAME} v${VERSION} (Universal: Intel + Apple Silicon) ==="

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Ошибка: сборка возможна только на macOS."
    exit 1
fi

# Сборка для обеих архитектур
echo "→ Компиляция arm64 (Apple Silicon)..."
swift build -c release --arch arm64 2>&1
ARM_BIN="${BUILD_DIR}/arm64-apple-macosx/release/${APP_NAME}"

echo "→ Компиляция x86_64 (Intel Mac)..."
swift build -c release --arch x86_64 2>&1
X86_BIN="${BUILD_DIR}/x86_64-apple-macosx/release/${APP_NAME}"

if [[ ! -f "$ARM_BIN" ]]; then
    ARM_BIN="$(swift build -c release --arch arm64 --show-bin-path)/${APP_NAME}"
fi
if [[ ! -f "$X86_BIN" ]]; then
    X86_BIN="$(swift build -c release --arch x86_64 --show-bin-path)/${APP_NAME}"
fi

UNIVERSAL_BIN="$ROOT/build/${APP_NAME}-universal"
echo "→ Объединение в Universal Binary..."
lipo -create -output "$UNIVERSAL_BIN" "$ARM_BIN" "$X86_BIN"
lipo -info "$UNIVERSAL_BIN"

echo "→ Создание .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_BIN" "$RESOURCES"

cp "$UNIVERSAL_BIN" "$MACOS_BIN/${APP_NAME}"
chmod +x "$MACOS_BIN/${APP_NAME}"

# Info.plist
cp Sources/DartBetPredictor/Info.plist "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion 13.0" "$CONTENTS/Info.plist" 2>/dev/null || true

# PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

# Иконка
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

echo "→ Подпись приложения..."
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "  (codesign пропущен)"

echo ""
echo "✓ Готово: $APP_DIR"
echo "  Архитектуры: $(lipo -info "$MACOS_BIN/${APP_NAME}" | cut -d: -f3)"
echo "  Запуск: open \"$APP_DIR\""
