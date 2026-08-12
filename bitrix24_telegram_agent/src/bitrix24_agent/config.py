from functools import lru_cache
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=Path(__file__).parents[2] / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    telegram_bot_token: SecretStr
    telegram_allowed_user_ids: frozenset[int]
    bitrix24_webhook_url: str
    bitrix24_user_id: int | None = None
    bitrix24_timeout_seconds: float = Field(default=30, gt=0, le=120)
    bitrix24_openlines_stats_method: str = "imopenlines.v2.Stat.get"
    report_timezone: str = "Europe/Moscow"
    log_level: str = "INFO"

    @field_validator("telegram_allowed_user_ids", mode="before")
    @classmethod
    def parse_user_ids(cls, value: object) -> object:
        if isinstance(value, str):
            return frozenset(int(item.strip()) for item in value.split(",") if item.strip())
        return value

    @field_validator("telegram_allowed_user_ids")
    @classmethod
    def ensure_allowlist(cls, value: frozenset[int]) -> frozenset[int]:
        if not value:
            raise ValueError("TELEGRAM_ALLOWED_USER_IDS must contain at least one user ID")
        return value

    @field_validator("bitrix24_webhook_url")
    @classmethod
    def validate_webhook(cls, value: str) -> str:
        value = value.strip().rstrip("/") + "/"
        if not value.startswith("https://"):
            raise ValueError("BITRIX24_WEBHOOK_URL must use HTTPS")
        if "/rest/" not in value:
            raise ValueError("BITRIX24_WEBHOOK_URL must be an incoming webhook URL")
        return value

    @field_validator("report_timezone")
    @classmethod
    def validate_timezone(cls, value: str) -> str:
        try:
            ZoneInfo(value)
        except ZoneInfoNotFoundError as error:
            raise ValueError(f"Unknown timezone: {value}") from error
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
