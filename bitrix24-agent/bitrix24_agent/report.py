"""Сборка и форматирование итогового отчёта (текст / Markdown / JSON)."""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Optional

from .client import BitrixClient
from .openlines_report import OpenLinesReport, build_openlines_report
from .period import Period
from .tasks_report import STAGE_LABELS, TasksReport, build_tasks_report


@dataclass
class FullReport:
    user_id: int
    period: Period
    tasks: TasksReport
    openlines: OpenLinesReport


def build_full_report(client: BitrixClient, user_id: int, period: Period) -> FullReport:
    tasks = build_tasks_report(client, user_id, period)
    openlines = build_openlines_report(client, user_id, period)
    return FullReport(user_id=user_id, period=period, tasks=tasks, openlines=openlines)


def _fmt_hours(hours: Optional[float]) -> str:
    if hours is None:
        return "нет данных"
    if hours < 1:
        return f"{hours * 60:.0f} мин"
    return f"{hours:.1f} ч"


def _fmt_minutes(minutes: Optional[float]) -> str:
    if minutes is None:
        return "нет данных"
    if minutes >= 60:
        return f"{minutes / 60:.1f} ч"
    return f"{minutes:.0f} мин"


def render_text(report: FullReport) -> str:
    t = report.tasks
    o = report.openlines
    lines = []
    lines.append(f"Отчёт по продуктивности — пользователь {report.user_id}")
    lines.append(f"Период: {report.period}")
    lines.append("")
    lines.append("ЗАДАЧИ")
    lines.append(f"  Закрыто за период: {t.closed_count}")
    lines.append(f"  Среднее время выполнения закрытых задач: {_fmt_hours(t.avg_closing_hours)}")
    lines.append(f"  В работе сейчас (\"Выполняется\"): {t.in_progress_count}")
    lines.append(f"  Всего активных задач (сумма стадий): {t.open_total_count}")
    lines.append(f"  Просрочено сейчас: {t.overdue_count}")
    lines.append("  Распределение активных задач по стадиям:")
    for line in t.stage_breakdown() or ["    (нет активных задач)"]:
        lines.append(f"    - {line}")
    lines.append("")
    lines.append("ОТКРЫТЫЕ ЛИНИИ")
    if o.total_count == 0:
        lines.append("  За период не найдено обращений, привязанных к CRM с провайдером")
        lines.append("  IMOPENLINES_SESSION. Если вы точно обрабатывали обращения — проверьте,")
        lines.append("  включена ли в настройках линии привязка диалогов к CRM (лид/сделка/")
        lines.append("  контакт). Без этой привязки Открытые линии не отдают статистику через")
        lines.append("  официальный REST API.")
    else:
        lines.append(f"  Всего обращений за период: {o.total_count}")
        lines.append(f"  Обработано (закрыто): {o.closed_count}")
        lines.append(f"  В работе сейчас: {o.open_count}")
        lines.append(f"  Среднее время решения: {_fmt_minutes(o.avg_resolution_minutes)}")
    return "\n".join(lines)


def render_markdown(report: FullReport) -> str:
    t = report.tasks
    o = report.openlines
    lines = []
    lines.append(f"### Отчёт по продуктивности — пользователь {report.user_id}")
    lines.append(f"**Период:** {report.period}")
    lines.append("")
    lines.append("#### Задачи")
    lines.append(f"- Закрыто за период: **{t.closed_count}**")
    lines.append(f"- Среднее время выполнения закрытых задач: **{_fmt_hours(t.avg_closing_hours)}**")
    lines.append(f"- В работе сейчас («Выполняется»): **{t.in_progress_count}**")
    lines.append(f"- Всего активных задач: **{t.open_total_count}**")
    lines.append(f"- Просрочено сейчас: **{t.overdue_count}**")
    if t.stage_counts:
        lines.append("- Распределение по стадиям:")
        for stage, count in sorted(t.stage_counts.items()):
            label = STAGE_LABELS.get(stage, f"Статус {stage}")
            lines.append(f"  - {label}: {count}")
    lines.append("")
    lines.append("#### Открытые линии")
    if o.total_count == 0:
        lines.append(
            "- Нет данных по обращениям, привязанным к CRM (провайдер `IMOPENLINES_SESSION`). "
            "Проверьте привязку линии к CRM или используйте нативный отчёт Битрикс24."
        )
    else:
        lines.append(f"- Всего обращений за период: **{o.total_count}**")
        lines.append(f"- Обработано (закрыто): **{o.closed_count}**")
        lines.append(f"- В работе сейчас: **{o.open_count}**")
        lines.append(f"- Среднее время решения: **{_fmt_minutes(o.avg_resolution_minutes)}**")
    return "\n".join(lines)


def render_json(report: FullReport) -> str:
    t = report.tasks
    o = report.openlines
    data = {
        "user_id": report.user_id,
        "period": {
            "name": report.period.name,
            "from": report.period.date_from.isoformat(),
            "to": report.period.date_to.isoformat(),
        },
        "tasks": {
            "closed_count": t.closed_count,
            "avg_closing_hours": t.avg_closing_hours,
            "in_progress_count": t.in_progress_count,
            "open_total_count": t.open_total_count,
            "overdue_count": t.overdue_count,
            "stage_counts": {STAGE_LABELS.get(k, str(k)): v for k, v in t.stage_counts.items()},
            "closed_tasks": [
                {
                    "id": task.id,
                    "title": task.title,
                    "created_date": task.created_date.isoformat() if task.created_date else None,
                    "closed_date": task.closed_date.isoformat() if task.closed_date else None,
                    "duration_hours": task.duration_hours,
                }
                for task in t.closed_in_period
            ],
        },
        "openlines": {
            "total_count": o.total_count,
            "closed_count": o.closed_count,
            "open_count": o.open_count,
            "avg_resolution_minutes": o.avg_resolution_minutes,
        },
    }
    return json.dumps(data, ensure_ascii=False, indent=2)


def notify_user(client: BitrixClient, user_id: int, text: str) -> None:
    """Отправляет готовый отчёт пользователю личным уведомлением в Битрикс24."""
    client.call(
        "im.notify.system.add",
        {
            "USER_ID": user_id,
            "MESSAGE": text,
        },
    )
