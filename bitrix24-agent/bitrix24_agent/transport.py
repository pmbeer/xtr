"""HTTP-транспорт к REST Битрикс24: лимит частоты, повторы, разбор ошибок."""

from __future__ import annotations

import json
import logging
import random
import threading
import time
import urllib.error
import urllib.request
from collections.abc import Mapping
from typing import Any, Protocol

from .errors import Bitrix24Error, TransportError

log = logging.getLogger(__name__)

#: Ошибки, при которых имеет смысл повторить запрос.
RETRYABLE_CODES = frozenset(
    {
        "QUERY_LIMIT_EXCEEDED",
        "OPERATION_TIME_LIMIT",
        "INTERNAL_SERVER_ERROR",
        "ERROR_UNEXPECTED_ANSWER",
        "ERROR_CORE",
    }
)
RETRYABLE_STATUSES = frozenset({429, 500, 502, 503, 504})

MAX_BACKOFF_SECONDS = 30.0


class Transport(Protocol):
    """Минимальный контракт транспорта — облегчает подмену в тестах."""

    def request(self, method: str, params: Mapping[str, Any] | None = None) -> dict:
        """Вызывает метод REST и возвращает конверт ответа целиком."""


class RateLimiter:
    """Равномерно разносит запросы во времени.

    Облако Битрикс24 ограничивает интенсивность (обычно 2 запроса в секунду,
    Enterprise — 5) и при превышении отдаёт `QUERY_LIMIT_EXCEEDED`.
    """

    def __init__(self, rate_per_second: float):
        self._interval = 1.0 / rate_per_second if rate_per_second > 0 else 0.0
        self._lock = threading.Lock()
        self._next_allowed_at = 0.0

    def acquire(self) -> None:
        if self._interval <= 0:
            return
        with self._lock:
            now = time.monotonic()
            delay = self._next_allowed_at - now
            if delay > 0:
                time.sleep(delay)
                now = time.monotonic()
            self._next_allowed_at = now + self._interval


class WebhookTransport:
    """Транспорт поверх входящего вебхука Битрикс24."""

    def __init__(
        self,
        base_url: str,
        *,
        timeout: float = 30.0,
        rate_limit: float = 2.0,
        max_retries: int = 4,
        user_agent: str = "bitrix24-analytics-agent/1.0",
    ):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.max_retries = max_retries
        self.user_agent = user_agent
        self.limiter = RateLimiter(rate_limit)
        self.calls_made = 0

    def request(self, method: str, params: Mapping[str, Any] | None = None) -> dict:
        url = f"{self.base_url}/{method}.json"
        body = json.dumps(params or {}, ensure_ascii=False).encode("utf-8")
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": self.user_agent,
        }

        last_error: Exception | None = None
        for attempt in range(self.max_retries + 1):
            self.limiter.acquire()
            self.calls_made += 1
            try:
                status, payload = self._send(url, body, headers)
            except TransportError as exc:
                last_error = exc
                if attempt >= self.max_retries:
                    raise
                self._sleep_before_retry(attempt, method, str(exc))
                continue

            error_code = self._error_code(payload)
            if status == 200 and not error_code:
                return payload

            description = str(
                payload.get("error_description") or payload.get("error_information") or ""
            )
            retryable = status in RETRYABLE_STATUSES or error_code in RETRYABLE_CODES
            if retryable and attempt < self.max_retries:
                self._sleep_before_retry(attempt, method, error_code or f"HTTP {status}")
                continue
            raise Bitrix24Error(method, error_code or f"HTTP_{status}", description, status)

        raise TransportError(f"{method}: запрос не удался") from last_error

    def _send(self, url: str, body: bytes, headers: Mapping[str, str]) -> tuple[int, dict]:
        request = urllib.request.Request(url, data=body, headers=dict(headers), method="POST")
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                raw = response.read()
                status = response.status
        except urllib.error.HTTPError as exc:
            raw = exc.read()
            status = exc.code
        except urllib.error.URLError as exc:
            raise TransportError(f"сеть недоступна: {exc.reason}") from exc
        except TimeoutError as exc:
            raise TransportError("превышено время ожидания ответа портала") from exc

        if not raw:
            return status, {}
        try:
            payload = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            preview = raw[:200].decode("utf-8", errors="replace")
            raise TransportError(f"портал вернул не JSON (HTTP {status}): {preview!r}") from exc
        if not isinstance(payload, dict):
            raise TransportError(f"портал вернул неожиданную структуру ответа: {type(payload)}")
        return status, payload

    @staticmethod
    def _error_code(payload: Mapping[str, Any]) -> str:
        error = payload.get("error")
        if isinstance(error, str):
            return error
        if isinstance(error, Mapping):
            return str(error.get("code") or error.get("error") or "UNKNOWN_ERROR")
        return ""

    def _sleep_before_retry(self, attempt: int, method: str, reason: str) -> None:
        delay = min(MAX_BACKOFF_SECONDS, (2.0**attempt)) + random.uniform(0, 0.5)
        log.warning(
            "%s: %s, повтор через %.1f с (попытка %d из %d)",
            method,
            reason,
            delay,
            attempt + 1,
            self.max_retries,
        )
        time.sleep(delay)
