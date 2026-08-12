"""Тесты REST-клиента: кодирование параметров, пагинация, batch, повторы."""

from __future__ import annotations

import logging
import unittest
from collections.abc import Mapping
from typing import Any
from unittest import mock

from bitrix24_agent.client import Bitrix24Client, build_command, php_query_pairs
from bitrix24_agent.errors import Bitrix24Error, TransportError
from bitrix24_agent.transport import WebhookTransport

from .fakes import FakePortal, parse_php_query


class QueryEncodingTests(unittest.TestCase):
    def test_nested_filters_and_lists_are_flattened(self) -> None:
        pairs = dict(
            php_query_pairs({"filter": {">=CLOSED_DATE": "2026-06-01"}, "select": ["ID", "TITLE"]})
        )
        self.assertEqual(pairs["filter[>=CLOSED_DATE]"], "2026-06-01")
        self.assertEqual(pairs["select[0]"], "ID")
        self.assertEqual(pairs["select[1]"], "TITLE")

    def test_command_round_trips_through_query_string(self) -> None:
        params = {"filter": {"RESPONSIBLE_ID": 7, "REAL_STATUS": [2, 3]}, "start": 0}
        method, _, query = build_command("tasks.task.list", params).partition("?")
        self.assertEqual(method, "tasks.task.list")
        self.assertEqual(
            parse_php_query(query),
            {"filter": {"RESPONSIBLE_ID": "7", "REAL_STATUS": ["2", "3"]}, "start": "0"},
        )

    def test_booleans_become_digits(self) -> None:
        self.assertEqual(dict(php_query_pairs({"flag": True}))["flag"], "1")


class PaginationTests(unittest.TestCase):
    def test_paginate_walks_every_page(self) -> None:
        tasks = [{"id": index, "responsibleId": 1} for index in range(120)]
        portal = FakePortal(tasks=tasks)
        client = Bitrix24Client(portal)

        collected = list(
            client.paginate("tasks.task.list", {"filter": {"RESPONSIBLE_ID": 1}})
        )

        self.assertEqual(len(collected), 120)
        self.assertEqual([call[0] for call in portal.calls].count("tasks.task.list"), 3)

    def test_paginate_respects_limit(self) -> None:
        portal = FakePortal(tasks=[{"id": index, "responsibleId": 1} for index in range(120)])
        client = Bitrix24Client(portal)
        collected = list(client.paginate("tasks.task.list", max_items=60))
        self.assertEqual(len(collected), 60)

    def test_count_reads_total_without_fetching_pages(self) -> None:
        portal = FakePortal(tasks=[{"id": index, "responsibleId": 1} for index in range(120)])
        client = Bitrix24Client(portal)

        total = client.count("tasks.task.list", {"filter": {"RESPONSIBLE_ID": 1}})

        self.assertEqual(total, 120)
        self.assertEqual(len(portal.calls), 1)


class BatchTests(unittest.TestCase):
    def test_batch_returns_result_per_command(self) -> None:
        portal = FakePortal(tasks=[{"id": 1, "responsibleId": 1, "status": "5"}])
        client = Bitrix24Client(portal)

        results = client.batch(
            {
                "mine": ("tasks.task.list", {"filter": {"RESPONSIBLE_ID": 1}, "start": 0}),
                "foreign": ("tasks.task.list", {"filter": {"RESPONSIBLE_ID": 99}, "start": 0}),
            }
        )

        self.assertEqual(results["mine"].total, 1)
        self.assertEqual(results["foreign"].total, 0)
        self.assertTrue(results["mine"].ok)

    def test_batch_splits_requests_above_fifty_commands(self) -> None:
        portal = FakePortal(tasks=[])
        client = Bitrix24Client(portal)

        commands = {
            f"cmd{index}": ("tasks.task.list", {"start": 0}) for index in range(60)
        }
        results = client.batch(commands)

        self.assertEqual(len(results), 60)
        self.assertEqual(sum(1 for method, _ in portal.calls if method == "batch"), 2)

    def test_failed_command_does_not_break_the_rest(self) -> None:
        portal = FakePortal(
            tasks=[{"id": 1, "responsibleId": 1}],
            errors={"crm.deal.list": Bitrix24Error("crm.deal.list", "ACCESS_DENIED")},
        )
        client = Bitrix24Client(portal)

        results = client.batch(
            {
                "tasks": ("tasks.task.list", {"start": 0}),
                "deals": ("crm.deal.list", {"start": 0}),
            }
        )

        self.assertTrue(results["tasks"].ok)
        self.assertFalse(results["deals"].ok)


class TryCallTests(unittest.TestCase):
    def test_missing_method_returns_none(self) -> None:
        portal = FakePortal(errors={"task.stages.get": Bitrix24Error("task.stages.get", "ERROR_METHOD_NOT_FOUND")})
        self.assertIsNone(Bitrix24Client(portal).try_call("task.stages.get", {"entityId": 0}))

    def test_unexpected_error_is_raised(self) -> None:
        portal = FakePortal(errors={"task.stages.get": Bitrix24Error("task.stages.get", "INTERNAL_SERVER_ERROR")})
        with self.assertRaises(Bitrix24Error):
            Bitrix24Client(portal).try_call("task.stages.get", {"entityId": 0})


class StubbedTransport(WebhookTransport):
    """Транспорт с подменённым сетевым слоем."""

    def __init__(self, responses: list[tuple[int, dict]], **kwargs: Any):
        super().__init__("https://portal.bitrix24.ru/rest/1/token", rate_limit=0, **kwargs)
        self.responses = responses
        self.attempts = 0

    def _send(
        self, url: str, body: bytes, headers: Mapping[str, str]
    ) -> tuple[int, dict]:  # noqa: D102 - см. базовый класс
        self.attempts += 1
        if not self.responses:
            raise TransportError("ответы закончились")
        return self.responses.pop(0)


class RetryTests(unittest.TestCase):
    def setUp(self) -> None:
        # Повторы намеренно пишут предупреждения — в выводе тестов они лишние.
        logging.getLogger("bitrix24_agent.transport").setLevel(logging.ERROR)
        self.addCleanup(logging.getLogger("bitrix24_agent.transport").setLevel, logging.NOTSET)

    def test_rate_limit_error_is_retried(self) -> None:
        transport = StubbedTransport(
            [
                (503, {"error": "QUERY_LIMIT_EXCEEDED", "error_description": "Too many requests"}),
                (200, {"result": {"ok": True}}),
            ],
            max_retries=2,
        )
        with mock.patch("bitrix24_agent.transport.time.sleep") as sleep:
            envelope = transport.request("user.current")

        self.assertEqual(envelope["result"], {"ok": True})
        self.assertEqual(transport.attempts, 2)
        sleep.assert_called_once()

    def test_permanent_error_is_raised_immediately(self) -> None:
        transport = StubbedTransport(
            [(400, {"error": "ACCESS_DENIED", "error_description": "нет прав"})], max_retries=3
        )
        with self.assertRaises(Bitrix24Error) as error:
            transport.request("crm.deal.list")

        self.assertEqual(transport.attempts, 1)
        self.assertTrue(error.exception.is_access_denied)

    def test_retries_are_bounded(self) -> None:
        transport = StubbedTransport([(503, {"error": "QUERY_LIMIT_EXCEEDED"})] * 5, max_retries=2)
        with mock.patch("bitrix24_agent.transport.time.sleep"), self.assertRaises(Bitrix24Error):
            transport.request("user.current")
        self.assertEqual(transport.attempts, 3)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
