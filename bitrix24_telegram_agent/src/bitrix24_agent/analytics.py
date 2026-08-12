import asyncio
from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

from .bitrix import BitrixAPIError, BitrixClient
from .periods import ReportPeriod

STATUS_NAMES = {
    1: "Новая",
    2: "Ждёт выполнения",
    3: "Выполняется",
    4: "Ждёт контроля",
    5: "Завершена",
    6: "Отложена",
    7: "Отклонена",
}
ACTIVE_STATUSES = {2, 3, 4, 6}
TASK_FIELDS = [
    "ID",
    "TITLE",
    "STATUS",
    "RESPONSIBLE_ID",
    "GROUP_ID",
    "STAGE_ID",
    "DEADLINE",
    "CREATED_DATE",
    "CLOSED_DATE",
]


def field(item: dict[str, Any], name: str, default: Any = None) -> Any:
    target = name.replace("_", "").lower()
    for key, value in item.items():
        if key.replace("_", "").lower() == target:
            return value
    return default


def nested_data(value: Any) -> dict[str, Any]:
    while isinstance(value, dict) and isinstance(value.get("data"), dict):
        value = value["data"]
    return value if isinstance(value, dict) else {}


@dataclass
class TaskAnalytics:
    completed: list[dict[str, Any]] = field(default_factory=list)
    active: list[dict[str, Any]] = field(default_factory=list)
    statuses: Counter[str] = field(default_factory=Counter)
    stages: Counter[str] = field(default_factory=Counter)
    overdue: int = 0


@dataclass
class OpenLinesAnalytics:
    processed: int | None = None
    closed: int | None = None
    average_first_answer_seconds: float | None = None
    average_resolution_seconds: float | None = None
    active: int | None = None
    error: str | None = None


@dataclass
class AnalyticsResult:
    user_id: int
    period: ReportPeriod
    tasks: TaskAnalytics
    open_lines: OpenLinesAnalytics


class AnalyticsService:
    def __init__(
        self,
        client: BitrixClient,
        user_id: int | None,
        openlines_stats_method: str,
    ) -> None:
        self.client = client
        self.configured_user_id = user_id
        self.openlines_stats_method = openlines_stats_method

    async def collect(self, period: ReportPeriod) -> AnalyticsResult:
        user_id = self.configured_user_id or await self.client.get_current_user_id()
        completed, all_non_completed = await asyncio.gather(
            self.client.list_tasks(
                {
                    "RESPONSIBLE_ID": user_id,
                    "REAL_STATUS": 5,
                    ">=CLOSED_DATE": period.start.isoformat(),
                    "<=CLOSED_DATE": period.end.isoformat(),
                },
                TASK_FIELDS,
            ),
            self.client.list_tasks(
                {"RESPONSIBLE_ID": user_id, "!REAL_STATUS": 5},
                TASK_FIELDS,
            ),
        )
        active = [
            task
            for task in all_non_completed
            if int(field(task, "STATUS", 0) or 0) in ACTIVE_STATUSES
        ]
        tasks = await self._task_analytics(completed, active, period.end)
        open_lines = await self._open_lines(user_id, period)
        return AnalyticsResult(user_id, period, tasks, open_lines)

    async def _task_analytics(
        self,
        completed: list[dict[str, Any]],
        active: list[dict[str, Any]],
        now: datetime,
    ) -> TaskAnalytics:
        statuses = Counter(
            STATUS_NAMES.get(int(field(task, "STATUS", 0) or 0), "Неизвестно") for task in active
        )
        group_ids = {int(field(task, "GROUP_ID", 0) or 0) for task in active}
        stage_maps: dict[int, dict[str, str]] = {}

        async def load_stages(group_id: int) -> None:
            try:
                stage_maps[group_id] = await self.client.get_stages(group_id)
            except (BitrixAPIError, KeyError, TypeError):
                stage_maps[group_id] = {}

        await asyncio.gather(*(load_stages(group_id) for group_id in group_ids))
        stages: Counter[str] = Counter()
        overdue = 0
        for task in active:
            group_id = int(field(task, "GROUP_ID", 0) or 0)
            stage_id = str(field(task, "STAGE_ID", "") or "")
            stage_name = stage_maps.get(group_id, {}).get(stage_id)
            status = int(field(task, "STATUS", 0) or 0)
            stages[stage_name or STATUS_NAMES.get(status, "Без стадии")] += 1
            deadline = field(task, "DEADLINE")
            if deadline:
                try:
                    parsed = datetime.fromisoformat(str(deadline).replace("Z", "+00:00"))
                    overdue += int(parsed < now)
                except ValueError:
                    pass
        return TaskAnalytics(completed, active, statuses, stages, overdue)

    async def _open_lines(
        self,
        user_id: int,
        period: ReportPeriod,
    ) -> OpenLinesAnalytics:
        try:
            raw = await self.client.call(
                self.openlines_stats_method,
                {
                    "dateFrom": period.start.isoformat(),
                    "dateTo": period.end.isoformat(),
                    "operatorId": user_id,
                },
            )
            stats = nested_data(raw)
            return OpenLinesAnalytics(
                processed=_integer(stats, "totalSessions"),
                closed=_integer(stats, "closedSessions"),
                average_first_answer_seconds=_number(stats, "avgWaitAnswer"),
                average_resolution_seconds=_number(stats, "avgSessionDuration", "avgWaitClose"),
                active=_integer(stats, "activeSessions"),
            )
        except BitrixAPIError as error:
            return OpenLinesAnalytics(error=f"{error.code}: {error.message}")
        except (httpx_error_types()):
            return OpenLinesAnalytics(error="Не удалось подключиться к Bitrix24")


def httpx_error_types() -> tuple[type[Exception], ...]:
    # Imported lazily so this module remains easy to unit test with a fake client.
    import httpx

    return (httpx.HTTPError,)


def _find(stats: dict[str, Any], *names: str) -> Any:
    for name in names:
        value = field(stats, name)
        if value is not None:
            return value
    return None


def _integer(stats: dict[str, Any], *names: str) -> int | None:
    value = _find(stats, *names)
    return int(value) if value is not None else None


def _number(stats: dict[str, Any], *names: str) -> float | None:
    value = _find(stats, *names)
    return float(value) if value is not None else None
