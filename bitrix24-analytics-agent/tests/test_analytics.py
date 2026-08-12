from __future__ import annotations

import json
from pathlib import Path

import pytest

from bitrix_agent.analytics.openlines import OpenLinesAnalytics, _parse_session_item
from bitrix_agent.analytics.report import ActivityReport
from bitrix_agent.analytics.tasks import TasksAnalytics, _parse_dt, _task_fields
from bitrix_agent.client import BitrixAPIError, BitrixClient
from bitrix_agent.storage import AnalyticsStore


class FakeResponse:
    def __init__(self, payload: dict, status_code: int = 200):
        self._payload = payload
        self.status_code = status_code

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            raise RuntimeError(f"HTTP {self.status_code}")

    def json(self) -> dict:
        return self._payload


class FakeSession:
    def __init__(self, routes: dict[str, dict | list]):
        self.routes = routes
        self.calls: list[tuple[str, dict]] = []

    def post(self, url: str, json=None, timeout=None):
        method = url.rstrip("/").split("/")[-1]
        self.calls.append((method, json or {}))
        payload = self.routes.get(method)
        if payload is None:
            return FakeResponse({"error": "ERROR_METHOD_NOT_FOUND", "error_description": method})
        if isinstance(payload, list):
            # queue of responses for pagination
            if not payload:
                return FakeResponse({"result": []})
            item = payload.pop(0)
            return FakeResponse(item)
        return FakeResponse(payload)


def test_parse_dt_iso_with_colon_offset():
    dt = _parse_dt("2026-08-01T12:30:00+03:00")
    assert dt is not None
    assert dt.hour == 12


def test_task_fields_camel_case():
    fields = _task_fields(
        {
            "id": "10",
            "title": "Demo",
            "status": 3,
            "responsibleId": 5,
            "createdDate": "2026-08-01T10:00:00",
            "closedDate": None,
            "stageId": 42,
        }
    )
    assert fields["ID"] == "10"
    assert fields["TITLE"] == "Demo"
    assert fields["REAL_STATUS"] == 3
    assert fields["STAGE_ID"] == 42


def test_client_raises_method_not_found():
    client = BitrixClient("https://example.bitrix24.ru/rest/1/token/")
    client.session = FakeSession({})
    with pytest.raises(BitrixAPIError) as exc:
        client.call("unknown.method")
    assert exc.value.error == "ERROR_METHOD_NOT_FOUND"


def test_tasks_report_with_fake_api(tmp_path: Path):
    closed_page = {
        "result": {
            "tasks": [
                {
                    "id": "1",
                    "title": "Done task",
                    "status": 5,
                    "responsibleId": 7,
                    "createdDate": "2026-08-01T10:00:00",
                    "closedDate": "2026-08-02T10:00:00",
                }
            ]
        },
        "total": 1,
    }
    active_page = {
        "result": {
            "tasks": [
                {
                    "id": "2",
                    "title": "Active",
                    "status": 3,
                    "responsibleId": 7,
                    "deadline": "2020-01-01T00:00:00",
                    "stageId": 11,
                },
                {
                    "id": "3",
                    "title": "Waiting",
                    "status": 2,
                    "responsibleId": 7,
                },
            ]
        },
        "total": 2,
    }
    created_page = {"result": {"tasks": []}, "total": 0}

    client = BitrixClient("https://example.bitrix24.ru/rest/1/token/")
    client.session = FakeSession(
        {
            "tasks.task.list": [closed_page, active_page, created_page]
        }
    )

    report = TasksAnalytics(client).build_report(7, days=7)
    assert report.closed_count == 1
    assert report.in_progress_count == 1
    assert report.waiting_count == 1
    assert report.overdue_count == 1
    assert report.avg_close_hours == 24.0


def test_openlines_local_store(tmp_path: Path):
    store = AnalyticsStore(tmp_path / "a.db")
    store.upsert_session(
        {
            "session_id": 101,
            "operator_id": 7,
            "status": "closed",
            "source": "telegram",
            "date_create": "2026-08-10T10:00:00+00:00",
            "date_close": "2026-08-10T10:20:00+00:00",
            "duration_sec": 1200,
            "wait_answer_sec": 30,
            "spam": 0,
        }
    )
    client = BitrixClient("https://example.bitrix24.ru/rest/1/token/")
    client.session = FakeSession(
        {
            "imopenlines.v2.Session.list": {
                "error": "METHOD_NOT_YET_AVAILABLE",
                "error_description": "not yet",
            },
            "imopenlines.session.list": {
                "error": "ERROR_METHOD_NOT_FOUND",
                "error_description": "missing",
            },
            "imopenlines.v2.Stat.get": {
                "error": "METHOD_NOT_YET_AVAILABLE",
                "error_description": "not yet",
            },
            "imopenlines.stat.get": {
                "error": "ERROR_METHOD_NOT_FOUND",
                "error_description": "missing",
            },
        }
    )
    report = OpenLinesAnalytics(client, store).build_report(7, days=30)
    assert report.processed_count == 1
    assert report.closed_count == 1
    assert report.source == "local_store"
    assert report.avg_resolution_sec == 1200
    assert report.avg_resolution_human is not None


def test_ingest_event(tmp_path: Path):
    store = AnalyticsStore(tmp_path / "events.db")
    client = BitrixClient("https://example.bitrix24.ru/rest/1/token/")
    client.session = FakeSession({})
    analytics = OpenLinesAnalytics(client, store)
    analytics.ingest_event(
        "ONSESSIONFINISH",
        {
            "event": "ONSESSIONFINISH",
            "data": {
                "SESSION": {
                    "ID": 55,
                    "OPERATOR_ID": 3,
                    "STATUS": "closed",
                    "SOURCE": "livechat",
                    "DATE_CREATE": "2026-08-11T09:00:00",
                    "DATE_CLOSE": "2026-08-11T09:15:00",
                    "TIME_DIALOG": 900,
                }
            },
        },
    )
    rows = store.sessions_for_operator(3)
    assert len(rows) == 1
    assert rows[0].session_id == 55
    assert rows[0].duration_sec == 900


def test_parse_session_item():
    row = _parse_session_item(
        {"sessionId": 9, "operatorId": 1, "dateCreate": "2026-01-01", "source": "whatsapp"}
    )
    assert row["session_id"] == 9
    assert row["operator_id"] == 1
    assert row["source"] == "whatsapp"


def test_activity_report_text():
    report = ActivityReport(
        generated_at="2026-08-12T12:00:00",
        user_id=1,
        user_name="Иван",
        days=7,
        tasks={
            "closed_count": 2,
            "in_progress_count": 1,
            "waiting_count": 0,
            "deferred_count": 0,
            "overdue_count": 0,
            "created_count": 3,
            "avg_close_hours": 5.5,
            "by_status": {"В работе": 1},
            "by_stage": {},
        },
        openlines={
            "source": "local_store",
            "processed_count": 4,
            "closed_count": 3,
            "open_count": 1,
            "spam_count": 0,
            "avg_resolution_human": "10 мин",
            "avg_wait_answer_sec": 12,
            "notes": ["ok"],
        },
        summary={
            "closed_tasks": 2,
            "active_tasks": 1,
            "openline_sessions": 4,
            "avg_resolution_human": "10 мин",
        },
    )
    text = report.to_text()
    assert "Иван" in text
    assert "Закрыто за период: 2" in text
    assert "Обработано обращений: 4" in text
