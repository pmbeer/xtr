"""Текстовая сводка отчёта — она уходит в сообщение рядом с файлом."""

from __future__ import annotations

from html import escape

from b24agent.analytics.humanize import duration, percent, plural
from b24agent.analytics.models import Report

MAX_TELEGRAM_TEXT = 3500


def build_summary(report: Report) -> str:
    """Собирает HTML-сводку для Telegram (parse_mode=HTML)."""
    lines: list[str] = [
        f"<b>Отчёт по Битрикс24</b> — {escape(report.user_name)}",
        f"Период: <b>{escape(report.period.human())}</b>",
    ]

    if report.tasks is not None:
        tasks = report.tasks
        lines.append("")
        lines.append("<b>Задачи</b>")
        lines.append(
            f"• закрыто: <b>{tasks.closed_count}</b> "
            f"{plural(tasks.closed_count, 'задача', 'задачи', 'задач')}"
        )
        lines.append(f"• поставлено за период: <b>{tasks.created_count}</b>")
        lines.append(f"• сейчас не закрыто: <b>{tasks.open_count}</b>")
        for status, count in tasks.by_status.items():
            lines.append(f"   ◦ {escape(status)}: {count}")
        if tasks.overdue_open_count:
            lines.append(f"• просрочено: <b>{tasks.overdue_open_count}</b>")
        lines.append(
            f"• среднее время закрытия: <b>{duration(tasks.avg_lead_time_seconds)}</b>"
            f" (медиана {duration(tasks.median_lead_time_seconds)})"
        )
        if tasks.by_stage:
            top_stages = list(tasks.by_stage.items())[:5]
            stages = ", ".join(f"{escape(name)} — {count}" for name, count in top_stages)
            lines.append(f"• стадии: {stages}")

    if report.openlines is not None:
        lines_data = report.openlines
        lines.append("")
        lines.append("<b>Открытые линии</b>")
        lines.append(
            f"• обращений: <b>{lines_data.total_sessions}</b>, "
            f"закрыто: <b>{lines_data.closed_sessions}</b>"
        )
        lines.append(
            "• среднее время решения: "
            f"<b>{duration(lines_data.avg_resolution_seconds)}</b>"
            f" (медиана {duration(lines_data.median_resolution_seconds)})"
        )
        if lines_data.avg_first_answer_seconds is not None:
            lines.append(
                f"• среднее время до первого ответа: <b>{duration(lines_data.avg_first_answer_seconds)}</b>"
            )
        if lines_data.voted_sessions:
            lines.append(
                f"• оценки клиентов: {lines_data.likes} 👍 / {lines_data.dislikes} 👎"
                f" (положительных {percent(lines_data.positive_rate)})"
            )
        if lines_data.by_source:
            channels = ", ".join(
                f"{escape(name)} — {count}"
                for name, count in list(lines_data.by_source.items())[:5]
            )
            lines.append(f"• каналы: {channels}")

    if report.warnings:
        lines.append("")
        lines.append("<b>Примечания</b>")
        lines.extend(f"⚠️ {escape(warning)}" for warning in report.warnings)

    text = "\n".join(lines)
    if len(text) > MAX_TELEGRAM_TEXT:
        text = text[: MAX_TELEGRAM_TEXT - 1] + "…"
    return text
