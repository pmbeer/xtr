"""Статистика по обращениям в Открытых линиях на основе дел (activities) CRM.

Официального REST-метода, который отдаёт готовую агрегированную статистику по
операторам Открытых линий, на момент написания бота нет. Зато при включённой
интеграции "Открытые линии -> CRM" (это поведение по умолчанию: любой диалог,
привязанный к лиду/сделке/контакту/компании) Битрикс24 создаёт для каждой
сессии диалога отдельное "дело" (activity) в CRM с
``PROVIDER_ID = IMOPENLINES_SESSION``. Именно по этим делам собирается
статистика: количество обращений, сколько из них закрыто и среднее время
обработки (от начала до завершения сессии).

Если у портала нет интеграции с CRM или недостаточно прав, метод вернёт
пустой список — это не ошибка, а особенность Открытых линий Битрикс24.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any

from dateutil.parser import isoparse

from .client import BitrixApiError, BitrixClient
from .constants import OPENLINES_ACTIVITY_PROVIDER_ID

OPENLINES_SELECT_FIELDS = [
    "ID",
    "SUBJECT",
    "RESPONSIBLE_ID",
    "CREATED",
    "LAST_UPDATED",
    "START_TIME",
    "END_TIME",
    "COMPLETED",
    "ASSOCIATED_ENTITY_ID",
]


def _parse_dt(value: Any) -> datetime | None:
    if not value:
        return None
    try:
        return isoparse(str(value))
    except (ValueError, TypeError):
        return None


@dataclass
class OpenLineSession:
    id: int
    subject: str
    created: datetime | None
    start_time: datetime | None
    end_time: datetime | None
    completed: bool
    associated_entity_id: int | None

    @property
    def duration_seconds(self) -> float | None:
        start = self.start_time or self.created
        if start is None or self.end_time is None:
            return None
        delta = (self.end_time - start).total_seconds()
        return delta if delta >= 0 else None


@dataclass
class OpenLinesStats:
    total: int
    completed: int
    in_progress: int
    avg_resolution_seconds: float | None
    sessions: list[OpenLineSession]
    error: str | None = None

    @property
    def avg_resolution_human(self) -> str:
        if self.avg_resolution_seconds is None:
            return "—"
        return format_duration(self.avg_resolution_seconds)


def format_duration(seconds: float) -> str:
    seconds = int(round(seconds))
    hours, remainder = divmod(seconds, 3600)
    minutes, secs = divmod(remainder, 60)
    if hours:
        return f"{hours} ч {minutes} мин"
    if minutes:
        return f"{minutes} мин {secs} сек"
    return f"{secs} сек"


def _to_session(raw: dict[str, Any]) -> OpenLineSession:
    associated_raw = raw.get("associatedEntityId") or raw.get("ASSOCIATED_ENTITY_ID")
    try:
        associated_entity_id = int(associated_raw) if associated_raw else None
    except (TypeError, ValueError):
        associated_entity_id = None

    return OpenLineSession(
        id=int(raw.get("id") or raw.get("ID") or 0),
        subject=str(raw.get("subject") or raw.get("SUBJECT") or "Обращение"),
        created=_parse_dt(raw.get("created") or raw.get("CREATED")),
        start_time=_parse_dt(raw.get("startTime") or raw.get("START_TIME")),
        end_time=_parse_dt(raw.get("endTime") or raw.get("END_TIME")),
        completed=str(raw.get("completed") or raw.get("COMPLETED") or "N").upper() == "Y",
        associated_entity_id=associated_entity_id,
    )


async def fetch_openlines_stats(
    client: BitrixClient,
    bitrix_user_id: int,
    date_from: datetime,
    date_to: datetime,
) -> OpenLinesStats:
    date_from_str = date_from.strftime("%Y-%m-%dT%H:%M:%S")
    date_to_str = date_to.strftime("%Y-%m-%dT%H:%M:%S")

    try:
        raw_sessions = await client.collect_all(
            "crm.activity.list",
            select=OPENLINES_SELECT_FIELDS,
            filter_={
                "PROVIDER_ID": OPENLINES_ACTIVITY_PROVIDER_ID,
                "RESPONSIBLE_ID": bitrix_user_id,
                ">=CREATED": date_from_str,
                "<=CREATED": date_to_str,
            },
            order={"CREATED": "DESC"},
        )
    except BitrixApiError as exc:
        return OpenLinesStats(
            total=0,
            completed=0,
            in_progress=0,
            avg_resolution_seconds=None,
            sessions=[],
            error=(
                "Не удалось получить статистику Открытых линий из Битрикс24 "
                f"({exc.code}: {exc.description}). Проверьте, что у вебхука есть "
                "права на CRM (scope crm) и что у портала подключена CRM."
            ),
        )

    sessions = [_to_session(item) for item in raw_sessions]
    completed_sessions = [s for s in sessions if s.completed]
    durations = [s.duration_seconds for s in completed_sessions if s.duration_seconds is not None]
    avg_resolution = sum(durations) / len(durations) if durations else None

    return OpenLinesStats(
        total=len(sessions),
        completed=len(completed_sessions),
        in_progress=len(sessions) - len(completed_sessions),
        avg_resolution_seconds=avg_resolution,
        sessions=sessions,
    )
