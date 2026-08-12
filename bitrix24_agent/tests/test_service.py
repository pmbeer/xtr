from __future__ import annotations

from b24agent.analytics import period as periods
from b24agent.analytics.models import ReportFormat, ReportRequest, ReportSection
from b24agent.analytics.service import AnalyticsService
from b24agent.bitrix.openlines import OpenLinesDataSource
from b24agent.reports import build_report_file
from tests.fake_portal import FakePortal, ok, session_payload, task_payload


def portal_with_tasks_and_lines() -> FakePortal:
    closed = [
        task_payload(
            1,
            created="2026-08-03T10:00:00+03:00",
            closed="2026-08-03T12:00:00+03:00",
        ),
        task_payload(
            2,
            created="2026-08-04T10:00:00+03:00",
            closed="2026-08-04T18:00:00+03:00",
        ),
    ]
    open_tasks = [
        task_payload(10, status=3, closed=None, stage_id=11, group_id=12),
        task_payload(11, status=2, closed=None),
    ]

    def tasks_handler(params):
        task_filter = params["filter"]
        status = task_filter.get("REAL_STATUS")
        if status == 5:
            return ok({"tasks": closed}, total=len(closed))
        if isinstance(status, list):
            return ok({"tasks": open_tasks}, total=len(open_tasks))
        return ok({"tasks": closed}, total=len(closed))

    return (
        FakePortal()
        .static("profile", {"ID": "1", "NAME": "Иван", "LAST_NAME": "Петров"})
        .on(
            "user.get",
            lambda params: ok(
                [{"ID": str(params.get("ID", 1)), "NAME": "Иван", "LAST_NAME": "Петров"}]
            ),
        )
        .on("tasks.task.list", tasks_handler)
        .static("sonet_group.get", [{"ID": "12", "NAME": "Поддержка"}])
        .on(
            "batch",
            lambda _params: ok(
                {
                    "result": {
                        "stages_0": {"11": {"ID": "11", "TITLE": "В работе", "ENTITY_ID": "0"}},
                        "stages_12": {},
                    },
                    "result_error": {},
                }
            ),
        )
        .static(
            "imopenlines.v2.Session.list",
            {"sessions": [session_payload(index) for index in (100, 101, 102)], "hasNextPage": False},
        )
        .static("imopenlines.v2.Stat.get", {"totalSessions": 3, "closedSessions": 3})
        .static("imopenlines.config.list.get", [{"ID": "3", "LINE_NAME": "Поддержка"}])
    )


async def test_full_report_collects_both_sections(tz, now):
    portal = portal_with_tasks_and_lines()
    async with portal.client() as client:
        service = AnalyticsService(client, tz=tz, portal_url="https://example.bitrix24.ru")
        report = await service.build_report(
            ReportRequest(period=periods.last_week(now), raw_query="полный отчёт")
        )

    assert report.user_name == "Петров Иван"
    assert report.tasks is not None
    assert report.tasks.closed_count == 2
    assert report.tasks.open_count == 2
    assert report.tasks.by_stage == {"В работе": 1, "Без стадии": 1}
    assert report.tasks.by_group == {"Поддержка": 1, "Вне проектов": 1}
    assert report.openlines is not None
    assert report.openlines.total_sessions == 3
    assert report.openlines.data_source is OpenLinesDataSource.STATS_V2
    assert report.warnings == []


async def test_report_for_single_section_skips_other_calls(tz, now):
    portal = portal_with_tasks_and_lines()
    async with portal.client() as client:
        service = AnalyticsService(client, tz=tz)
        report = await service.build_report(
            ReportRequest(
                period=periods.last_week(now),
                sections=frozenset({ReportSection.OPENLINES}),
            )
        )

    assert report.tasks is None
    assert report.openlines is not None
    assert portal.params_for("tasks.task.list") == []


async def test_broken_openlines_do_not_break_task_report(tz, now):
    portal = portal_with_tasks_and_lines()
    portal.fails("imopenlines.v2.Session.list", "INTERNAL_ERROR", status=400)
    portal.fails("crm.activity.list", "ACCESS_DENIED", status=403)

    async with portal.client() as client:
        service = AnalyticsService(client, tz=tz)
        report = await service.build_report(ReportRequest(period=periods.last_week(now)))

    assert report.tasks is not None
    assert report.tasks.closed_count == 2
    assert report.openlines is not None
    assert report.openlines.data_source is OpenLinesDataSource.UNAVAILABLE
    assert any("ACCESS_DENIED" in warning for warning in report.warnings)


async def test_report_survives_missing_tasks_module(tz, now):
    portal = portal_with_tasks_and_lines()
    portal.fails("tasks.task.list", "ACCESS_DENIED", status=403)

    async with portal.client() as client:
        service = AnalyticsService(client, tz=tz)
        report = await service.build_report(ReportRequest(period=periods.last_week(now)))

    assert report.tasks is None
    assert any("задачам" in warning for warning in report.warnings)
    assert report.openlines is not None


async def test_explicit_user_id_is_used(tz, now):
    portal = portal_with_tasks_and_lines()
    portal.static("user.get", [{"ID": "42", "NAME": "Мария", "LAST_NAME": "Сидорова"}])

    async with portal.client() as client:
        service = AnalyticsService(client, tz=tz, default_user_id=7)
        report = await service.build_report(
            ReportRequest(period=periods.today(now), bitrix_user_id=42)
        )

    assert report.user_id == 42
    assert report.user_name == "Сидорова Мария"
    assert portal.params_for("user.get")[0]["ID"] == 42
    assert portal.params_for("profile") == []


async def test_end_to_end_produces_openable_file(tz, now):
    portal = portal_with_tasks_and_lines()
    async with portal.client() as client:
        service = AnalyticsService(client, tz=tz)
        report = await service.build_report(
            ReportRequest(period=periods.last_week(now), report_format=ReportFormat.XLSX)
        )

    document = build_report_file(report)
    assert document.content[:2] == b"PK"
    assert document.size_kb > 0
    assert document.filename.startswith("bitrix24_petrov_ivan_")
