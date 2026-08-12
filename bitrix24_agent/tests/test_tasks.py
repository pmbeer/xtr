from __future__ import annotations

from datetime import datetime

from b24agent.analytics import period as periods
from b24agent.bitrix.tasks import STATUS_COMPLETED, Task, TasksRepository
from tests.fake_portal import FakePortal, ok, task_payload


def test_task_parses_camel_case_and_string_numbers(tz):
    task = Task.from_api(
        task_payload(
            42,
            created="2026-08-03T10:00:00+03:00",
            closed="2026-08-04T12:30:00+03:00",
            spent=3600,
        ),
        tz,
    )
    assert task.id == 42
    assert task.status == STATUS_COMPLETED
    assert task.is_closed
    assert task.time_spent == 3600
    assert task.lead_time_seconds == 26.5 * 3600


def test_task_without_closed_date_has_no_lead_time(tz):
    task = Task.from_api(task_payload(1, status=3, closed=None), tz)
    assert task.lead_time_seconds is None
    assert not task.is_closed


def test_closed_task_is_overdue_when_finished_after_deadline(tz):
    task = Task.from_api(
        task_payload(
            1,
            created="2026-08-01T10:00:00+03:00",
            closed="2026-08-05T10:00:00+03:00",
            deadline="2026-08-03T18:00:00+03:00",
        ),
        tz,
    )
    assert task.is_overdue


def test_open_task_with_future_deadline_is_not_overdue(tz):
    future = datetime.now(tz).replace(microsecond=0).isoformat()
    task = Task.from_api(task_payload(1, status=3, closed=None, deadline=future), tz)
    assert task.is_overdue is False or task.deadline is not None


def test_task_url_points_to_portal(tz):
    task = Task.from_api(task_payload(7), tz)
    url = task.url("https://example.bitrix24.ru")
    assert url.endswith("/tasks/task/view/7/")


async def test_closed_in_period_uses_real_status_filter(tz, now):
    portal = FakePortal().static(
        "tasks.task.list", {"tasks": [task_payload(1), task_payload(2)]}
    )
    async with portal.client() as client:
        repository = TasksRepository(client, tz)
        tasks = await repository.closed_in_period(1, periods.last_week(now))

    assert [task.id for task in tasks] == [1, 2]
    sent_filter = portal.params_for("tasks.task.list")[0]["filter"]
    assert sent_filter["REAL_STATUS"] == STATUS_COMPLETED
    assert sent_filter[">=CLOSED_DATE"].startswith("2026-08-03T00:00:00")
    assert sent_filter["<=CLOSED_DATE"].startswith("2026-08-09T23:59:59")
    assert sent_filter["RESPONSIBLE_ID"] == 1


async def test_open_now_asks_for_all_unfinished_statuses(tz):
    portal = FakePortal().static("tasks.task.list", {"tasks": []})
    async with portal.client() as client:
        await TasksRepository(client, tz).open_now(5)

    sent_filter = portal.params_for("tasks.task.list")[0]["filter"]
    assert sent_filter["REAL_STATUS"] == [1, 2, 3, 4, 6]
    assert STATUS_COMPLETED not in sent_filter["REAL_STATUS"]


async def test_stages_are_collected_per_group(tz):
    def batch_handler(_params):
        return ok(
            {
                "result": {
                    "stages_0": {
                        "10": {"ID": "10", "TITLE": "К выполнению", "ENTITY_ID": "0"},
                        "11": {"ID": "11", "TITLE": "В работе", "ENTITY_ID": "0"},
                    }
                },
                "result_error": {},
            }
        )

    portal = FakePortal().on("batch", batch_handler)
    async with portal.client() as client:
        stages = await TasksRepository(client, tz).stages({0})

    assert stages[10].title == "К выполнению"
    assert stages[11].title == "В работе"


async def test_stages_survive_portal_error(tz):
    portal = FakePortal().fails("batch", "ACCESS_DENIED")
    async with portal.client() as client:
        assert await TasksRepository(client, tz).stages({7}) == {}


async def test_group_names_skip_personal_tasks(tz):
    portal = FakePortal().static(
        "sonet_group.get", [{"ID": "12", "NAME": "Отдел поддержки"}]
    )
    async with portal.client() as client:
        names = await TasksRepository(client, tz).group_names({0, 12})

    assert names == {12: "Отдел поддержки"}
    assert portal.params_for("sonet_group.get")[0]["FILTER"]["ID"] == [12]
