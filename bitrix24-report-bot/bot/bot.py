"""Точка входа Telegram-бота: инициализация и запуск polling."""

from __future__ import annotations

import asyncio
import logging

from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode

from .bitrix.client import BitrixClient
from .config import Config, ConfigError, load_config
from .handlers import common, report
from .middlewares import AccessControlMiddleware

logger = logging.getLogger(__name__)


def _setup_logging(level: str) -> None:
    logging.basicConfig(
        level=getattr(logging, level, logging.INFO),
        format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    )
    # Снижаем "шум" от httpx/aiogram на уровне DEBUG.
    logging.getLogger("httpx").setLevel(max(logging.WARNING, getattr(logging, level, logging.INFO)))


async def run(config: Config) -> None:
    bot = Bot(
        token=config.telegram_bot_token,
        default=DefaultBotProperties(parse_mode=ParseMode.HTML),
    )
    dp = Dispatcher()

    access_control = AccessControlMiddleware(config)
    dp.message.middleware(access_control)

    dp.include_router(common.router)
    dp.include_router(report.router)

    bitrix_client = BitrixClient(config.bitrix_webhook_url)

    try:
        await bot.delete_webhook(drop_pending_updates=True)
        logger.info("Бот запущен, начинаю polling…")
        await dp.start_polling(bot, config=config, bitrix_client=bitrix_client)
    finally:
        await bitrix_client.close()
        await bot.session.close()


def main() -> None:
    try:
        config = load_config()
    except ConfigError as exc:
        print(f"Ошибка конфигурации: {exc}")  # noqa: T201 - выводим до инициализации логгера
        raise SystemExit(1) from exc

    _setup_logging(config.log_level)
    logger.info(
        "Конфигурация загружена: webhook=%s, default_user_id=%s, timezone=%s",
        config.bitrix_webhook_url,
        config.bitrix_default_user_id,
        config.timezone,
    )

    try:
        asyncio.run(run(config))
    except (KeyboardInterrupt, SystemExit):
        logger.info("Бот остановлен.")


if __name__ == "__main__":
    main()
