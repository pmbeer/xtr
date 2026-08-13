#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCH="${ARCH:-x86_64 arm64}"
APP_NAME="DartPredictor"
SCHEME="DartPredictor"
PROJECT="$PROJECT_DIR/DartPredictor.xcodeproj"

echo "=== DartPredictor Build Script ==="
echo "Target architectures: $ARCH"

if ! command -v xcodebuild &>/dev/null; then
  echo "ERROR: xcodebuild not found. Build must run on macOS with Xcode installed."
  exit 1
fi

"$SCRIPT_DIR/generate_icons.sh"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

ARCH_ARGS=()
for a in $ARCH; do
  ARCH_ARGS+=(-arch "$a")
done

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  "${ARCH_ARGS[@]}" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-"" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  build

APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME.app" -type d | head -1)
if [[ -z "$APP_PATH" ]]; then
  echo "ERROR: Built .app not found"
  exit 1
fi

cp -R "$APP_PATH" "$BUILD_DIR/$APP_NAME.app"
echo "Built: $BUILD_DIR/$APP_NAME.app"

DMG_NAME="${DMG_NAME:-DartPredictor-macOS-Universal.dmg}"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
STAGING="$BUILD_DIR/dmg_staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$BUILD_DIR/$APP_NAME.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
echo "DMG created: $DMG_PATH"
