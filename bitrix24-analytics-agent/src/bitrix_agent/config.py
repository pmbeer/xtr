from __future__ import annotations

from pathlib import Path
from typing import Optional

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    bitrix24_webhook_url: str = Field(
        default="",
        description="Incoming Bitrix24 webhook URL ending with /",
    )
    bitrix24_user_id: Optional[int] = Field(
        default=None,
        description="User ID to analyze; defaults to webhook owner",
    )
    report_days: int = Field(default=7, ge=1, le=365)
    database_path: Path = Field(default=Path("./data/analytics.db"))
    host: str = "0.0.0.0"
    port: int = 8080

    def require_webhook(self) -> str:
        url = (self.bitrix24_webhook_url or "").strip()
        if not url:
            raise ValueError(
                "Задайте BITRIX24_WEBHOOK_URL в .env "
                "(входящий вебхук портала Bitrix24)."
            )
        if not url.endswith("/"):
            url += "/"
        return url


def get_settings() -> Settings:
    return Settings()
