#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
chmod +x "$ROOT/scripts/build-app.sh"
"$ROOT/scripts/build-app.sh"
echo "Run: open $ROOT/build/DartsForecast.app"
