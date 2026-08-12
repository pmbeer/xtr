"""Асинхронный клиент REST API Битрикс24, работающий через входящий вебхук.

Особенности реализации:
- Постраничная выгрузка списков (`list_all`) с автоматической пагинацией.
- Автоматические повторные попытки при временных ошибках Битрикс24
  (превышение лимита запросов, перегрузка) с экспоненциальной задержкой.
- Единая обработка ошибок через :class:`BitrixApiError`.

Метод вызова соответствует классическому REST API Битрикс24 (вебхуки):
``POST {webhook_url}{method}.json`` с телом запроса в JSON.
"""

from __future__ import annotations

import asyncio
import logging
from typing import Any, AsyncIterator

import httpx

logger = logging.getLogger(__name__)

# Коды ошибок Битрикс24, при которых имеет смысл повторить запрос.
RETRYABLE_ERROR_CODES = {
    "QUERY_LIMIT_EXCEEDED",
    "OPERATION_TIME_LIMIT",
    "OVERLOAD_LIMIT",
    "INTERNAL_SERVER_ERROR",
    "ERROR_UNEXPECTED_ANSWER",
}

# Классический tasks.task.list всегда отдаёт страницы по 50 записей.
DEFAULT_PAGE_SIZE = 50


class BitrixApiError(RuntimeError):
    """Ошибка, которую вернул REST API Битрикс24."""

    def __init__(self, method: str, code: str, description: str, raw: Any = None):
        self.method = method
        self.code = code
        self.description = description
        self.raw = raw
        super().__init__(f"Bitrix24 API [{method}] -> {code}: {description}")


class BitrixClient:
    """Тонкая обёртка над REST API Битрикс24 (входящий вебхук)."""

    def __init__(
        self,
        webhook_url: str,
        timeout: float = 30.0,
        max_retries: int = 5,
        retry_base_delay: float = 1.5,
    ) -> None:
        if not webhook_url.endswith("/"):
            webhook_url += "/"
        self._base_url = webhook_url
        self._max_retries = max_retries
        self._retry_base_delay = retry_base_delay
        self._client = httpx.AsyncClient(timeout=timeout)

    async def __aenter__(self) -> "BitrixClient":
        return self

    async def __aexit__(self, *exc_info: object) -> None:
        await self.close()

    async def close(self) -> None:
        await self._client.aclose()

    async def call(self, method: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        """Выполняет один вызов REST-метода и возвращает JSON-ответ Битрикс24."""
        url = f"{self._base_url}{method}.json"
        payload = params or {}

        attempt = 0
        while True:
            attempt += 1
            try:
                response = await self._client.post(url, json=payload)
            except httpx.HTTPError as exc:
                if attempt > self._max_retries:
                    raise BitrixApiError(method, "NETWORK_ERROR", str(exc)) from exc
                await self._sleep_before_retry(attempt)
                continue

            try:
                data = response.json()
            except ValueError as exc:
                raise BitrixApiError(
                    method, "INVALID_RESPONSE", f"Не удалось разобрать JSON-ответ: {exc}"
                ) from exc

            if isinstance(data, dict) and data.get("error"):
                code = str(data["error"])
                description = str(data.get("error_description", ""))
                if code in RETRYABLE_ERROR_CODES and attempt <= self._max_retries:
                    logger.warning(
                        "Bitrix24 %s вернул %s (%s), повтор %s/%s",
                        method,
                        code,
                        description,
                        attempt,
                        self._max_retries,
                    )
                    await self._sleep_before_retry(attempt)
                    continue
                raise BitrixApiError(method, code, description, raw=data)

            if response.status_code >= 400:
                raise BitrixApiError(
                    method,
                    str(response.status_code),
                    f"HTTP {response.status_code}: {response.text[:500]}",
                )

            return data

    async def _sleep_before_retry(self, attempt: int) -> None:
        delay = self._retry_base_delay * (2 ** (attempt - 1))
        await asyncio.sleep(delay)

    async def list_all(
        self,
        method: str,
        *,
        select: list[str] | None = None,
        filter_: dict[str, Any] | None = None,
        order: dict[str, str] | None = None,
        extra_params: dict[str, Any] | None = None,
        result_key: str | None = None,
        limit: int | None = None,
        page_size: int = DEFAULT_PAGE_SIZE,
    ) -> AsyncIterator[dict[str, Any]]:
        """Асинхронный генератор, отдающий все элементы списка постранично.

        ``result_key`` нужен для методов, которые оборачивают массив в объект,
        например ``tasks.task.list`` -> ``{"result": {"tasks": [...]}}``.
        """
        params: dict[str, Any] = dict(extra_params or {})
        if select:
            params["select"] = select
        if filter_:
            params["filter"] = filter_
        if order:
            params["order"] = order

        start = 0
        fetched = 0
        while True:
            params["start"] = start
            data = await self.call(method, params)
            result = data.get("result", [])

            if result_key is not None and isinstance(result, dict):
                items = result.get(result_key, [])
            elif isinstance(result, dict) and "items" in result:
                items = result["items"]
            else:
                items = result

            if not isinstance(items, list):
                items = []

            for item in items:
                yield item
                fetched += 1
                if limit is not None and fetched >= limit:
                    return

            next_start = data.get("next")
            if next_start is None or not items:
                return
            if len(items) < page_size and next_start <= start:
                # Защита от зацикливания, если API вернул неожиданный "next".
                return
            start = next_start

    async def collect_all(
        self,
        method: str,
        *,
        select: list[str] | None = None,
        filter_: dict[str, Any] | None = None,
        order: dict[str, str] | None = None,
        extra_params: dict[str, Any] | None = None,
        result_key: str | None = None,
        limit: int | None = None,
    ) -> list[dict[str, Any]]:
        """Как :meth:`list_all`, но сразу возвращает список (а не генератор)."""
        items = []
        async for item in self.list_all(
            method,
            select=select,
            filter_=filter_,
            order=order,
            extra_params=extra_params,
            result_key=result_key,
            limit=limit,
        ):
            items.append(item)
        return items
