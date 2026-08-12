#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/bitrix-relay"
SERVICE_NAME="bitrix-relay"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Запустите скрипт от root: sudo bash scripts/install.sh"
  exit 1
fi

apt-get update
apt-get install -y python3 python3-venv python3-pip nginx certbot python3-certbot-nginx curl

mkdir -p "${APP_DIR}/data"
cp -r app requirements.txt .env.example scripts deploy README.md "${APP_DIR}/"

if [[ ! -f "${APP_DIR}/.env" ]]; then
  cp "${APP_DIR}/.env.example" "${APP_DIR}/.env"
  echo "Создан ${APP_DIR}/.env — заполните его перед запуском"
fi

python3 -m venv "${APP_DIR}/venv"
"${APP_DIR}/venv/bin/pip" install --upgrade pip
"${APP_DIR}/venv/bin/pip" install -r "${APP_DIR}/requirements.txt"

cp "${APP_DIR}/deploy/bitrix-relay.service" "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"

echo ""
echo "Установка завершена."
echo "1) Отредактируйте ${APP_DIR}/.env"
echo "2) Настройте nginx: cp ${APP_DIR}/deploy/nginx.conf.example /etc/nginx/sites-available/bitrix-relay"
echo "3) sudo certbot --nginx -d relay.ваш-домен.ru"
echo "4) sudo systemctl restart ${SERVICE_NAME} nginx"
echo "5) curl http://127.0.0.1:8000/health"
