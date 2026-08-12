# Bitrix24 → Telegram + MAX Relay

Сервис для автоматической пересылки сообщений из группы/канала **Битрикс24** в каналы **Telegram** и **MAX** — включая фото, видео, аудио, голосовые и любые файлы.

---

## Что внутри архива

```
bitrix-relay/
├── app/                    # Python-сервис (FastAPI)
├── deploy/                 # systemd + nginx
├── scripts/                # установка и регистрация бота
├── .env.example            # шаблон настроек
├── requirements.txt
└── README.md
```

---

## Быстрый старт (кратко)

1. Настроить ботов в **Telegram** и **MAX**
2. Создать входящий вебхук и бота `supervisor` в **Битрикс24**
3. Развернуть этот сервис на **VPS** с HTTPS
4. Заполнить `.env`
5. Добавить бота в нужный чат Битрикс24
6. Протестировать

---

# ЧАСТЬ 1. Telegram

## 1.1. Создать бота

1. Откройте [@BotFather](https://t.me/BotFather) в Telegram
2. Отправьте `/newbot`
3. Введите имя бота (например: `Мой ретранслятор`)
4. Введите username (например: `my_company_relay_bot`)
5. **Сохраните токен** — строка вида:
   ```
   1234567890:AAHxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
   Это значение для `TELEGRAM_BOT_TOKEN`

## 1.2. Создать канал

1. Telegram → **Новый канал**
2. Укажите название и описание
3. Выберите тип:
   - **Публичный** — будет `@имя_канала`
   - **Приватный** — ID вида `-1001234567890`

## 1.3. Добавить бота администратором

1. Откройте канал → **Управление каналом** → **Администраторы**
2. **Добавить администратора** → найдите вашего бота
3. Включите право **«Публикация сообщений»** (обязательно)
4. Сохраните

## 1.4. Узнать chat_id канала

### Публичный канал
Используйте `@имя_канала` — это значение для `TELEGRAM_CHANNEL_ID`

Пример:
```
TELEGRAM_CHANNEL_ID=@my_news_channel
```

### Приватный канал
1. Опубликуйте любое сообщение в канале
2. На сервере выполните:
   ```bash
   export TELEGRAM_BOT_TOKEN="ваш_токен"
   bash scripts/get_telegram_chat_id.sh
   ```
3. В ответе найдите `"chat":{"id":-1001234567890,...}`
4. Укажите:
   ```
   TELEGRAM_CHANNEL_ID=-1001234567890
   ```

## 1.5. Проверка Telegram

```bash
curl -s "https://api.telegram.org/bot<TOKEN>/getMe"
curl -s -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -H "Content-Type: application/json" \
  -d '{"chat_id":"@ваш_канал","text":"Тест из curl"}'
```

Если сообщение появилось в канале — Telegram настроен.

### Лимит Telegram
- Бот через стандартный API отправляет файлы **до 50 МБ**
- Файлы больше 50 МБ в Telegram не отправляются — сервис пишет уведомление, полный файл уходит в MAX (если влезает в лимиты MAX)

---

# ЧАСТЬ 2. MAX (российский мессенджер)

## 2.1. Создать бота

1. Откройте [https://dev.max.ru](https://dev.max.ru) (или «MAX для бизнеса»)
2. Создайте чат-бота
3. Перейдите: **Чат-боты → ваш бот → Расширенные настройки → Настроить**
4. **Сохраните токен** — это `MAX_BOT_TOKEN`

> API MAX работает на домене `platform-api2.max.ru`

## 2.2. Создать канал

1. В приложении MAX создайте канал
2. Добавьте вашего бота **администратором** канала

## 2.3. Узнать chat_id канала MAX

Способ 1 — из события бота:
1. Включите webhook/long polling для бота в кабинете MAX
2. Опубликуйте тестовый пост в канале
3. В событии `message_created` найдите `chat_id`

Способ 2 — скрипт:
```bash
export MAX_BOT_TOKEN="ваш_токен"
bash scripts/get_max_chat_id.sh
```

Укажите числовой ID:
```
MAX_CHANNEL_CHAT_ID=1234567890
```

## 2.4. Проверка MAX

```bash
curl -s -H "Authorization: ваш_токен" \
  "https://platform-api2.max.ru/me"

curl -s -X POST \
  "https://platform-api2.max.ru/messages?chat_id=ВАШ_CHAT_ID" \
  -H "Authorization: ваш_токен" \
  -H "Content-Type: application/json" \
  -d '{"text":"Тест из curl","notify":true}'
```

### Лимиты MAX
| Тип | Лимит |
|-----|-------|
| image | 50 МБ |
| video | 250 МБ |
| audio | 256 МБ / 60 мин |
| file | 4 ГБ |
| Скорость | ~2 сообщения/сек в канал |

Сервис автоматически:
- загружает файлы через `POST /uploads`
- делает retry при ошибке `attachment.not.ready`
- соблюдает паузу между отправками (`MAX_SEND_DELAY=0.6`)

---

# ЧАСТЬ 3. Битрикс24

## 3.1. Создать входящий вебхук

1. Битрикс24 → **Разработчикам** (или Приложения → Ресурсы разработчика)
2. **Другое** → **Входящий вебхук**
3. Права: обязательно **`imbot`**, желательно **`im`**
4. Сохраните URL:
   ```
   https://ваш-портал.bitrix24.ru/rest/1/xxxxxxxxxxxxxxxx/
   ```
   Это `BITRIX_WEBHOOK_URL` (со слэшем в конце)

## 3.2. Подготовить публичный URL обработчика

Сначала разверните сервис на VPS (см. Часть 4). Вам нужен HTTPS-адрес:
```
https://relay.ваш-домен.ru/bitrix/webhook
```

## 3.3. Зарегистрировать бота supervisor

На VPS (или локально с curl):

```bash
cd /opt/bitrix-relay
bash scripts/register_bitrix_bot.sh \
  'https://ваш-портал.bitrix24.ru/rest/1/ВЕБХУК_ТОКЕН/' \
  'https://relay.ваш-домен.ru/bitrix/webhook'
```

Скрипт выведет:
```
BITRIX_BOT_ID=456
BITRIX_BOT_TOKEN=сгенерированный_секрет
```

Скопируйте в `.env`.

### Что делает бот supervisor
- Видит **все** сообщения в чатах, где он участник
- Не требует `@упоминания`
- Получает `FILE_ID` вложений в событии `ONIMBOTV2MESSAGEADD`

## 3.4. Добавить бота в группу/канал Битрикс24

1. Откройте нужную группу или канал в Битрикс24
2. **Участники** → добавьте бота «Ретранслятор»
3. Напишите тестовое сообщение с картинкой

## 3.5. Узнать ID чата-источника

После тестового сообщения посмотрите логи сервиса:
```bash
sudo journalctl -u bitrix-relay -f
```

Или временно поставьте `BITRIX_SOURCE_CHAT_ID=0` — в логах будет:
```
Skip chat 123
```

Число `123` — это `BITRIX_SOURCE_CHAT_ID`.

## 3.6. Получить BITRIX_APP_TOKEN (безопасность)

1. Отправьте сообщение в чат с ботом
2. В логах nginx или journalctl найдите webhook (или включите debug)
3. В теле запроса есть `auth[application_token]=...`
4. Укажите в `.env`:
   ```
   BITRIX_APP_TOKEN=полученный_токен
   ```

Без этого токена сервис тоже работает (проверка отключена), но для продакшена **рекомендуется включить**.

## 3.7. Проверка Битрикс24

Чеклист:
- [ ] Бот добавлен в нужный чат
- [ ] `BITRIX_SOURCE_CHAT_ID` указан верно
- [ ] Webhook URL доступен по HTTPS
- [ ] Текстовое сообщение уходит в TG и MAX
- [ ] Фото/видео/файл уходит в TG и MAX

---

# ЧАСТЬ 4. Установка на VPS

## 4.1. Требования

- Ubuntu 22.04 / 24.04 (или Debian)
- Домен, указывающий на IP сервера (например `relay.example.ru`)
- Открыты порты 80 и 443

## 4.2. Загрузка архива на сервер

```bash
# На вашем компьютере
scp bitrix-relay.zip root@ВАШ_IP:/tmp/

# На сервере
cd /tmp
unzip bitrix-relay.zip
cd bitrix-relay
sudo bash scripts/install.sh
```

## 4.3. Настройка .env

```bash
sudo nano /opt/bitrix-relay/.env
```

Заполните все поля по образцу `.env.example`:

```env
BITRIX_WEBHOOK_URL=https://portal.bitrix24.ru/rest/1/abc123/
BITRIX_BOT_ID=456
BITRIX_BOT_TOKEN=ваш_секрет_бота
BITRIX_SOURCE_CHAT_ID=123
BITRIX_APP_TOKEN=

TELEGRAM_BOT_TOKEN=123456:ABC...
TELEGRAM_CHANNEL_ID=@my_channel

MAX_BOT_TOKEN=ваш_max_токен
MAX_CHANNEL_CHAT_ID=1234567890
```

## 4.4. Nginx + SSL

```bash
sudo cp /opt/bitrix-relay/deploy/nginx.conf.example /etc/nginx/sites-available/bitrix-relay
sudo nano /etc/nginx/sites-available/bitrix-relay
# Замените relay.example.ru на ваш домен

sudo ln -sf /etc/nginx/sites-available/bitrix-relay /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

sudo certbot --nginx -d relay.ваш-домен.ru
```

## 4.5. Запуск сервиса

```bash
sudo systemctl restart bitrix-relay
sudo systemctl status bitrix-relay
curl http://127.0.0.1:8000/health
```

Ответ `{"status":"ok","missing_env":[]}` — конфигурация полная.

## 4.6. Логи

```bash
sudo journalctl -u bitrix-relay -f
```

---

# ЧАСТЬ 5. Как работает пересылка файлов

1. Битрикс24 шлёт webhook `ONIMBOTV2MESSAGEADD`
2. Сервис читает `message.text` и `message.params.FILE_ID[]`
3. Для каждого `FILE_ID` вызывает `imbot.v2.File.download` → скачивает файл
4. Определяет тип: image / video / audio / file
5. Отправляет в Telegram (`sendPhoto`, `sendVideo`, `sendAudio`, `sendDocument`)
6. Загружает в MAX (`POST /uploads` → загрузка → `POST /messages`)
7. Записывает `message.id` в SQLite — защита от дублей

### Поддерживаемые типы
| Битрикс24 | Telegram | MAX |
|-----------|----------|-----|
| Текст | sendMessage | messages + text |
| Фото | sendPhoto | type=image |
| Видео | sendVideo | type=video |
| Аудио / голосовое | sendAudio | type=audio |
| Документы, архивы | sendDocument | type=file |
| Несколько файлов | по очереди | по очереди с паузой |

### Что фильтруется
- Системные сообщения (`isSystem`)
- Сообщения от самого бота (защита от петли)
- Сообщения из других чатов (не `BITRIX_SOURCE_CHAT_ID`)
- Дубликаты (повторный webhook)

---

# ЧАСТЬ 6. Тестирование

Проверьте по порядку:

| # | Действие | Ожидание |
|---|----------|----------|
| 1 | Только текст | Пост в TG и MAX |
| 2 | Текст + 1 фото | Фото с подписью |
| 3 | Только фото | Фото без текста |
| 4 | Видео | Видео в обоих каналах |
| 5 | Голосовое | Аудио в обоих каналах |
| 6 | PDF / ZIP | Документ |
| 7 | 2+ файла в одном сообщении | Несколько постов |
| 8 | Сообщение в другом чате | Игнорируется |
| 9 | «X вошёл в чат» | Игнорируется |

---

# ЧАСТЬ 7. Устранение неполадок

### Webhook не приходит
- Проверьте HTTPS (Битрикс24 не шлёт на HTTP)
- `curl https://relay.ваш-домен.ru/health`
- Перерегистрируйте бота с правильным `webhookUrl`

### Файлы не скачиваются
- Бот должен быть **участником** чата
- Подождите 1–2 сек (disk Битрикс24 индексирует файл) — сервис делает retry
- Проверьте права вебхука `imbot`

### Telegram: Forbidden
- Бот не админ канала
- Нет права «Публикация сообщений»

### MAX: attachment.not.ready
- Нормально для видео/аудио — сервис повторяет до 6 раз
- Увеличьте `MAX_SEND_DELAY` до `1.0`

### Файл > 50 МБ не в Telegram
- Ожидаемое поведение — уведомление в TG, полный файл в MAX

### health показывает missing_env
- Заполните все обязательные поля в `.env`
- `sudo systemctl restart bitrix-relay`

---

# ЧАСТЬ 8. Обновление

```bash
cd /tmp
unzip -o bitrix-relay.zip
sudo cp -r bitrix-relay/app /opt/bitrix-relay/
sudo systemctl restart bitrix-relay
```

Файл `.env` и `data/dedup.db` не перезаписывайте.

---

# Переменные окружения

| Переменная | Описание |
|------------|----------|
| `BITRIX_WEBHOOK_URL` | URL входящего вебхука Битрикс24 |
| `BITRIX_BOT_ID` | ID зарегистрированного бота |
| `BITRIX_BOT_TOKEN` | Секрет бота при регистрации |
| `BITRIX_SOURCE_CHAT_ID` | ID чата-источника (число) |
| `BITRIX_APP_TOKEN` | Токен проверки webhook (рекомендуется) |
| `TELEGRAM_BOT_TOKEN` | Токен Telegram-бота |
| `TELEGRAM_CHANNEL_ID` | @канал или -100... |
| `MAX_BOT_TOKEN` | Токен MAX-бота |
| `MAX_CHANNEL_CHAT_ID` | ID канала MAX |
| `MESSAGE_AUTHOR_PREFIX` | Добавлять имя автора (true/false) |
| `MAX_SEND_DELAY` | Пауза между постами в MAX (сек) |
| `DEDUP_DB_PATH` | Путь к SQLite для дедупликации |

---

## Лицензия

MIT — используйте свободно.
