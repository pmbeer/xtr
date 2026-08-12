"""Формирование итогового отчёта: текст для консоли и JSON."""

from __future__ import annotations

import json
from dataclasses import asdict
from typing import Any, Dict

from .openlines import OpenLinesReport
from .tasks import TasksReport
from .util import format_duration


def build_json(
    user: Dict[str, Any],
    tasks: TasksReport,
    openlines: OpenLinesReport,
    include_details: bool = False,
) -> str:
    tasks_dict = asdict(tasks)
    openlines_dict = asdict(openlines)
    tasks_dict["date_from"] = tasks.date_from.isoformat()
    tasks_dict["date_to"] = tasks.date_to.isoformat()
    if not include_details:
        tasks_dict.pop("closed_tasks", None)
        tasks_dict.pop("open_tasks", None)
        openlines_dict.pop("sessions", None)
    payload = {"user": user, "tasks": tasks_dict, "openlines": openlines_dict}
    return json.dumps(payload, ensure_ascii=False, indent=2, default=str)


def build_text(user: Dict[str, Any], tasks: TasksReport, openlines: OpenLinesReport) -> str:
    lines = []
    name = " ".join(filter(None, [user.get("NAME"), user.get("LAST_NAME")])) or f"ID {user.get('ID')}"
    period = f"{tasks.date_from:%d.%m.%Y} — {tasks.date_to:%d.%m.%Y}"

    lines.append("=" * 62)
    lines.append(f"  Отчёт по активности в Битрикс24: {name}")
    lines.append(f"  Период: {period}")
    lines.append("=" * 62)

    lines.append("")
    lines.append("ЗАДАЧИ")
    lines.append("-" * 62)
    lines.append(f"  Закрыто за период:            {tasks.closed_count}")
    lines.append(f"  Создано (я исполнитель):      {tasks.created_count}")
    lines.append(f"  Сейчас в работе:              {tasks.open_count}")
    lines.append(f"  Из них просрочено:            {tasks.overdue_count}")
    lines.append(f"  Среднее время выполнения:     {format_duration(tasks.avg_completion_seconds)}")
    lines.append(f"  Медианное время выполнения:   {format_duration(tasks.median_completion_seconds)}")

    if tasks.open_by_status:
        lines.append("")
        lines.append("  Задачи в работе по статусам:")
        for status, count in tasks.open_by_status.items():
            lines.append(f"    • {status}: {count}")

    if tasks.open_by_stage:
        lines.append("")
        lines.append("  Задачи в работе по стадиям канбана:")
        for stage, count in tasks.open_by_stage.items():
            lines.append(f"    • {stage}: {count}")

    lines.append("")
    lines.append("ОТКРЫТЫЕ ЛИНИИ")
    lines.append("-" * 62)
    if not openlines.available:
        lines.append(f"  {openlines.unavailable_reason}")
    else:
        lines.append(f"  Обработано обращений:         {openlines.handled_sessions}")
        lines.append(f"  Среднее время решения:        {format_duration(openlines.avg_resolution_seconds)}")
        lines.append(f"  Медианное время решения:      {format_duration(openlines.median_resolution_seconds)}")
        lines.append(f"  Среднее время первого ответа: {format_duration(openlines.avg_first_answer_seconds)}")
        voted = openlines.likes + openlines.dislikes
        if voted:
            positive = openlines.likes / voted * 100
            lines.append(
                f"  Оценки клиентов:              {openlines.likes} лайков / {openlines.dislikes} дизлайков "
                f"({positive:.0f}% положительных)"
            )
        if openlines.sessions_by_source:
            lines.append("")
            lines.append("  Обращения по каналам:")
            for source, count in openlines.sessions_by_source.items():
                lines.append(f"    • {source}: {count}")
        totals = openlines.line_totals
        if totals:
            lines.append("")
            lines.append("  Сводка по доступным линиям за период (все операторы):")
            lines.append(f"    • Всего обращений: {totals.get('totalSessions', '—')}")
            lines.append(f"    • Закрыто: {totals.get('closedSessions', '—')}")
            avg_duration = totals.get("avgSessionDuration")
            if avg_duration is not None:
                lines.append(f"    • Средняя длительность сессии: {format_duration(avg_duration)}")

    for warning in list(tasks.warnings) + list(openlines.warnings):
        lines.append("")
        lines.append(f"  ⚠ {warning}")

    lines.append("")
    return "\n".join(lines)
