#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Resources/AppIcon-1024.png"
ICONSET="$ROOT/build/AppIcon.iconset"
ICNS="$ROOT/build/AppIcon.icns"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Skipping .icns generation on non-macOS host."
    exit 0
fi

if [[ ! -f "$SOURCE" ]]; then
    echo "Icon source not found: $SOURCE"
    exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$ICNS"
echo "Created $ICNS"
