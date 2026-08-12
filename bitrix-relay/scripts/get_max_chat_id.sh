#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${MAX_BOT_TOKEN:-}" ]]; then
  echo "Укажите MAX_BOT_TOKEN в окружении"
  exit 1
fi

echo "1) Добавьте MAX-бота админом в канал"
echo "2) Опубликуйте тестовый пост в канале"
echo "3) Если у бота включён webhook — chat_id придёт в событии message_created"
echo ""
echo "Альтернатива: временно включите long polling в dev.max.ru и посмотрите chat_id в update."
echo ""
echo "Проверка токена бота:"
curl -sS -H "Authorization: ${MAX_BOT_TOKEN}" \
  "https://platform-api2.max.ru/me" | python3 -m json.tool
