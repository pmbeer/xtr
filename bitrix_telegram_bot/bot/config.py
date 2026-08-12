"""Конфигурация приложения."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    telegram_bot_token: str
    bitrix_webhook_url: str
    bitrix_user_id: int
    allowed_telegram_ids: str = ""

    @property
    def allowed_ids(self) -> set[int]:
        if not self.allowed_telegram_ids.strip():
            return set()
        return {int(x.strip()) for x in self.allowed_telegram_ids.split(",") if x.strip()}

    @property
    def bitrix_base_url(self) -> str:
        return self.bitrix_webhook_url.rstrip("/")

