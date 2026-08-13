#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
chmod +x "$ROOT/scripts/"*.sh
"$ROOT/scripts/build-app.sh"
"$ROOT/scripts/create-dmg.sh" "2.0.0"
echo "Installer ready in $ROOT/dist/"
