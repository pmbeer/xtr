"""Загрузка конфигурации бота из переменных окружения (.env)."""

import os
from dataclasses import dataclass, field
from zoneinfo import ZoneInfo

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Config:
    telegram_bot_token: str
    bitrix_webhook_url: str
    bitrix_user_id: int
    allowed_telegram_ids: frozenset[int] = field(default_factory=frozenset)
    timezone: str = "Europe/Moscow"

    @property
    def tzinfo(self) -> ZoneInfo:
        return ZoneInfo(self.timezone)

    def is_user_allowed(self, telegram_id: int) -> bool:
        return not self.allowed_telegram_ids or telegram_id in self.allowed_telegram_ids


def load_config() -> Config:
    token = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
    webhook = os.getenv("BITRIX_WEBHOOK_URL", "").strip()
    user_id = os.getenv("BITRIX_USER_ID", "").strip()

    missing = [
        name
        for name, value in [
            ("TELEGRAM_BOT_TOKEN", token),
            ("BITRIX_WEBHOOK_URL", webhook),
            ("BITRIX_USER_ID", user_id),
        ]
        if not value
    ]
    if missing:
        raise SystemExit(
            "Не заданы обязательные переменные окружения: "
            + ", ".join(missing)
            + ". Скопируйте .env.example в .env и заполните значения."
        )

    allowed = frozenset(
        int(part)
        for part in os.getenv("ALLOWED_TELEGRAM_IDS", "").replace(";", ",").split(",")
        if part.strip().lstrip("-").isdigit()
    )

    return Config(
        telegram_bot_token=token,
        bitrix_webhook_url=webhook.rstrip("/") + "/",
        bitrix_user_id=int(user_id),
        allowed_telegram_ids=allowed,
        timezone=os.getenv("TIMEZONE", "Europe/Moscow").strip() or "Europe/Moscow",
    )
