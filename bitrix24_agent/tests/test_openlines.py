from __future__ import annotations

from b24agent.analytics import period as periods
from b24agent.bitrix.openlines import OpenLinesDataSource, OpenLinesRepository
from tests.fake_portal import FakePortal, ok, session_payload


async def test_v2_path_reads_sessions_and_aggregate(tz, now):
    portal = (
        FakePortal()
        .static(
            "imopenlines.v2.Session.list",
            {"sessions": [session_payload(1), session_payload(2)], "hasNextPage": False},
        )
        .static(
            "imopenlines.v2.Stat.get",
            {"totalSessions": 2, "closedSessions": 2, "avgWaitAnswer": 45.0},
        )
        .static("imopenlines.config.list.get", [{"ID": "3", "LINE_NAME": "Поддержка"}])
    )
    async with portal.client() as client:
        data = await OpenLinesRepository(client, tz).collect(periods.last_week(now), 1)

    assert data.source is OpenLinesDataSource.STATS_V2
    assert [session.id for session in data.sessions] == [1, 2]
    assert data.aggregate["avgWaitAnswer"] == 45.0
    assert data.line_names == {3: "Поддержка"}
    assert data.notes == []


async def test_v2_pagination_uses_offset(tz, now):
    def handler(params):
        if params["offset"] == 0:
            return ok({"sessions": [session_payload(index) for index in range(200)], "hasNextPage": True})
        return ok({"sessions": [session_payload(999)], "hasNextPage": False})

    portal = (
        FakePortal()
        .on("imopenlines.v2.Session.list", handler)
        .static("imopenlines.v2.Stat.get", {})
        .static("imopenlines.config.list.get", [])
    )
    async with portal.client() as client:
        data = await OpenLinesRepository(client, tz).collect(periods.last_week(now), 1)

    assert len(data.sessions) == 201
    assert [call["offset"] for call in portal.params_for("imopenlines.v2.Session.list")] == [0, 200]


async def test_falls_back_to_crm_activities_when_method_missing(tz, now):
    activity = {
        "ID": "501",
        "CREATED": "2026-08-04T09:00:00+03:00",
        "END_TIME": "2026-08-04T09:25:00+03:00",
        "COMPLETED": "Y",
        "RESPONSIBLE_ID": "1",
        "PROVIDER_ID": "IMOPENLINES",
        "PROVIDER_TYPE_ID": "telegrambot",
        "OWNER_ID": "77",
        "OWNER_TYPE_ID": "1",
    }
    portal = FakePortal().static("crm.activity.list", [activity])

    async with portal.client() as client:
        data = await OpenLinesRepository(client, tz).collect(periods.last_week(now), 1)

    assert data.source is OpenLinesDataSource.CRM_ACTIVITIES
    assert data.notes and "приблизительн" in data.notes[0]
    session = data.sessions[0]
    assert session.id == 501
    assert session.is_closed
    assert session.resolution_seconds == 25 * 60
    assert session.source == "telegrambot"

    sent_filter = portal.params_for("crm.activity.list")[0]["filter"]
    assert sent_filter["PROVIDER_ID"] == ["IMOPENLINES", "IMOPENLINES_SESSION"]
    assert sent_filter["RESPONSIBLE_ID"] == 1


async def test_tariff_restriction_also_falls_back(tz, now):
    portal = (
        FakePortal()
        .fails("imopenlines.v2.Session.list", "B24_TARIFF_RESTRICTION", status=403)
        .static("crm.activity.list", [])
    )
    async with portal.client() as client:
        data = await OpenLinesRepository(client, tz).collect(periods.last_week(now), 1)

    assert data.source is OpenLinesDataSource.CRM_ACTIVITIES
    assert "B24_TARIFF_RESTRICTION" in data.notes[0]


async def test_both_paths_unavailable_is_reported(tz, now):
    portal = FakePortal().fails("crm.activity.list", "ACCESS_DENIED", status=403)
    async with portal.client() as client:
        data = await OpenLinesRepository(client, tz).collect(periods.last_week(now), 1)

    assert data.source is OpenLinesDataSource.UNAVAILABLE
    assert data.sessions == []
    assert len(data.notes) == 2
