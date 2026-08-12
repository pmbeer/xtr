"""Клиент REST Битрикс24: одиночные вызовы, пагинация, batch."""

from __future__ import annotations

import logging
from collections.abc import Callable, Iterable, Iterator, Mapping, Sequence
from typing import Any
from urllib.parse import urlencode

from .errors import Bitrix24Error
from .transport import Transport

log = logging.getLogger(__name__)

#: Максимум подзапросов в одном `batch` (ограничение портала).
BATCH_LIMIT = 50
#: Размер страницы списочных методов Битрикс24 — всегда 50 записей.
PAGE_SIZE = 50
#: Страховка от бесконечной пагинации при неожиданном ответе портала.
MAX_PAGES = 200


def php_query_pairs(params: Mapping[str, Any], prefix: str = "") -> list[tuple[str, str]]:
    """Разворачивает вложенный словарь в пары вида `filter[>=CLOSED_DATE]=...`.

    Команды внутри `batch` передаются строкой запроса, поэтому вложенные
    структуры приходится кодировать так, как их ждёт PHP.
    """
    pairs: list[tuple[str, str]] = []
    for key, value in params.items():
        full_key = f"{prefix}[{key}]" if prefix else str(key)
        if isinstance(value, Mapping):
            pairs.extend(php_query_pairs(value, full_key))
        elif isinstance(value, (list, tuple)):
            indexed = {str(index): item for index, item in enumerate(value)}
            pairs.extend(php_query_pairs(indexed, full_key))
        elif isinstance(value, bool):
            pairs.append((full_key, "1" if value else "0"))
        elif value is None:
            pairs.append((full_key, ""))
        else:
            pairs.append((full_key, str(value)))
    return pairs


def build_command(method: str, params: Mapping[str, Any] | None = None) -> str:
    """Собирает подзапрос для `batch`."""
    if not params:
        return method
    return f"{method}?{urlencode(php_query_pairs(params))}"


class BatchResult:
    """Результат одной команды внутри `batch`."""

    def __init__(self, key: str, result: Any, error: Any, total: int | None):
        self.key = key
        self.result = result
        self.error = error
        self.total = total

    @property
    def ok(self) -> bool:
        return not self.error

    def __repr__(self) -> str:  # pragma: no cover - отладочное представление
        return f"BatchResult(key={self.key!r}, ok={self.ok}, total={self.total})"


class Bitrix24Client:
    """Тонкая обёртка над REST: знает про `result`, `total`, `next` и `batch`."""

    def __init__(self, transport: Transport):
        self.transport = transport

    def call_envelope(self, method: str, params: Mapping[str, Any] | None = None) -> dict:
        """Вызов метода с полным конвертом ответа (`result`, `total`, `next`, `time`)."""
        return self.transport.request(method, params)

    def call(self, method: str, params: Mapping[str, Any] | None = None) -> Any:
        """Вызов метода, возвращает только `result`."""
        return self.call_envelope(method, params).get("result")

    def try_call(self, method: str, params: Mapping[str, Any] | None = None) -> Any:
        """Как `call`, но возвращает `None`, если метода нет или закрыт доступ."""
        try:
            return self.call(method, params)
        except Bitrix24Error as exc:
            if exc.is_method_missing or exc.is_access_denied:
                log.info("метод %s недоступен: %s", method, exc.code)
                return None
            raise

    def count(
        self,
        method: str,
        params: Mapping[str, Any] | None = None,
        *,
        total_key: str = "total",
    ) -> int:
        """Количество записей без выгрузки всех страниц.

        Списочные методы возвращают `total` рядом с первой страницей, поэтому
        достаточно одного запроса с минимальным `select`.
        """
        envelope = self.call_envelope(method, {**(params or {}), "start": 0})
        return _extract_total(envelope, total_key)

    def paginate(
        self,
        method: str,
        params: Mapping[str, Any] | None = None,
        *,
        extract: Callable[[Any], Sequence[Any]] | None = None,
        max_items: int | None = None,
    ) -> Iterator[Any]:
        """Перебирает все страницы списочного метода через параметр `start`."""
        extract = extract or _extract_list
        start = 0
        collected = 0
        for _ in range(MAX_PAGES):
            envelope = self.call_envelope(method, {**(params or {}), "start": start})
            items = extract(envelope.get("result"))
            if not items:
                return
            for item in items:
                yield item
                collected += 1
                if max_items is not None and collected >= max_items:
                    log.info("%s: достигнут лимит выгрузки в %d записей", method, max_items)
                    return
            next_start = envelope.get("next")
            if next_start is None:
                return
            next_start = int(next_start)
            if next_start <= start:
                return
            start = next_start
        log.warning("%s: пагинация прервана после %d страниц", method, MAX_PAGES)

    def batch(
        self,
        commands: Mapping[str, tuple[str, Mapping[str, Any] | None]],
        *,
        halt: bool = False,
    ) -> dict[str, BatchResult]:
        """Выполняет до 50 вызовов за один HTTP-запрос.

        Ключи словаря — произвольные имена команд, по ним же возвращается
        результат. Ошибка отдельной команды не прерывает остальные.
        """
        results: dict[str, BatchResult] = {}
        for chunk in _chunked(list(commands.items()), BATCH_LIMIT):
            payload = {
                "halt": 1 if halt else 0,
                "cmd": {key: build_command(method, params) for key, (method, params) in chunk},
            }
            envelope = self.call_envelope("batch", payload)
            body = envelope.get("result") or {}
            raw_results = body.get("result") or {}
            raw_errors = body.get("result_error") or {}
            raw_totals = body.get("result_total") or {}
            for key, _ in chunk:
                results[key] = BatchResult(
                    key=key,
                    result=raw_results.get(key),
                    error=raw_errors.get(key),
                    total=_coerce_total(raw_totals.get(key), raw_results.get(key)),
                )
        return results


def _chunked(items: Sequence[Any], size: int) -> Iterable[Sequence[Any]]:
    for index in range(0, len(items), size):
        yield items[index : index + size]


def _extract_list(result: Any) -> Sequence[Any]:
    if result is None:
        return []
    if isinstance(result, list):
        return result
    if isinstance(result, Mapping):
        for key in ("tasks", "items", "sessions"):
            value = result.get(key)
            if isinstance(value, list):
                return value
        return list(result.values())
    return []


def _extract_total(envelope: Mapping[str, Any], total_key: str) -> int:
    """Достаёт `total` из конверта или из тела результата.

    У `crm.*.list` счётчик лежит рядом с `result`, у `tasks.task.list` — внутри.
    """
    if total_key in envelope:
        return int(envelope[total_key] or 0)
    result = envelope.get("result")
    if isinstance(result, Mapping) and total_key in result:
        return int(result[total_key] or 0)
    return len(_extract_list(result))


def _coerce_total(raw_total: Any, result: Any) -> int | None:
    if raw_total is not None:
        try:
            return int(raw_total)
        except (TypeError, ValueError):
            pass
    if isinstance(result, Mapping) and "total" in result:
        try:
            return int(result["total"])
        except (TypeError, ValueError):
            return None
    return None
