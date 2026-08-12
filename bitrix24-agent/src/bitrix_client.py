"""Клиент REST API Bitrix24."""

from __future__ import annotations

import time
from typing import Any

import httpx


class Bitrix24Error(Exception):
    def __init__(self, message: str, *, error_code: str | None = None):
        super().__init__(message)
        self.error_code = error_code


class Bitrix24Client:
    PAGE_SIZE = 50
    REQUEST_DELAY_SEC = 0.35

    def __init__(self, webhook_url: str):
        self.webhook_url = webhook_url.rstrip("/")
        self._http = httpx.Client(timeout=60.0)

    def close(self) -> None:
        self._http.close()

    def __enter__(self) -> Bitrix24Client:
        return self

    def __exit__(self, *args: object) -> None:
        self.close()

    def call(self, method: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        url = f"{self.webhook_url}/{method}"
        response = self._http.post(url, json=params or {})
        response.raise_for_status()
        payload = response.json()

        if "error" in payload:
            raise Bitrix24Error(
                payload.get("error_description", payload["error"]),
                error_code=payload.get("error"),
            )

        return payload.get("result", payload)

    def call_all(
        self,
        method: str,
        params: dict[str, Any] | None = None,
        *,
        result_key: str | None = None,
    ) -> list[dict[str, Any]]:
        """Получить все записи с пагинацией (классический REST API)."""
        params = dict(params or {})
        all_items: list[dict[str, Any]] = []
        start = 0

        while True:
            params["start"] = start
            raw = self.call(method, params)

            if isinstance(raw, list):
                items = raw
                total = None
            elif isinstance(raw, dict):
                if result_key and result_key in raw:
                    items = raw[result_key]
                elif "tasks" in raw:
                    items = raw["tasks"]
                elif "items" in raw:
                    items = raw["items"]
                elif "sessions" in raw:
                    items = raw["sessions"]
                else:
                    items = list(raw.values())[0] if raw else []
                total = raw.get("total") if isinstance(raw, dict) else None
            else:
                break

            if not items:
                break

            all_items.extend(items)
            start += self.PAGE_SIZE

            if total is not None and start >= total:
                break
            if len(items) < self.PAGE_SIZE:
                break

            time.sleep(self.REQUEST_DELAY_SEC)

        return all_items

    def get_current_user(self) -> dict[str, Any]:
        return self.call("user.current")

    def method_available(self, method: str) -> bool:
        try:
            self.call(method, {})
            return True
        except Bitrix24Error as exc:
            if exc.error_code in {"ERROR_METHOD_NOT_FOUND", "METHOD_NOT_FOUND"}:
                return False
            return True
        except httpx.HTTPError:
            return False
