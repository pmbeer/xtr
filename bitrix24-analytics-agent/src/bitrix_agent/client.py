from __future__ import annotations

import logging
import time
from typing import Any, Optional

import requests

logger = logging.getLogger(__name__)


class BitrixAPIError(RuntimeError):
    def __init__(self, message: str, *, error: str | None = None, payload: Any = None):
        super().__init__(message)
        self.error = error
        self.payload = payload


class BitrixClient:
    """Thin REST client for Bitrix24 incoming webhooks."""

    def __init__(
        self,
        webhook_url: str,
        *,
        timeout: float = 30.0,
        max_retries: int = 3,
        pause_between_pages: float = 0.35,
    ) -> None:
        if not webhook_url.endswith("/"):
            webhook_url += "/"
        self.webhook_url = webhook_url
        self.timeout = timeout
        self.max_retries = max_retries
        self.pause_between_pages = pause_between_pages
        self.session = requests.Session()

    def _request(self, method: str, params: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        url = f"{self.webhook_url}{method}"
        params = params or {}
        last_error: Exception | None = None

        for attempt in range(1, self.max_retries + 1):
            try:
                response = self.session.post(url, json=params, timeout=self.timeout)
                response.raise_for_status()
                data = response.json()
            except (requests.RequestException, ValueError) as exc:
                last_error = exc
                time.sleep(min(2 ** attempt, 8))
                continue

            if "error" in data:
                error = str(data.get("error"))
                description = data.get("error_description") or error
                if error in {
                    "ERROR_METHOD_NOT_FOUND",
                    "METHOD_NOT_FOUND",
                    "METHOD_NOT_YET_AVAILABLE",
                    "ACCESS_DENIED",
                    "insufficient_scope",
                    "NO_AUTH_FOUND",
                }:
                    raise BitrixAPIError(
                        f"{method}: {description}",
                        error=error,
                        payload=data,
                    )
                if error == "QUERY_LIMIT_EXCEEDED":
                    time.sleep(min(2 ** attempt, 8))
                    continue
                raise BitrixAPIError(
                    f"{method}: {description}",
                    error=error,
                    payload=data,
                )
            return data

        raise BitrixAPIError(f"{method}: network failure: {last_error}")

    def call(self, method: str, params: Optional[dict[str, Any]] = None) -> Any:
        return self._request(method, params).get("result")

    def call_list(
        self,
        method: str,
        params: Optional[dict[str, Any]] = None,
        *,
        result_key: str | None = None,
        start: int = 0,
        max_items: int | None = None,
    ) -> list[Any]:
        """Paginate classic Bitrix list methods that return `next`/`total`."""
        params = dict(params or {})
        items: list[Any] = []
        cursor = start

        while True:
            page_params = dict(params)
            page_params["start"] = cursor
            data = self._request(method, page_params)
            raw = data.get("result")

            chunk: list[Any]
            if isinstance(raw, list):
                chunk = raw
            elif isinstance(raw, dict):
                if result_key and result_key in raw:
                    chunk = list(raw[result_key] or [])
                elif "tasks" in raw:
                    chunk = list(raw["tasks"] or [])
                elif "items" in raw:
                    chunk = list(raw["items"] or [])
                else:
                    values = list(raw.values())
                    chunk = values if values and isinstance(values[0], dict) else []
            else:
                chunk = []

            items.extend(chunk)
            if max_items is not None and len(items) >= max_items:
                return items[:max_items]

            nxt = data.get("next")
            if nxt is None:
                break
            cursor = int(nxt)
            time.sleep(self.pause_between_pages)

        return items

    def current_user(self) -> dict[str, Any]:
        result = self.call("user.current")
        if not isinstance(result, dict):
            raise BitrixAPIError("user.current returned unexpected payload")
        return result

    def resolve_user_id(self, explicit: int | None = None) -> int:
        if explicit:
            return int(explicit)
        user = self.current_user()
        return int(user["ID"])
