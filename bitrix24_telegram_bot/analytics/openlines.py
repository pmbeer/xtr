"""Аналитика по обращениям открытых линий.

Диалоги открытых линий, связанные с CRM, создают дела (активности)
с провайдером IMOPENLINES_SESSION — их можно получить через
crm.activity.list и посчитать статистику оператора.
"""

import logging
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

from bitrix import Bitrix24Client, Bitrix24Error

from .periods import Period

logger = logging.getLogger(__name__)

PROVIDER_ID = "IMOPENLINES_SESSION"

SELECT_FIELDS = [
    "ID",
    "SUBJECT",
    "CREATED",
    "LAST_UPDATED",
    "END_TIME",
    "START_TIME",
    "COMPLETED",
    "RESPONSIBLE_ID",
]


@dataclass
class SessionRow:
    session_id: int
    subject: str
    created: datetime | None
    finished: datetime | None
    completed: bool

    @property
    def resolution_seconds(self) -> float | None:
        if self.completed and self.created and self.finished:
            seconds = (self.finished - self.created).total_seconds()
            return seconds if seconds >= 0 else None
        return None


@dataclass
class OpenLinesStats:
    period: Period
    sessions: list[SessionRow] = field(default_factory=list)
    error: str | None = None

    @property
    def total_count(self) -> int:
        return len(self.sessions)

    @property
    def handled_count(self) -> int:
        return sum(1 for session in self.sessions if session.completed)

    @property
    def open_count(self) -> int:
        return sum(1 for session in self.sessions if not session.completed)

    @property
    def avg_resolution_seconds(self) -> float | None:
        durations = [
            session.resolution_seconds
            for session in self.sessions
            if session.resolution_seconds is not None
        ]
        if not durations:
            return None
        return sum(durations) / len(durations)


def _parse_dt(value: Any) -> datetime | None:
    if not value or not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


async def collect_openlines_stats(
    client: Bitrix24Client, user_id: int, period: Period
) -> OpenLinesStats:
    stats = OpenLinesStats(period=period)

    try:
        items = await client.call_list(
            "crm.activity.list",
            {
                "filter": {
                    "PROVIDER_ID": PROVIDER_ID,
                    "RESPONSIBLE_ID": user_id,
                    ">=CREATED": period.date_from.isoformat(),
                    "<=CREATED": period.date_to.isoformat(),
                },
                "select": SELECT_FIELDS,
                "order": {"CREATED": "DESC"},
            },
        )
    except Bitrix24Error as exc:
        logger.exception("Ошибка получения обращений открытых линий")
        stats.error = str(exc)
        return stats

    for item in items:
        completed = str(item.get("COMPLETED", "N")).upper() == "Y"
        finished = _parse_dt(item.get("END_TIME")) or _parse_dt(item.get("LAST_UPDATED"))
        stats.sessions.append(
            SessionRow(
                session_id=int(item.get("ID") or 0),
                subject=str(item.get("SUBJECT") or "Обращение"),
                created=_parse_dt(item.get("CREATED")),
                finished=finished if completed else None,
                completed=completed,
            )
        )
    return stats
