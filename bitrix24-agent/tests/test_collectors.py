"""Тесты сборщиков метрик на фейковом портале."""

from __future__ import annotations

import unittest
from datetime import date, datetime
from typing import Any
from zoneinfo import ZoneInfo

from bitrix24_agent.client import Bitrix24Client
from bitrix24_agent.collectors import collect_calls, collect_openlines, collect_tasks, resolve_user
from bitrix24_agent.collectors.base import OK, PARTIAL, UNAVAILABLE
from bitrix24_agent.errors import Bitrix24Error
from bitrix24_agent.period import parse_period

from .fakes import FakePortal

TZ = ZoneInfo("Europe/Moscow")
TODAY = date(2026, 6, 17)
NOW = datetime(2026, 6, 17, 12, 0, tzinfo=TZ)
PERIOD = parse_period("2026-06-01..2026-06-30", TZ, today=TODAY)

DAY = 86400


def make_task(
    task_id: int,
    status: int,
    created: str,
    closed: str | None = None,
    deadline: str | None = None,
    group_id: int = 0,
    stage_id: int = 0,
    time_spent: int = 0,
) -> dict[str, Any]:
    """Задача в том виде, в каком её отдаёт `tasks.task.list` (camelCase)."""
    return {
        "id": str(task_id),
        "title": f"Задача {task_id}",
        "status": str(status),
        "createdDate": created,
        "closedDate": closed,
        "deadline": deadline,
        "responsibleId": "1",
        "createdBy": "1",
        "groupId": str(group_id),
        "stageId": str(stage_id),
        "timeSpentInLogs": str(time_spent),
    }


CLOSED_TASKS = [
    make_task(1, 5, "2026-06-01T10:00:00+03:00", "2026-06-02T10:00:00+03:00", time_spent=3600),
    make_task(2, 5, "2026-06-03T10:00:00+03:00", "2026-06-05T10:00:00+03:00", time_spent=7200),
    make_task(
        3,
        5,
        "2026-06-04T10:00:00+03:00",
        "2026-06-07T10:00:00+03:00",
        deadline="2026-06-06T10:00:00+03:00",
    ),
]
OPEN_TASKS = [
    make_task(10, 2, "2026-06-10T10:00:00+03:00", deadline="2026-06-16T10:00:00+03:00", stage_id=10),
    make_task(11, 2, "2026-05-01T10:00:00+03:00", stage_id=10, group_id=5),
    make_task(12, 3, "2026-06-12T10:00:00+03:00", deadline="2026-06-30T10:00:00+03:00", stage_id=11),
    make_task(13, 6, "2026-06-13T10:00:00+03:00", deadline="2026-06-25T10:00:00+03:00"),
]

STAGES = {
    0: [
        {"ID": "10", "TITLE": "В работе", "SORT": 100, "SYSTEM_TYPE": "WORK"},
        {"ID": "11", "TITLE": "На проверке", "SORT": 200, "SYSTEM_TYPE": "REVIEW"},
    ],
    5: [{"ID": "10", "TITLE": "В работе", "SORT": 100, "SYSTEM_TYPE": "WORK"}],
}


def make_session(
    session_id: int,
    *,
    wait_answer: int,
    wait_close: int,
    vote: str = "none",
    source: str = "livechat",
    status: str = "closed",
    created: str = "2026-06-10T14:00:00+03:00",
    kpi: bool = True,
) -> dict[str, Any]:
    return {
        "id": session_id,
        "configId": 3,
        "source": source,
        "operatorId": 1,
        "status": status,
        "closeReason": "operator",
        "dateCreate": created,
        "dateClose": "2026-06-10T14:30:00+03:00",
        "dateFirstAnswer": "2026-06-10T14:01:00+03:00",
        "waitAnswer": wait_answer,
        "waitClose": wait_close,
        "vote": vote,
        "kpiFirstAnswer": kpi,
        "messageCount": 10,
        "crmEntityType": "deal",
    }


SESSIONS = [
    make_session(1, wait_answer=30, wait_close=600, vote="like"),
    make_session(2, wait_answer=60, wait_close=1200, vote="like", source="whatsapp"),
    make_session(3, wait_answer=90, wait_close=1800, vote="dislike", kpi=False),
    make_session(4, wait_answer=120, wait_close=2400, status="answered", created="2026-06-11T09:00:00+03:00"),
]


class TasksCollectorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.portal = FakePortal(
            tasks=CLOSED_TASKS + OPEN_TASKS,
            stages=STAGES,
            groups=[{"ID": "5", "NAME": "Проект Альфа"}],
        )
        self.client = Bitrix24Client(self.portal)

    def collect(self):
        return collect_tasks(self.client, user_id=1, period=PERIOD, tz=TZ, now=NOW)

    def test_counts_closed_and_open_tasks(self) -> None:
        section = self.collect()
        self.assertEqual(section.closed_count, 3)
        self.assertEqual(section.open_count, 4)
        self.assertEqual(section.in_progress_count, 3)
        self.assertEqual(section.status, OK)

    def test_open_tasks_are_grouped_by_status(self) -> None:
        section = self.collect()
        self.assertEqual(section.open_by_status["Ждёт выполнения"], 2)
        self.assertEqual(section.open_by_status["Выполняется"], 1)
        self.assertEqual(section.open_by_status["Отложена"], 1)

    def test_resolution_time_uses_creation_and_closing_dates(self) -> None:
        section = self.collect()
        self.assertEqual(section.resolution.count, 3)
        self.assertEqual(section.resolution.median, 2 * DAY)
        self.assertEqual(section.resolution.minimum, 1 * DAY)
        self.assertEqual(section.resolution.maximum, 3 * DAY)

    def test_deadline_violations_are_counted(self) -> None:
        section = self.collect()
        self.assertEqual(section.closed_late, 1)
        self.assertEqual(section.open_overdue, 1)
        self.assertEqual(section.open_without_deadline, 1)

    def test_stale_tasks_are_detected(self) -> None:
        section = self.collect()
        self.assertEqual(section.open_stale_count, 1)
        self.assertEqual(section.longest_open[0]["id"], 11)

    def test_stage_titles_come_from_kanban(self) -> None:
        section = self.collect()
        titles = {bucket.title: bucket.count for bucket in section.stages}
        self.assertEqual(titles["В работе"], 2)
        self.assertEqual(titles["На проверке"], 1)

    def test_group_names_are_resolved(self) -> None:
        section = self.collect()
        titles = {bucket.title for bucket in section.groups}
        self.assertIn("Проект Альфа", titles)
        self.assertIn("Без проекта", titles)

    def test_time_spent_is_summed_for_closed_tasks(self) -> None:
        self.assertEqual(self.collect().time_spent_seconds, 10800)

    def test_stage_lookup_failure_does_not_break_the_section(self) -> None:
        self.portal.errors["task.stages.get"] = Bitrix24Error("task.stages.get", "ACCESS_DENIED")
        section = self.collect()
        self.assertEqual(section.closed_count, 3)
        self.assertTrue(all(bucket.title.startswith("Стадия #") for bucket in section.stages))

    def test_partial_status_when_export_limit_reached(self) -> None:
        section = collect_tasks(
            self.client, user_id=1, period=PERIOD, tz=TZ, now=NOW, max_tasks=2
        )
        self.assertEqual(section.status, PARTIAL)
        self.assertEqual(section.closed_count, 3)
        self.assertEqual(section.closed_analyzed, 2)


class OpenLinesCollectorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.portal = FakePortal(sessions=SESSIONS)
        self.client = Bitrix24Client(self.portal)

    def collect(self):
        return collect_openlines(self.client, user_id=1, period=PERIOD, tz=TZ)

    def test_counts_handled_and_closed_sessions(self) -> None:
        section = self.collect()
        self.assertEqual(section.handled_count, 4)
        self.assertEqual(section.closed_count, 3)
        self.assertEqual(section.source_method, "imopenlines.v2.Session.list")

    def test_resolution_and_response_times(self) -> None:
        section = self.collect()
        self.assertEqual(section.resolution.median, 1500)
        self.assertEqual(section.first_response.median, 75)
        self.assertEqual(section.first_response.minimum, 30)

    def test_customer_satisfaction(self) -> None:
        section = self.collect()
        self.assertEqual(section.likes, 2)
        self.assertEqual(section.dislikes, 1)
        self.assertEqual(section.satisfaction_rate, 66.7)

    def test_sla_and_channel_breakdown(self) -> None:
        section = self.collect()
        self.assertEqual(section.kpi_ok, 3)
        self.assertEqual(section.kpi_failed, 1)
        self.assertEqual(section.by_source["livechat"], 3)
        self.assertEqual(section.by_source["whatsapp"], 1)
        self.assertEqual(section.by_hour[14], 3)
        self.assertEqual(section.by_hour[9], 1)

    def test_only_my_sessions_are_counted(self) -> None:
        foreign = dict(SESSIONS[0], id=99, operatorId=42)
        self.portal.sessions = SESSIONS + [foreign]
        self.assertEqual(self.collect().handled_count, 4)

    def test_falls_back_to_crm_activities_when_method_is_not_released(self) -> None:
        portal = FakePortal(
            errors={
                "imopenlines.v2.Session.list": Bitrix24Error(
                    "imopenlines.v2.Session.list", "METHOD_NOT_YET_AVAILABLE"
                )
            },
            extra={
                "crm.activity.list": lambda params: {
                    "result": [
                        {
                            "ID": "1",
                            "CREATED": "2026-06-10T14:00:00+03:00",
                            "END_TIME": "2026-06-10T14:20:00+03:00",
                        }
                    ],
                    "total": 7,
                }
            },
        )
        section = collect_openlines(Bitrix24Client(portal), user_id=1, period=PERIOD, tz=TZ)

        self.assertEqual(section.status, PARTIAL)
        self.assertEqual(section.handled_count, 7)
        self.assertEqual(section.resolution.median, 1200)
        self.assertTrue(any("imopenlines 26.700.0" in note for note in section.notes))

    def test_section_is_unavailable_when_no_source_works(self) -> None:
        portal = FakePortal(
            errors={
                "imopenlines.v2.Session.list": Bitrix24Error(
                    "imopenlines.v2.Session.list", "B24_TARIFF_RESTRICTION"
                ),
                "crm.activity.list": Bitrix24Error("crm.activity.list", "ACCESS_DENIED"),
            }
        )
        section = collect_openlines(Bitrix24Client(portal), user_id=1, period=PERIOD, tz=TZ)
        self.assertEqual(section.status, UNAVAILABLE)


class CallsCollectorTests(unittest.TestCase):
    def test_missing_telephony_is_not_an_error(self) -> None:
        portal = FakePortal()
        section = collect_calls(Bitrix24Client(portal), user_id=1, period=PERIOD)
        self.assertEqual(section.status, UNAVAILABLE)
        self.assertIn("Телефония недоступна", section.notes[0])

    def test_calls_are_aggregated(self) -> None:
        portal = FakePortal(
            extra={
                "voximplant.statistic.get": lambda params: {
                    "result": [
                        {"CALL_TYPE": "1", "CALL_DURATION": "60", "CALL_FAILED_CODE": "200"},
                        {"CALL_TYPE": "2", "CALL_DURATION": "120", "CALL_FAILED_CODE": "200"},
                        {"CALL_TYPE": "2", "CALL_DURATION": "0", "CALL_FAILED_CODE": "486"},
                    ],
                    "total": 3,
                }
            }
        )
        section = collect_calls(Bitrix24Client(portal), user_id=1, period=PERIOD)

        self.assertEqual(section.total, 3)
        self.assertEqual(section.succeeded, 2)
        self.assertEqual(section.missed, 1)
        self.assertEqual(section.total_duration_seconds, 180)
        self.assertEqual(section.by_type["Входящие"], 2)


class IdentityTests(unittest.TestCase):
    def test_current_user_name_is_assembled(self) -> None:
        portal = FakePortal(
            current_user={"ID": "7", "NAME": "Иван", "LAST_NAME": "Петров", "WORK_POSITION": "Менеджер"}
        )
        user = resolve_user(Bitrix24Client(portal))
        self.assertEqual(user.id, 7)
        self.assertEqual(user.name, "Петров Иван")
        self.assertEqual(user.position, "Менеджер")


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
