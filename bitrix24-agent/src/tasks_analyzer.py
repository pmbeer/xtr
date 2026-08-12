"""Аналитика задач Bitrix24."""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any

from .bitrix_client import Bitrix24Client

TASK_STATUS_LABELS = {
    2: "Ждёт выполнения",
    3: "Выполняется",
    4: "Ждёт контроля",
    5: "Завершена",
    6: "Отложена",
    7: "Отклонена",
}


@dataclass
class TaskAnalytics:
    user_id: int
    period_from: date
    period_to: date
    total_responsible: int = 0
    in_progress: int = 0
    waiting: int = 0
    awaiting_control: int = 0
    completed_in_period: int = 0
    deferred: int = 0
    declined: int = 0
    overdue: int = 0
    by_status: dict[str, int] = field(default_factory=dict)
    by_stage: dict[str, int] = field(default_factory=dict)
    by_group: dict[str, int] = field(default_factory=dict)
    avg_completion_hours: float | None = None
    tasks_created_in_period: int = 0

    def to_dict(self) -> dict[str, Any]:
        return {
            "user_id": self.user_id,
            "period": {
                "from": self.period_from.isoformat(),
                "to": self.period_to.isoformat(),
            },
            "summary": {
                "total_responsible": self.total_responsible,
                "in_progress": self.in_progress,
                "waiting": self.waiting,
                "awaiting_control": self.awaiting_control,
                "completed_in_period": self.completed_in_period,
                "deferred": self.deferred,
                "declined": self.declined,
                "overdue": self.overdue,
                "tasks_created_in_period": self.tasks_created_in_period,
                "avg_completion_hours": self.avg_completion_hours,
            },
            "by_status": self.by_status,
            "by_stage": self.by_stage,
            "by_group": self.by_group,
        }


def _parse_datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    normalized = value.replace("T", " ").split("+")[0].strip()
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
        try:
            return datetime.strptime(normalized, fmt)
        except ValueError:
            continue
    return None


def _task_status(task: dict[str, Any]) -> int:
    status = task.get("status") or task.get("STATUS") or task.get("realStatus") or task.get("REAL_STATUS")
    return int(status) if status is not None else 0


def _task_field(task: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in task and task[key] is not None:
            return task[key]
    return None


class TasksAnalyzer:
    def __init__(self, client: Bitrix24Client):
        self.client = client

    def analyze(self, user_id: int, date_from: date, date_to: date) -> TaskAnalytics:
        analytics = TaskAnalytics(
            user_id=user_id,
            period_from=date_from,
            period_to=date_to,
        )

        active_tasks = self._fetch_tasks(
            filter_params={"RESPONSIBLE_ID": user_id, "!STATUS": 5},
            select=[
                "ID", "TITLE", "STATUS", "REAL_STATUS", "STAGE_ID",
                "GROUP_ID", "DEADLINE", "CREATED_DATE", "CLOSED_DATE",
            ],
        )

        completed_tasks = self._fetch_tasks(
            filter_params={
                "RESPONSIBLE_ID": user_id,
                "STATUS": 5,
                ">=CLOSED_DATE": date_from.isoformat(),
                "<=CLOSED_DATE": date_to.isoformat(),
            },
            select=[
                "ID", "TITLE", "STATUS", "STAGE_ID", "GROUP_ID",
                "CREATED_DATE", "CLOSED_DATE", "DEADLINE",
            ],
        )

        created_tasks = self._fetch_tasks(
            filter_params={
                "RESPONSIBLE_ID": user_id,
                ">=CREATED_DATE": date_from.isoformat(),
                "<=CREATED_DATE": date_to.isoformat(),
            },
            select=["ID", "CREATED_DATE"],
        )

        status_counter: Counter[str] = Counter()
        stage_counter: Counter[str] = Counter()
        group_counter: Counter[str] = Counter()
        completion_durations: list[float] = []
        now = datetime.now()

        for task in active_tasks:
            status = _task_status(task)
            status_label = TASK_STATUS_LABELS.get(status, f"Статус {status}")
            status_counter[status_label] += 1

            stage_id = _task_field(task, "stageId", "STAGE_ID")
            stage_counter[f"Стадия {stage_id or 'без стадии'}"] += 1

            group_id = _task_field(task, "groupId", "GROUP_ID")
            group_counter[f"Проект {group_id or 'личные'}"] += 1

            deadline = _parse_datetime(_task_field(task, "deadline", "DEADLINE"))
            if deadline and deadline < now and status not in (5, 6, 7):
                analytics.overdue += 1

            if status == 2:
                analytics.waiting += 1
            elif status == 3:
                analytics.in_progress += 1
            elif status == 4:
                analytics.awaiting_control += 1
            elif status == 6:
                analytics.deferred += 1
            elif status == 7:
                analytics.declined += 1

        analytics.total_responsible = len(active_tasks)
        analytics.completed_in_period = len(completed_tasks)
        analytics.tasks_created_in_period = len(created_tasks)

        for task in completed_tasks:
            created = _parse_datetime(_task_field(task, "createdDate", "CREATED_DATE"))
            closed = _parse_datetime(_task_field(task, "closedDate", "CLOSED_DATE"))
            if created and closed:
                hours = (closed - created).total_seconds() / 3600
                if hours >= 0:
                    completion_durations.append(hours)

            stage_id = _task_field(task, "stageId", "STAGE_ID")
            stage_counter[f"Стадия {stage_id or 'без стадии'}"] += 1

        if completion_durations:
            analytics.avg_completion_hours = round(
                sum(completion_durations) / len(completion_durations), 2
            )

        analytics.by_status = dict(status_counter)
        analytics.by_stage = dict(stage_counter)
        analytics.by_group = dict(group_counter)

        return analytics

    def _fetch_tasks(
        self,
        filter_params: dict[str, Any],
        select: list[str],
    ) -> list[dict[str, Any]]:
        params = {
            "filter": filter_params,
            "select": select,
            "order": {"ID": "DESC"},
        }

        try:
            raw = self.client.call_all("tasks.task.list", params, result_key="tasks")
        except Exception:
            legacy_params = {
                "FILTER": filter_params,
                "SELECT": select,
                "ORDER": {"ID": "DESC"},
            }
            raw = self.client.call_all("tasks.task.list", legacy_params, result_key="tasks")

        normalized: list[dict[str, Any]] = []
        for item in raw:
            if isinstance(item, dict) and "task" in item:
                normalized.append(item["task"])
            else:
                normalized.append(item)
        return normalized
