"""Основной сценарий: запрос пользователя -> файл с результатами."""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime

from aiogram import F, Router
from aiogram.filters import Command
from aiogram.types import BufferedInputFile, Message

from b24agent.analytics.models import Report
from b24agent.analytics.service import AnalyticsService
from b24agent.bitrix.errors import Bitrix24Error
from b24agent.bot import texts
from b24agent.bot.keyboards import main_keyboard
from b24agent.bot.middlewares import SingleFlightMiddleware
from b24agent.config import Settings
from b24agent.nlu import parse_query
from b24agent.reports import GeneratedReport, build_report_file, build_summary
from b24agent.storage import UserStore

logger = logging.getLogger(__name__)


def build_router() -> Router:
    """Создаёт новый роутер: экземпляр Router можно подключить лишь однажды."""
    router = Router(name="reports")
    router.message.middleware(SingleFlightMiddleware())
    router.message.register(handle_report_command, Command("report"))
    router.message.register(handle_free_text, F.text & ~F.text.startswith("/"))
    return router


async def handle_report_command(
    message: Message,
    settings: Settings,
    store: UserStore,
    service: AnalyticsService,
) -> None:
    await _produce_report(message, "отчёт за текущий месяц", settings, store, service)


async def handle_free_text(
    message: Message,
    settings: Settings,
    store: UserStore,
    service: AnalyticsService,
) -> None:
    await _produce_report(message, message.text or "", settings, store, service)


async def _produce_report(
    message: Message,
    query: str,
    settings: Settings,
    store: UserStore,
    service: AnalyticsService,
) -> None:
    if message.from_user is None:
        return

    user_settings = await store.get(message.from_user.id)
    request = parse_query(
        query,
        now=datetime.now(settings.tz),
        tz=settings.tz,
        default_format=user_settings.report_format,
        bitrix_user_id=user_settings.bitrix_user_id,
    )

    status = await message.answer(f"{texts.BUILDING}\n<i>{request.period.human()}</i>")

    try:
        report = await service.build_report(request)
        document = await asyncio.to_thread(build_report_file, report)
    except Bitrix24Error as exc:
        logger.warning("Отчёт не собран: %s", exc)
        await status.edit_text(texts.FAILED.format(error=f"{exc.code} {exc.description}".strip()))
        return
    except Exception as exc:
        logger.exception("Непредвиденная ошибка при сборке отчёта")
        await status.edit_text(texts.FAILED.format(error=str(exc)))
        return

    await _send_report(message, status, report, document)
    await store.log_report(
        message.from_user.id,
        query=request.raw_query,
        period_label=request.period.label,
        filename=document.filename,
    )


async def _send_report(
    message: Message,
    status: Message,
    report: Report,
    document: GeneratedReport,
) -> None:
    summary = build_summary(report)
    await status.edit_text(summary)
    await message.answer_document(
        BufferedInputFile(document.content, filename=document.filename),
        caption=(
            f"{report.period.human()} · {document.report_format.value.upper()}"
            f" · {document.size_kb} КБ"
        ),
        reply_markup=main_keyboard(),
    )
