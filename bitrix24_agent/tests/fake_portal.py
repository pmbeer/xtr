"""Поддельный портал Битрикс24 на httpx.MockTransport для тестов."""

from __future__ import annotations

import json
from collections.abc import Callable
from typing import Any

import httpx

from b24agent.bitrix.client import Bitrix24Client

WEBHOOK = "https://example.bitrix24.ru/rest/1/testtoken/"

Handler = Callable[[dict[str, Any]], httpx.Response]


def ok(result: Any, **extra: Any) -> httpx.Response:
    return httpx.Response(200, json={"result": result, **extra})


def error(code: str, description: str = "", status: int = 400) -> httpx.Response:
    return httpx.Response(
        status, json={"error": code, "error_description": description}
    )


class FakePortal:
    """Маршрутизирует запросы по имени REST-метода.

    Обработчик получает разобранное тело запроса и возвращает готовый ответ,
    поэтому в тестах можно проверять и то, какие параметры ушли на портал.
    """

    def __init__(self) -> None:
        self.handlers: dict[str, Handler] = {}
        self.calls: list[tuple[str, dict[str, Any]]] = []

    def on(self, method: str, handler: Handler) -> FakePortal:
        self.handlers[method] = handler
        return self

    def static(self, method: str, result: Any, **extra: Any) -> FakePortal:
        return self.on(method, lambda _params: ok(result, **extra))

    def fails(self, method: str, code: str, status: int = 400) -> FakePortal:
        return self.on(method, lambda _params: error(code, status=status))

    def params_for(self, method: str) -> list[dict[str, Any]]:
        return [params for name, params in self.calls if name == method]

    def transport(self) -> httpx.MockTransport:
        def handle(request: httpx.Request) -> httpx.Response:
            method = request.url.path.rsplit("/", 1)[-1]
            payload = json.loads(request.content or b"{}")
            self.calls.append((method, payload))
            handler = self.handlers.get(method)
            if handler is None:
                return error("ERROR_METHOD_NOT_FOUND", f"Метод {method} не найден")
            return handler(payload)

        return httpx.MockTransport(handle)

    def client(self, **kwargs: Any) -> Bitrix24Client:
        return Bitrix24Client(
            WEBHOOK,
            rate_limit=1000.0,
            http_client=httpx.AsyncClient(transport=self.transport()),
            **kwargs,
        )


def task_payload(
    task_id: int,
    *,
    status: int = 5,
    created: str = "2026-08-03T10:00:00+03:00",
    closed: str | None = "2026-08-03T13:00:00+03:00",
    deadline: str | None = None,
    stage_id: int = 0,
    group_id: int = 0,
    spent: int = 0,
    title: str | None = None,
) -> dict[str, Any]:
    """Задача в том виде, в котором её отдаёт tasks.task.list (camelCase)."""
    return {
        "id": str(task_id),
        "title": title or f"Задача {task_id}",
        "status": str(status),
        "responsibleId": "1",
        "createdBy": "2",
        "createdDate": created,
        "closedDate": closed,
        "changedDate": created,
        "dateStart": None,
        "deadline": deadline,
        "groupId": str(group_id),
        "stageId": str(stage_id),
        "priority": "1",
        "mark": None,
        "timeEstimate": "0",
        "timeSpentInLogs": str(spent),
    }


def session_payload(
    session_id: int,
    *,
    created: str = "2026-08-03T10:00:00+03:00",
    closed: str | None = "2026-08-03T10:20:00+03:00",
    wait_answer: int | None = 60,
    wait_close: int | None = 1200,
    vote: str = "like",
    source: str = "livechat",
    status: str = "closed",
    messages: int = 10,
) -> dict[str, Any]:
    return {
        "id": session_id,
        "configId": 3,
        "source": source,
        "operatorId": 1,
        "dateCreate": created,
        "dateClose": closed,
        "dateFirstAnswer": created,
        "status": status,
        "closeReason": "operator",
        "vote": vote,
        "waitAnswer": wait_answer,
        "waitClose": wait_close,
        "kpiFirstAnswer": True,
        "messageCount": messages,
    }
