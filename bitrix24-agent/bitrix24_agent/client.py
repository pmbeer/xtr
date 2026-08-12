"""Низкоуровневый клиент REST API Битрикс24 (на основе входящего вебхука).

Использует только официально документированные методы REST API Битрикс24
(https://apidocs.bitrix24.com/). Никакие сторонние прокси или сервисы не
используются — все запросы идут напрямую на домен вашего портала.
"""

from __future__ import annotations

import time
from typing import Any, Dict, Iterable, Iterator, List, Optional
from urllib.parse import urljoin

import requests

DEFAULT_TIMEOUT = 30
MAX_RETRIES = 5
PAGE_SIZE = 50  # размер страницы, который Битрикс24 использует для *.list методов


class BitrixApiError(RuntimeError):
    """Битрикс24 вернул ошибку уровня приложения (поле `error` в ответе)."""

    def __init__(self, method: str, error: str, description: str):
        self.method = method
        self.error = error
        self.description = description
        super().__init__(f"{method}: {error} — {description}")


class BitrixClient:
    """Тонкая обёртка над REST API Битрикс24 через входящий вебхук."""

    def __init__(
        self,
        webhook_url: str,
        session: Optional[requests.Session] = None,
        timeout: int = DEFAULT_TIMEOUT,
    ):
        if not webhook_url.endswith("/"):
            webhook_url += "/"
        self.webhook_url = webhook_url
        self.session = session or requests.Session()
        self.timeout = timeout

    def call(self, method: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Вызывает произвольный метод REST API и возвращает поле `result`."""
        url = urljoin(self.webhook_url, f"{method}.json")
        params = params or {}

        last_error: Optional[Exception] = None
        for attempt in range(1, MAX_RETRIES + 1):
            try:
                response = self.session.post(url, json=params, timeout=self.timeout)
            except requests.RequestException as exc:
                last_error = exc
                time.sleep(min(2 ** attempt, 16))
                continue

            if response.status_code == 503 or response.status_code == 429:
                # QUERY_LIMIT_EXCEEDED — превышен лимит интенсивности запросов.
                time.sleep(min(2 ** attempt, 16))
                continue

            try:
                payload = response.json()
            except ValueError as exc:
                last_error = exc
                time.sleep(min(2 ** attempt, 16))
                continue

            if "error" in payload:
                error_code = payload.get("error", "UNKNOWN_ERROR")
                if error_code == "QUERY_LIMIT_EXCEEDED":
                    time.sleep(min(2 ** attempt, 16))
                    continue
                raise BitrixApiError(
                    method,
                    error_code,
                    payload.get("error_description", ""),
                )

            return payload.get("result", payload)

        raise RuntimeError(
            f"Не удалось выполнить запрос {method} после {MAX_RETRIES} попыток: {last_error}"
        )

    def call_list(
        self,
        method: str,
        filter_: Optional[Dict[str, Any]] = None,
        select: Optional[Iterable[str]] = None,
        order: Optional[Dict[str, str]] = None,
        extra_params: Optional[Dict[str, Any]] = None,
    ) -> Iterator[Dict[str, Any]]:
        """Постранично перебирает все элементы *.list метода (генератор)."""
        start = 0
        while True:
            params: Dict[str, Any] = dict(extra_params or {})
            if filter_ is not None:
                params["filter"] = filter_
            if select is not None:
                params["select"] = list(select)
            if order is not None:
                params["order"] = order
            params["start"] = start

            url = urljoin(self.webhook_url, f"{method}.json")
            raw = self._raw_call(url, params)

            result = raw.get("result", [])
            items: List[Dict[str, Any]] = result if isinstance(result, list) else result.get("tasks", result)
            if not items:
                break

            for item in items:
                yield item

            next_start = raw.get("next")
            if next_start is None:
                break
            start = next_start

    def _raw_call(self, url: str, params: Dict[str, Any]) -> Dict[str, Any]:
        last_error: Optional[Exception] = None
        for attempt in range(1, MAX_RETRIES + 1):
            try:
                response = self.session.post(url, json=params, timeout=self.timeout)
            except requests.RequestException as exc:
                last_error = exc
                time.sleep(min(2 ** attempt, 16))
                continue

            if response.status_code in (503, 429):
                time.sleep(min(2 ** attempt, 16))
                continue

            try:
                payload = response.json()
            except ValueError as exc:
                last_error = exc
                time.sleep(min(2 ** attempt, 16))
                continue

            if "error" in payload:
                error_code = payload.get("error", "UNKNOWN_ERROR")
                if error_code == "QUERY_LIMIT_EXCEEDED":
                    time.sleep(min(2 ** attempt, 16))
                    continue
                method_name = url.rsplit("/", 1)[-1].removesuffix(".json")
                raise BitrixApiError(method_name, error_code, payload.get("error_description", ""))

            return payload

        raise RuntimeError(f"Не удалось выполнить запрос после {MAX_RETRIES} попыток: {last_error}")

    def current_user_id(self) -> int:
        """Возвращает ID пользователя, от имени которого работает вебхук."""
        result = self.call("user.current")
        return int(result["ID"])
