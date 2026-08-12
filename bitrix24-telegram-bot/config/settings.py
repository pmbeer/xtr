from __future__ import annotations

from pathlib import Path
from typing import List

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    telegram_bot_token: str = Field(default="", alias="TELEGRAM_BOT_TOKEN")
    bitrix_webhook_url: str = Field(default="", alias="BITRIX_WEBHOOK_URL")
    bitrix_user_id: int = Field(default=0, alias="BITRIX_USER_ID")
    allowed_telegram_ids: List[int] = Field(default_factory=list, alias="ALLOWED_TELEGRAM_IDS")
    default_period_days: int = Field(default=30, alias="DEFAULT_PERIOD_DAYS")
    reports_dir: Path = Field(default=Path("./data/reports"), alias="REPORTS_DIR")
    demo_mode: bool = Field(default=False, alias="DEMO_MODE")

    @field_validator("allowed_telegram_ids", mode="before")
    @classmethod
    def parse_allowed_ids(cls, value: object) -> List[int]:
        if value is None or value == "":
            return []
        if isinstance(value, list):
            return [int(item) for item in value]
        return [int(part.strip()) for part in str(value).split(",") if part.strip()]

    @field_validator("bitrix_webhook_url")
    @classmethod
    def normalize_webhook(cls, value: str) -> str:
        value = (value or "").strip()
        if value and not value.endswith("/"):
            value += "/"
        return value

    def ensure_dirs(self) -> None:
        self.reports_dir.mkdir(parents=True, exist_ok=True)


settings = Settings()
