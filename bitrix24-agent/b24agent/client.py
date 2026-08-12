"""REST-клиент для облачного Битрикс24 (входящий вебхук).

Использует стандартный REST-эндпоинт вида
``https://<портал>.bitrix24.ru/rest/<user_id>/<token>/``.
"""

from __future__ import annotations

import time
from typing import Any, Dict, Iterator, List, Optional

import requests


class Bitrix24Error(Exception):
    """Ошибка, которую вернул REST Битрикс24."""

    def __init__(self, code: str, description: str, http_status: int = 0):
        self.code = code or ""
        self.description = description or ""
        self.http_status = http_status
        super().__init__(f"{self.code}: {self.description}".strip(": "))


class MethodNotAvailableError(Bitrix24Error):
    """Метод не существует на портале (не приехало обновление или нет модуля)."""


#: Коды ошибок, означающие «метода на портале нет».
_NOT_AVAILABLE_CODES = {
    "ERROR_METHOD_NOT_FOUND",
    "METHOD_NOT_FOUND",
    "METHOD_NOT_YET_AVAILABLE",
}

#: Коды, при которых имеет смысл повторить запрос с паузой.
_RETRYABLE_CODES = {"QUERY_LIMIT_EXCEEDED", "OPERATION_TIME_LIMIT", "INTERNAL_SERVER_ERROR"}


class Bitrix24Client:
    """Синхронный клиент с троттлингом и повторами.

    Облачный Битрикс24 ограничивает интенсивность запросов (~2 запроса/сек),
    поэтому клиент сам выдерживает паузу между вызовами и повторяет запрос
    при ошибке ``QUERY_LIMIT_EXCEEDED``.
    """

    def __init__(
        self,
        webhook_url: str,
        timeout: float = 60.0,
        max_retries: int = 5,
        requests_per_second: float = 2.0,
    ):
        if not webhook_url:
            raise ValueError("Не задан URL входящего вебхука Битрикс24")
        self.webhook_url = webhook_url.rstrip("/") + "/"
        self.timeout = timeout
        self.max_retries = max_retries
        self._min_interval = 1.0 / requests_per_second if requests_per_second > 0 else 0.0
        self._last_request_at = 0.0
        self._session = requests.Session()

    # ------------------------------------------------------------------ core

    def call(self, method: str, params: Optional[Dict[str, Any]] = None) -> Any:
        """Вызывает REST-метод и возвращает содержимое ``result``."""
        return self.call_raw(method, params).get("result")

    def call_raw(self, method: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Вызывает REST-метод и возвращает весь ответ (нужны ``next``/``total``)."""
        payload = params or {}
        url = self.webhook_url + method
        attempt = 0
        while True:
            self._throttle()
            try:
                response = self._session.post(url, json=payload, timeout=self.timeout)
            except requests.RequestException as exc:
                attempt += 1
                if attempt > self.max_retries:
                    raise Bitrix24Error("NETWORK_ERROR", str(exc)) from exc
                time.sleep(min(2 ** attempt, 30))
                continue

            data = self._parse_json(response)
            error_code = str(data.get("error", "") or "")
            if not error_code and response.ok:
                return data

            description = str(data.get("error_description", "") or response.reason or "")
            if error_code.upper() in _NOT_AVAILABLE_CODES or response.status_code == 404:
                raise MethodNotAvailableError(
                    error_code or "METHOD_NOT_FOUND", description, response.status_code
                )
            if error_code.upper() in _RETRYABLE_CODES and attempt < self.max_retries:
                attempt += 1
                time.sleep(min(2 ** attempt, 30))
                continue
            raise Bitrix24Error(
                error_code or f"HTTP_{response.status_code}", description, response.status_code
            )

    # ------------------------------------------------------------- iterators

    def iter_list(
        self,
        method: str,
        params: Optional[Dict[str, Any]] = None,
        items_key: Optional[str] = None,
    ) -> Iterator[Dict[str, Any]]:
        """Итерирует элементы списочного метода со ``start``-пагинацией.

        Работает с методами вида ``tasks.task.list``: ответ содержит
        ``result`` (список либо словарь с ключом *items_key*) и ``next``.
        """
        params = dict(params or {})
        start = 0
        while True:
            page_params = dict(params)
            page_params["start"] = start
            data = self.call_raw(method, page_params)
            items = self._extract_items(data.get("result"), items_key)
            for item in items:
                yield item
            next_start = data.get("next")
            if next_start is None or not items:
                return
            start = int(next_start)

    def iter_offset_list(
        self,
        method: str,
        params: Optional[Dict[str, Any]] = None,
        items_key: str = "sessions",
        page_size: int = 200,
        max_items: int = 100_000,
    ) -> Iterator[Dict[str, Any]]:
        """Итерирует элементы методов с ``limit``/``offset``-пагинацией.

        Используется для ``imopenlines.v2.Session.list``: ответ содержит
        список элементов и флаг ``hasNextPage``.
        """
        params = dict(params or {})
        offset = int(params.pop("offset", 0))
        limit = int(params.pop("limit", page_size))
        fetched = 0
        while True:
            page_params = dict(params)
            page_params["limit"] = limit
            page_params["offset"] = offset
            result = self.call(method, page_params)
            items = self._extract_items(result, items_key)
            for item in items:
                yield item
                fetched += 1
                if fetched >= max_items:
                    return
            has_next = bool(isinstance(result, dict) and result.get("hasNextPage"))
            if not has_next or not items:
                return
            offset += limit

    # -------------------------------------------------------------- helpers

    @staticmethod
    def _extract_items(result: Any, items_key: Optional[str]) -> List[Dict[str, Any]]:
        if result is None:
            return []
        if isinstance(result, list):
            return result
        if isinstance(result, dict):
            keys = (items_key,) if items_key else ("tasks", "items", "sessions")
            for key in keys:
                if key and key in result:
                    value = result[key]
                    return list(value.values()) if isinstance(value, dict) else list(value or [])
        return []

    @staticmethod
    def _parse_json(response: requests.Response) -> Dict[str, Any]:
        try:
            data = response.json()
        except ValueError:
            return {"error": f"HTTP_{response.status_code}", "error_description": response.text[:500]}
        return data if isinstance(data, dict) else {"result": data}

    def _throttle(self) -> None:
        if self._min_interval <= 0:
            return
        elapsed = time.monotonic() - self._last_request_at
        if elapsed < self._min_interval:
            time.sleep(self._min_interval - elapsed)
        self._last_request_at = time.monotonic()
