from __future__ import annotations

from collections import Counter
from dataclasses import asdict, dataclass, field
from datetime import datetime, timedelta
from typing import Any, Optional

from bitrix_agent.client import BitrixClient

# Bitrix task REAL_STATUS values
STATUS_LABELS = {
    1: "Новая",
    2: "Ждёт выполнения",
    3: "В работе",
    4: "Ждёт контроля",
    5: "Завершена",
    6: "Отложена",
    7: "Отклонена",
}


@dataclass
class TasksReport:
    user_id: int
    period_from: str
    period_to: str
    closed_count: int = 0
    in_progress_count: int = 0
    waiting_count: int = 0
    deferred_count: int = 0
    overdue_count: int = 0
    created_count: int = 0
    by_status: dict[str, int] = field(default_factory=dict)
    by_stage: dict[str, int] = field(default_factory=dict)
    avg_close_hours: Optional[float] = None
    closed_tasks: list[dict[str, Any]] = field(default_factory=list)
    active_tasks: list[dict[str, Any]] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


TASK_SELECT = [
    "ID",
    "TITLE",
    "STATUS",
    "REAL_STATUS",
    "STAGE_ID",
    "RESPONSIBLE_ID",
    "CREATED_BY",
    "CREATED_DATE",
    "CLOSED_DATE",
    "DEADLINE",
    "CHANGED_DATE",
    "GROUP_ID",
    "PRIORITY",
]


def _parse_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    text = value.strip()
    parsed: datetime | None = None
    for fmt in (
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d %H:%M:%S%z",
        "%Y-%m-%d %H:%M:%S",
    ):
        try:
            candidate = text
            if len(candidate) >= 5 and candidate[-3] == ":" and candidate[-6] in "+-":
                candidate = candidate[:-3] + candidate[-2:]
            parsed = datetime.strptime(candidate, fmt)
            break
        except ValueError:
            continue
    if parsed is None:
        try:
            parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
        except ValueError:
            return None
    if parsed.tzinfo is None:
        parsed = parsed.astimezone()
    return parsed


def _task_fields(task: dict[str, Any]) -> dict[str, Any]:
    if "id" in task or "title" in task:
        return {
            "ID": str(task.get("id") or task.get("ID") or ""),
            "TITLE": task.get("title") or task.get("TITLE") or "",
            "STATUS": task.get("status") or task.get("STATUS"),
            "REAL_STATUS": task.get("realStatus")
            or task.get("status")
            or task.get("REAL_STATUS")
            or task.get("STATUS"),
            "STAGE_ID": task.get("stageId") or task.get("STAGE_ID"),
            "RESPONSIBLE_ID": task.get("responsibleId") or task.get("RESPONSIBLE_ID"),
            "CREATED_BY": task.get("createdBy") or task.get("CREATED_BY"),
            "CREATED_DATE": task.get("createdDate") or task.get("CREATED_DATE"),
            "CLOSED_DATE": task.get("closedDate") or task.get("CLOSED_DATE"),
            "DEADLINE": task.get("deadline") or task.get("DEADLINE"),
            "CHANGED_DATE": task.get("changedDate") or task.get("CHANGED_DATE"),
            "GROUP_ID": task.get("groupId") or task.get("GROUP_ID"),
            "PRIORITY": task.get("priority") or task.get("PRIORITY"),
        }
    return task


class TasksAnalytics:
    def __init__(self, client: BitrixClient) -> None:
        self.client = client

    def _list_tasks(self, filter_: dict[str, Any], *, max_items: int = 500) -> list[dict[str, Any]]:
        raw_items = self.client.call_list(
            "tasks.task.list",
            {
                "filter": filter_,
                "select": TASK_SELECT,
                "order": {"ID": "DESC"},
            },
            result_key="tasks",
            max_items=max_items,
        )
        return [_task_fields(item if isinstance(item, dict) else {}) for item in raw_items]

    def build_report(
        self,
        user_id: int,
        *,
        days: int = 7,
        now: datetime | None = None,
    ) -> TasksReport:
        now = now or datetime.now().astimezone()
        period_from = (now - timedelta(days=days)).replace(microsecond=0)
        period_to = now.replace(microsecond=0)
        from_str = period_from.strftime("%Y-%m-%dT%H:%M:%S")
        to_str = period_to.strftime("%Y-%m-%dT%H:%M:%S")

        closed = self._list_tasks(
            {
                "RESPONSIBLE_ID": user_id,
                "REAL_STATUS": 5,
                ">=CLOSED_DATE": from_str,
                "<=CLOSED_DATE": to_str,
            }
        )
        active = self._list_tasks(
            {
                "RESPONSIBLE_ID": user_id,
                "!REAL_STATUS": 5,
            }
        )
        created = self._list_tasks(
            {
                "RESPONSIBLE_ID": user_id,
                ">=CREATED_DATE": from_str,
                "<=CREATED_DATE": to_str,
            }
        )

        status_counter: Counter[str] = Counter()
        stage_counter: Counter[str] = Counter()
        in_progress = waiting = deferred = overdue = 0

        for task in active:
            real_status = int(task.get("REAL_STATUS") or task.get("STATUS") or 0)
            label = STATUS_LABELS.get(real_status, f"Статус {real_status}")
            status_counter[label] += 1
            stage_id = task.get("STAGE_ID")
            if stage_id not in (None, "", "0", 0):
                stage_counter[str(stage_id)] += 1

            if real_status == 3:
                in_progress += 1
            elif real_status in {1, 2, 4}:
                waiting += 1
            elif real_status == 6:
                deferred += 1

            deadline = _parse_dt(str(task.get("DEADLINE") or "") or None)
            if deadline and deadline < now and real_status != 5:
                overdue += 1

        close_hours: list[float] = []
        closed_brief: list[dict[str, Any]] = []
        for task in closed:
            created_at = _parse_dt(str(task.get("CREATED_DATE") or "") or None)
            closed_at = _parse_dt(str(task.get("CLOSED_DATE") or "") or None)
            hours = None
            if created_at and closed_at:
                hours = round((closed_at - created_at).total_seconds() / 3600, 2)
                close_hours.append(hours)
            closed_brief.append(
                {
                    "id": task.get("ID"),
                    "title": task.get("TITLE"),
                    "closed_date": task.get("CLOSED_DATE"),
                    "hours_to_close": hours,
                }
            )

        active_brief = [
            {
                "id": t.get("ID"),
                "title": t.get("TITLE"),
                "status": STATUS_LABELS.get(
                    int(t.get("REAL_STATUS") or t.get("STATUS") or 0),
                    str(t.get("REAL_STATUS") or t.get("STATUS")),
                ),
                "stage_id": t.get("STAGE_ID"),
                "deadline": t.get("DEADLINE"),
            }
            for t in active[:50]
        ]

        stage_labels = self._resolve_stage_names(list(stage_counter.keys()))
        by_stage = {
            stage_labels.get(stage_id, f"Стадия {stage_id}"): count
            for stage_id, count in stage_counter.items()
        }

        return TasksReport(
            user_id=user_id,
            period_from=from_str,
            period_to=to_str,
            closed_count=len(closed),
            in_progress_count=in_progress,
            waiting_count=waiting,
            deferred_count=deferred,
            overdue_count=overdue,
            created_count=len(created),
            by_status=dict(status_counter),
            by_stage=by_stage,
            avg_close_hours=round(sum(close_hours) / len(close_hours), 2) if close_hours else None,
            closed_tasks=closed_brief[:30],
            active_tasks=active_brief,
        )

    def _resolve_stage_names(self, stage_ids: list[str]) -> dict[str, str]:
        labels: dict[str, str] = {}
        if not stage_ids:
            return labels
        for method in ("task.stages.get", "task.item.stage.get"):
            try:
                result = self.client.call(method, {"ENTITY_ID": 0, "isAdmin": "N"})
                if isinstance(result, dict):
                    for key, value in result.items():
                        if isinstance(value, dict):
                            sid = str(value.get("ID") or key)
                            title = value.get("TITLE") or value.get("title")
                            if title:
                                labels[sid] = str(title)
                break
            except Exception:
                continue
        return labels
