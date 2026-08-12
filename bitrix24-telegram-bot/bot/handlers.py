from __future__ import annotations

import logging
from typing import Optional

from aiogram import Bot, Dispatcher, F, Router
from aiogram.filters import Command, CommandStart
from aiogram.types import BufferedInputFile, Message

from bot.keyboards import main_keyboard
from bot.nlp import UserIntent, parse_user_request
from config import settings
from services.analytics import AnalyticsService
from services.bitrix import BitrixAPIError, BitrixClient
from services.models import AnalyticsReport
from services.report import ReportGenerator

logger = logging.getLogger(__name__)
router = Router()


HELP_TEXT = (
    "Я анализирую ваши действия в облачном Bitrix24 и отдаю готовый файл-отчёт.\n\n"
    "Что умею считать:\n"
    "• закрытые задачи и задачи в работе\n"
    "• статусы и стадии задач\n"
    "• просрочки\n"
    "• обращения в открытых линиях\n"
    "• среднее время ответа и решения\n\n"
    "Примеры запросов:\n"
    "• отчёт за 7 дней\n"
    "• сколько задач я закрыл за месяц\n"
    "• статистика открытых линий за прошлую неделю\n"
    "• отчёт 01.07.2026 — 31.07.2026\n"
    "• краткая сводка без файла\n\n"
    "Команды: /report /stats /help"
)


def _is_allowed(user_id: Optional[int]) -> bool:
    if not settings.allowed_telegram_ids:
        return True
    return bool(user_id and user_id in settings.allowed_telegram_ids)


async def _build_and_send(message: Message, intent: UserIntent) -> None:
    await message.answer("⏳ Собираю данные из Bitrix24…")

    if settings.demo_mode:
        service = AnalyticsService(None, settings.bitrix_user_id or 1, demo_mode=True)
        report = await service.build_report(intent.period)
        await _deliver_report(message, report, intent)
        return

    async with BitrixClient(settings.bitrix_webhook_url) as client:
        service = AnalyticsService(client, settings.bitrix_user_id, demo_mode=False)
        report = await service.build_report(intent.period)
    await _deliver_report(message, report, intent)


async def _deliver_report(message: Message, report: AnalyticsReport, intent: UserIntent) -> None:
    summary = "\n".join(report.summary_lines or report.build_summary())
    if len(summary) > 3500:
        summary = summary[:3490] + "\n…"

    await message.answer(f"<pre>{_escape_pre(summary)}</pre>", parse_mode="HTML")

    if not intent.want_file:
        return

    generator = ReportGenerator(settings.reports_dir)
    if intent.format == "txt":
        path = generator.generate_txt(report)
    else:
        path = generator.generate_excel(report)

    document = BufferedInputFile(path.read_bytes(), filename=path.name)
    await message.answer_document(
        document,
        caption=f"Готовый отчёт за {report.period.date_from:%d.%m.%Y} — {report.period.date_to:%d.%m.%Y}",
    )


def _escape_pre(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


@router.message(CommandStart())
async def cmd_start(message: Message) -> None:
    if not _is_allowed(message.from_user.id if message.from_user else None):
        await message.answer("Доступ запрещён.")
        return
    await message.answer(HELP_TEXT, reply_markup=main_keyboard())


@router.message(Command("help"))
async def cmd_help(message: Message) -> None:
    if not _is_allowed(message.from_user.id if message.from_user else None):
        await message.answer("Доступ запрещён.")
        return
    await message.answer(HELP_TEXT, reply_markup=main_keyboard())


@router.message(Command("report", "stats"))
async def cmd_report(message: Message) -> None:
    if not _is_allowed(message.from_user.id if message.from_user else None):
        await message.answer("Доступ запрещён.")
        return
    text = message.text or ""
    # /report 7
    parts = text.split(maxsplit=1)
    arg = parts[1] if len(parts) > 1 else f"отчёт за {settings.default_period_days} дней"
    if arg.isdigit():
        arg = f"отчёт за {arg} дней"
    intent = parse_user_request(arg, default_days=settings.default_period_days)
    intent.kind = "report"
    try:
        await _build_and_send(message, intent)
    except BitrixAPIError as exc:
        logger.exception("Bitrix error")
        await message.answer(f"Ошибка Bitrix24: {exc}")
    except Exception as exc:  # noqa: BLE001
        logger.exception("Report failed")
        await message.answer(f"Не удалось построить отчёт: {exc}")


@router.message(F.text)
async def on_text(message: Message) -> None:
    if not _is_allowed(message.from_user.id if message.from_user else None):
        await message.answer("Доступ запрещён.")
        return

    text = message.text or ""
    # кнопки
    mapping = {
        "📊 Отчёт за 7 дней": "отчёт за 7 дней",
        "📊 Отчёт за 30 дней": "отчёт за 30 дней",
        "✅ Только задачи": "отчёт по задачам за 30 дней",
        "💬 Только открытые линии": "статистика открытых линий за 30 дней",
        "📝 Краткая сводка": "краткая сводка за 30 дней без файла",
        "❓ Помощь": "/help",
    }
    text = mapping.get(text, text)

    intent = parse_user_request(text, default_days=settings.default_period_days)
    if intent.kind == "help":
        await message.answer(HELP_TEXT, reply_markup=main_keyboard())
        return
    if intent.kind == "unknown":
        await message.answer(
            "Не совсем понял запрос. Напишите, например: «отчёт за 7 дней» или нажмите кнопку.",
            reply_markup=main_keyboard(),
        )
        return

    try:
        await _build_and_send(message, intent)
    except BitrixAPIError as exc:
        logger.exception("Bitrix error")
        await message.answer(f"Ошибка Bitrix24: {exc}")
    except Exception as exc:  # noqa: BLE001
        logger.exception("Report failed")
        await message.answer(f"Не удалось построить отчёт: {exc}")


def create_dispatcher() -> Dispatcher:
    dp = Dispatcher()
    dp.include_router(router)
    return dp


async def run_bot() -> None:
    if not settings.telegram_bot_token and not settings.demo_mode:
        raise RuntimeError("TELEGRAM_BOT_TOKEN не задан")
    if not settings.telegram_bot_token:
        raise RuntimeError("TELEGRAM_BOT_TOKEN не задан (нужен даже в DEMO_MODE для запуска бота)")

    settings.ensure_dirs()
    bot = Bot(token=settings.telegram_bot_token)
    dp = create_dispatcher()
    logger.info(
        "Bot started (demo_mode=%s, user_id=%s)",
        settings.demo_mode,
        settings.bitrix_user_id,
    )
    await dp.start_polling(bot)
