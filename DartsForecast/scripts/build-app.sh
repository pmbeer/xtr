#!/usr/bin/env bash
# Собирает DartsForecast.app — Universal на CI, нативно на Intel/ARM.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="2.0.0"
APP_NAME="DartsForecast"
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
    swift build -c release --arch "$arch" --product DartsForecast >&2
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
cp "$ROOT/Sources/DartsForecast/Info.plist" "$CONTENTS/Info.plist"

# Icon
if command -v iconutil >/dev/null 2>&1 && [[ -d "$ROOT/Assets/AppIcon.iconset" ]]; then
    iconutil -c icns "$ROOT/Assets/AppIcon.iconset" -o "$RESOURCES/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS/Info.plist" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$CONTENTS/Info.plist" || true
elif [[ -f "$ROOT/Assets/AppIcon-1024.png" ]]; then
    cp "$ROOT/Assets/AppIcon-1024.png" "$RESOURCES/AppIcon.png"
fi

if [[ -d "Sources/DartsForecast/Resources" ]]; then
    cp -R Sources/DartsForecast/Resources/* "$RESOURCES/" 2>/dev/null || true
fi

# SPM resource bundle
bundle=$(find "$BUILD_DIR" -name "${APP_NAME}_${APP_NAME}.bundle" -type d 2>/dev/null | head -1 || true)
if [[ -n "${bundle:-}" && -d "$bundle" ]]; then
    cp -R "$bundle" "$RESOURCES/"
fi

ENTITLEMENTS="$ROOT/Sources/DartsForecast/DartsForecast.entitlements"
if [[ -f "$ENTITLEMENTS" ]]; then
    codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_DIR" || true
else
    codesign --force --deep --sign - "$APP_DIR" || true
fi

echo "=== App ready: $APP_DIR ==="
file "$MACOS_BIN/${APP_NAME}" || true
lipo -info "$MACOS_BIN/${APP_NAME}" || true
