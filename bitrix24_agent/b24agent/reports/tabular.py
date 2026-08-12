"""Отчёты в CSV и JSON.

CSV собирается блоками «раздел — таблица», разделёнными пустой строкой: такой
файл одинаково нормально открывается и в Excel, и в Google Таблицах, и глазами
в текстовом редакторе. Разделитель — точка с запятой, чтобы русский Excel не
ломал строки с запятыми.
"""

from __future__ import annotations

import csv
import json
from collections.abc import Iterable, Sequence
from io import StringIO
from typing import Any

from b24agent.analytics.humanize import date_ru, datetime_ru, duration, hours, percent
from b24agent.analytics.models import OpenLineMetrics, Report, TaskMetrics
from b24agent.bitrix.openlines import source_title
from b24agent.bitrix.tasks import status_name

BOM = "\ufeff"


def render_csv(report: Report) -> bytes:
    buffer = StringIO()
    writer = csv.writer(buffer, delimiter=";", lineterminator="\r\n")

    _block(
        writer,
        "Отчёт по активности в Битрикс24",
        [
            ("Сотрудник", report.user_name),
            ("ID сотрудника", report.user_id),
            ("Период", report.period.human()),
            ("Сформирован", datetime_ru(report.generated_at)),
            ("Запрос", report.request.raw_query or "—"),
        ],
    )

    if report.tasks is not None:
        _block(writer, "Задачи", list(_task_rows(report.tasks)))
        _table(
            writer,
            "Задачи: закрыто по дням",
            ["Дата", "Закрыто"],
            ([date_ru(day), count] for day, count in report.tasks.closed_per_day.items()),
        )
        _table(
            writer,
            "Задачи в работе: по статусам",
            ["Статус", "Задач"],
            ([name, count] for name, count in report.tasks.by_status.items()),
        )
        _table(
            writer,
            "Задачи в работе: по стадиям",
            ["Стадия", "Задач"],
            ([name, count] for name, count in report.tasks.by_stage.items()),
        )
        _table(
            writer,
            "Задачи в работе: по проектам",
            ["Проект", "Задач"],
            ([name, count] for name, count in report.tasks.by_group.items()),
        )
        if report.request.include_details:
            _table(
                writer,
                "Закрытые задачи",
                ["ID", "Название", "Поставлена", "Завершена", "Дедлайн", "Время закрытия, ч", "Списано, ч"],
                (
                    [
                        task.id,
                        task.title,
                        datetime_ru(task.created_at),
                        datetime_ru(task.closed_at),
                        datetime_ru(task.deadline),
                        hours(task.lead_time_seconds),
                        hours(task.time_spent),
                    ]
                    for task in report.tasks.closed_tasks
                ),
            )
            _table(
                writer,
                "Задачи в работе",
                ["ID", "Название", "Статус", "Поставлена", "Дедлайн", "Просрочена"],
                (
                    [
                        task.id,
                        task.title,
                        status_name(task.status),
                        datetime_ru(task.created_at),
                        datetime_ru(task.deadline),
                        "да" if task.is_overdue else "нет",
                    ]
                    for task in report.tasks.open_tasks
                ),
            )

    if report.openlines is not None:
        _block(writer, "Открытые линии", list(_openline_rows(report.openlines)))
        _table(
            writer,
            "Обращения по каналам",
            ["Канал", "Обращений"],
            ([name, count] for name, count in report.openlines.by_source.items()),
        )
        _table(
            writer,
            "Обращения по дням",
            ["Дата", "Обращений"],
            ([date_ru(day), count] for day, count in report.openlines.by_day.items()),
        )
        if report.request.include_details and report.openlines.sessions:
            _table(
                writer,
                "Детализация обращений",
                [
                    "ID",
                    "Канал",
                    "Начало",
                    "Закрыто",
                    "До первого ответа, сек",
                    "Время решения, сек",
                    "Статус",
                    "Оценка",
                ],
                (
                    [
                        session.id,
                        source_title(session.source),
                        datetime_ru(session.created_at),
                        datetime_ru(session.closed_at),
                        _number(session.wait_answer_seconds),
                        _number(session.resolution_seconds),
                        session.status or "—",
                        session.vote or "—",
                    ]
                    for session in report.openlines.sessions
                ),
            )

    if report.warnings:
        _table(writer, "Примечания", ["Текст"], ([warning] for warning in report.warnings))

    return (BOM + buffer.getvalue()).encode("utf-8")


def render_json(report: Report) -> bytes:
    payload = report.to_dict()
    if report.request.include_details:
        payload["details"] = _details(report)
    return json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")


# ------------------------------------------------------------------ внутреннее


def _task_rows(tasks: TaskMetrics) -> Iterable[tuple[str, Any]]:
    yield "Закрыто за период", tasks.closed_count
    yield "Поставлено за период", tasks.created_count
    yield "Сейчас не закрыто", tasks.open_count
    yield "Просрочено из незакрытых", tasks.overdue_open_count
    yield "Закрыто в срок", tasks.closed_on_time_count
    yield "Закрыто с просрочкой", tasks.closed_overdue_count
    yield "Среднее время закрытия", duration(tasks.avg_lead_time_seconds)
    yield "Медианное время закрытия", duration(tasks.median_lead_time_seconds)
    yield "90-й персентиль времени закрытия", duration(tasks.p90_lead_time_seconds)
    yield "Списано времени по закрытым задачам", duration(tasks.total_time_spent_seconds or None)


def _openline_rows(lines: OpenLineMetrics) -> Iterable[tuple[str, Any]]:
    yield "Источник данных", lines.data_source.title
    yield "Всего обращений", lines.total_sessions
    yield "Закрыто обращений", lines.closed_sessions
    yield "Не закрыто обращений", lines.open_sessions
    yield "Среднее время до первого ответа", duration(lines.avg_first_answer_seconds)
    yield "Среднее время решения вопроса", duration(lines.avg_resolution_seconds)
    yield "Медианное время решения", duration(lines.median_resolution_seconds)
    yield "Оценки «хорошо»", lines.likes
    yield "Оценки «плохо»", lines.dislikes
    yield "Доля положительных оценок", percent(lines.positive_rate)


def _details(report: Report) -> dict[str, Any]:
    details: dict[str, Any] = {}
    if report.tasks is not None:
        details["closed_tasks"] = [
            {
                "id": task.id,
                "title": task.title,
                "created_at": _iso(task.created_at),
                "closed_at": _iso(task.closed_at),
                "deadline": _iso(task.deadline),
                "lead_time_seconds": task.lead_time_seconds,
                "time_spent_seconds": task.time_spent,
                "overdue": task.is_overdue,
            }
            for task in report.tasks.closed_tasks
        ]
        details["open_tasks"] = [
            {
                "id": task.id,
                "title": task.title,
                "status": status_name(task.status),
                "stage": report.tasks.stage_titles.get(task.stage_id, task.stage_id or None),
                "created_at": _iso(task.created_at),
                "deadline": _iso(task.deadline),
                "overdue": task.is_overdue,
            }
            for task in report.tasks.open_tasks
        ]
    if report.openlines is not None:
        details["sessions"] = [
            {
                "id": session.id,
                "source": session.source,
                "created_at": _iso(session.created_at),
                "closed_at": _iso(session.closed_at),
                "wait_answer_seconds": session.wait_answer_seconds,
                "resolution_seconds": session.resolution_seconds,
                "status": session.status,
                "vote": session.vote,
                "messages": session.message_count,
            }
            for session in report.openlines.sessions
        ]
    return details


def _block(writer: Any, title: str, rows: Sequence[tuple[str, Any]]) -> None:
    writer.writerow([title])
    writer.writerow(["Показатель", "Значение"])
    for name, value in rows:
        writer.writerow([name, value])
    writer.writerow([])


def _table(
    writer: Any, title: str, header: Sequence[str], rows: Iterable[Sequence[Any]]
) -> None:
    materialized = [list(row) for row in rows]
    if not materialized:
        return
    writer.writerow([title])
    writer.writerow(list(header))
    writer.writerows(materialized)
    writer.writerow([])


def _number(value: float | None) -> Any:
    return "" if value is None else round(value, 1)


def _iso(value: Any) -> str | None:
    return value.isoformat(timespec="seconds") if value is not None else None
