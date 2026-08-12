from pydantic import HttpUrl, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration loaded from environment variables or a .env file."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    telegram_bot_token: SecretStr
    bitrix24_webhook_url: HttpUrl
    bitrix24_user_id: int
    telegram_allowed_user_id: int | None = None
