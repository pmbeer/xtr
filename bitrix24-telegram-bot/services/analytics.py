from __future__ import annotations

import logging
import random
from collections import Counter
from datetime import datetime
from typing import Any, Dict, List, Optional, Sequence

from services.bitrix import BitrixClient
from services.models import (
    TASK_STATUS_LABELS,
    AnalyticsReport,
    OpenLineStats,
    Period,
    TaskStats,
    parse_bitrix_datetime,
)

logger = logging.getLogger(__name__)

TASK_SELECT = [
    "ID",
    "TITLE",
    "STATUS",
    "REAL_STATUS",
    "RESPONSIBLE_ID",
    "CREATED_BY",
    "CREATED_DATE",
    "CLOSED_DATE",
    "CLOSED_BY",
    "DEADLINE",
    "STAGE_ID",
    "GROUP_ID",
    "CHANGED_DATE",
]


class AnalyticsService:
    def __init__(
        self,
        client: Optional[BitrixClient],
        user_id: int,
        *,
        demo_mode: bool = False,
    ) -> None:
        self.client = client
        self.user_id = user_id
        self.demo_mode = demo_mode

    async def build_report(self, period: Period) -> AnalyticsReport:
        if self.demo_mode or self.client is None:
            return self._demo_report(period)

        assert self.client is not None
        user = await self.client.get_user(self.user_id)
        user_name = _format_user_name(user)

        stages = await self.client.get_task_stages(0)
        tasks = await self._fetch_user_tasks(period)
        task_stats = self._analyze_tasks(tasks, stages, period)

        open_lines = await self._analyze_open_lines(period)
        report = AnalyticsReport(
            user_id=self.user_id,
            user_name=user_name,
            period=period,
            generated_at=datetime.now(),
            tasks=task_stats,
            open_lines=open_lines,
        )
        report.build_summary()
        return report

    async def _fetch_user_tasks(self, period: Period) -> List[Dict[str, Any]]:
        assert self.client is not None
        date_from = period.to_bitrix_from()
        date_to = period.to_bitrix_to()

        # Задачи, где пользователь ответственный (активные + закрытые в периоде)
        responsible = await self.client.list_tasks(
            {
                "RESPONSIBLE_ID": self.user_id,
                ">=CHANGED_DATE": date_from,
                "<=CHANGED_DATE": date_to,
            },
            TASK_SELECT,
        )
        closed_by = await self.client.list_tasks(
            {
                "CLOSED_BY": self.user_id,
                ">=CLOSED_DATE": date_from,
                "<=CLOSED_DATE": date_to,
            },
            TASK_SELECT,
        )
        # Активные сейчас (чтобы корректно показать «в работе»)
        active_now = await self.client.list_tasks(
            {
                "RESPONSIBLE_ID": self.user_id,
                "REAL_STATUS": [2, 3, 4, 6],
            },
            TASK_SELECT,
        )

        by_id: Dict[str, Dict[str, Any]] = {}
        for bucket in (responsible, closed_by, active_now):
            for task in bucket:
                task_id = str(_task_field(task, "id", "ID") or "")
                if task_id:
                    by_id[task_id] = task
        return list(by_id.values())

    def _analyze_tasks(
        self,
        tasks: Sequence[Dict[str, Any]],
        stages: Dict[str, str],
        period: Period,
    ) -> TaskStats:
        stats = TaskStats()
        status_counter: Counter[str] = Counter()
        stage_counter: Counter[str] = Counter()
        close_hours: List[float] = []
        now = datetime.now()

        for task in tasks:
            status = _as_int(_task_field(task, "status", "STATUS", "realStatus", "REAL_STATUS"))
            title = str(_task_field(task, "title", "TITLE") or f"#{_task_field(task, 'id', 'ID')}")
            stage_id = str(_task_field(task, "stageId", "STAGE_ID") or "")
            stage_name = stages.get(stage_id) or (f"Стадия {stage_id}" if stage_id else "Без стадии")

            closed_date = parse_bitrix_datetime(_task_field(task, "closedDate", "CLOSED_DATE"))
            created_date = parse_bitrix_datetime(_task_field(task, "createdDate", "CREATED_DATE"))
            deadline = parse_bitrix_datetime(_task_field(task, "deadline", "DEADLINE"))
            closed_by = _as_int(_task_field(task, "closedBy", "CLOSED_BY"))

            stats.total += 1
            label = TASK_STATUS_LABELS.get(status or 0, f"Статус {status}")
            status_counter[label] += 1
            stage_counter[stage_name] += 1

            closed_in_period = bool(
                closed_date and period.date_from <= closed_date <= period.date_to
            )
            closed_by_me = closed_by == self.user_id or closed_by is None
            if status == 5 and closed_in_period and closed_by_me:
                stats.closed += 1
                stats.closed_titles.append(title)
                if created_date and closed_date:
                    close_hours.append((closed_date - created_date).total_seconds() / 3600.0)

            if status == 3:
                stats.in_progress += 1
                stats.in_progress_titles.append(title)
            elif status == 2:
                stats.pending += 1
            elif status == 4:
                stats.awaiting_control += 1
            elif status == 6:
                stats.deferred += 1

            if deadline and deadline < now and status in (2, 3, 4, 6):
                stats.overdue += 1

        # Уникальность в closed_titles
        stats.closed_titles = _unique_keep_order(stats.closed_titles)[:50]
        stats.in_progress_titles = _unique_keep_order(stats.in_progress_titles)[:50]
        stats.by_status = dict(status_counter)
        stats.by_stage = dict(stage_counter)
        if close_hours:
            stats.avg_close_hours = sum(close_hours) / len(close_hours)
        return stats

    async def _analyze_open_lines(self, period: Period) -> OpenLineStats:
        assert self.client is not None
        date_from = period.to_bitrix_from()
        date_to = period.to_bitrix_to()

        sessions = await self.client.list_openline_sessions_v2(
            operator_id=self.user_id,
            date_from=date_from,
            date_to=date_to,
        )
        if sessions:
            return self._stats_from_sessions(sessions)

        activities = await self.client.list_openline_activities(
            responsible_id=self.user_id,
            date_from=date_from,
            date_to=date_to,
        )
        if activities:
            return self._stats_from_activities(activities)

        return OpenLineStats(
            notes=(
                "Не удалось получить сессии открытых линий через REST "
                "(метод недоступен на вебхуке или нет прав imopenlines). "
                "Проверьте права вебхука: task, user, crm, imopenlines."
            )
        )

    def _stats_from_sessions(self, sessions: Sequence[Dict[str, Any]]) -> OpenLineStats:
        stats = OpenLineStats(total_sessions=len(sessions))
        answer_times: List[float] = []
        close_times: List[float] = []
        sources: Counter[str] = Counter()

        for session in sessions:
            status = session.get("status")
            closed = str(session.get("closed") or "").upper() in {"Y", "1", "TRUE"}
            if status in (0, "0", "closed", "CLOSE") or closed or session.get("dateClose"):
                stats.closed_sessions += 1
            else:
                stats.active_sessions += 1

            source = str(session.get("source") or session.get("connector") or "unknown")
            sources[source] += 1

            wait_answer = session.get("waitAnswer") or session.get("timeAnswer")
            wait_close = session.get("waitClose") or session.get("timeClose")
            if wait_answer is not None:
                try:
                    answer_times.append(float(wait_answer))
                except (TypeError, ValueError):
                    pass
            if wait_close is not None:
                try:
                    close_times.append(float(wait_close))
                except (TypeError, ValueError):
                    pass
            else:
                created = parse_bitrix_datetime(session.get("dateCreate") or session.get("date_create"))
                closed_at = parse_bitrix_datetime(session.get("dateClose") or session.get("date_close"))
                if created and closed_at:
                    close_times.append((closed_at - created).total_seconds())

        if answer_times:
            stats.avg_answer_seconds = sum(answer_times) / len(answer_times)
        if close_times:
            stats.avg_close_seconds = sum(close_times) / len(close_times)
            stats.avg_close_hours = stats.avg_close_seconds / 3600.0
        stats.by_source = dict(sources)
        return stats

    def _stats_from_activities(self, activities: Sequence[Dict[str, Any]]) -> OpenLineStats:
        stats = OpenLineStats(
            total_sessions=len(activities),
            notes="Данные из CRM-активностей IMOPENLINES_SESSION (fallback).",
        )
        close_times: List[float] = []
        for activity in activities:
            completed = str(activity.get("COMPLETED") or "").upper() == "Y"
            if completed:
                stats.closed_sessions += 1
            else:
                stats.active_sessions += 1
            start = parse_bitrix_datetime(activity.get("START_TIME"))
            end = parse_bitrix_datetime(activity.get("END_TIME"))
            if start and end and end >= start:
                close_times.append((end - start).total_seconds())
        if close_times:
            stats.avg_close_seconds = sum(close_times) / len(close_times)
            stats.avg_close_hours = stats.avg_close_seconds / 3600.0
        return stats

    def _demo_report(self, period: Period) -> AnalyticsReport:
        rng = random.Random(period.date_from.toordinal() + self.user_id)
        closed = rng.randint(8, 25)
        in_progress = rng.randint(3, 12)
        pending = rng.randint(1, 8)
        awaiting = rng.randint(0, 4)
        deferred = rng.randint(0, 3)
        overdue = rng.randint(0, 5)
        tasks = TaskStats(
            total=closed + in_progress + pending + awaiting + deferred,
            closed=closed,
            in_progress=in_progress,
            pending=pending,
            awaiting_control=awaiting,
            deferred=deferred,
            overdue=overdue,
            by_status={
                "Завершена": closed,
                "В работе": in_progress,
                "Ждёт выполнения": pending,
                "Ждёт контроля": awaiting,
                "Отложена": deferred,
            },
            by_stage={
                "Новые": pending,
                "В работе": in_progress,
                "На проверке": awaiting,
                "Готово": closed,
                "Пауза": deferred,
            },
            closed_titles=[f"Демо-задача закрыта #{i}" for i in range(1, min(6, closed + 1))],
            in_progress_titles=[f"Демо-задача в работе #{i}" for i in range(1, min(6, in_progress + 1))],
            avg_close_hours=round(rng.uniform(4, 48), 1),
        )
        sessions = rng.randint(15, 60)
        closed_ol = int(sessions * rng.uniform(0.7, 0.95))
        open_lines = OpenLineStats(
            total_sessions=sessions,
            closed_sessions=closed_ol,
            active_sessions=sessions - closed_ol,
            avg_answer_seconds=rng.uniform(60, 900),
            avg_close_seconds=rng.uniform(900, 7200),
            avg_close_hours=None,
            by_source={"telegram": sessions // 2, "whatsapp": sessions // 3, "livechat": sessions - sessions // 2 - sessions // 3},
            notes="Демо-данные (DEMO_MODE=true).",
        )
        open_lines.avg_close_hours = (open_lines.avg_close_seconds or 0) / 3600.0
        report = AnalyticsReport(
            user_id=self.user_id or 1,
            user_name="Демо Пользователь",
            period=period,
            generated_at=datetime.now(),
            tasks=tasks,
            open_lines=open_lines,
        )
        report.build_summary()
        return report


def _task_field(task: Dict[str, Any], *keys: str) -> Any:
    # tasks.task.list часто возвращает {id: ..., title: ...} или вложенный task
    node = task.get("task") if isinstance(task.get("task"), dict) else task
    for key in keys:
        if key in node and node[key] not in (None, ""):
            return node[key]
    lower_map = {str(k).lower(): v for k, v in node.items()}
    for key in keys:
        if key.lower() in lower_map:
            return lower_map[key.lower()]
    return None


def _as_int(value: Any) -> Optional[int]:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _format_user_name(user: Dict[str, Any]) -> str:
    parts = [
        str(user.get("NAME") or user.get("name") or "").strip(),
        str(user.get("LAST_NAME") or user.get("lastName") or "").strip(),
    ]
    name = " ".join(p for p in parts if p)
    return name or f"User {user.get('ID') or user.get('id') or ''}".strip()


def _unique_keep_order(items: Sequence[str]) -> List[str]:
    seen = set()
    result: List[str] = []
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        result.append(item)
    return result
