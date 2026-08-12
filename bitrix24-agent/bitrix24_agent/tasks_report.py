"""Аналитика по задачам пользователя через метод tasks.task.list.

Документация метода: https://apidocs.bitrix24.com/api-reference/tasks/tasks-task-list.html

Важно: для фильтрации по фактическому статусу задачи нужно использовать поле
REAL_STATUS (а не STATUS — это мета-статус для сортировки, куда попадают ещё
и "просроченная"/"почти просрочена"/"не просмотрена").
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional

from .client import BitrixClient
from .period import Period
from .utils import parse_bitrix_datetime

# https://apidocs.bitrix24.com/api-reference/tasks/tasks-task-list.html (REAL_STATUS)
STAGE_LABELS: Dict[int, str] = {
    1: "Новая",
    2: "Ждёт выполнения",
    3: "Выполняется",
    4: "Ждёт контроля",
    5: "Завершена",
    6: "Отложена",
    7: "Отклонена",
}

TASK_SELECT = [
    "ID",
    "TITLE",
    "STATUS",
    "CREATED_DATE",
    "CLOSED_DATE",
    "CHANGED_DATE",
    "DEADLINE",
    "GROUP_ID",
]


@dataclass
class ClosedTaskInfo:
    id: int
    title: str
    created_date: Optional[datetime]
    closed_date: Optional[datetime]

    @property
    def duration_hours(self) -> Optional[float]:
        if self.created_date is None or self.closed_date is None:
            return None
        delta = self.closed_date - self.created_date
        return delta.total_seconds() / 3600.0


@dataclass
class TasksReport:
    user_id: int
    period: Period
    stage_counts: Dict[int, int] = field(default_factory=dict)
    overdue_count: int = 0
    closed_in_period: List[ClosedTaskInfo] = field(default_factory=list)

    @property
    def in_progress_count(self) -> int:
        return self.stage_counts.get(3, 0)

    @property
    def open_total_count(self) -> int:
        """Все незавершённые и не отклонённые задачи (текущий снимок, без учёта периода)."""
        closed_like = {5, 7}
        return sum(count for stage, count in self.stage_counts.items() if stage not in closed_like)

    @property
    def closed_count(self) -> int:
        return len(self.closed_in_period)

    @property
    def avg_closing_hours(self) -> Optional[float]:
        durations = [t.duration_hours for t in self.closed_in_period if t.duration_hours is not None]
        if not durations:
            return None
        return sum(durations) / len(durations)

    def stage_breakdown(self) -> List[str]:
        lines = []
        for stage, count in sorted(self.stage_counts.items()):
            label = STAGE_LABELS.get(stage, f"Статус {stage}")
            lines.append(f"{label}: {count}")
        return lines


def build_tasks_report(client: BitrixClient, user_id: int, period: Period) -> TasksReport:
    """Собирает отчёт по задачам: текущее распределение по стадиям + закрытые в периоде."""
    report = TasksReport(user_id=user_id, period=period)

    # 1. Текущий снимок по активным стадиям (без ограничения по дате — "где я сейчас").
    # Берём только незавершённые/неотклонённые задачи (REAL_STATUS без 5 и 7),
    # чтобы не тянуть всю историю выполненных задач за все время.
    active_stages = [1, 2, 3, 4, 6]
    for task in client.call_list(
        "tasks.task.list",
        filter_={"RESPONSIBLE_ID": user_id, "REAL_STATUS": active_stages},
        select=["ID", "STATUS", "DEADLINE"],
    ):
        try:
            status = int(task.get("status", task.get("STATUS", 0)))
        except (TypeError, ValueError):
            status = 0
        report.stage_counts[status] = report.stage_counts.get(status, 0) + 1

    # 2. Просроченные задачи (мета-статус -1 через поле STATUS).
    overdue_filter = {"RESPONSIBLE_ID": user_id, "STATUS": -1}
    report.overdue_count = sum(1 for _ in client.call_list(
        "tasks.task.list", filter_=overdue_filter, select=["ID"]
    ))

    # 3. Задачи, закрытые в указанном периоде (по дате фактического завершения).
    closed_filter: Dict[str, object] = {"RESPONSIBLE_ID": user_id, "REAL_STATUS": 5}
    closed_filter.update(period.as_bitrix_filter("CLOSED_DATE"))
    for task in client.call_list(
        "tasks.task.list",
        filter_=closed_filter,
        select=TASK_SELECT,
        order={"CLOSED_DATE": "asc"},
    ):
        report.closed_in_period.append(
            ClosedTaskInfo(
                id=int(task.get("id", task.get("ID"))),
                title=task.get("title", task.get("TITLE", "")),
                created_date=parse_bitrix_datetime(task.get("createdDate") or task.get("CREATED_DATE")),
                closed_date=parse_bitrix_datetime(task.get("closedDate") or task.get("CLOSED_DATE")),
            )
        )

    return report
