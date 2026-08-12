from __future__ import annotations

import httpx
import pytest

from b24agent.bitrix.client import Bitrix24Client, _build_command
from b24agent.bitrix.errors import (
    Bitrix24Error,
    MethodNotAvailableError,
    NotAuthorizedError,
)
from tests.fake_portal import WEBHOOK, FakePortal, ok


async def test_call_returns_result():
    portal = FakePortal().static("profile", {"ID": "7", "NAME": "Иван"})
    async with portal.client() as client:
        assert await client.call("profile") == {"ID": "7", "NAME": "Иван"}


async def test_fetch_all_follows_next_pages():
    pages = {
        0: ok({"tasks": [{"id": "1"}, {"id": "2"}]}, next=2, total=3),
        2: ok({"tasks": [{"id": "3"}]}, total=3),
    }
    portal = FakePortal().on(
        "tasks.task.list", lambda params: pages[int(params.get("start", 0))]
    )
    async with portal.client() as client:
        items = await client.fetch_all(
            "tasks.task.list", {}, extract=lambda result: result["tasks"]
        )
    assert [item["id"] for item in items] == ["1", "2", "3"]
    assert [params["start"] for _, params in portal.calls] == [0, 2]


async def test_fetch_all_respects_max_records():
    portal = FakePortal().on(
        "crm.activity.list",
        lambda params: ok([{"ID": str(index)} for index in range(50)], next=params["start"] + 50),
    )
    async with portal.client() as client:
        items = await client.fetch_all("crm.activity.list", {}, max_records=70)
    assert len(items) == 70


async def test_missing_method_raises_specific_error():
    portal = FakePortal()
    async with portal.client() as client:
        with pytest.raises(MethodNotAvailableError):
            await client.call("imopenlines.v2.Session.list")


async def test_revoked_webhook_raises_auth_error():
    portal = FakePortal().fails("profile", "NO_AUTH_FOUND", status=401)
    async with portal.client() as client:
        with pytest.raises(NotAuthorizedError):
            await client.call("profile")


async def test_retries_on_rate_limit_then_succeeds():
    attempts = {"count": 0}

    def handler(_params):
        attempts["count"] += 1
        if attempts["count"] < 3:
            return httpx.Response(503, json={"error": "QUERY_LIMIT_EXCEEDED"})
        return ok({"ok": True})

    portal = FakePortal().on("profile", handler)
    async with portal.client() as client:
        assert await client.call("profile") == {"ok": True}
    assert attempts["count"] == 3


async def test_gives_up_after_retries():
    portal = FakePortal().on(
        "profile", lambda _params: httpx.Response(500, json={"error": "ERROR_CORE"})
    )
    async with Bitrix24Client(
        WEBHOOK,
        rate_limit=1000.0,
        max_retries=1,
        http_client=httpx.AsyncClient(transport=portal.transport()),
    ) as client:
        with pytest.raises(Bitrix24Error):
            await client.call("profile")


async def test_batch_splits_results_and_errors():
    def handler(params):
        assert params["halt"] == 0
        return ok(
            {
                "result": {"stages_0": {"1": {"ID": 1, "TITLE": "Новые"}}},
                "result_error": {"stages_5": "ACCESS_DENIED"},
            }
        )

    portal = FakePortal().on("batch", handler)
    async with portal.client() as client:
        results, errors = await client.batch(
            {
                "stages_0": ("tasks.task.stages.get", {"entityId": 0}),
                "stages_5": ("tasks.task.stages.get", {"entityId": 5}),
            }
        )
    assert results["stages_0"]["1"]["TITLE"] == "Новые"
    assert errors == {"stages_5": "ACCESS_DENIED"}


async def test_batch_chunks_more_than_fifty_commands():
    portal = FakePortal().on("batch", lambda _params: ok({"result": {}, "result_error": {}}))
    async with portal.client() as client:
        await client.batch(
            {f"cmd{index}": ("user.get", {"ID": index}) for index in range(120)}
        )
    assert len(portal.params_for("batch")) == 3


def test_build_command_encodes_nested_params():
    command = _build_command("tasks.task.list", {"filter": {"REAL_STATUS": 5}, "start": 0})
    assert "filter%5BREAL_STATUS%5D=5" in command
    assert command.startswith("tasks.task.list?")


def test_webhook_url_is_normalized():
    client = Bitrix24Client("https://example.bitrix24.ru/rest/1/token")
    assert client._base_url == "https://example.bitrix24.ru/rest/1/token/"
