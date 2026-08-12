"""Настройки приложения, читаются из переменных окружения и файла .env."""

from __future__ import annotations

import re
from functools import cached_property
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

WEBHOOK_RE = re.compile(
    r"^(?P<base>https?://[^/\s]+/rest/\d+/[A-Za-z0-9]+)(?:/.*)?$",
)


class Settings(BaseSettings):
    """Конфигурация бота.

    Списочные значения читаются как строки с разделителем-запятой: так
    настройка выглядит привычно в .env и docker-compose, где JSON неудобен.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    telegram_bot_token: str = Field(min_length=10)
    telegram_allowed_user_ids: str = ""

    bitrix_webhook_url: str
    bitrix_default_user_id: int | None = None
    bitrix_rate_limit: float = 2.0
    bitrix_timeout: float = 30.0
    bitrix_max_records: int = 5000

    timezone: str = "Europe/Moscow"
    database_path: Path = Path("./data/bot.sqlite3")
    reports_dir: Path = Path("./data/reports")
    default_report_format: str = "xlsx"
    log_level: str = "INFO"

    @field_validator("bitrix_webhook_url")
    @classmethod
    def _validate_webhook(cls, value: str) -> str:
        match = WEBHOOK_RE.match(value.strip())
        if not match:
            raise ValueError(
                "BITRIX_WEBHOOK_URL должен иметь вид "
                "https://portal.bitrix24.ru/rest/<user_id>/<код вебхука>/"
            )
        return match.group("base") + "/"

    @field_validator("default_report_format")
    @classmethod
    def _validate_format(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in {"xlsx", "csv", "json"}:
            raise ValueError("DEFAULT_REPORT_FORMAT должен быть xlsx, csv или json")
        return normalized

    @field_validator("timezone")
    @classmethod
    def _validate_timezone(cls, value: str) -> str:
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError) as exc:  # pragma: no cover
            raise ValueError(f"Неизвестный часовой пояс: {value}") from exc
        return value

    @cached_property
    def allowed_user_ids(self) -> frozenset[int]:
        """Разбирает TELEGRAM_ALLOWED_USER_IDS в множество идентификаторов."""
        ids: set[int] = set()
        for chunk in re.split(r"[,\s;]+", self.telegram_allowed_user_ids or ""):
            if chunk:
                ids.add(int(chunk))
        return frozenset(ids)

    @cached_property
    def tz(self) -> ZoneInfo:
        return ZoneInfo(self.timezone)

    @cached_property
    def portal_url(self) -> str:
        """Адрес портала без части вебхука — нужен для ссылок в отчётах."""
        match = re.match(r"^(https?://[^/]+)/", self.bitrix_webhook_url)
        return match.group(1) if match else ""

    def ensure_directories(self) -> None:
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        self.reports_dir.mkdir(parents=True, exist_ok=True)


def load_settings(**overrides: object) -> Settings:
    return Settings(**overrides)  # type: ignore[arg-type]
