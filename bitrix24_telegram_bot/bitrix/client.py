"""Асинхронный клиент Bitrix24 REST (через входящий вебхук).

Поддерживает автоматическую пагинацию списочных методов и
бережно относится к лимитам REST (2 запроса в секунду).
"""

import asyncio
import logging
from typing import Any

import aiohttp

logger = logging.getLogger(__name__)

# Bitrix24 отдаёт списки страницами по 50 элементов.
PAGE_SIZE = 50
# Ограничение облачного Bitrix24 — 2 запроса в секунду.
REQUEST_INTERVAL = 0.5
MAX_RETRIES = 3


class Bitrix24Error(Exception):
    """Ошибка, возвращённая REST API Bitrix24."""

    def __init__(self, code: str, description: str):
        self.code = code
        self.description = description
        super().__init__(f"{code}: {description}")


class Bitrix24Client:
    def __init__(self, webhook_url: str):
        self._webhook_url = webhook_url.rstrip("/") + "/"
        self._session: aiohttp.ClientSession | None = None
        self._lock = asyncio.Lock()
        self._last_request_at = 0.0

    async def __aenter__(self) -> "Bitrix24Client":
        await self._ensure_session()
        return self

    async def __aexit__(self, *exc_info) -> None:
        await self.close()

    async def _ensure_session(self) -> aiohttp.ClientSession:
        if self._session is None or self._session.closed:
            self._session = aiohttp.ClientSession(
                timeout=aiohttp.ClientTimeout(total=60)
            )
        return self._session

    async def close(self) -> None:
        if self._session and not self._session.closed:
            await self._session.close()

    async def _throttle(self) -> None:
        async with self._lock:
            loop = asyncio.get_running_loop()
            wait = self._last_request_at + REQUEST_INTERVAL - loop.time()
            if wait > 0:
                await asyncio.sleep(wait)
            self._last_request_at = loop.time()

    async def call(self, method: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        """Выполнить REST-метод и вернуть весь ответ (result, total, next...)."""
        session = await self._ensure_session()
        url = f"{self._webhook_url}{method}.json"

        for attempt in range(1, MAX_RETRIES + 1):
            await self._throttle()
            try:
                async with session.post(url, json=params or {}) as response:
                    payload = await response.json(content_type=None)
            except (aiohttp.ClientError, asyncio.TimeoutError) as exc:
                if attempt == MAX_RETRIES:
                    raise Bitrix24Error("NETWORK_ERROR", str(exc)) from exc
                await asyncio.sleep(attempt)
                continue

            if isinstance(payload, dict) and payload.get("error"):
                code = str(payload.get("error"))
                description = str(payload.get("error_description", ""))
                # При превышении лимита запросов повторяем попытку.
                if code == "QUERY_LIMIT_EXCEEDED" and attempt < MAX_RETRIES:
                    await asyncio.sleep(attempt * 2)
                    continue
                raise Bitrix24Error(code, description)
            return payload

        raise Bitrix24Error("UNKNOWN", "Не удалось выполнить запрос")

    async def call_list(
        self,
        method: str,
        params: dict[str, Any] | None = None,
        max_items: int = 5000,
    ) -> list[dict[str, Any]]:
        """Выполнить списочный метод, собрав все страницы результата.

        Работает и с методами, возвращающими список напрямую
        (crm.activity.list), и с методами, оборачивающими список
        в словарь (tasks.task.list -> {"tasks": [...]}).
        """
        params = dict(params or {})
        items: list[dict[str, Any]] = []
        start = 0

        while True:
            params["start"] = start
            payload = await self.call(method, params)
            result = payload.get("result")

            page: list[dict[str, Any]]
            if isinstance(result, list):
                page = result
            elif isinstance(result, dict):
                # Берём первое списочное значение (tasks, items и т.п.)
                page = next(
                    (value for value in result.values() if isinstance(value, list)),
                    [],
                )
            else:
                page = []

            items.extend(page)

            next_start = payload.get("next")
            if next_start is None or not page or len(items) >= max_items:
                if len(items) >= max_items:
                    logger.warning(
                        "Метод %s вернул более %s элементов, выборка усечена",
                        method,
                        max_items,
                    )
                break
            start = int(next_start)

        return items[:max_items]
