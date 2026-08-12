"""Конфигурация агента аналитики Bitrix24."""

from __future__ import annotations

from datetime import date, datetime

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    bitrix24_webhook_url: str = Field(alias="BITRIX24_WEBHOOK_URL")
    bitrix24_user_id: int = Field(alias="BITRIX24_USER_ID")
    analytics_date_from: date | None = Field(default=None, alias="ANALYTICS_DATE_FROM")
    analytics_date_to: date | None = Field(default=None, alias="ANALYTICS_DATE_TO")

    @field_validator("bitrix24_webhook_url")
    @classmethod
    def strip_trailing_slash(cls, value: str) -> str:
        return value.rstrip("/")

    def resolve_period(self) -> tuple[date, date]:
        today = date.today()
        date_from = self.analytics_date_from or today.replace(day=1)
        date_to = self.analytics_date_to or today
        return date_from, date_to

    def period_filter_datetime(self) -> tuple[str, str]:
        date_from, date_to = self.resolve_period()
        start = datetime.combine(date_from, datetime.min.time()).isoformat()
        end = datetime.combine(date_to, datetime.max.time()).isoformat()
        return start, end
