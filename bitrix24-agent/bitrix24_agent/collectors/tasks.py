"""Метрики по задачам: закрыто, в работе, по стадиям, время решения."""

from __future__ import annotations

import logging
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from datetime import datetime, tzinfo
from typing import Any

from ..client import Bitrix24Client
from ..errors import Bitrix24Error
from ..metrics import Summary, summarize
from ..normalize import iter_records, parse_datetime, parse_float, parse_int, pick
from ..period import Period
from .base import ERROR, PARTIAL, Section

log = logging.getLogger(__name__)

#: Реальные статусы задач Битрикс24 (`REAL_STATUS` в фильтре, `status` в ответе).
STATUS_LABELS: dict[int, str] = {
    1: "Новая",
    2: "Ждёт выполнения",
    3: "Выполняется",
    4: "Ждёт контроля",
    5: "Завершена",
    6: "Отложена",
    7: "Отклонена",
}
#: Незакрытые статусы — из них складывается текущая нагрузка.
OPEN_STATUSES: tuple[int, ...] = (1, 2, 3, 4, 6)
#: «В работе» в узком смысле: без отложенных.
ACTIVE_STATUSES: frozenset[int] = frozenset({2, 3, 4})

TASK_FIELDS = [
    "ID",
    "TITLE",
    "STATUS",
    "CREATED_DATE",
    "CLOSED_DATE",
    "DEADLINE",
    "RESPONSIBLE_ID",
    "CREATED_BY",
    "GROUP_ID",
    "STAGE_ID",
    "TIME_SPENT_IN_LOGS",
    "TIME_ESTIMATE",
    "PRIORITY",
    "MARK",
]

#: Сколько групп максимум опрашиваем ради названий стадий канбана.
MAX_STAGE_GROUPS = 12


@dataclass(frozen=True)
class Task:
    """Задача в том объёме полей, который нужен аналитике."""

    id: int
    title: str
    status: int
    created: datetime | None = None
    closed: datetime | None = None
    deadline: datetime | None = None
    group_id: int = 0
    stage_id: int = 0
    responsible_id: int = 0
    created_by: int = 0
    time_spent: float = 0.0
    time_estimate: float = 0.0
    mark: str = ""

    @property
    def status_label(self) -> str:
        return STATUS_LABELS.get(self.status, f"Статус {self.status}")

    @property
    def resolution_seconds(self) -> float | None:
        """Сколько задача прожила от постановки до закрытия."""
        if self.created is None or self.closed is None:
            return None
        seconds = (self.closed - self.created).total_seconds()
        return seconds if seconds >= 0 else None

    @property
    def closed_late(self) -> bool:
        return bool(self.deadline and self.closed and self.closed > self.deadline)

    def is_overdue(self, now: datetime) -> bool:
        return bool(self.deadline and self.closed is None and self.deadline < now)

    @classmethod
    def from_raw(cls, record: Mapping[str, Any], tz: tzinfo) -> Task | None:
        task_id = parse_int(pick(record, "ID"))
        if task_id is None:
            return None
        return cls(
            id=task_id,
            title=str(pick(record, "TITLE", default="") or f"Задача #{task_id}"),
            status=parse_int(pick(record, "STATUS", "REAL_STATUS"), 0) or 0,
            created=parse_datetime(pick(record, "CREATED_DATE"), tz),
            closed=parse_datetime(pick(record, "CLOSED_DATE"), tz),
            deadline=parse_datetime(pick(record, "DEADLINE"), tz),
            group_id=parse_int(pick(record, "GROUP_ID"), 0) or 0,
            stage_id=parse_int(pick(record, "STAGE_ID"), 0) or 0,
            responsible_id=parse_int(pick(record, "RESPONSIBLE_ID"), 0) or 0,
            created_by=parse_int(pick(record, "CREATED_BY"), 0) or 0,
            time_spent=parse_float(pick(record, "TIME_SPENT_IN_LOGS"), 0.0) or 0.0,
            time_estimate=parse_float(pick(record, "TIME_ESTIMATE"), 0.0) or 0.0,
            mark=str(pick(record, "MARK", default="") or ""),
        )


@dataclass
class StageBucket:
    """Колонка канбана и сколько задач в ней стоит."""

    stage_id: int
    title: str
    system_type: str = ""
    count: int = 0
    scope: str = ""


@dataclass
class GroupBucket:
    """Проект или рабочая группа со счётчиками задач."""

    group_id: int
    title: str
    closed: int = 0
    open: int = 0


@dataclass
class TasksSection(Section):
    """Сводка по задачам за период и на текущий момент."""

    name: str = "tasks"
    title: str = "Задачи"

    closed_count: int = 0
    closed_analyzed: int = 0
    closed_late: int = 0
    created_count: int = 0
    resolution: Summary = field(default_factory=Summary)
    time_spent_seconds: float = 0.0

    open_count: int = 0
    in_progress_count: int = 0
    open_by_status: dict[str, int] = field(default_factory=dict)
    open_overdue: int = 0
    open_without_deadline: int = 0
    open_stale_count: int = 0

    stages: list[StageBucket] = field(default_factory=list)
    groups: list[GroupBucket] = field(default_factory=list)
    longest_open: list[dict[str, Any]] = field(default_factory=list)
    fastest_closed: list[dict[str, Any]] = field(default_factory=list)
    slowest_closed: list[dict[str, Any]] = field(default_factory=list)


def collect_tasks(
    client: Bitrix24Client,
    *,
    user_id: int,
    period: Period,
    tz: tzinfo,
    now: datetime | None = None,
    max_tasks: int = 2000,
    stale_days: int = 14,
) -> TasksSection:
    """Собирает раздел «Задачи».

    Счётчики берём из `total` списочного метода одним пакетным запросом, а
    детальные метрики считаем по выгруженным задачам — так на большом портале
    отчёт не упирается в лимиты REST.
    """
    section = TasksSection()
    now = now or datetime.now(tz)

    try:
        counts = _fetch_counts(client, user_id=user_id, period=period)
    except Bitrix24Error as exc:
        section.status = ERROR
        section.note(f"Не удалось получить счётчики задач: {exc}")
        return section

    section.closed_count = counts.get("closed", 0)
    section.created_count = counts.get("created", 0)
    for status in OPEN_STATUSES:
        count = counts.get(f"status_{status}", 0)
        if count:
            section.open_by_status[STATUS_LABELS[status]] = count
    section.open_count = sum(section.open_by_status.values())
    section.in_progress_count = sum(
        counts.get(f"status_{status}", 0) for status in ACTIVE_STATUSES
    )

    closed_tasks = _fetch_closed(client, user_id=user_id, period=period, tz=tz, limit=max_tasks)
    open_tasks = _fetch_open(client, user_id=user_id, tz=tz, limit=max_tasks)

    if section.closed_count > len(closed_tasks):
        section.status = PARTIAL
        section.note(
            f"Закрытых задач за период {section.closed_count}, детально разобрано "
            f"{len(closed_tasks)} (лимит выгрузки). Счётчики точные, средние — по выборке."
        )

    _fill_closed_metrics(section, closed_tasks)
    _fill_open_metrics(section, open_tasks, now=now, stale_days=stale_days)
    _fill_stages(client, section, open_tasks)
    _fill_groups(client, section, closed_tasks, open_tasks)

    return section


def _fetch_counts(client: Bitrix24Client, *, user_id: int, period: Period) -> dict[str, int]:
    """Один batch: закрыто за период, поставлено мной, и остатки по статусам."""
    commands: dict[str, tuple[str, dict]] = {
        "closed": (
            "tasks.task.list",
            {
                "filter": {
                    "RESPONSIBLE_ID": user_id,
                    ">=CLOSED_DATE": period.iso_start(),
                    "<=CLOSED_DATE": period.iso_end(),
                },
                "select": ["ID"],
                "start": 0,
            },
        ),
        "created": (
            "tasks.task.list",
            {
                "filter": {
                    "CREATED_BY": user_id,
                    ">=CREATED_DATE": period.iso_start(),
                    "<=CREATED_DATE": period.iso_end(),
                },
                "select": ["ID"],
                "start": 0,
            },
        ),
    }
    for status in OPEN_STATUSES:
        commands[f"status_{status}"] = (
            "tasks.task.list",
            {
                "filter": {"RESPONSIBLE_ID": user_id, "REAL_STATUS": status},
                "select": ["ID"],
                "start": 0,
            },
        )

    counts: dict[str, int] = {}
    for key, result in client.batch(commands).items():
        if not result.ok:
            log.info("счётчик %s недоступен: %s", key, result.error)
            continue
        counts[key] = result.total if result.total is not None else 0
    return counts


def _fetch_closed(
    client: Bitrix24Client, *, user_id: int, period: Period, tz: tzinfo, limit: int
) -> list[Task]:
    raw = client.paginate(
        "tasks.task.list",
        {
            "filter": {
                "RESPONSIBLE_ID": user_id,
                ">=CLOSED_DATE": period.iso_start(),
                "<=CLOSED_DATE": period.iso_end(),
            },
            "select": TASK_FIELDS,
            "order": {"CLOSED_DATE": "desc"},
        },
        max_items=limit,
    )
    return _to_tasks(raw, tz)


def _fetch_open(client: Bitrix24Client, *, user_id: int, tz: tzinfo, limit: int) -> list[Task]:
    raw = client.paginate(
        "tasks.task.list",
        {
            "filter": {"RESPONSIBLE_ID": user_id, "REAL_STATUS": list(OPEN_STATUSES)},
            "select": TASK_FIELDS,
            "order": {"CREATED_DATE": "asc"},
        },
        max_items=limit,
    )
    return _to_tasks(raw, tz)


def _to_tasks(raw: Iterable[Any], tz: tzinfo) -> list[Task]:
    tasks: list[Task] = []
    for record in raw:
        if not isinstance(record, Mapping):
            continue
        task = Task.from_raw(record, tz)
        if task is not None:
            tasks.append(task)
    return tasks


def _fill_closed_metrics(section: TasksSection, closed_tasks: list[Task]) -> None:
    section.closed_analyzed = len(closed_tasks)
    durations = [task.resolution_seconds for task in closed_tasks]
    section.resolution = summarize([value for value in durations if value is not None])
    section.closed_late = sum(1 for task in closed_tasks if task.closed_late)
    section.time_spent_seconds = sum(task.time_spent for task in closed_tasks)

    measured = [task for task in closed_tasks if task.resolution_seconds is not None]
    measured.sort(key=lambda task: task.resolution_seconds or 0.0)
    section.fastest_closed = [_task_brief(task) for task in measured[:5]]
    section.slowest_closed = [_task_brief(task) for task in reversed(measured[-5:])]


def _fill_open_metrics(
    section: TasksSection, open_tasks: list[Task], *, now: datetime, stale_days: int
) -> None:
    if not open_tasks:
        return
    if not section.open_count:
        section.open_count = len(open_tasks)
        for task in open_tasks:
            label = task.status_label
            section.open_by_status[label] = section.open_by_status.get(label, 0) + 1
        section.in_progress_count = sum(
            1 for task in open_tasks if task.status in ACTIVE_STATUSES
        )

    section.open_overdue = sum(1 for task in open_tasks if task.is_overdue(now))
    section.open_without_deadline = sum(1 for task in open_tasks if task.deadline is None)

    stale_threshold = stale_days * 86400
    aged = [
        (task, (now - task.created).total_seconds())
        for task in open_tasks
        if task.created is not None
    ]
    section.open_stale_count = sum(1 for _, age in aged if age >= stale_threshold)
    aged.sort(key=lambda pair: pair[1], reverse=True)
    section.longest_open = [
        {**_task_brief(task), "age_seconds": round(age)} for task, age in aged[:5]
    ]


def _fill_stages(client: Bitrix24Client, section: TasksSection, open_tasks: list[Task]) -> None:
    """Раскладывает незакрытые задачи по колонкам канбана."""
    counts: dict[tuple[int, int], int] = {}
    for task in open_tasks:
        if task.stage_id:
            counts[(task.group_id, task.stage_id)] = counts.get((task.group_id, task.stage_id), 0) + 1
    if not counts:
        return

    entity_ids = sorted({group_id for group_id, _ in counts})[:MAX_STAGE_GROUPS]
    titles: dict[int, tuple[str, str, str]] = {}
    for entity_id in entity_ids:
        titles.update(_fetch_stage_titles(client, entity_id))

    buckets: dict[int, StageBucket] = {}
    for (_, stage_id), count in counts.items():
        title, system_type, scope = titles.get(stage_id, (f"Стадия #{stage_id}", "", ""))
        bucket = buckets.get(stage_id)
        if bucket is None:
            bucket = StageBucket(stage_id=stage_id, title=title, system_type=system_type, scope=scope)
            buckets[stage_id] = bucket
        bucket.count += count
    section.stages = sorted(buckets.values(), key=lambda item: item.count, reverse=True)


def _fetch_stage_titles(
    client: Bitrix24Client, entity_id: int
) -> dict[int, tuple[str, str, str]]:
    """`entityId = 0` — стадии «Моего плана», иначе канбан рабочей группы."""
    try:
        payload = client.try_call("task.stages.get", {"entityId": entity_id})
    except Bitrix24Error as exc:
        log.info("стадии для entityId=%s недоступны: %s", entity_id, exc.code)
        return {}
    titles: dict[int, tuple[str, str, str]] = {}
    for record in iter_records(payload):
        stage_id = parse_int(pick(record, "ID"))
        if stage_id is None:
            continue
        scope = "Мой план" if entity_id == 0 else f"Группа #{entity_id}"
        titles[stage_id] = (
            str(pick(record, "TITLE", default="") or f"Стадия #{stage_id}"),
            str(pick(record, "SYSTEM_TYPE", default="") or ""),
            scope,
        )
    return titles


def _fill_groups(
    client: Bitrix24Client,
    section: TasksSection,
    closed_tasks: list[Task],
    open_tasks: list[Task],
) -> None:
    buckets: dict[int, GroupBucket] = {}
    for task in closed_tasks:
        bucket = buckets.setdefault(task.group_id, GroupBucket(task.group_id, ""))
        bucket.closed += 1
    for task in open_tasks:
        bucket = buckets.setdefault(task.group_id, GroupBucket(task.group_id, ""))
        bucket.open += 1
    if not buckets:
        return

    names = _fetch_group_names(client, [group_id for group_id in buckets if group_id])
    for group_id, bucket in buckets.items():
        bucket.title = names.get(group_id, "Без проекта" if not group_id else f"Группа #{group_id}")
    section.groups = sorted(
        buckets.values(), key=lambda item: (item.closed + item.open), reverse=True
    )[:10]


def _fetch_group_names(client: Bitrix24Client, group_ids: list[int]) -> dict[int, str]:
    unique_ids = sorted(set(group_ids))
    if not unique_ids:
        return {}
    payload = client.try_call("sonet_group.get", {"FILTER": {"ID": unique_ids}})
    names: dict[int, str] = {}
    for record in iter_records(payload):
        group_id = parse_int(pick(record, "ID"))
        if group_id is not None:
            names[group_id] = str(pick(record, "NAME", default="") or f"Группа #{group_id}")
    return names


def _task_brief(task: Task) -> dict[str, Any]:
    return {
        "id": task.id,
        "title": task.title,
        "status": task.status_label,
        "resolution_seconds": task.resolution_seconds,
        "deadline_missed": task.closed_late,
    }
