# Bitrix24 → Telegram Analytics Bot

Telegram-бот на Python, который подключается к **облачному Bitrix24** через входящий вебхук, считает вашу рабочую статистику и при запросе присылает **готовый файл Excel** (или TXT).

## Что считает

**Задачи**
- сколько закрыто
- сколько в работе / ждут выполнения / ждут контроля / отложены
- просроченные
- распределение по статусам и стадиям канбана
- среднее время закрытия задачи

**Открытые линии**
- сколько обращений (сессий) обработано
- закрытые / активные
- среднее время первого ответа
- среднее время решения
- разбивка по каналам (если API отдаёт source)

## Быстрый старт

### 1. Создайте Telegram-бота
1. Откройте [@BotFather](https://t.me/BotFather)
2. `/newbot` → получите `TELEGRAM_BOT_TOKEN`

### 2. Создайте входящий вебхук Bitrix24
1. Bitrix24 → **Разработчикам** → **Другое** → **Входящий вебхук**
2. Права минимум: `task`, `user`, `crm`, `imopenlines` (если есть)
3. Скопируйте URL вида  
   `https://ваш-портал.bitrix24.ru/rest/1/xxxxxxxxxxxxxxxx/`

### 3. Узнайте свой `BITRIX_USER_ID`
- URL профиля или метод `user.current` / `user.get`

### 4. Настройка

```bash
cd bitrix24-telegram-bot
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# отредактируйте .env
python main.py
```

### Демо без Bitrix24

В `.env`:

```env
DEMO_MODE=true
TELEGRAM_BOT_TOKEN=...
BITRIX_USER_ID=1
```

Или локально сгенерировать файл:

```bash
DEMO_MODE=true python generate_report.py --days 7
```

### Docker

```bash
cp .env.example .env
docker compose up -d --build
```

## Как пользоваться в Telegram

Примеры сообщений боту:
- `отчёт за 7 дней`
- `сколько задач я закрыл за месяц`
- `статистика открытых линий за прошлую неделю`
- `отчёт 01.07.2026 — 31.07.2026`
- `краткая сводка без файла`

Команды: `/start` `/help` `/report` `/stats`

Бот отвечает текстовой сводкой и прикрепляет `.xlsx`.

## Структура

```
bitrix24-telegram-bot/
  main.py                 # запуск Telegram-бота
  generate_report.py      # отчёт без Telegram
  bot/                    # handlers, NLP запросов, клавиатура
  services/
    bitrix.py             # REST-клиент Bitrix24
    analytics.py          # агрегация метрик
    report.py             # Excel/TXT
    models.py             # модели данных
  config/settings.py
  tests/
```

## Важно про открытые линии

На разных тарифах/порталах набор REST-методов отличается. Бот пробует:
1. `imopenlines.v2.Session.list`
2. fallback: `crm.activity.list` с `PROVIDER_ID=IMOPENLINES_SESSION`

Если оба варианта недоступны, в отчёте будет примечание — расширьте права вебхука или уточните у администратора портала доступ к статистике открытых линий.

## Безопасность

- Не публикуйте `.env` и URL вебхука
- Ограничьте доступ через `ALLOWED_TELEGRAM_IDS=123,456`
- Вебхук Bitrix24 = полный доступ в рамках выданных прав
