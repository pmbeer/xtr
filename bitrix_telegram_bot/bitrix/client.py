"""Клиент REST API Bitrix24."""

from __future__ import annotations

from datetime import datetime
from typing import Any

import httpx


class Bitrix24Client:
    """Асинхронный клиент для работы с REST API Bitrix24 через входящий вебхук."""

    def __init__(self, webhook_url: str, timeout: float = 60.0) -> None:
        self._base_url = webhook_url.rstrip("/")
        self._timeout = timeout

    async def call(self, method: str, params: dict[str, Any] | None = None) -> Any:
        url = f"{self._base_url}/{method}"
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            response = await client.post(url, json=params or {})
            response.raise_for_status()
            data = response.json()
            if "error" in data:
                raise Bitrix24Error(
                    data.get("error_description", data.get("error", "Unknown error")),
                    error_code=data.get("error"),
                )
            return data.get("result")

    async def call_batch_pages(
        self,
        method: str,
        params: dict[str, Any],
        result_key: str | None = None,
    ) -> list[Any]:
        """Загрузить все страницы результата (пагинация через start)."""
        all_items: list[Any] = []
        start = 0

        while True:
            page_params = {**params, "start": start}
            result = await self.call(method, page_params)

            if isinstance(result, dict):
                if result_key:
                    items = result.get(result_key, [])
                else:
                    items = result.get("tasks", result.get("items", []))
                all_items.extend(items)
                next_start = result.get("next")
                if next_start is None:
                    break
                start = next_start
            elif isinstance(result, list):
                all_items.extend(result)
                break
            else:
                break

        return all_items

    async def get_user_tasks(
        self,
        user_id: int,
        date_from: datetime | None = None,
        date_to: datetime | None = None,
    ) -> list[dict[str, Any]]:
        """Получить задачи, где пользователь — ответственный."""
        filter_params: dict[str, Any] = {"RESPONSIBLE_ID": user_id}

        if date_from:
            filter_params[">=CREATED_DATE"] = date_from.strftime("%Y-%m-%dT%H:%M:%S")
        if date_to:
            filter_params["<=CREATED_DATE"] = date_to.strftime("%Y-%m-%dT%H:%M:%S")

        params = {
            "filter": filter_params,
            "select": [
                "ID",
                "TITLE",
                "STATUS",
                "STAGE_ID",
                "CREATED_DATE",
                "CLOSED_DATE",
                "DEADLINE",
                "RESPONSIBLE_ID",
                "CREATED_BY",
                "GROUP_ID",
            ],
        }

        return await self.call_batch_pages("tasks.task.list", params, result_key="tasks")

    async def get_openline_sessions(
        self,
        operator_id: int,
        date_from: datetime | None = None,
        date_to: datetime | None = None,
    ) -> list[dict[str, Any]]:
        """Получить сессии открытой линии оператора."""
        filter_params: dict[str, Any] = {"OPERATOR_ID": operator_id}

        if date_from:
            filter_params[">=DATE_CREATE"] = date_from.strftime("%Y-%m-%dT%H:%M:%S")
        if date_to:
            filter_params["<=DATE_CREATE"] = date_to.strftime("%Y-%m-%dT%H:%M:%S")

        params = {
            "filter": filter_params,
            "select": [
                "ID",
                "CONFIG_ID",
                "OPERATOR_ID",
                "USER_CODE",
                "DATE_CREATE",
                "DATE_CLOSE",
                "DATE_OPERATOR",
                "STATUS",
                "CLOSE_REASON",
                "CHAT_ID",
            ],
        }

        try:
            return await self.call_batch_pages("imopenlines.session.list", params)
        except Bitrix24Error:
            return await self._get_openline_sessions_fallback(
                operator_id, date_from, date_to
            )

    async def _get_openline_sessions_fallback(
        self,
        operator_id: int,
        date_from: datetime | None,
        date_to: datetime | None,
    ) -> list[dict[str, Any]]:
        """Альтернативный метод через CRM-активности, если session.list недоступен."""
        filter_params: dict[str, Any] = {
            "RESPONSIBLE_ID": operator_id,
            "PROVIDER_ID": "IMOPENLINES_SESSION",
        }

        if date_from:
            filter_params[">=CREATED"] = date_from.strftime("%Y-%m-%dT%H:%M:%S")
        if date_to:
            filter_params["<=CREATED"] = date_to.strftime("%Y-%m-%dT%H:%M:%S")

        params = {
            "filter": filter_params,
            "select": ["ID", "SUBJECT", "CREATED", "END_TIME", "STATUS", "RESPONSIBLE_ID"],
        }

        return await self.call_batch_pages("crm.activity.list", params)

    async def get_user_info(self, user_id: int) -> dict[str, Any]:
        result = await self.call("user.get", {"ID": user_id})
        if isinstance(result, list) and result:
            return result[0]
        return {}


class Bitrix24Error(Exception):
    def __init__(self, message: str, error_code: str | None = None) -> None:
        super().__init__(message)
        self.error_code = error_code
