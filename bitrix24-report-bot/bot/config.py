"""Загрузка и валидация конфигурации бота из переменных окружения (.env)."""

from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass
from pathlib import Path
from zoneinfo import ZoneInfo

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent


def _parse_int_list(raw: str) -> list[int]:
    result = []
    for chunk in raw.replace(";", ",").split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        try:
            result.append(int(chunk))
        except ValueError:
            logging.getLogger(__name__).warning("Пропускаю некорректный Telegram ID: %r", chunk)
    return result


def _parse_user_map(raw: str) -> dict[int, int]:
    raw = (raw or "").strip()
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        logging.getLogger(__name__).warning(
            "TELEGRAM_TO_BITRIX_USER_MAP не является корректным JSON, игнорирую значение: %r", raw
        )
        return {}
    result: dict[int, int] = {}
    for key, value in data.items():
        try:
            result[int(key)] = int(value)
        except (TypeError, ValueError):
            continue
    return result


class ConfigError(RuntimeError):
    """Ошибка конфигурации приложения."""


@dataclass
class Config:
    telegram_bot_token: str
    telegram_allowed_user_ids: list[int]
    bitrix_webhook_url: str
    bitrix_default_user_id: int
    telegram_to_bitrix_user_map: dict[int, int]
    timezone: ZoneInfo
    reports_dir: Path
    log_level: str = "INFO"

    def bitrix_user_id_for(self, telegram_user_id: int) -> int:
        """Возвращает ID пользователя Битрикс24, чью статистику нужно показать
        конкретному пользователю Telegram."""
        return self.telegram_to_bitrix_user_map.get(telegram_user_id, self.bitrix_default_user_id)

    def is_allowed(self, telegram_user_id: int) -> bool:
        if not self.telegram_allowed_user_ids:
            # Список не задан явно — доступ не ограничивается (небезопасно, но допустимо
            # для тестового запуска).
            return True
        return telegram_user_id in self.telegram_allowed_user_ids


def load_config(env_file: str | os.PathLike[str] | None = None) -> Config:
    """Читает .env (если найден) и переменные окружения, возвращает Config.

    Бросает ConfigError, если обязательные параметры не заданы.
    """
    load_dotenv(dotenv_path=env_file or (BASE_DIR / ".env"), override=False)

    token = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
    if not token:
        raise ConfigError("Не задан TELEGRAM_BOT_TOKEN. Заполните .env по примеру .env.example")

    webhook_url = os.getenv("BITRIX_WEBHOOK_URL", "").strip()
    if not webhook_url:
        raise ConfigError("Не задан BITRIX_WEBHOOK_URL. Заполните .env по примеру .env.example")
    if not webhook_url.endswith("/"):
        webhook_url += "/"

    default_user_raw = os.getenv("BITRIX_DEFAULT_USER_ID", "").strip()
    try:
        default_user_id = int(default_user_raw)
    except ValueError:
        raise ConfigError(
            "BITRIX_DEFAULT_USER_ID должен быть числом (ID пользователя Битрикс24)."
        ) from None

    tz_name = os.getenv("BITRIX_TIMEZONE", "Europe/Moscow").strip() or "Europe/Moscow"
    try:
        tz = ZoneInfo(tz_name)
    except Exception as exc:  # noqa: BLE001 - хотим единое сообщение об ошибке
        raise ConfigError(f"Некорректный BITRIX_TIMEZONE={tz_name!r}: {exc}") from exc

    reports_dir = Path(os.getenv("REPORTS_DIR", str(BASE_DIR / "data" / "reports"))).resolve()
    reports_dir.mkdir(parents=True, exist_ok=True)

    return Config(
        telegram_bot_token=token,
        telegram_allowed_user_ids=_parse_int_list(os.getenv("TELEGRAM_ALLOWED_USER_IDS", "")),
        bitrix_webhook_url=webhook_url,
        bitrix_default_user_id=default_user_id,
        telegram_to_bitrix_user_map=_parse_user_map(os.getenv("TELEGRAM_TO_BITRIX_USER_MAP", "{}")),
        timezone=tz,
        reports_dir=reports_dir,
        log_level=os.getenv("LOG_LEVEL", "INFO").strip().upper() or "INFO",
    )
