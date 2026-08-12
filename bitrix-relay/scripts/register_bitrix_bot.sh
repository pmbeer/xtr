#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Использование:"
  echo "  bash scripts/register_bitrix_bot.sh <BITRIX_WEBHOOK_URL> <WEBHOOK_HANDLER_URL>"
  echo ""
  echo "Пример:"
  echo "  bash scripts/register_bitrix_bot.sh \\"
  echo "    'https://portal.bitrix24.ru/rest/1/abc123/' \\"
  echo "    'https://relay.example.ru/bitrix/webhook'"
  exit 1
fi

WEBHOOK_URL="$1"
HANDLER_URL="$2"
BOT_TOKEN="${BITRIX_BOT_TOKEN:-relay_bot_secret_$(openssl rand -hex 16)}"

if [[ "${WEBHOOK_URL}" != */ ]]; then
  WEBHOOK_URL="${WEBHOOK_URL}/"
fi

read -r -p "Имя бота [Ретранслятор]: " BOT_NAME
BOT_NAME="${BOT_NAME:-Ретранслятор}"

payload=$(cat <<JSON
{
  "botToken": "${BOT_TOKEN}",
  "fields": {
    "code": "bitrix_relay_bot",
    "type": "supervisor",
    "properties": {
      "name": "${BOT_NAME}",
      "workPosition": "Пересылает сообщения в Telegram и MAX"
    },
    "eventMode": "webhook",
    "webhookUrl": "${HANDLER_URL}",
    "isHidden": true
  }
}
JSON
)

echo "Регистрируем бота..."
response=$(curl -sS -X POST "${WEBHOOK_URL}imbot.v2.Bot.register" \
  -H "Content-Type: application/json" \
  -d "${payload}")

echo "${response}" | python3 -m json.tool || echo "${response}"

BOT_ID=$(echo "${response}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('id',''))" 2>/dev/null || true)

echo ""
echo "===== Сохраните в .env ====="
echo "BITRIX_WEBHOOK_URL=${WEBHOOK_URL}"
echo "BITRIX_BOT_ID=${BOT_ID}"
echo "BITRIX_BOT_TOKEN=${BOT_TOKEN}"
echo "============================"
echo ""
echo "Добавьте бота в нужный чат Битрикс24 и отправьте тестовое сообщение."
