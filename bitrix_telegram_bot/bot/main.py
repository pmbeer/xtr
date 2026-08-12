"""Точка входа Telegram-бота."""

import logging
import sys

from telegram.ext import Application, CommandHandler, MessageHandler, filters

from bitrix.analytics import AnalyticsService
from bitrix.client import Bitrix24Client
from bot.config import Settings
from bot.handlers import (
    help_command,
    report_command,
    start_command,
    summary_command,
    text_handler,
)

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger(__name__)


def main() -> None:
    try:
        settings = Settings()
    except Exception as e:
        logger.error("Не удалось загрузить настройки. Создайте файл .env: %s", e)
        sys.exit(1)

    bitrix_client = Bitrix24Client(settings.bitrix_base_url)
    analytics = AnalyticsService(bitrix_client)

    app = (
        Application.builder()
        .token(settings.telegram_bot_token)
        .build()
    )

    app.bot_data["settings"] = settings
    app.bot_data["bitrix_client"] = bitrix_client
    app.bot_data["analytics"] = analytics

    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(CommandHandler("report", report_command))
    app.add_handler(CommandHandler("summary", summary_command))
    app.add_handler(
        MessageHandler(filters.TEXT & ~filters.COMMAND, text_handler)
    )

    logger.info("Бот запущен. Bitrix24 user ID: %s", settings.bitrix_user_id)
    app.run_polling(allowed_updates=["message"])


if __name__ == "__main__":
    main()
