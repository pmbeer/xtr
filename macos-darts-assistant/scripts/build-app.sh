#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="DartsAssistant"
DISPLAY_NAME="Darts Assistant"
VERSION="1.0.0"
APP_DIR="$ROOT/build/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
SWIFT_ARGS=(-c release --arch arm64 --arch x86_64)

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This application bundle must be built on macOS."
    exit 1
fi

echo "Building universal ${DISPLAY_NAME} ${VERSION}..."
swift build "${SWIFT_ARGS[@]}"
BIN_DIR="$(swift build "${SWIFT_ARGS[@]}" --show-bin-path)"
BIN="$BIN_DIR/$APP_NAME"

if [[ ! -x "$BIN" ]]; then
    echo "Built executable not found: $BIN"
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
install -m 755 "$BIN" "$MACOS_DIR/$APP_NAME"
install -m 644 Sources/DartsAssistant/Info.plist "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $VERSION" \
    "$CONTENTS/Info.plist"

echo "Architectures: $(lipo -archs "$MACOS_DIR/$APP_NAME")"
lipo -verify_arch arm64 x86_64 "$MACOS_DIR/$APP_NAME"

codesign \
    --force \
    --deep \
    --sign - \
    --entitlements Sources/DartsAssistant/DartsAssistant.entitlements \
    "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "Application bundle created: $APP_DIR"
