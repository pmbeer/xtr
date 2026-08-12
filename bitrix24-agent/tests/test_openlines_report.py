from bitrix24_agent.openlines_report import build_openlines_report
from bitrix24_agent.period import parse_period


class FakeClient:
    def __init__(self, items):
        self._items = items

    def call_list(self, method, filter_=None, select=None, order=None, extra_params=None):
        assert method == "crm.activity.list"
        assert filter_["PROVIDER_ID"] == "IMOPENLINES_SESSION"
        yield from self._items


def test_build_openlines_report_computes_counts_and_avg_duration():
    items = [
        {
            "ID": "1",
            "SUBJECT": "Обращение 1",
            "COMPLETED": "Y",
            "START_TIME": "2026-02-01T10:00:00+03:00",
            "END_TIME": "2026-02-01T10:30:00+03:00",
        },
        {
            "ID": "2",
            "SUBJECT": "Обращение 2",
            "COMPLETED": "Y",
            "START_TIME": "2026-02-01T11:00:00+03:00",
            "END_TIME": "2026-02-01T11:10:00+03:00",
        },
        {
            "ID": "3",
            "SUBJECT": "Обращение 3 (в работе)",
            "COMPLETED": "N",
            "START_TIME": "2026-02-01T12:00:00+03:00",
            "END_TIME": None,
        },
    ]
    client = FakeClient(items)
    period = parse_period("2026-02-01:2026-02-28", tz_offset="+03:00")
    report = build_openlines_report(client, user_id=7, period=period)

    assert report.total_count == 3
    assert report.closed_count == 2
    assert report.open_count == 1
    assert report.avg_resolution_minutes == 20.0  # (30 + 10) / 2


def test_build_openlines_report_empty():
    client = FakeClient([])
    period = parse_period("2026-02-01:2026-02-28", tz_offset="+03:00")
    report = build_openlines_report(client, user_id=7, period=period)

    assert report.total_count == 0
    assert report.avg_resolution_minutes is None
