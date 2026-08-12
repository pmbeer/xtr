"""Аналитика по задачам Bitrix24 (tasks.task.list)."""

import logging
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

from bitrix import Bitrix24Client, Bitrix24Error

from .periods import Period

logger = logging.getLogger(__name__)

STATUS_LABELS = {
    1: "Новая",
    2: "Ждёт выполнения",
    3: "Выполняется",
    4: "Ждёт контроля",
    5: "Завершена",
    6: "Отложена",
    7: "Отклонена",
}

OPEN_STATUSES = [2, 3, 4, 6]
COMPLETED_STATUS = 5

SELECT_FIELDS = [
    "ID",
    "TITLE",
    "STATUS",
    "CREATED_DATE",
    "CLOSED_DATE",
    "DEADLINE",
    "GROUP_ID",
    "STAGE_ID",
    "RESPONSIBLE_ID",
]


@dataclass
class TaskRow:
    task_id: int
    title: str
    status: int
    status_label: str
    stage: str
    created: datetime | None
    closed: datetime | None
    deadline: datetime | None

    @property
    def resolution_seconds(self) -> float | None:
        if self.created and self.closed:
            return (self.closed - self.created).total_seconds()
        return None


@dataclass
class TaskStats:
    period: Period
    closed_tasks: list[TaskRow] = field(default_factory=list)
    open_tasks: list[TaskRow] = field(default_factory=list)
    error: str | None = None

    @property
    def closed_count(self) -> int:
        return len(self.closed_tasks)

    @property
    def open_count(self) -> int:
        return len(self.open_tasks)

    @property
    def in_progress_count(self) -> int:
        return sum(1 for task in self.open_tasks if task.status == 3)

    @property
    def overdue_count(self) -> int:
        now = self.period.date_to
        return sum(
            1
            for task in self.open_tasks
            if task.deadline is not None and task.deadline < now
        )

    @property
    def avg_resolution_seconds(self) -> float | None:
        durations = [
            task.resolution_seconds
            for task in self.closed_tasks
            if task.resolution_seconds is not None
        ]
        if not durations:
            return None
        return sum(durations) / len(durations)

    @property
    def open_by_stage(self) -> dict[str, int]:
        grouped: dict[str, int] = {}
        for task in self.open_tasks:
            grouped[task.stage] = grouped.get(task.stage, 0) + 1
        return dict(sorted(grouped.items(), key=lambda item: -item[1]))


def _parse_dt(value: Any) -> datetime | None:
    if not value or not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def _get(item: dict[str, Any], *keys: str) -> Any:
    """Bitrix возвращает поля то в camelCase, то в UPPER_CASE."""
    for key in keys:
        if key in item:
            return item[key]
    return None


async def _fetch_stage_titles(
    client: Bitrix24Client, group_ids: set[int]
) -> dict[int, dict[int, str]]:
    """Названия стадий канбана для каждой группы (task.stages.get)."""
    titles: dict[int, dict[int, str]] = {}
    for group_id in group_ids:
        if not group_id:
            continue
        try:
            payload = await client.call("task.stages.get", {"entityId": group_id})
        except Bitrix24Error as exc:
            logger.warning("Не удалось получить стадии группы %s: %s", group_id, exc)
            continue
        result = payload.get("result") or {}
        if isinstance(result, dict):
            titles[group_id] = {
                int(stage_id): str(stage.get("TITLE", stage_id))
                for stage_id, stage in result.items()
                if isinstance(stage, dict)
            }
    return titles


def _to_row(
    item: dict[str, Any], stage_titles: dict[int, dict[int, str]]
) -> TaskRow:
    status = int(_get(item, "status", "STATUS") or 0)
    group_id = int(_get(item, "groupId", "GROUP_ID") or 0)
    stage_id = int(_get(item, "stageId", "STAGE_ID") or 0)

    stage = stage_titles.get(group_id, {}).get(stage_id, "")
    if not stage:
        stage = STATUS_LABELS.get(status, f"Статус {status}")

    return TaskRow(
        task_id=int(_get(item, "id", "ID") or 0),
        title=str(_get(item, "title", "TITLE") or ""),
        status=status,
        status_label=STATUS_LABELS.get(status, f"Статус {status}"),
        stage=stage,
        created=_parse_dt(_get(item, "createdDate", "CREATED_DATE")),
        closed=_parse_dt(_get(item, "closedDate", "CLOSED_DATE")),
        deadline=_parse_dt(_get(item, "deadline", "DEADLINE")),
    )


async def collect_task_stats(
    client: Bitrix24Client, user_id: int, period: Period
) -> TaskStats:
    stats = TaskStats(period=period)

    try:
        closed_items = await client.call_list(
            "tasks.task.list",
            {
                "filter": {
                    "RESPONSIBLE_ID": user_id,
                    "REAL_STATUS": COMPLETED_STATUS,
                    ">=CLOSED_DATE": period.date_from.isoformat(),
                    "<=CLOSED_DATE": period.date_to.isoformat(),
                },
                "select": SELECT_FIELDS,
            },
        )
        open_items = await client.call_list(
            "tasks.task.list",
            {
                "filter": {
                    "RESPONSIBLE_ID": user_id,
                    "REAL_STATUS": OPEN_STATUSES,
                },
                "select": SELECT_FIELDS,
            },
        )
    except Bitrix24Error as exc:
        logger.exception("Ошибка получения задач из Bitrix24")
        stats.error = str(exc)
        return stats

    group_ids = {
        int(_get(item, "groupId", "GROUP_ID") or 0)
        for item in open_items + closed_items
    }
    stage_titles = await _fetch_stage_titles(client, group_ids)

    stats.closed_tasks = [_to_row(item, stage_titles) for item in closed_items]
    stats.open_tasks = [_to_row(item, stage_titles) for item in open_items]
    return stats
