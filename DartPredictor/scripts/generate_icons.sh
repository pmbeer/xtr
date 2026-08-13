#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE="$PROJECT_DIR/DartPredictor/Resources/icon_source.png"
ICONSET="$PROJECT_DIR/DartPredictor/Resources/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$SOURCE" ]]; then
  echo "Source icon not found: $SOURCE"
  exit 1
fi

generate() {
  local size=$1
  local output=$2
  sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/$output" >/dev/null
}

generate 16 icon_16.png
generate 32 icon_32.png
generate 64 icon_64.png
generate 128 icon_128.png
generate 256 icon_256.png
generate 512 icon_512.png
generate 1024 icon_1024.png

echo "App icons generated in $ICONSET"
