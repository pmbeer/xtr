# Bitrix24 Analytics Agent

Агент для облачного Bitrix24: собирает и считает вашу личную активность.

## Что считает

**Задачи**
- сколько закрыто за период
- сколько в работе / ожидают / отложены
- просроченные
- распределение по статусам и стадиям
- среднее время закрытия задачи

**Открытые линии**
- сколько обращений обработано
- сколько закрыто / ещё открыто
- среднее время решения
- среднее ожидание первого ответа
- разбивка по каналам

## Быстрый старт

```bash
cd bitrix24-analytics-agent
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env
```

### 1. Входящий вебхук Bitrix24

1. Откройте портал → **Приложения** → **Разработчикам** → **Другое** → **Входящий вебхук**
2. Права минимум: `task`, `user`, `imopenlines` (желательно также `im`)
3. Скопируйте URL вида `https://ваш-портал.bitrix24.ru/rest/1/xxxxx/` в `.env`:

```env
BITRIX24_WEBHOOK_URL=https://your-portal.bitrix24.ru/rest/1/xxxxxxxx/
BITRIX24_USER_ID=
REPORT_DAYS=7
```

Если `BITRIX24_USER_ID` пустой — анализируется владелец вебхука.

### 2. CLI-отчёт

```bash
bitrix-agent
bitrix-agent --days 30
bitrix-agent --json --output report.json
```

Или без установки скрипта:

```bash
PYTHONPATH=src python -m bitrix_agent.cli --days 7
```

### 3. Веб-дашборд

```bash
bitrix-agent-web
# открыть http://127.0.0.1:8080
```

API JSON: `GET /api/report?days=7`

## Открытые линии: как получить полную историю

Bitrix24 не всегда отдаёт удобный список сессий на всех тарифах/версиях. Агент пробует источники по порядку:

1. `imopenlines.v2.Session.list` / статистика (если на портале есть обновление `imopenlines 26.700.0+`)
2. локальная SQLite-база событий
3. текущие диалоги через `im.recent.list` + `imopenlines.session.history.get`

### Рекомендуется: исходящий вебхук событий

Чтобы копить историю обращений:

1. Запустите веб-приложение так, чтобы URL был доступен из интернета (или через туннель)
2. В Bitrix24 создайте **исходящий вебхук** на события:
   - `OnSessionStart`
   - `OnSessionFinish`
3. URL обработчика: `https://ваш-хост/webhook/bitrix`

События сохраняются в `data/analytics.db` и попадают в отчёт.

## Структура

```
bitrix24-analytics-agent/
  src/bitrix_agent/
    client.py          # REST-клиент
    config.py          # настройки из .env
    storage.py         # SQLite для событий ОЛ
    analytics/
      tasks.py         # метрики задач
      openlines.py     # метрики открытых линий
      report.py        # сводный отчёт
    cli.py             # консольный отчёт
    web/               # дашборд + webhook
  tests/
```

## Тесты

```bash
pytest
```

## Примечания по безопасности

- Не коммитьте `.env` и URL входящего вебхука — это полный доступ в рамках выданных прав.
- Для продакшена лучше локальное/облачное приложение Bitrix24 с OAuth вместо долгоживущего входящего вебхука.
