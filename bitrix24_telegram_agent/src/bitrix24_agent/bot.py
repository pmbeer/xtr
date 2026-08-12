import asyncio
import logging

from aiogram import Bot, Dispatcher, F, Router
from aiogram.filters import Command, CommandStart
from aiogram.types import BufferedInputFile, Message

from .analytics import AnalyticsService
from .bitrix import BitrixClient
from .config import Settings
from .periods import parse_period
from .report import build_xlsx

logger = logging.getLogger(__name__)

HELP_TEXT = """Я формирую персональный Excel-отчёт по Bitrix24.

Примеры запросов:
• отчёт за сегодня
• отчёт за эту неделю
• отчёт за прошлый месяц
• отчёт за последние 14 дней
• отчёт с 01.08.2026 по 10.08.2026

Без указанного периода сформирую отчёт за текущий месяц."""


def create_dispatcher(settings: Settings, client: BitrixClient) -> Dispatcher:
    router = Router()
    semaphore = asyncio.Semaphore(2)
    service = AnalyticsService(
        client,
        settings.bitrix24_user_id,
        settings.bitrix24_openlines_stats_method,
    )

    async def is_allowed(message: Message) -> bool:
        user_id = message.from_user.id if message.from_user else None
        if user_id not in settings.telegram_allowed_user_ids:
            logger.warning("Rejected Telegram user ID %s", user_id)
            await message.answer("У вас нет доступа к этому боту.")
            return False
        return True

    @router.message(CommandStart())
    @router.message(Command("help"))
    async def help_handler(message: Message) -> None:
        if await is_allowed(message):
            await message.answer(HELP_TEXT)

    @router.message(Command("report"))
    @router.message(F.text)
    async def report_handler(message: Message) -> None:
        if not await is_allowed(message):
            return
        try:
            period = parse_period(message.text or "", settings.report_timezone)
        except ValueError as error:
            await message.answer(f"Не удалось разобрать период: {error}")
            return

        status = await message.answer(f"Собираю данные за период «{period.label}»…")
        try:
            async with semaphore:
                result = await service.collect(period)
                document = build_xlsx(result)
            filename = f"bitrix24_report_{period.start:%Y-%m-%d}_{period.end:%Y-%m-%d}.xlsx"
            await message.answer_document(
                BufferedInputFile(document, filename=filename),
                caption=(
                    f"Готово: {period.label}\n"
                    f"Завершено задач: {len(result.tasks.completed)}, "
                    f"активных: {len(result.tasks.active)}."
                ),
            )
            await status.delete()
        except Exception:
            logger.exception("Failed to generate report")
            await status.edit_text(
                "Не удалось сформировать отчёт. Проверьте доступ вебхука Bitrix24 "
                "к задачам и статистике Открытых линий."
            )

    dispatcher = Dispatcher()
    dispatcher.include_router(router)
    return dispatcher


async def run_bot(settings: Settings) -> None:
    bot = Bot(token=settings.telegram_bot_token.get_secret_value())
    async with BitrixClient(
        settings.bitrix24_webhook_url,
        settings.bitrix24_timeout_seconds,
    ) as client:
        dispatcher = create_dispatcher(settings, client)
        await dispatcher.start_polling(bot, allowed_updates=dispatcher.resolve_used_update_types())
