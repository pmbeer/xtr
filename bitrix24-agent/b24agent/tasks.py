"""Аналитика по задачам Битрикс24 (методы ``tasks.task.*``)."""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime, timezone
from statistics import median
from typing import Any, Dict, List, Optional

from .client import Bitrix24Client, Bitrix24Error
from .util import parse_b24_datetime

#: Статусы задач Битрикс24 (поле ``status`` / фильтр ``REAL_STATUS``).
STATUS_LABELS = {
    1: "Новая",
    2: "Ждёт выполнения",
    3: "Выполняется",
    4: "Ждёт контроля",
    5: "Завершена",
    6: "Отложена",
    7: "Отклонена",
}

#: Статусы, которые считаем «задача в работе» (не завершена и не отклонена).
OPEN_STATUSES = (2, 3, 4, 6)

_TASK_SELECT = [
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
class TasksReport:
    """Итоговые метрики по задачам за период."""

    date_from: datetime
    date_to: datetime
    closed_count: int = 0
    created_count: int = 0
    open_count: int = 0
    overdue_count: int = 0
    open_by_status: Dict[str, int] = field(default_factory=dict)
    open_by_stage: Dict[str, int] = field(default_factory=dict)
    avg_completion_seconds: Optional[float] = None
    median_completion_seconds: Optional[float] = None
    closed_tasks: List[Dict[str, Any]] = field(default_factory=list)
    open_tasks: List[Dict[str, Any]] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)


def task_status(task: Dict[str, Any]) -> Optional[int]:
    value = task.get("status", task.get("STATUS"))
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def completion_seconds(task: Dict[str, Any]) -> Optional[float]:
    """Время от создания до закрытия задачи, в секундах."""
    created = parse_b24_datetime(task.get("createdDate") or task.get("CREATED_DATE"))
    closed = parse_b24_datetime(task.get("closedDate") or task.get("CLOSED_DATE"))
    if created is None or closed is None or closed < created:
        return None
    return (closed - created).total_seconds()


def is_overdue(task: Dict[str, Any], now: datetime) -> bool:
    deadline = parse_b24_datetime(task.get("deadline") or task.get("DEADLINE"))
    return deadline is not None and deadline < now


def aggregate_tasks(
    closed_tasks: List[Dict[str, Any]],
    open_tasks: List[Dict[str, Any]],
    created_count: int,
    date_from: datetime,
    date_to: datetime,
    stage_names: Optional[Dict[str, str]] = None,
    now: Optional[datetime] = None,
) -> TasksReport:
    """Чистая агрегация метрик (без обращений к API) — удобно тестировать."""
    now = now or datetime.now(timezone.utc)
    stage_names = stage_names or {}
    report = TasksReport(date_from=date_from, date_to=date_to)
    report.closed_tasks = closed_tasks
    report.open_tasks = open_tasks
    report.closed_count = len(closed_tasks)
    report.created_count = created_count
    report.open_count = len(open_tasks)

    durations = [d for d in (completion_seconds(t) for t in closed_tasks) if d is not None]
    if durations:
        report.avg_completion_seconds = sum(durations) / len(durations)
        report.median_completion_seconds = median(durations)

    by_status: Counter = Counter()
    by_stage: Counter = Counter()
    for task in open_tasks:
        status = task_status(task)
        by_status[STATUS_LABELS.get(status, f"Статус #{status}")] += 1
        if is_overdue(task, now):
            report.overdue_count += 1
        stage_id = str(task.get("stageId", task.get("STAGE_ID", "0")) or "0")
        if stage_id not in ("0", "None", ""):
            by_stage[stage_names.get(stage_id, f"Стадия #{stage_id}")] += 1

    report.open_by_status = dict(by_status.most_common())
    report.open_by_stage = dict(by_stage.most_common())
    return report


class TaskAnalytics:
    """Собирает метрики задач пользователя через REST."""

    def __init__(self, client: Bitrix24Client):
        self.client = client
        self._stage_cache: Dict[int, Dict[str, str]] = {}

    def collect(self, user_id: int, date_from: datetime, date_to: datetime) -> TasksReport:
        closed_tasks = self._list_tasks(
            {
                "RESPONSIBLE_ID": user_id,
                "REAL_STATUS": 5,
                ">=CLOSED_DATE": _iso(date_from),
                "<=CLOSED_DATE": _iso(date_to),
            }
        )
        open_tasks = self._list_tasks(
            {
                "RESPONSIBLE_ID": user_id,
                "REAL_STATUS": list(OPEN_STATUSES),
            }
        )
        created_tasks = self._list_tasks(
            {
                "RESPONSIBLE_ID": user_id,
                ">=CREATED_DATE": _iso(date_from),
                "<=CREATED_DATE": _iso(date_to),
            }
        )

        report = aggregate_tasks(
            closed_tasks=closed_tasks,
            open_tasks=open_tasks,
            created_count=len(created_tasks),
            date_from=date_from,
            date_to=date_to,
            stage_names=self._resolve_stage_names(open_tasks),
        )
        return report

    # -------------------------------------------------------------- internal

    def _list_tasks(self, task_filter: Dict[str, Any]) -> List[Dict[str, Any]]:
        params = {"filter": task_filter, "select": _TASK_SELECT, "order": {"ID": "asc"}}
        return list(self.client.iter_list("tasks.task.list", params, items_key="tasks"))

    def _resolve_stage_names(self, tasks: List[Dict[str, Any]]) -> Dict[str, str]:
        """Подтягивает названия канбан-стадий для задач в группах (проектах)."""
        names: Dict[str, str] = {}
        group_ids = set()
        for task in tasks:
            group_id = task.get("groupId", task.get("GROUP_ID"))
            stage_id = str(task.get("stageId", task.get("STAGE_ID", "0")) or "0")
            if stage_id not in ("0", "None", "") and group_id:
                try:
                    group_ids.add(int(group_id))
                except (TypeError, ValueError):
                    continue
        for group_id in group_ids:
            names.update(self._group_stages(group_id))
        return names

    def _group_stages(self, group_id: int) -> Dict[str, str]:
        if group_id in self._stage_cache:
            return self._stage_cache[group_id]
        stages: Dict[str, str] = {}
        try:
            result = self.client.call("task.stages.get", {"entityId": group_id})
            if isinstance(result, dict):
                for stage_id, stage in result.items():
                    if isinstance(stage, dict):
                        stages[str(stage.get("ID", stage_id))] = str(stage.get("TITLE", stage_id))
        except Bitrix24Error:
            pass  # нет доступа к группе — покажем «Стадия #id»
        self._stage_cache[group_id] = stages
        return stages


def _iso(value: datetime) -> str:
    return value.replace(microsecond=0).isoformat()
