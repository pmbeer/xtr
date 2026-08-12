"""Фейковый портал Битрикс24 для тестов.

Повторяет поведение настоящего REST в том, что важно агенту: фильтры, страницы
по 50 записей, `total`/`next` в конверте и разбор команд внутри `batch`.
"""

from __future__ import annotations

from collections.abc import Callable, Mapping
from datetime import datetime
from typing import Any
from urllib.parse import parse_qsl, unquote

from bitrix24_agent.errors import Bitrix24Error

PAGE_SIZE = 50


def parse_php_query(query: str) -> dict[str, Any]:
    """Обратное преобразование `filter[>=CLOSED_DATE]=...` в словарь."""
    tree: dict[str, Any] = {}
    for raw_key, value in parse_qsl(query, keep_blank_values=True):
        path = _split_key(unquote(raw_key))
        node: dict[str, Any] = tree
        for part in path[:-1]:
            node = node.setdefault(part, {})
        node[path[-1]] = value
    return _collapse_lists(tree)


def _split_key(key: str) -> list[str]:
    head, _, rest = key.partition("[")
    parts = [head]
    while rest:
        name, _, rest = rest.partition("]")
        parts.append(name)
        rest = rest.lstrip("[")
    return [part for part in parts if part != ""]


def _collapse_lists(node: Any) -> Any:
    if not isinstance(node, dict):
        return node
    collapsed = {key: _collapse_lists(value) for key, value in node.items()}
    keys = list(collapsed)
    if keys and all(key.isdigit() for key in keys):
        return [collapsed[key] for key in sorted(keys, key=int)]
    return collapsed


class FakePortal:
    """Транспорт, отвечающий из заранее заданных данных."""

    def __init__(
        self,
        *,
        tasks: list[dict[str, Any]] | None = None,
        sessions: list[dict[str, Any]] | None = None,
        stages: dict[int, list[dict[str, Any]]] | None = None,
        groups: list[dict[str, Any]] | None = None,
        current_user: dict[str, Any] | None = None,
        errors: dict[str, Bitrix24Error] | None = None,
        extra: dict[str, Callable[[Mapping[str, Any]], dict]] | None = None,
    ):
        self.tasks = tasks or []
        self.sessions = sessions or []
        self.stages = stages or {}
        self.groups = groups or []
        self.current_user = current_user or {"ID": "1", "NAME": "Иван", "LAST_NAME": "Иванов"}
        self.errors = errors or {}
        self.extra = extra or {}
        self.calls: list[tuple[str, Mapping[str, Any]]] = []
        self.calls_made = 0

    def request(self, method: str, params: Mapping[str, Any] | None = None) -> dict:
        params = params or {}
        self.calls.append((method, params))
        self.calls_made += 1

        if method in self.errors:
            raise self.errors[method]
        handler = self.extra.get(method)
        if handler is not None:
            return handler(params)

        handlers: dict[str, Callable[[Mapping[str, Any]], dict]] = {
            "user.current": lambda _: {"result": self.current_user},
            "batch": self._batch,
            "tasks.task.list": self._tasks_list,
            "task.stages.get": self._stages_get,
            "sonet_group.get": lambda _: {"result": self.groups},
            "imopenlines.v2.Session.list": self._sessions_list,
            "imopenlines.config.list.get": lambda _: {"result": []},
        }
        handler = handlers.get(method)
        if handler is None:
            raise Bitrix24Error(method, "ERROR_METHOD_NOT_FOUND", "метод не поддержан фейком")
        return handler(params)

    def _batch(self, params: Mapping[str, Any]) -> dict:
        commands = params.get("cmd") or {}
        results: dict[str, Any] = {}
        errors: dict[str, Any] = {}
        totals: dict[str, Any] = {}
        for key, command in commands.items():
            method, _, query = str(command).partition("?")
            try:
                envelope = self.request(method, parse_php_query(query))
            except Bitrix24Error as exc:
                errors[key] = {"error": exc.code, "error_description": exc.description}
                continue
            results[key] = envelope.get("result")
            total = envelope.get("total")
            if total is None and isinstance(envelope.get("result"), Mapping):
                total = envelope["result"].get("total")
            if total is not None:
                totals[key] = total
        return {
            "result": {
                "result": results,
                "result_error": errors,
                "result_total": totals,
                "result_next": {},
            }
        }

    def _tasks_list(self, params: Mapping[str, Any]) -> dict:
        selected = [task for task in self.tasks if _task_matches(task, params.get("filter") or {})]
        start = int(params.get("start") or 0)
        page = selected[start : start + PAGE_SIZE]
        envelope: dict[str, Any] = {"result": {"tasks": page, "total": len(selected)}}
        if start + PAGE_SIZE < len(selected):
            envelope["next"] = start + PAGE_SIZE
        return envelope

    def _stages_get(self, params: Mapping[str, Any]) -> dict:
        entity_id = int(params.get("entityId") or 0)
        stages = self.stages.get(entity_id, [])
        return {"result": {str(stage["ID"]): stage for stage in stages}}

    def _sessions_list(self, params: Mapping[str, Any]) -> dict:
        operator_id = params.get("operatorId")
        selected = [
            session
            for session in self.sessions
            if operator_id is None or str(session.get("operatorId")) == str(operator_id)
        ]
        offset = int(params.get("offset") or 0)
        limit = int(params.get("limit") or 50)
        page = selected[offset : offset + limit]
        return {
            "result": {"sessions": page, "hasNextPage": offset + limit < len(selected)}
        }


def _task_matches(task: Mapping[str, Any], filters: Mapping[str, Any]) -> bool:
    return all(_filter_matches(task, key, expected) for key, expected in filters.items())


def _filter_matches(task: Mapping[str, Any], key: str, expected: Any) -> bool:
    if key == "RESPONSIBLE_ID":
        return str(task.get("responsibleId")) == str(expected)
    if key == "CREATED_BY":
        return str(task.get("createdBy")) == str(expected)
    if key == "REAL_STATUS":
        allowed = expected if isinstance(expected, list) else [expected]
        return str(task.get("status")) in {str(item) for item in allowed}
    if key.endswith("CLOSED_DATE"):
        return _date_matches(task.get("closedDate"), key, expected)
    if key.endswith("CREATED_DATE"):
        return _date_matches(task.get("createdDate"), key, expected)
    return True


def _date_matches(raw_value: Any, key: str, expected: Any) -> bool:
    if not raw_value:
        return False
    value = datetime.fromisoformat(str(raw_value))
    boundary = datetime.fromisoformat(str(expected))
    if key.startswith(">="):
        return value >= boundary
    if key.startswith("<="):
        return value <= boundary
    return True
