"""Загрузка конфигурации агента из переменных окружения / .env файла."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


def _load_dotenv_if_available(dotenv_path: Optional[str] = None) -> None:
    """Подгружает .env файл, если установлен python-dotenv. Не обязателен."""
    try:
        from dotenv import load_dotenv
    except ImportError:
        return
    if dotenv_path:
        load_dotenv(dotenv_path)
    else:
        load_dotenv()


class ConfigError(RuntimeError):
    """Ошибка конфигурации агента (не хватает обязательных параметров)."""


@dataclass(frozen=True)
class Config:
    webhook_url: str
    user_id: Optional[int]
    tz_offset: str
    notify: bool

    @staticmethod
    def load(env_file: Optional[str] = None) -> "Config":
        _load_dotenv_if_available(env_file)

        webhook_url = os.environ.get("BITRIX24_WEBHOOK_URL", "").strip()
        if not webhook_url:
            raise ConfigError(
                "Не задан BITRIX24_WEBHOOK_URL. Создайте входящий вебхук в "
                "Битрикс24 (Разработчикам -> Другое -> Входящий вебхук) и "
                "укажите его в .env (см. .env.example)."
            )
        if not webhook_url.endswith("/"):
            webhook_url += "/"

        user_id_raw = os.environ.get("BITRIX24_USER_ID", "").strip()
        user_id = int(user_id_raw) if user_id_raw else None

        tz_offset = os.environ.get("BITRIX24_TZ_OFFSET", "").strip() or _local_tz_offset()

        notify_raw = os.environ.get("BITRIX24_NOTIFY", "false").strip().lower()
        notify = notify_raw in ("1", "true", "yes", "y", "on")

        return Config(
            webhook_url=webhook_url,
            user_id=user_id,
            tz_offset=tz_offset,
            notify=notify,
        )


def _local_tz_offset() -> str:
    import time

    offset_seconds = -time.timezone if not time.daylight else -time.altzone
    sign = "+" if offset_seconds >= 0 else "-"
    offset_seconds = abs(offset_seconds)
    hours, remainder = divmod(offset_seconds, 3600)
    minutes = remainder // 60
    return f"{sign}{hours:02d}:{minutes:02d}"


def find_default_env_file() -> Optional[str]:
    candidate = Path.cwd() / ".env"
    return str(candidate) if candidate.exists() else None
