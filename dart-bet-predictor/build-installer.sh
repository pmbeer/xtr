#!/bin/bash
# Полная сборка: .app + .dmg установщик для macOS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  Сборка установщика возможна только на macOS            ║"
    echo "║                                                          ║"
    echo "║  Варианты:                                               ║"
    echo "║  1. Запустите на MacBook:  ./build-installer.sh         ║"
    echo "║  2. Скачайте готовый DMG из GitHub Actions (см. README)  ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    exit 1
fi

echo "╔══════════════════════════════════════════════════╗"
echo "║     Dart Bet Predictor — сборка установщика      ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

chmod +x scripts/build-app.sh scripts/create-dmg.sh

echo "[1/2] Сборка приложения..."
./scripts/build-app.sh

echo ""
echo "[2/2] Создание DMG..."
./scripts/create-dmg.sh

echo ""
echo "════════════════════════════════════════════════════"
echo " Готово! Установщик: dist/DartBetPredictor-1.0.1-macOS-Universal.dmg"
echo "════════════════════════════════════════════════════"
