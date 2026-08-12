"""Асинхронный клиент REST API облачного Битрикс24 (авторизация вебхуком).

Клиент закрывает три неприятных особенности REST Битрикс24:

* лимит частоты запросов (портал отвечает ``QUERY_LIMIT_EXCEEDED``, если
  давить чаще ~2 запросов в секунду) — здесь стоит token bucket;
* постраничную выдачу списочных методов через ``start``/``next``;
* пакетный вызов ``batch`` (до 50 методов за один HTTP-запрос).
"""

from __future__ import annotations

import asyncio
import logging
import random
import time
from collections.abc import Callable, Iterable, Mapping, Sequence
from typing import Any
from urllib.parse import urlencode

import httpx

from b24agent.bitrix.errors import Bitrix24Error, Bitrix24HTTPError, build_error

logger = logging.getLogger(__name__)

PAGE_SIZE = 50
BATCH_LIMIT = 50
RETRY_STATUS_CODES = frozenset({429, 500, 502, 503, 504})
RETRY_ERROR_CODES = frozenset({"QUERY_LIMIT_EXCEEDED", "OPERATION_TIMEOUT", "ERROR_CORE"})


class RateLimiter:
    """Token bucket: не более ``rate`` запросов в секунду в среднем."""

    def __init__(self, rate: float, capacity: float | None = None) -> None:
        self._rate = max(rate, 0.1)
        self._capacity = capacity if capacity is not None else max(self._rate, 1.0)
        self._tokens = self._capacity
        self._updated_at = time.monotonic()
        self._lock = asyncio.Lock()

    async def acquire(self) -> None:
        async with self._lock:
            while True:
                now = time.monotonic()
                self._tokens = min(
                    self._capacity, self._tokens + (now - self._updated_at) * self._rate
                )
                self._updated_at = now
                if self._tokens >= 1:
                    self._tokens -= 1
                    return
                await asyncio.sleep((1 - self._tokens) / self._rate)


class Bitrix24Client:
    """Тонкая обёртка над REST-методами портала.

    Пример::

        async with Bitrix24Client(webhook_url) as client:
            profile = await client.call("profile")
    """

    def __init__(
        self,
        webhook_url: str,
        *,
        timeout: float = 30.0,
        rate_limit: float = 2.0,
        max_retries: int = 4,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self._base_url = webhook_url.rstrip("/") + "/"
        self._max_retries = max(max_retries, 0)
        self._limiter = RateLimiter(rate_limit)
        self._owns_client = http_client is None
        self._http = http_client or httpx.AsyncClient(
            timeout=httpx.Timeout(timeout),
            headers={"User-Agent": "b24agent/1.0 (+telegram analytics bot)"},
        )

    async def __aenter__(self) -> Bitrix24Client:
        return self

    async def __aexit__(self, *exc_info: object) -> None:
        await self.aclose()

    async def aclose(self) -> None:
        if self._owns_client:
            await self._http.aclose()

    # ------------------------------------------------------------------ вызовы

    async def call(self, method: str, params: Mapping[str, Any] | None = None) -> Any:
        """Вызывает метод и возвращает содержимое поля ``result``."""
        envelope = await self.call_raw(method, params)
        return envelope.get("result")

    async def call_raw(
        self, method: str, params: Mapping[str, Any] | None = None
    ) -> dict[str, Any]:
        """Вызывает метод и возвращает конверт ответа целиком.

        Поля ``next``/``total`` конверта нужны для постраничной выгрузки, поэтому
        они доступны отдельно от :meth:`call`.
        """
        payload: dict[str, Any] = dict(params or {})
        url = f"{self._base_url}{method}"
        last_error: Exception | None = None

        for attempt in range(self._max_retries + 1):
            await self._limiter.acquire()
            try:
                response = await self._http.post(url, json=payload)
            except httpx.TimeoutException as exc:
                last_error = exc
            except httpx.TransportError as exc:
                last_error = exc
            else:
                envelope = self._parse_body(response, method)
                error_code = self._error_code(envelope, response)
                if error_code is None:
                    return envelope
                if not self._is_retryable(response.status_code, error_code):
                    raise build_error(
                        error_code,
                        str(
                            envelope.get("error_description")
                            or envelope.get("error_message")
                            or ""
                        ),
                        method,
                    )
                last_error = build_error(error_code, "", method)

            if attempt < self._max_retries:
                delay = self._backoff(attempt)
                logger.warning(
                    "Повтор запроса %s через %.1f c (попытка %s/%s): %s",
                    method,
                    delay,
                    attempt + 1,
                    self._max_retries,
                    last_error,
                )
                await asyncio.sleep(delay)

        assert last_error is not None
        if isinstance(last_error, Bitrix24Error):
            raise last_error
        raise Bitrix24Error("TRANSPORT_ERROR", str(last_error), method) from last_error

    async def fetch_all(
        self,
        method: str,
        params: Mapping[str, Any] | None = None,
        *,
        extract: Callable[[Any], Sequence[Any]] | None = None,
        max_records: int | None = None,
        page_size: int = PAGE_SIZE,
    ) -> list[Any]:
        """Выгружает все страницы списочного метода.

        ``extract`` достаёт список из ``result``: у одних методов это сам список
        (``crm.activity.list``), у других — вложенный ключ (``tasks.task.list``
        отдаёт ``{"tasks": [...]}``).
        """
        extract = extract or _default_extract
        collected: list[Any] = []
        start = 0
        seen_pages = 0

        while True:
            page_params = dict(params or {})
            page_params["start"] = start
            envelope = await self.call_raw(method, page_params)
            items = list(extract(envelope.get("result")))
            collected.extend(items)
            seen_pages += 1

            if max_records is not None and len(collected) >= max_records:
                logger.info(
                    "Достигнут лимит выгрузки %s записей для %s — данные усечены",
                    max_records,
                    method,
                )
                return collected[:max_records]

            next_start = envelope.get("next")
            if next_start is None or not items:
                return collected
            start = int(next_start)
            if seen_pages > 500:  # предохранитель от зацикливания
                logger.warning("Слишком много страниц в %s, выгрузка прервана", method)
                return collected

    async def batch(
        self,
        commands: Mapping[str, tuple[str, Mapping[str, Any] | None]],
        *,
        halt_on_error: bool = False,
    ) -> tuple[dict[str, Any], dict[str, str]]:
        """Выполняет до 50 методов одним запросом.

        Возвращает пару ``(результаты, ошибки)`` с теми же ключами, что и во
        входном словаре команд.
        """
        results: dict[str, Any] = {}
        errors: dict[str, str] = {}
        items = list(commands.items())

        for chunk_start in range(0, len(items), BATCH_LIMIT):
            chunk = items[chunk_start : chunk_start + BATCH_LIMIT]
            cmd = {
                key: _build_command(method, method_params)
                for key, (method, method_params) in chunk
            }
            envelope = await self.call_raw(
                "batch", {"halt": int(halt_on_error), "cmd": cmd}
            )
            payload = envelope.get("result") or {}
            results.update(payload.get("result") or {})
            raw_errors = payload.get("result_error") or {}
            errors.update({key: str(value) for key, value in raw_errors.items()})

        return results, errors

    # ------------------------------------------------------------ вспомогательное

    @staticmethod
    def _parse_body(response: httpx.Response, method: str) -> dict[str, Any]:
        try:
            body = response.json()
        except ValueError as exc:
            raise Bitrix24HTTPError(response.status_code, response.text, method) from exc
        if not isinstance(body, dict):
            raise Bitrix24HTTPError(response.status_code, response.text, method)
        return body

    @staticmethod
    def _error_code(envelope: Mapping[str, Any], response: httpx.Response) -> str | None:
        error = envelope.get("error")
        if error:
            return str(error)
        if response.status_code >= 400:
            return f"HTTP_{response.status_code}"
        return None

    @staticmethod
    def _is_retryable(status_code: int, error_code: str) -> bool:
        if status_code in RETRY_STATUS_CODES:
            return True
        return error_code.upper() in RETRY_ERROR_CODES

    @staticmethod
    def _backoff(attempt: int) -> float:
        return min(2.0**attempt, 16.0) * (0.8 + random.random() * 0.4)


def _default_extract(result: Any) -> Sequence[Any]:
    if result is None:
        return []
    if isinstance(result, list):
        return result
    if isinstance(result, dict):
        # Часть методов кладёт список внутрь единственного ключа.
        for value in result.values():
            if isinstance(value, list):
                return value
    return []


def _build_command(method: str, params: Mapping[str, Any] | None) -> str:
    """Собирает строку команды для ``batch``: ``method?a[b]=c``."""
    if not params:
        return method
    return f"{method}?{urlencode(list(_flatten(params)), doseq=False)}"


def _flatten(params: Mapping[str, Any], prefix: str = "") -> Iterable[tuple[str, str]]:
    for key, value in params.items():
        name = f"{prefix}[{key}]" if prefix else str(key)
        yield from _flatten_value(name, value)


def _flatten_value(name: str, value: Any) -> Iterable[tuple[str, str]]:
    if isinstance(value, Mapping):
        yield from _flatten(value, name)
    elif isinstance(value, (list, tuple, set)):
        for index, item in enumerate(value):
            yield from _flatten_value(f"{name}[{index}]", item)
    elif isinstance(value, bool):
        yield name, "Y" if value else "N"
    elif value is None:
        yield name, ""
    else:
        yield name, str(value)
