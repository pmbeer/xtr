"""Формирование отчётов аналитики."""

from __future__ import annotations

import json
from typing import Any

from rich.console import Console
from rich.panel import Panel
from rich.table import Table

from .openlines_analyzer import OpenLinesAnalytics
from .tasks_analyzer import TaskAnalytics


def _format_duration(seconds: float | None) -> str:
    if seconds is None:
        return "—"
    if seconds < 60:
        return f"{seconds:.0f} сек"
    if seconds < 3600:
        return f"{seconds / 60:.1f} мин"
    return f"{seconds / 3600:.1f} ч"


def _format_hours(hours: float | None) -> str:
    if hours is None:
        return "—"
    if hours < 24:
        return f"{hours:.1f} ч"
    return f"{hours / 24:.1f} дн"


def render_report(
    tasks: TaskAnalytics,
    openlines: OpenLinesAnalytics,
    user_name: str | None = None,
) -> None:
    console = Console()
    title = f"Аналитика Bitrix24 — {user_name or f'пользователь #{tasks.user_id}'}"
    console.print(Panel(title, style="bold cyan"))

    period = f"{tasks.period_from.strftime('%d.%m.%Y')} — {tasks.period_to.strftime('%d.%m.%Y')}"
    console.print(f"\n[bold]Период:[/bold] {period}\n")

    _render_tasks_table(console, tasks)
    console.print()
    _render_openlines_table(console, openlines)


def _render_tasks_table(console: Console, tasks: TaskAnalytics) -> None:
    table = Table(title="Задачи", show_header=True, header_style="bold magenta")
    table.add_column("Метрика", style="dim")
    table.add_column("Значение", justify="right")

    table.add_row("Всего активных (ответственный)", str(tasks.total_responsible))
    table.add_row("В работе", str(tasks.in_progress))
    table.add_row("Ждут выполнения", str(tasks.waiting))
    table.add_row("Ждут контроля", str(tasks.awaiting_control))
    table.add_row("Завершено за период", str(tasks.completed_in_period))
    table.add_row("Создано за период", str(tasks.tasks_created_in_period))
    table.add_row("Просрочено", str(tasks.overdue))
    table.add_row("Среднее время выполнения", _format_hours(tasks.avg_completion_hours))

    console.print(table)

    if tasks.by_status:
        status_table = Table(title="По статусам", show_header=True)
        status_table.add_column("Статус")
        status_table.add_column("Кол-во", justify="right")
        for status, count in sorted(tasks.by_status.items(), key=lambda x: -x[1]):
            status_table.add_row(status, str(count))
        console.print(status_table)

    if tasks.by_stage:
        stage_table = Table(title="По стадиям", show_header=True)
        stage_table.add_column("Стадия")
        stage_table.add_column("Кол-во", justify="right")
        for stage, count in sorted(tasks.by_stage.items(), key=lambda x: -x[1]):
            stage_table.add_row(stage, str(count))
        console.print(stage_table)


def _render_openlines_table(console: Console, openlines: OpenLinesAnalytics) -> None:
    table = Table(title="Открытые линии", show_header=True, header_style="bold green")
    table.add_column("Метрика", style="dim")
    table.add_column("Значение", justify="right")

    table.add_row("Обработано обращений", str(openlines.sessions_processed))
    table.add_row("Открытых сессий", str(openlines.sessions_open))
    table.add_row("Среднее время первого ответа", _format_duration(openlines.avg_first_response_sec))
    table.add_row("Среднее время решения", _format_duration(openlines.avg_resolution_sec))
    table.add_row("Среднее сообщений в сессии", str(openlines.avg_messages_per_session or "—"))
    table.add_row("Положительных оценок", str(openlines.positive_votes))
    table.add_row("Отрицательных оценок", str(openlines.negative_votes))

    console.print(table)

    if openlines.by_line:
        line_table = Table(title="По линиям", show_header=True)
        line_table.add_column("Линия")
        line_table.add_column("Сессий", justify="right")
        for line, count in sorted(openlines.by_line.items(), key=lambda x: -x[1]):
            line_table.add_row(line, str(count))
        console.print(line_table)

    if openlines.warnings:
        console.print("\n[yellow]Предупреждения:[/yellow]")
        for warning in openlines.warnings:
            console.print(f"  • {warning}")


def export_json(
    tasks: TaskAnalytics,
    openlines: OpenLinesAnalytics,
    user_name: str | None = None,
) -> dict[str, Any]:
    return {
        "user": user_name,
        "tasks": tasks.to_dict(),
        "openlines": openlines.to_dict(),
    }


def save_json_report(
    path: str,
    tasks: TaskAnalytics,
    openlines: OpenLinesAnalytics,
    user_name: str | None = None,
) -> None:
    data = export_json(tasks, openlines, user_name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
