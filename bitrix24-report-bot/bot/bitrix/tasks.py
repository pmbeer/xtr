"""Получение и агрегация статистики по задачам пользователя Битрикс24."""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from datetime import datetime
from typing import Any

from dateutil.parser import isoparse

from .client import BitrixApiError, BitrixClient
from .constants import (
    ACTIVE_TASK_STATUSES,
    TASK_PRIORITY_LABELS,
    TASK_STATUS_COMPLETED,
    TASK_STATUS_LABELS,
)

TASK_SELECT_FIELDS = [
    "ID",
    "TITLE",
    "STATUS",
    "PRIORITY",
    "CREATED_DATE",
    "CLOSED_DATE",
    "DEADLINE",
    "RESPONSIBLE_ID",
    "GROUP_ID",
    "STAGE_ID",
    "MARK",
]


def _parse_dt(value: Any) -> datetime | None:
    if not value:
        return None
    try:
        return isoparse(str(value))
    except (ValueError, TypeError):
        return None


@dataclass
class TaskItem:
    id: int
    title: str
    status_code: int
    status_label: str
    priority_label: str
    created: datetime | None
    closed: datetime | None
    deadline: datetime | None
    group_id: int
    stage_id: int
    stage_label: str = ""

    @property
    def is_overdue(self) -> bool:
        if self.deadline is None:
            return False
        if self.status_code == TASK_STATUS_COMPLETED:
            return False
        return self.deadline < datetime.now(self.deadline.tzinfo)


@dataclass
class TaskStats:
    active_count: int
    closed_count: int
    overdue_count: int
    created_count: int
    avg_completion_hours: float | None
    by_status: Counter
    by_stage: Counter
    active_tasks: list[TaskItem]
    closed_tasks: list[TaskItem]
    error: str | None = None


def _to_task_item(raw: dict[str, Any]) -> TaskItem:
    status_code = int(raw.get("status") or 0)
    return TaskItem(
        id=int(raw.get("id") or 0),
        title=str(raw.get("title") or "(без названия)"),
        status_code=status_code,
        status_label=TASK_STATUS_LABELS.get(status_code, f"Статус {status_code}"),
        priority_label=TASK_PRIORITY_LABELS.get(str(raw.get("priority")), "—"),
        created=_parse_dt(raw.get("createdDate")),
        closed=_parse_dt(raw.get("closedDate")),
        deadline=_parse_dt(raw.get("deadline")),
        group_id=int(raw.get("groupId") or 0),
        stage_id=int(raw.get("stageId") or 0),
    )


async def _fetch_stage_titles(client: BitrixClient, group_ids: set[int]) -> dict[tuple[int, int], str]:
    """Возвращает {(group_id, stage_id): title} для канбан-стадий переданных групп.

    Метод task.stages.get требует прав доступа к группе — если их нет,
    просто пропускаем эту группу (в отчёте будет числовой ID стадии).
    """
    titles: dict[tuple[int, int], str] = {}
    for group_id in group_ids:
        if not group_id:
            continue
        try:
            data = await client.call("task.stages.get", {"entityId": group_id})
        except BitrixApiError:
            continue
        result = data.get("result") or {}
        if isinstance(result, dict):
            for stage_id_str, stage in result.items():
                try:
                    stage_id = int(stage_id_str)
                except (TypeError, ValueError):
                    continue
                title = stage.get("TITLE") if isinstance(stage, dict) else None
                if title:
                    titles[(group_id, stage_id)] = str(title)
    return titles


async def fetch_task_stats(
    client: BitrixClient,
    bitrix_user_id: int,
    date_from: datetime,
    date_to: datetime,
) -> TaskStats:
    """Собирает статистику по задачам пользователя за период.

    - Задачи "в работе" — текущий снимок (без учёта периода): всё, что назначено
      пользователю и ещё не завершено/не отклонено.
    - Задачи "закрыл" — задачи со статусом "Завершена", у которых CLOSED_DATE
      попадает в выбранный период.
    - Просроченные — активные задачи с истёкшим сроком.
    """
    date_from_str = date_from.strftime("%Y-%m-%dT%H:%M:%S")
    date_to_str = date_to.strftime("%Y-%m-%dT%H:%M:%S")

    active_raw = await client.collect_all(
        "tasks.task.list",
        select=TASK_SELECT_FIELDS,
        filter_={
            "RESPONSIBLE_ID": bitrix_user_id,
            "REAL_STATUS": list(ACTIVE_TASK_STATUSES),
        },
        order={"DEADLINE": "asc"},
        result_key="tasks",
    )

    closed_raw = await client.collect_all(
        "tasks.task.list",
        select=TASK_SELECT_FIELDS,
        filter_={
            "RESPONSIBLE_ID": bitrix_user_id,
            "REAL_STATUS": TASK_STATUS_COMPLETED,
            ">=CLOSED_DATE": date_from_str,
            "<=CLOSED_DATE": date_to_str,
        },
        order={"CLOSED_DATE": "desc"},
        result_key="tasks",
    )

    created_raw = await client.collect_all(
        "tasks.task.list",
        select=["ID"],
        filter_={
            "RESPONSIBLE_ID": bitrix_user_id,
            ">=CREATED_DATE": date_from_str,
            "<=CREATED_DATE": date_to_str,
        },
        result_key="tasks",
    )

    active_tasks = [_to_task_item(item) for item in active_raw]
    closed_tasks = [_to_task_item(item) for item in closed_raw]

    group_ids = {t.group_id for t in active_tasks if t.group_id} | {
        t.group_id for t in closed_tasks if t.group_id
    }
    stage_titles = await _fetch_stage_titles(client, group_ids)
    for task in (*active_tasks, *closed_tasks):
        if task.group_id and task.stage_id:
            task.stage_label = stage_titles.get((task.group_id, task.stage_id), "")
        if not task.stage_label:
            task.stage_label = task.status_label

    overdue_count = sum(1 for t in active_tasks if t.is_overdue)

    completion_hours = [
        (t.closed - t.created).total_seconds() / 3600.0
        for t in closed_tasks
        if t.closed and t.created
    ]
    avg_completion_hours = sum(completion_hours) / len(completion_hours) if completion_hours else None

    by_status = Counter(t.status_label for t in active_tasks)
    by_stage = Counter(t.stage_label for t in active_tasks)

    return TaskStats(
        active_count=len(active_tasks),
        closed_count=len(closed_tasks),
        overdue_count=overdue_count,
        created_count=len(created_raw),
        avg_completion_hours=avg_completion_hours,
        by_status=by_status,
        by_stage=by_stage,
        active_tasks=active_tasks,
        closed_tasks=closed_tasks,
    )
