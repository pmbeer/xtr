"""Telegram-бот аналитики Bitrix24.

Принимает запросы на естественном языке («сколько задач я закрыл за
неделю?», «отчёт за месяц»), собирает статистику через REST Bitrix24
и присылает сводку в чат + подробный Excel-файл.
"""

import asyncio
import logging
from datetime import datetime

from aiogram import Bot, Dispatcher, F
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ChatAction, ParseMode
from aiogram.filters import Command, CommandStart
from aiogram.types import BufferedInputFile, Message

from analytics import (
    OpenLinesStats,
    TaskStats,
    collect_openlines_stats,
    collect_task_stats,
    resolve_period,
)
from analytics.periods import format_timedelta
from bitrix import Bitrix24Client
from config import Config, load_config
from nlp import ParsedQuery, parse_query
from reports import build_excel_report

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

HELP_TEXT = (
    "Я анализирую вашу работу в Bitrix24 и присылаю отчёт файлом.\n\n"
    "Просто напишите запрос, например:\n"
    "• <i>сколько задач я закрыл за неделю?</i>\n"
    "• <i>какие задачи у меня в работе и на каких стадиях?</i>\n"
    "• <i>сколько обращений я обработал за месяц?</i>\n"
    "• <i>среднее время решения вопроса за квартал</i>\n"
    "• <i>полный отчёт за прошлый месяц</i>\n\n"
    "Команды:\n"
    "/report — полный отчёт за текущий месяц\n"
    "/today — отчёт за сегодня\n"
    "/week — отчёт за текущую неделю\n"
    "/help — эта справка\n\n"
    "Понимаю периоды: сегодня, вчера, неделя, прошлая неделя, месяц, "
    "прошлый месяц, квартал, год."
)


def _build_summary_text(
    query: ParsedQuery,
    tasks: TaskStats | None,
    openlines: OpenLinesStats | None,
) -> str:
    period = (tasks or openlines).period
    lines = [
        f"<b>Отчёт за период: {period.label}</b>",
        f"({period.date_from:%d.%m.%Y} — {period.date_to:%d.%m.%Y})",
        "",
    ]

    if tasks is not None:
        if tasks.error:
            lines.append(f"⚠️ Задачи: не удалось получить данные ({tasks.error})")
        else:
            if "tasks_closed" in query.sections:
                lines.append(f"✅ Задач закрыто: <b>{tasks.closed_count}</b>")
                lines.append(
                    "⏱ Среднее время выполнения задачи: "
                    f"<b>{format_timedelta(tasks.avg_resolution_seconds)}</b>"
                )
            if "tasks_open" in query.sections:
                lines.append(f"🔧 Задач в работе: <b>{tasks.open_count}</b>")
                if tasks.overdue_count:
                    lines.append(f"🔥 Из них просрочено: <b>{tasks.overdue_count}</b>")
            if "stages" in query.sections and tasks.open_by_stage:
                lines.append("")
                lines.append("<b>Открытые задачи по стадиям:</b>")
                for stage, count in tasks.open_by_stage.items():
                    lines.append(f"• {stage} — {count}")

    if openlines is not None:
        if lines[-1] != "":
            lines.append("")
        if openlines.error:
            lines.append(
                f"⚠️ Открытые линии: не удалось получить данные ({openlines.error})"
            )
        else:
            lines.append(
                f"💬 Обращений за период: <b>{openlines.total_count}</b> "
                f"(обработано: <b>{openlines.handled_count}</b>, "
                f"открыто: <b>{openlines.open_count}</b>)"
            )
            lines.append(
                "⏱ Среднее время решения обращения: "
                f"<b>{format_timedelta(openlines.avg_resolution_seconds)}</b>"
            )

    lines.append("")
    lines.append("Подробности — в приложенном файле 📎")
    return "\n".join(lines)


async def _handle_report_request(
    message: Message, config: Config, query: ParsedQuery
) -> None:
    if not config.is_user_allowed(message.from_user.id):
        await message.answer("⛔ У вас нет доступа к этому боту.")
        return

    await message.bot.send_chat_action(message.chat.id, ChatAction.UPLOAD_DOCUMENT)
    period = resolve_period(query.period_name, config.tzinfo)

    need_tasks = bool(
        query.sections & {"tasks_closed", "tasks_open", "stages", "avg_time"}
    )
    need_openlines = "openlines" in query.sections

    tasks: TaskStats | None = None
    openlines: OpenLinesStats | None = None

    async with Bitrix24Client(config.bitrix_webhook_url) as client:
        if need_tasks:
            tasks = await collect_task_stats(client, config.bitrix_user_id, period)
        if need_openlines:
            openlines = await collect_openlines_stats(
                client, config.bitrix_user_id, period
            )

    if tasks is None and openlines is None:
        await message.answer(HELP_TEXT)
        return

    summary = _build_summary_text(query, tasks, openlines)

    report_bytes = build_excel_report(tasks, openlines)
    filename = f"bitrix24_отчёт_{datetime.now():%Y-%m-%d_%H-%M}.xlsx"
    document = BufferedInputFile(report_bytes, filename=filename)

    await message.answer_document(document, caption=None)
    await message.answer(summary)


def create_dispatcher(config: Config) -> Dispatcher:
    dispatcher = Dispatcher()

    @dispatcher.message(CommandStart())
    async def on_start(message: Message) -> None:
        await message.answer(
            f"Привет, {message.from_user.first_name}! 👋\n\n{HELP_TEXT}"
        )

    @dispatcher.message(Command("help"))
    async def on_help(message: Message) -> None:
        await message.answer(HELP_TEXT)

    @dispatcher.message(Command("report"))
    async def on_report(message: Message) -> None:
        await _handle_report_request(message, config, ParsedQuery(period_name="month"))

    @dispatcher.message(Command("today"))
    async def on_today(message: Message) -> None:
        await _handle_report_request(message, config, ParsedQuery(period_name="today"))

    @dispatcher.message(Command("week"))
    async def on_week(message: Message) -> None:
        await _handle_report_request(message, config, ParsedQuery(period_name="week"))

    @dispatcher.message(F.text)
    async def on_text(message: Message) -> None:
        query = parse_query(message.text)
        await _handle_report_request(message, config, query)

    return dispatcher


async def main() -> None:
    config = load_config()
    bot = Bot(
        token=config.telegram_bot_token,
        default=DefaultBotProperties(parse_mode=ParseMode.HTML),
    )
    dispatcher = create_dispatcher(config)
    logger.info("Бот запущен, ожидаю сообщения...")
    await dispatcher.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
