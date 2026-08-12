"""Сборка и запуск Telegram-бота."""

from __future__ import annotations

import logging

from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode
from aiogram.types import BotCommand

from b24agent.analytics.service import AnalyticsService
from b24agent.bitrix.client import Bitrix24Client
from b24agent.bitrix.errors import Bitrix24Error
from b24agent.bot.handlers import build_router
from b24agent.bot.middlewares import AccessMiddleware
from b24agent.config import Settings
from b24agent.storage import UserStore

logger = logging.getLogger(__name__)

BOT_COMMANDS = (
    BotCommand(command="report", description="Отчёт за текущий месяц"),
    BotCommand(command="whoami", description="По кому считается отчёт"),
    BotCommand(command="link", description="Указать сотрудника Битрикс24"),
    BotCommand(command="format", description="Формат файла: xlsx, csv, json"),
    BotCommand(command="history", description="Последние запросы"),
    BotCommand(command="help", description="Справка"),
)


def build_dispatcher(
    settings: Settings,
    service: AnalyticsService,
    store: UserStore,
) -> Dispatcher:
    dispatcher = Dispatcher()
    dispatcher["settings"] = settings
    dispatcher["service"] = service
    dispatcher["store"] = store

    access = AccessMiddleware(settings.allowed_user_ids)
    dispatcher.message.middleware(access)
    dispatcher.callback_query.middleware(access)
    dispatcher.include_router(build_router())
    return dispatcher


async def run_bot(settings: Settings) -> None:
    """Запускает бота на long polling до остановки процесса."""
    settings.ensure_directories()

    store = UserStore(settings.database_path)
    await store.init()

    client = Bitrix24Client(
        settings.bitrix_webhook_url,
        timeout=settings.bitrix_timeout,
        rate_limit=settings.bitrix_rate_limit,
    )
    service = AnalyticsService(
        client,
        tz=settings.tz,
        portal_url=settings.portal_url,
        default_user_id=settings.bitrix_default_user_id,
        max_records=settings.bitrix_max_records,
    )

    bot = Bot(
        token=settings.telegram_bot_token,
        default=DefaultBotProperties(parse_mode=ParseMode.HTML),
    )
    dispatcher = build_dispatcher(settings, service, store)

    try:
        await _log_portal_owner(service)
        await bot.set_my_commands(BOT_COMMANDS)
        logger.info("Бот запущен, ожидаю сообщения")
        await dispatcher.start_polling(bot, allowed_updates=dispatcher.resolve_used_update_types())
    finally:
        await client.aclose()
        await bot.session.close()


async def _log_portal_owner(service: AnalyticsService) -> None:
    """Проверяет вебхук на старте, чтобы проблема была видна сразу в логах.

    Недоступный портал не мешает запуску: бот поднимется и ответит на запрос
    понятной ошибкой вместо молчания.
    """
    try:
        user = await service.resolve_user(None)
    except Bitrix24Error as exc:
        logger.error(
            "Вебхук Битрикс24 не отвечает (%s). Бот запустится, но отчёты собрать "
            "не сможет — проверьте BITRIX_WEBHOOK_URL и права вебхука",
            exc,
        )
        return
    logger.info("Вебхук Битрикс24 работает, отчёты по умолчанию: %s (ID %s)", user.name, user.id)
