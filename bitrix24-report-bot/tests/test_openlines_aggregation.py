from __future__ import annotations

from datetime import datetime, timedelta

import pytest

from bot.bitrix.client import BitrixApiError
from bot.bitrix.openlines import fetch_openlines_stats, format_duration


class FakeClient:
    def __init__(self, sessions=None, error: BitrixApiError | None = None):
        self._sessions = sessions or []
        self._error = error

    async def collect_all(self, method, **kwargs):
        if self._error is not None:
            raise self._error
        return self._sessions


def _iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%S+03:00")


@pytest.mark.asyncio
async def test_fetch_openlines_stats_aggregates(tz):
    now = datetime(2026, 8, 12, 12, 0, tzinfo=tz)
    created = now - timedelta(hours=3)
    ended = now - timedelta(hours=2)  # длительность 1 час = 3600 сек

    sessions_raw = [
        {
            "ID": "1",
            "SUBJECT": "Обращение 1",
            "CREATED": _iso(created),
            "START_TIME": _iso(created),
            "END_TIME": _iso(ended),
            "COMPLETED": "Y",
            "ASSOCIATED_ENTITY_ID": "555",
        },
        {
            "ID": "2",
            "SUBJECT": "Обращение 2 (не закрыто)",
            "CREATED": _iso(created),
            "START_TIME": _iso(created),
            "END_TIME": None,
            "COMPLETED": "N",
            "ASSOCIATED_ENTITY_ID": "556",
        },
    ]

    client = FakeClient(sessions_raw)
    stats = await fetch_openlines_stats(client, bitrix_user_id=1, date_from=now - timedelta(days=1), date_to=now)

    assert stats.error is None
    assert stats.total == 2
    assert stats.completed == 1
    assert stats.in_progress == 1
    assert stats.avg_resolution_seconds == pytest.approx(3600.0, rel=0.01)


@pytest.mark.asyncio
async def test_fetch_openlines_stats_handles_api_error(tz):
    now = datetime(2026, 8, 12, 12, 0, tzinfo=tz)
    error = BitrixApiError("crm.activity.list", "ACCESS_DENIED", "no rights")
    client = FakeClient(error=error)

    stats = await fetch_openlines_stats(client, bitrix_user_id=1, date_from=now - timedelta(days=1), date_to=now)

    assert stats.error is not None
    assert stats.total == 0
    assert stats.sessions == []


def test_format_duration():
    assert format_duration(45) == "45 сек"
    assert format_duration(125) == "2 мин 5 сек"
    assert format_duration(3725) == "1 ч 2 мин"
