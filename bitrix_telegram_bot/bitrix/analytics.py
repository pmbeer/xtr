"""Аналитика данных Bitrix24."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any

from bitrix.client import Bitrix24Client

# Статусы задач Bitrix24
TASK_STATUS_NAMES = {
    2: "Ждёт выполнения",
    3: "Ждёт контроля",
    4: "Выполняется",
    5: "Завершена",
    6: "Отложена",
    7: "Отклонена",
}

CLOSED_TASK_STATUSES = {5, 7}
ACTIVE_TASK_STATUSES = {2, 3, 4, 6}


@dataclass
class TaskAnalytics:
    total: int = 0
    closed: int = 0
    in_progress: int = 0
    by_status: dict[str, int] = field(default_factory=dict)
    by_stage: dict[str, int] = field(default_factory=dict)
    tasks: list[dict[str, Any]] = field(default_factory=list)


@dataclass
class OpenLineAnalytics:
    total_sessions: int = 0
    closed_sessions: int = 0
    open_sessions: int = 0
    avg_resolution_seconds: float = 0.0
    avg_first_response_seconds: float = 0.0
    sessions: list[dict[str, Any]] = field(default_factory=list)


@dataclass
class UserReport:
    user_id: int
    user_name: str
    period_from: datetime | None
    period_to: datetime | None
    generated_at: datetime
    tasks: TaskAnalytics
    open_lines: OpenLineAnalytics


def _parse_bitrix_date(value: str | None) -> datetime | None:
    if not value:
        return None
    for fmt in ("%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(value.replace("+03:00", "+0300"), fmt)
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def _seconds_between(start: datetime | None, end: datetime | None) -> float | None:
    if start and end:
        return (end - start).total_seconds()
    return None


class AnalyticsService:
    def __init__(self, client: Bitrix24Client) -> None:
        self._client = client

    async def build_report(
        self,
        user_id: int,
        date_from: datetime | None = None,
        date_to: datetime | None = None,
    ) -> UserReport:
        user_info = await self._client.get_user_info(user_id)
        user_name = _format_user_name(user_info)

        raw_tasks = await self._client.get_user_tasks(user_id, date_from, date_to)
        task_analytics = self._analyze_tasks(raw_tasks)

        raw_sessions = await self._client.get_openline_sessions(
            user_id, date_from, date_to
        )
        openline_analytics = self._analyze_openlines(raw_sessions)

        return UserReport(
            user_id=user_id,
            user_name=user_name,
            period_from=date_from,
            period_to=date_to,
            generated_at=datetime.now(),
            tasks=task_analytics,
            open_lines=openline_analytics,
        )

    def _analyze_tasks(self, raw_tasks: list[dict[str, Any]]) -> TaskAnalytics:
        analytics = TaskAnalytics()
        analytics.tasks = raw_tasks
        analytics.total = len(raw_tasks)

        for task in raw_tasks:
            status = int(task.get("status", task.get("STATUS", 0)))
            status_name = TASK_STATUS_NAMES.get(status, f"Статус {status}")
            analytics.by_status[status_name] = analytics.by_status.get(status_name, 0) + 1

            stage = task.get("stageId", task.get("STAGE_ID", "—"))
            analytics.by_stage[str(stage)] = analytics.by_stage.get(str(stage), 0) + 1

            if status in CLOSED_TASK_STATUSES:
                analytics.closed += 1
            elif status in ACTIVE_TASK_STATUSES:
                analytics.in_progress += 1

        return analytics

    def _analyze_openlines(self, raw_sessions: list[dict[str, Any]]) -> OpenLineAnalytics:
        analytics = OpenLineAnalytics()
        analytics.sessions = raw_sessions
        analytics.total_sessions = len(raw_sessions)

        resolution_times: list[float] = []
        first_response_times: list[float] = []

        for session in raw_sessions:
            status = session.get("STATUS", session.get("status", ""))
            is_closed = str(status).upper() in {"CLOSE", "CLOSED", "5", "1"} or session.get(
                "DATE_CLOSE", session.get("dateClose")
            )

            if is_closed:
                analytics.closed_sessions += 1
            else:
                analytics.open_sessions += 1

            date_create = _parse_bitrix_date(
                session.get("DATE_CREATE", session.get("dateCreate", session.get("CREATED")))
            )
            date_close = _parse_bitrix_date(
                session.get("DATE_CLOSE", session.get("dateClose", session.get("END_TIME")))
            )
            date_operator = _parse_bitrix_date(
                session.get("DATE_OPERATOR", session.get("dateOperatorAnswer"))
            )

            resolution = _seconds_between(date_create, date_close)
            if resolution is not None and resolution >= 0:
                resolution_times.append(resolution)

            first_response = _seconds_between(date_create, date_operator)
            if first_response is not None and first_response >= 0:
                first_response_times.append(first_response)

        if resolution_times:
            analytics.avg_resolution_seconds = sum(resolution_times) / len(resolution_times)
        if first_response_times:
            analytics.avg_first_response_seconds = sum(first_response_times) / len(
                first_response_times
            )

        return analytics


def _format_user_name(user_info: dict[str, Any]) -> str:
    if not user_info:
        return "Неизвестный пользователь"
    parts = [
        user_info.get("LAST_NAME", ""),
        user_info.get("NAME", ""),
        user_info.get("SECOND_NAME", ""),
    ]
    name = " ".join(p for p in parts if p).strip()
    return name or user_info.get("EMAIL", "Пользователь")


def parse_period(text: str) -> tuple[datetime | None, datetime | None]:
    """Парсинг периода из текста: 'сегодня', 'неделя', 'месяц', '2024-01-01 2024-01-31'."""
    text = text.strip().lower()
    now = datetime.now()

    if text in ("сегодня", "today"):
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        return start, now

    if text in ("неделя", "week", "7 дней", "7д"):
        return now - timedelta(days=7), now

    if text in ("месяц", "month", "30 дней", "30д"):
        return now - timedelta(days=30), now

    if text in ("квартал", "quarter", "90 дней"):
        return now - timedelta(days=90), now

    parts = text.replace("—", "-").split()
    if len(parts) == 2:
        try:
            d_from = datetime.strptime(parts[0], "%Y-%m-%d")
            d_to = datetime.strptime(parts[1], "%Y-%m-%d")
            d_to = d_to.replace(hour=23, minute=59, second=59)
            return d_from, d_to
        except ValueError:
            pass

    return None, None
