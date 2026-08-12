from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()


def _env(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


def _env_bool(name: str, default: bool = True) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "y", "on"}


@dataclass(frozen=True)
class Settings:
    bitrix_webhook_url: str
    bitrix_bot_id: int
    bitrix_bot_token: str
    bitrix_source_chat_id: int
    bitrix_app_token: str
    telegram_bot_token: str
    telegram_channel_id: str
    max_bot_token: str
    max_channel_chat_id: int
    host: str
    port: int
    message_author_prefix: bool
    max_send_delay: float
    dedup_db_path: Path

    @classmethod
    def load(cls) -> "Settings":
        webhook = _env("BITRIX_WEBHOOK_URL")
        if webhook and not webhook.endswith("/"):
            webhook += "/"

        return cls(
            bitrix_webhook_url=webhook,
            bitrix_bot_id=int(_env("BITRIX_BOT_ID", "0") or "0"),
            bitrix_bot_token=_env("BITRIX_BOT_TOKEN"),
            bitrix_source_chat_id=int(_env("BITRIX_SOURCE_CHAT_ID", "0") or "0"),
            bitrix_app_token=_env("BITRIX_APP_TOKEN"),
            telegram_bot_token=_env("TELEGRAM_BOT_TOKEN"),
            telegram_channel_id=_env("TELEGRAM_CHANNEL_ID"),
            max_bot_token=_env("MAX_BOT_TOKEN"),
            max_channel_chat_id=int(_env("MAX_CHANNEL_CHAT_ID", "0") or "0"),
            host=_env("HOST", "127.0.0.1"),
            port=int(_env("PORT", "8000") or "8000"),
            message_author_prefix=_env_bool("MESSAGE_AUTHOR_PREFIX", True),
            max_send_delay=float(_env("MAX_SEND_DELAY", "0.6") or "0.6"),
            dedup_db_path=Path(_env("DEDUP_DB_PATH", "/opt/bitrix-relay/data/dedup.db")),
        )

    def validate_runtime(self) -> list[str]:
        errors: list[str] = []
        required = {
            "BITRIX_WEBHOOK_URL": self.bitrix_webhook_url,
            "BITRIX_BOT_ID": str(self.bitrix_bot_id),
            "BITRIX_BOT_TOKEN": self.bitrix_bot_token,
            "BITRIX_SOURCE_CHAT_ID": str(self.bitrix_source_chat_id),
            "TELEGRAM_BOT_TOKEN": self.telegram_bot_token,
            "TELEGRAM_CHANNEL_ID": self.telegram_channel_id,
            "MAX_BOT_TOKEN": self.max_bot_token,
            "MAX_CHANNEL_CHAT_ID": str(self.max_channel_chat_id),
        }
        for key, value in required.items():
            if not value or value in {"0", "change_me_bot_secret_token"}:
                errors.append(key)
        return errors


settings = Settings.load()
