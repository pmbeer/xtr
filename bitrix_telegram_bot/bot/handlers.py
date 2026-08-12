"""Обработчики команд Telegram-бота."""

from __future__ import annotations

import logging
import os

from telegram import Update
from telegram.ext import ContextTypes

from bitrix.analytics import AnalyticsService, parse_period
from bitrix.client import Bitrix24Client, Bitrix24Error
from bot.config import Settings
from reports.generator import generate_excel_report, _format_duration

logger = logging.getLogger(__name__)

HELP_TEXT = """
📊 *Bitrix24 Analytics Bot*

Анализирует вашу активность в облачном Bitrix24 и формирует Excel-отчёт.

*Команды:*
/start — приветствие и помощь
/report — отчёт за последние 30 дней
/report сегодня — отчёт за сегодня
/report неделя — отчёт за 7 дней
/report месяц — отчёт за 30 дней
/report 2024-01-01 2024-01-31 — отчёт за период
/summary — краткая сводка без файла
/help — эта помощь

*Что анализируется:*
• Закрытые и активные задачи
• Стадии и статусы задач
• Обращения в открытой линии
• Среднее время решения и первого ответа

Просто напишите «отчёт» или «report» с периодом — бот отправит файл.
"""


def _is_allowed(user_id: int, settings: Settings) -> bool:
    allowed = settings.allowed_ids
    if not allowed:
        return True
    return user_id in allowed


async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.bot_data["settings"]
    if not _is_allowed(update.effective_user.id, settings):
        await update.message.reply_text("⛔ У вас нет доступа к этому боту.")
        return
    await update.message.reply_text(HELP_TEXT, parse_mode="Markdown")


async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await start_command(update, context)


async def report_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.bot_data["settings"]
    if not _is_allowed(update.effective_user.id, settings):
        await update.message.reply_text("⛔ У вас нет доступа к этому боту.")
        return

    period_text = " ".join(context.args) if context.args else "месяц"
    await _generate_and_send_report(update, context, period_text)


async def summary_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.bot_data["settings"]
    if not _is_allowed(update.effective_user.id, settings):
        await update.message.reply_text("⛔ У вас нет доступа к этому боту.")
        return

    period_text = " ".join(context.args) if context.args else "месяц"
    await _send_summary(update, context, period_text)


async def text_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.bot_data["settings"]
    if not _is_allowed(update.effective_user.id, settings):
        return

    text = (update.message.text or "").strip().lower()
    triggers = ("отчёт", "отчет", "report", "аналитика", "статистика")

    if not any(t in text for t in triggers):
        return

    period_text = text
    for trigger in triggers:
        period_text = period_text.replace(trigger, "").strip()
    if not period_text:
        period_text = "месяц"

    await _generate_and_send_report(update, context, period_text)


async def _send_summary(
    update: Update,
    context: ContextTypes.DEFAULT_TYPE,
    period_text: str,
) -> None:
    settings: Settings = context.bot_data["settings"]
    client: Bitrix24Client = context.bot_data["bitrix_client"]
    analytics: AnalyticsService = context.bot_data["analytics"]

    date_from, date_to = parse_period(period_text)

    status_msg = await update.message.reply_text("⏳ Собираю данные из Bitrix24...")

    try:
        report = await analytics.build_report(
            settings.bitrix_user_id, date_from, date_to
        )
    except Bitrix24Error as e:
        await status_msg.edit_text(f"❌ Ошибка Bitrix24: {e}")
        return
    except Exception as e:
        logger.exception("Failed to build report")
        await status_msg.edit_text(f"❌ Ошибка: {e}")
        return

    text = (
        f"📊 *Сводка для {report.user_name}*\n\n"
        f"*Задачи:*\n"
        f"  • Всего: {report.tasks.total}\n"
        f"  • Закрыто: {report.tasks.closed}\n"
        f"  • В работе: {report.tasks.in_progress}\n\n"
        f"*Открытая линия:*\n"
        f"  • Обращений: {report.open_lines.total_sessions}\n"
        f"  • Закрыто: {report.open_lines.closed_sessions}\n"
        f"  • Среднее время решения: "
        f"{_format_duration(report.open_lines.avg_resolution_seconds) if report.open_lines.avg_resolution_seconds else '—'}\n"
        f"  • Среднее время первого ответа: "
        f"{_format_duration(report.open_lines.avg_first_response_seconds) if report.open_lines.avg_first_response_seconds else '—'}\n"
    )
    await status_msg.edit_text(text, parse_mode="Markdown")


async def _generate_and_send_report(
    update: Update,
    context: ContextTypes.DEFAULT_TYPE,
    period_text: str,
) -> None:
    settings: Settings = context.bot_data["settings"]
    analytics: AnalyticsService = context.bot_data["analytics"]

    date_from, date_to = parse_period(period_text)

    status_msg = await update.message.reply_text(
        "⏳ Формирую отчёт из Bitrix24...\nЭто может занять несколько секунд."
    )

    try:
        report = await analytics.build_report(
            settings.bitrix_user_id, date_from, date_to
        )
        filepath = generate_excel_report(report)

        period_label = period_text if period_text else "месяц"
        caption = (
            f"📊 Отчёт Bitrix24 — {report.user_name}\n"
            f"Период: {period_label}\n"
            f"Задач: {report.tasks.total} (закрыто: {report.tasks.closed})\n"
            f"Обращений: {report.open_lines.total_sessions}"
        )

        with open(filepath, "rb") as f:
            await update.message.reply_document(
                document=f,
                filename=os.path.basename(filepath),
                caption=caption,
            )

        await status_msg.delete()
        os.remove(filepath)

    except Bitrix24Error as e:
        await status_msg.edit_text(
            f"❌ Ошибка Bitrix24 API: {e}\n\n"
            "Проверьте URL вебхука и права доступа (задачи, открытая линия)."
        )
    except Exception as e:
        logger.exception("Failed to generate report")
        await status_msg.edit_text(f"❌ Ошибка при формировании отчёта: {e}")
