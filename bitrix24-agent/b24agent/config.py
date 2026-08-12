"""Загрузка настроек агента: переменные окружения и файл ``.env``."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Dict, Optional

ENV_WEBHOOK = "BITRIX24_WEBHOOK_URL"
ENV_USER_ID = "BITRIX24_USER_ID"


def load_dotenv(path: Optional[Path] = None) -> Dict[str, str]:
    """Минимальный загрузчик ``.env`` (без внешних зависимостей).

    Значения из файла не перекрывают уже установленные переменные окружения.
    """
    path = path or Path.cwd() / ".env"
    loaded: Dict[str, str] = {}
    if not path.is_file():
        return loaded
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip("'\"")
        if key and key not in os.environ:
            os.environ[key] = value
            loaded[key] = value
    return loaded


def get_webhook_url() -> str:
    url = os.environ.get(ENV_WEBHOOK, "").strip()
    if not url:
        raise SystemExit(
            f"Не задан {ENV_WEBHOOK}. Создайте входящий вебхук в Битрикс24 "
            "(Разработчикам → Другое → Входящий вебхук) и укажите его URL "
            f"в переменной окружения {ENV_WEBHOOK} или в файле .env."
        )
    return url


def get_default_user_id() -> Optional[int]:
    raw = os.environ.get(ENV_USER_ID, "").strip()
    return int(raw) if raw.isdigit() else None
