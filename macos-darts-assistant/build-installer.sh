#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

chmod +x scripts/build-app.sh scripts/build-icon.sh scripts/create-dmg.sh
scripts/build-app.sh
scripts/create-dmg.sh
