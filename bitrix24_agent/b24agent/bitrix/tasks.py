"""Задачи Битрикс24: выгрузка и стадии канбана.

Про фильтры важно помнить две вещи:

* фильтровать нужно по ``REAL_STATUS`` — ``STATUS`` в ``tasks.task.list``
  является мета-фильтром (``-1`` просрочена, ``-2`` не просмотрена,
  ``-3`` почти просрочена), и ``STATUS=5`` завершённые задачи не вернёт;
* поля фильтра и ``select`` пишутся в UPPER_CASE, а в ответе приходят
  в camelCase.
"""

from __future__ import annotations

import logging
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import datetime
from typing import Any
from zoneinfo import ZoneInfo

from b24agent.analytics.period import Period
from b24agent.bitrix.client import Bitrix24Client
from b24agent.bitrix.errors import Bitrix24Error
from b24agent.bitrix.parsing import as_int, as_opt_int, as_str, parse_datetime, pick

logger = logging.getLogger(__name__)

STATUS_NEW = 1
STATUS_PENDING = 2
STATUS_IN_PROGRESS = 3
STATUS_WAITING_CONTROL = 4
STATUS_COMPLETED = 5
STATUS_DEFERRED = 6
STATUS_DECLINED = 7

STATUS_NAMES: dict[int, str] = {
    STATUS_NEW: "Новая",
    STATUS_PENDING: "Ждёт выполнения",
    STATUS_IN_PROGRESS: "Выполняется",
    STATUS_WAITING_CONTROL: "Ждёт контроля",
    STATUS_COMPLETED: "Завершена",
    STATUS_DEFERRED: "Отложена",
    STATUS_DECLINED: "Отклонена",
}

# Статусы незакрытых задач: их считаем «в работе» в широком смысле.
OPEN_STATUSES: tuple[int, ...] = (
    STATUS_NEW,
    STATUS_PENDING,
    STATUS_IN_PROGRESS,
    STATUS_WAITING_CONTROL,
    STATUS_DEFERRED,
)

TASK_SELECT: tuple[str, ...] = (
    "ID",
    "TITLE",
    "STATUS",
    "RESPONSIBLE_ID",
    "CREATED_BY",
    "CREATED_DATE",
    "CLOSED_DATE",
    "CHANGED_DATE",
    "DATE_START",
    "DEADLINE",
    "GROUP_ID",
    "STAGE_ID",
    "PRIORITY",
    "MARK",
    "TIME_ESTIMATE",
    "TIME_SPENT_IN_LOGS",
)


def status_name(status: int) -> str:
    return STATUS_NAMES.get(status, f"Статус {status}")


@dataclass(frozen=True, slots=True)
class Task:
    """Задача в виде, удобном для расчёта метрик."""

    id: int
    title: str
    status: int
    responsible_id: int
    created_by: int
    created_at: datetime | None
    closed_at: datetime | None
    changed_at: datetime | None
    started_at: datetime | None
    deadline: datetime | None
    group_id: int
    stage_id: int
    priority: int
    mark: str
    time_estimate: int
    time_spent: int

    @classmethod
    def from_api(cls, raw: dict[str, Any], tz: ZoneInfo) -> Task:
        return cls(
            id=as_int(pick(raw, "id", "ID")),
            title=as_str(pick(raw, "title", "TITLE"), "Без названия"),
            status=as_int(pick(raw, "status", "STATUS", "realStatus", "REAL_STATUS")),
            responsible_id=as_int(pick(raw, "responsibleId", "RESPONSIBLE_ID")),
            created_by=as_int(pick(raw, "createdBy", "CREATED_BY")),
            created_at=parse_datetime(pick(raw, "createdDate", "CREATED_DATE"), tz),
            closed_at=parse_datetime(pick(raw, "closedDate", "CLOSED_DATE"), tz),
            changed_at=parse_datetime(pick(raw, "changedDate", "CHANGED_DATE"), tz),
            started_at=parse_datetime(pick(raw, "dateStart", "DATE_START"), tz),
            deadline=parse_datetime(pick(raw, "deadline", "DEADLINE"), tz),
            group_id=as_int(pick(raw, "groupId", "GROUP_ID")),
            stage_id=as_int(pick(raw, "stageId", "STAGE_ID")),
            priority=as_int(pick(raw, "priority", "PRIORITY"), 1),
            mark=as_str(pick(raw, "mark", "MARK")),
            time_estimate=as_int(pick(raw, "timeEstimate", "TIME_ESTIMATE")),
            time_spent=as_int(pick(raw, "timeSpentInLogs", "TIME_SPENT_IN_LOGS")),
        )

    @property
    def is_closed(self) -> bool:
        return self.status == STATUS_COMPLETED

    @property
    def lead_time_seconds(self) -> float | None:
        """Время от постановки до закрытия задачи."""
        if self.created_at is None or self.closed_at is None:
            return None
        delta = (self.closed_at - self.created_at).total_seconds()
        return delta if delta >= 0 else None

    @property
    def is_overdue(self) -> bool:
        """Дедлайн нарушен: для закрытой — по факту, для открытой — на сейчас."""
        if self.deadline is None:
            return False
        if self.is_closed:
            return self.closed_at is not None and self.closed_at > self.deadline
        return datetime.now(self.deadline.tzinfo) > self.deadline

    def url(self, portal_url: str) -> str:
        if not portal_url:
            return ""
        return f"{portal_url}/company/personal/user/{self.responsible_id}/tasks/task/view/{self.id}/"


@dataclass(frozen=True, slots=True)
class TaskStage:
    id: int
    title: str
    entity_id: int
    sort: int = 0


class TasksRepository:
    """Выгрузка задач по одному сотруднику."""

    def __init__(
        self,
        client: Bitrix24Client,
        tz: ZoneInfo,
        *,
        max_records: int = 5000,
    ) -> None:
        self._client = client
        self._tz = tz
        self._max_records = max_records

    async def closed_in_period(self, user_id: int, period: Period) -> list[Task]:
        """Задачи, завершённые сотрудником внутри периода."""
        return await self._list(
            {
                "RESPONSIBLE_ID": user_id,
                "REAL_STATUS": STATUS_COMPLETED,
                ">=CLOSED_DATE": period.bitrix_start(),
                "<=CLOSED_DATE": period.bitrix_end(),
            },
            order={"CLOSED_DATE": "desc"},
        )

    async def created_in_period(self, user_id: int, period: Period) -> list[Task]:
        """Задачи, поставленные сотруднику внутри периода."""
        return await self._list(
            {
                "RESPONSIBLE_ID": user_id,
                ">=CREATED_DATE": period.bitrix_start(),
                "<=CREATED_DATE": period.bitrix_end(),
            },
            order={"CREATED_DATE": "desc"},
        )

    async def open_now(self, user_id: int) -> list[Task]:
        """Текущий срез незакрытых задач сотрудника (не зависит от периода)."""
        return await self._list(
            {
                "RESPONSIBLE_ID": user_id,
                "REAL_STATUS": list(OPEN_STATUSES),
            },
            order={"DEADLINE": "asc"},
        )

    async def stages(self, entity_ids: Iterable[int]) -> dict[int, TaskStage]:
        """Стадии канбана для перечисленных групп (0 — личный канбан).

        Стадии живут отдельно от задач, и на портале без канбана метод может
        отвечать ошибкой — тогда стадия в отчёте останется числовым ID.
        """
        unique = sorted({as_int(entity_id) for entity_id in entity_ids})
        if not unique:
            return {}

        commands = {
            f"stages_{entity_id}": (
                "tasks.task.stages.get",
                {"entityId": entity_id},
            )
            for entity_id in unique
        }
        try:
            results, errors = await self._client.batch(commands)
        except Bitrix24Error as exc:
            logger.info("Стадии канбана недоступны: %s", exc)
            return {}

        for key, message in errors.items():
            logger.debug("Стадии для %s не получены: %s", key, message)

        stages: dict[int, TaskStage] = {}
        for key, payload in results.items():
            entity_id = as_int(key.removeprefix("stages_"))
            for stage in _iter_stage_payload(payload):
                stage_id = as_opt_int(pick(stage, "ID", "id"))
                if stage_id is None:
                    continue
                stages[stage_id] = TaskStage(
                    id=stage_id,
                    title=as_str(pick(stage, "TITLE", "title"), f"Стадия {stage_id}"),
                    entity_id=as_int(pick(stage, "ENTITY_ID", "entityId"), entity_id),
                    sort=as_int(pick(stage, "SORT", "sort")),
                )
        return stages

    async def group_names(self, group_ids: Iterable[int]) -> dict[int, str]:
        """Названия проектов/групп (0 — задачи вне проектов)."""
        unique = sorted({as_int(group_id) for group_id in group_ids} - {0})
        if not unique:
            return {}
        try:
            result = await self._client.call(
                "sonet_group.get", {"FILTER": {"ID": unique}}
            )
        except Bitrix24Error as exc:
            logger.info("Названия проектов недоступны: %s", exc)
            return {}

        names: dict[int, str] = {}
        items = result if isinstance(result, list) else []
        for item in items:
            if not isinstance(item, dict):
                continue
            group_id = as_opt_int(pick(item, "ID", "id"))
            if group_id is not None:
                names[group_id] = as_str(
                    pick(item, "NAME", "name"), f"Проект {group_id}"
                )
        return names

    async def _list(
        self,
        task_filter: dict[str, Any],
        *,
        order: dict[str, str] | None = None,
    ) -> list[Task]:
        raw_items = await self._client.fetch_all(
            "tasks.task.list",
            {
                "filter": task_filter,
                "select": list(TASK_SELECT),
                "order": order or {"ID": "desc"},
            },
            extract=_extract_tasks,
            max_records=self._max_records,
        )
        return [Task.from_api(item, self._tz) for item in raw_items if item]


def _extract_tasks(result: Any) -> Sequence[Any]:
    if isinstance(result, dict):
        tasks = result.get("tasks")
        if isinstance(tasks, list):
            return tasks
        # REST 3.0 отдаёт items вместо tasks.
        items = result.get("items")
        if isinstance(items, list):
            return items
        return []
    if isinstance(result, list):
        return result
    return []


def _iter_stage_payload(payload: Any) -> Iterable[dict[str, Any]]:
    """``tasks.task.stages.get`` отдаёт словарь стадий, но встречается и список."""
    if isinstance(payload, dict):
        for value in payload.values():
            if isinstance(value, dict):
                yield value
    elif isinstance(payload, list):
        for value in payload:
            if isinstance(value, dict):
                yield value
