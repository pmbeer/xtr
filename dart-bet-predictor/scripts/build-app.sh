#!/bin/bash
# Собирает DartBetPredictor.app — Universal на CI, нативно на Intel/ARM.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="1.1.0"
APP_NAME="DartBetPredictor"
APP_DIR="$ROOT/build/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_BIN="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
BUILD_DIR="$ROOT/.build"
HOST_ARCH="$(uname -m)"

echo "=== Сборка ${APP_NAME} v${VERSION} (хост: ${HOST_ARCH}) ==="

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Ошибка: сборка возможна только на macOS."
    exit 1
fi

build_arch() {
    local arch="$1"
    echo "→ Компиляция ${arch}..." >&2
    swift build -c release --arch "$arch" >&2
    local bin="${BUILD_DIR}/${arch}-apple-macosx/release/${APP_NAME}"
    if [[ ! -f "$bin" ]]; then
        bin="$(swift build -c release --arch "$arch" --show-bin-path)/${APP_NAME}"
    fi
    if [[ ! -f "$bin" ]]; then
        echo "Ошибка: бинарник не найден для ${arch}: $bin" >&2
        return 1
    fi
    echo "$bin"
}

copy_resources() {
    echo "→ Копирование ресурсов..."
    # Исходные ресурсы
    if [[ -d "Sources/DartBetPredictor/Resources" ]]; then
        cp -R Sources/DartBetPredictor/Resources/* "$RESOURCES/" 2>/dev/null || true
    fi
    # SPM resource bundle (обязательно для Bundle.module)
    local bundle
    bundle=$(find "$BUILD_DIR" -name "${APP_NAME}_${APP_NAME}.bundle" -type d 2>/dev/null | head -1)
    if [[ -n "$bundle" && -d "$bundle" ]]; then
        echo "  SPM bundle: $bundle"
        cp -R "$bundle" "$RESOURCES/"
    fi
    # entitlements рядом с бинарником
    if [[ -f "Sources/DartBetPredictor/DartBetPredictor.entitlements" ]]; then
        cp Sources/DartBetPredictor/DartBetPredictor.entitlements "$CONTENTS/entitlements.plist"
    fi
}

FINAL_BIN="$ROOT/build/${APP_NAME}-final"
mkdir -p "$ROOT/build"

if [[ "$HOST_ARCH" == "x86_64" ]]; then
    X86_BIN="$(build_arch x86_64)"
    cp "$X86_BIN" "$FINAL_BIN"
    echo "→ Сборка для Intel x86_64"
elif [[ "$HOST_ARCH" == "arm64" ]]; then
    ARM_BIN="$(build_arch arm64)"
    if X86_BIN="$(build_arch x86_64 2>/dev/null)"; then
        echo "→ Объединение arm64 + x86_64 в Universal Binary..."
        lipo -create -output "$FINAL_BIN" "$ARM_BIN" "$X86_BIN"
        lipo -info "$FINAL_BIN"
    else
        echo "→ x86_64 кросс-компиляция недоступна, только arm64"
        cp "$ARM_BIN" "$FINAL_BIN"
    fi
else
    echo "Неизвестная архитектура: $HOST_ARCH"
    exit 1
fi

echo "→ Создание .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_BIN" "$RESOURCES"

cp "$FINAL_BIN" "$MACOS_BIN/${APP_NAME}"
chmod +x "$MACOS_BIN/${APP_NAME}"

cp Sources/DartBetPredictor/Info.plist "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion 13.0" "$CONTENTS/Info.plist" 2>/dev/null || true

echo -n "APPL????" > "$CONTENTS/PkgInfo"

copy_resources

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

echo "→ Подпись с entitlements..."
ENTITLEMENTS="Sources/DartBetPredictor/DartBetPredictor.entitlements"
if [[ -f "$ENTITLEMENTS" ]]; then
    codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_DIR" 2>/dev/null || \
    codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
else
    codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
fi

echo ""
echo "✓ Готово: $APP_DIR"
file "$MACOS_BIN/${APP_NAME}"
lipo -info "$MACOS_BIN/${APP_NAME}" 2>/dev/null || true
echo "  Запуск: open \"$APP_DIR\""
