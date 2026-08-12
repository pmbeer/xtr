from datetime import datetime
from zoneinfo import ZoneInfo

from bitrix24_agent.analytics import AnalyticsService
from bitrix24_agent.bitrix import BitrixAPIError
from bitrix24_agent.periods import ReportPeriod


class FakeClient:
    async def get_current_user_id(self) -> int:
        return 42

    async def list_tasks(self, task_filter: dict, select: list[str]) -> list[dict]:
        if task_filter.get("REAL_STATUS") == 5:
            return [{"id": "1", "title": "Готово", "status": "5"}]
        return [
            {
                "id": "2",
                "title": "Срочно",
                "status": "3",
                "groupId": "7",
                "stageId": "11",
                "deadline": "2026-08-11T12:00:00+03:00",
            },
            {"id": "3", "title": "Позже", "status": "6", "groupId": "0", "stageId": "20"},
            {"id": "4", "title": "Отклонено", "status": "7"},
        ]

    async def get_stages(self, entity_id: int) -> dict[str, str]:
        return {"11": "В работе"} if entity_id == 7 else {"20": "Бэклог"}

    async def call(self, method: str, params: dict) -> dict:
        assert method == "imopenlines.v2.Stat.get"
        assert params["operatorId"] == 42
        return {
            "data": {
                "totalSessions": 8,
                "closedSessions": 7,
                "avgWaitAnswer": 45,
                "avgSessionDuration": 360,
            }
        }


class NoOpenLinesClient(FakeClient):
    async def call(self, method: str, params: dict) -> dict:
        raise BitrixAPIError(method, "B24_TARIFF_RESTRICTION", "Нет доступа")


def period() -> ReportPeriod:
    timezone = ZoneInfo("Europe/Moscow")
    return ReportPeriod(
        datetime(2026, 8, 1, tzinfo=timezone),
        datetime(2026, 8, 12, 23, 59, tzinfo=timezone),
        "тест",
    )


async def test_collects_task_and_open_line_analytics() -> None:
    result = await AnalyticsService(FakeClient(), None, "imopenlines.v2.Stat.get").collect(
        period()
    )
    assert result.user_id == 42
    assert len(result.tasks.completed) == 1
    assert len(result.tasks.active) == 2
    assert result.tasks.overdue == 1
    assert result.tasks.statuses == {"Выполняется": 1, "Отложена": 1}
    assert result.tasks.stages == {"В работе": 1, "Бэклог": 1}
    assert result.open_lines.processed == 8
    assert result.open_lines.average_resolution_seconds == 360


async def test_open_line_error_does_not_break_task_report() -> None:
    result = await AnalyticsService(
        NoOpenLinesClient(), 42, "imopenlines.v2.Stat.get"
    ).collect(period())
    assert len(result.tasks.completed) == 1
    assert result.open_lines.processed is None
    assert "B24_TARIFF_RESTRICTION" in (result.open_lines.error or "")
