from bitrix24_agent.period import parse_period
from bitrix24_agent.tasks_report import build_tasks_report


class FakeClient:
    """Простая замена BitrixClient для тестирования логики отчёта без HTTP."""

    def __init__(self, responses_by_method):
        self._responses = responses_by_method

    def call_list(self, method, filter_=None, select=None, order=None, extra_params=None):
        for item in self._responses.get(method, []):
            yield item


def test_build_tasks_report_groups_by_stage_and_computes_avg_duration():
    tasks_list = [
        {"id": "1", "status": "2", "deadline": None},
        {"id": "2", "status": "3", "deadline": None},
        {"id": "3", "status": "3", "deadline": None},
        {"id": "4", "status": "4", "deadline": None},
    ]
    overdue_list = [{"id": "2"}]
    closed_list = [
        {
            "id": "10",
            "title": "Задача 1",
            "createdDate": "2026-01-01T10:00:00+03:00",
            "closedDate": "2026-01-01T12:00:00+03:00",
        },
        {
            "id": "11",
            "title": "Задача 2",
            "createdDate": "2026-01-02T10:00:00+03:00",
            "closedDate": "2026-01-02T14:00:00+03:00",
        },
    ]

    call_counter = {"n": 0}

    class SequencedFakeClient(FakeClient):
        def call_list(self, method, filter_=None, select=None, order=None, extra_params=None):
            call_counter["n"] += 1
            if method == "tasks.task.list" and filter_ and "REAL_STATUS" in filter_ and isinstance(
                filter_["REAL_STATUS"], list
            ):
                yield from tasks_list
            elif method == "tasks.task.list" and filter_ and filter_.get("STATUS") == -1:
                yield from overdue_list
            elif method == "tasks.task.list" and filter_ and filter_.get("REAL_STATUS") == 5:
                yield from closed_list

    client = SequencedFakeClient({})
    period = parse_period("2026-01-01:2026-01-31", tz_offset="+03:00")
    report = build_tasks_report(client, user_id=42, period=period)

    assert report.stage_counts == {2: 1, 3: 2, 4: 1}
    assert report.in_progress_count == 2
    assert report.open_total_count == 4
    assert report.overdue_count == 1
    assert report.closed_count == 2
    assert report.avg_closing_hours == 3.0  # (2ч + 4ч) / 2
    assert "Выполняется: 2" in report.stage_breakdown()
