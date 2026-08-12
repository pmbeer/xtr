#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  echo "Укажите TELEGRAM_BOT_TOKEN в окружении"
  exit 1
fi

echo "Отправьте любое сообщение в ваш Telegram-канал (от имени админа)."
echo "Затем откройте:"
echo "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates"
echo ""
echo "Найдите chat.id канала (обычно начинается с -100)."

curl -sS "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates" | python3 -m json.tool
