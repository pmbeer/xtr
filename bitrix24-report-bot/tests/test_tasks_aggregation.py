from __future__ import annotations

from datetime import datetime, timedelta

import pytest

from bot.bitrix.tasks import fetch_task_stats


class FakeClient:
    """Заглушка BitrixClient для тестирования агрегации без сети."""

    def __init__(self, active, closed, created, stages=None):
        self._active = active
        self._closed = closed
        self._created = created
        self._stages = stages or {}

    async def collect_all(self, method, *, filter_=None, **kwargs):
        filter_ = filter_ or {}
        real_status = filter_.get("REAL_STATUS")
        if isinstance(real_status, (list, tuple)):
            return self._active
        if real_status == 5:
            return self._closed
        return self._created

    async def call(self, method, params):
        group_id = params.get("entityId")
        return {"result": self._stages.get(group_id, {})}


def _iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%S+03:00")


@pytest.mark.asyncio
async def test_fetch_task_stats_aggregates_correctly(tz):
    now = datetime(2026, 8, 12, 12, 0, tzinfo=tz)
    created_5_days_ago = now - timedelta(days=5)
    closed_2_days_ago = now - timedelta(days=2)
    deadline_in_past = now - timedelta(days=1)
    deadline_in_future = now + timedelta(days=3)

    active_raw = [
        {
            "id": "1",
            "title": "Просроченная задача",
            "status": "3",
            "priority": "2",
            "createdDate": _iso(created_5_days_ago),
            "deadline": _iso(deadline_in_past),
            "responsibleId": "1",
            "groupId": "10",
            "stageId": "100",
        },
        {
            "id": "2",
            "title": "Задача в работе",
            "status": "2",
            "priority": "1",
            "createdDate": _iso(created_5_days_ago),
            "deadline": _iso(deadline_in_future),
            "responsibleId": "1",
            "groupId": "10",
            "stageId": "101",
        },
    ]
    closed_raw = [
        {
            "id": "3",
            "title": "Закрытая задача",
            "status": "5",
            "priority": "1",
            "createdDate": _iso(created_5_days_ago),
            "closedDate": _iso(closed_2_days_ago),
            "responsibleId": "1",
            "groupId": "10",
            "stageId": "102",
        }
    ]
    created_raw = [{"id": "1"}, {"id": "2"}, {"id": "3"}, {"id": "4"}]

    stages = {
        10: {
            "100": {"TITLE": "В процессе"},
            "101": {"TITLE": "Новые"},
            "102": {"TITLE": "Готово"},
        }
    }

    client = FakeClient(active_raw, closed_raw, created_raw, stages)
    stats = await fetch_task_stats(client, bitrix_user_id=1, date_from=now - timedelta(days=7), date_to=now)

    assert stats.active_count == 2
    assert stats.closed_count == 1
    assert stats.created_count == 4
    assert stats.overdue_count == 1
    assert stats.avg_completion_hours == pytest.approx(72.0, rel=0.01)

    assert stats.by_stage["В процессе"] == 1
    assert stats.by_stage["Новые"] == 1

    overdue_task = next(t for t in stats.active_tasks if t.id == 1)
    assert overdue_task.is_overdue is True

    not_overdue_task = next(t for t in stats.active_tasks if t.id == 2)
    assert not_overdue_task.is_overdue is False
