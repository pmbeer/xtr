"""Формирование отчёта по свободному текстовому запросу пользователя."""

from __future__ import annotations

import logging
from datetime import datetime

from aiogram import F, Router
from aiogram.filters import Command
from aiogram.types import FSInputFile, Message

from ..bitrix.client import BitrixApiError, BitrixClient
from ..bitrix.openlines import OpenLinesStats, fetch_openlines_stats
from ..bitrix.tasks import TaskStats, fetch_task_stats
from ..config import Config
from ..reports.builder import ReportMeta, build_report_file
from ..utils.period import Period, resolve_period

logger = logging.getLogger(__name__)
router = Router(name="report")


def _build_caption(period: Period, task_stats: TaskStats, ol_stats: OpenLinesStats) -> str:
    lines = [f"📊 Отчёт за период: {period.label}", ""]
    lines.append(f"✅ Закрыто задач: {task_stats.closed_count}")
    lines.append(
        f"🗂 В работе сейчас: {task_stats.active_count} (просрочено: {task_stats.overdue_count})"
    )
    if ol_stats.error:
        lines.append("💬 Открытые линии: данные недоступны (подробности — в файле)")
    else:
        lines.append(f"💬 Обращений обработано: {ol_stats.completed} из {ol_stats.total}")
        lines.append(f"⏱ Среднее время решения: {ol_stats.avg_resolution_human}")
    lines.append("")
    lines.append("Полная детализация — в приложенном файле.")
    return "\n".join(lines)


async def _generate_and_send(
    message: Message,
    period_text: str,
    config: Config,
    bitrix_client: BitrixClient,
    warn_if_default: bool,
) -> None:
    user = message.from_user
    if user is None:
        return

    bitrix_user_id = config.bitrix_user_id_for(user.id)
    period = resolve_period(period_text, config.timezone)

    status_message = await message.answer(
        f"⏳ Собираю отчёт за период: {period.label}…\nЭто может занять до минуты."
    )

    try:
        task_stats = await fetch_task_stats(
            bitrix_client, bitrix_user_id, period.date_from, period.date_to
        )
        ol_stats = await fetch_openlines_stats(
            bitrix_client, bitrix_user_id, period.date_from, period.date_to
        )
    except BitrixApiError as exc:
        await status_message.edit_text(
            "❌ Не удалось получить данные из Битрикс24.\n"
            f"Ошибка: {exc.code} — {exc.description}\n\n"
            "Проверьте адрес вебхука и права доступа (scope: task, crm) в .env "
            "и попробуйте снова."
        )
        return
    except Exception:  # noqa: BLE001 - показываем пользователю дружелюбное сообщение
        logger.exception("Неожиданная ошибка при формировании отчёта")
        await status_message.edit_text(
            "❌ Произошла непредвиденная ошибка при формировании отчёта. "
            "Попробуйте ещё раз позже."
        )
        return

    display_name = user.full_name or (f"@{user.username}" if user.username else str(user.id))
    now = datetime.now(config.timezone)
    meta = ReportMeta(display_name=display_name, period=period, generated_at=now)

    file_name = f"bitrix24_report_{bitrix_user_id}_{now:%Y%m%d_%H%M%S}.xlsx"
    output_path = config.reports_dir / file_name

    try:
        build_report_file(output_path, meta, task_stats, ol_stats)
        caption = _build_caption(period, task_stats, ol_stats)
        await message.answer_document(
            FSInputFile(output_path, filename=file_name), caption=caption
        )
    finally:
        output_path.unlink(missing_ok=True)

    if warn_if_default and not period.matched:
        await status_message.edit_text(
            f"ℹ️ Не удалось точно определить период из запроса, использован период: "
            f"{period.label}.\nПопробуйте, например: «неделя», «прошлый месяц» или "
            "«01.08.2026-12.08.2026»."
        )
    else:
        await status_message.delete()


@router.message(Command("report"))
async def cmd_report(message: Message, config: Config, bitrix_client: BitrixClient) -> None:
    args = (message.text or "").split(maxsplit=1)
    period_text = args[1] if len(args) > 1 else ""
    await _generate_and_send(
        message, period_text, config, bitrix_client, warn_if_default=bool(period_text)
    )


@router.message(F.text)
async def handle_free_text(message: Message, config: Config, bitrix_client: BitrixClient) -> None:
    await _generate_and_send(
        message, message.text or "", config, bitrix_client, warn_if_default=True
    )
