from __future__ import annotations

import asyncio
import logging
from typing import Any, Dict, List, Optional

import aiohttp

logger = logging.getLogger(__name__)


class BitrixAPIError(RuntimeError):
    pass


class BitrixClient:
    """Клиент входящего вебхука Bitrix24 Cloud REST."""

    def __init__(self, webhook_url: str, *, timeout: float = 30.0) -> None:
        if not webhook_url:
            raise ValueError("BITRIX_WEBHOOK_URL is empty")
        self.webhook_url = webhook_url if webhook_url.endswith("/") else webhook_url + "/"
        self.timeout = aiohttp.ClientTimeout(total=timeout)
        self._session: Optional[aiohttp.ClientSession] = None

    async def __aenter__(self) -> "BitrixClient":
        self._session = aiohttp.ClientSession(timeout=self.timeout)
        return self

    async def __aexit__(self, *exc: object) -> None:
        if self._session:
            await self._session.close()
            self._session = None

    async def call(self, method: str, params: Optional[Dict[str, Any]] = None) -> Any:
        session = self._session
        if session is None:
            raise RuntimeError("BitrixClient must be used as async context manager")

        url = f"{self.webhook_url}{method}"
        payload = params or {}
        async with session.post(url, json=payload) as response:
            data = await response.json(content_type=None)
            if response.status >= 400:
                raise BitrixAPIError(f"HTTP {response.status} for {method}: {data}")
            if isinstance(data, dict) and data.get("error"):
                raise BitrixAPIError(
                    f"{method}: {data.get('error')} — {data.get('error_description', '')}".strip()
                )
            return data.get("result", data)

    async def call_list(
        self,
        method: str,
        params: Optional[Dict[str, Any]] = None,
        *,
        items_key: Optional[str] = None,
        start_param: str = "start",
        page_size: int = 50,
        max_pages: int = 40,
    ) -> List[Any]:
        """Пагинация Bitrix (start += 50)."""
        params = dict(params or {})
        start = 0
        items: List[Any] = []

        for _ in range(max_pages):
            page_params = dict(params)
            page_params[start_param] = start
            result = await self.call(method, page_params)

            page_items: List[Any]
            next_start: Optional[int] = None

            if isinstance(result, list):
                page_items = result
            elif isinstance(result, dict):
                if items_key and items_key in result:
                    page_items = list(result.get(items_key) or [])
                elif "tasks" in result:
                    page_items = list(result.get("tasks") or [])
                elif "items" in result:
                    page_items = list(result.get("items") or [])
                else:
                    # иногда result — словарь записей
                    page_items = list(result.values()) if result else []
                raw_next = result.get("next") if isinstance(result, dict) else None
                if raw_next is not None:
                    next_start = int(raw_next)
            else:
                page_items = []

            items.extend(page_items)

            # В корневом ответе next лежит рядом с result — повторный вызов без next
            # Для tasks.task.list next приходит в корне JSON, не в result.
            # Поэтому делаем отдельный запрос с контролем длины страницы.
            if next_start is not None:
                start = next_start
                continue
            if len(page_items) < page_size:
                break
            start += page_size
            await asyncio.sleep(0.05)

        return items

    async def get_user(self, user_id: int) -> Dict[str, Any]:
        users = await self.call("user.get", {"ID": user_id})
        if isinstance(users, list) and users:
            return users[0]
        if isinstance(users, dict):
            return users
        return {"ID": user_id, "NAME": f"User {user_id}"}

    async def get_current_user(self) -> Dict[str, Any]:
        return await self.call("user.current")

    async def list_tasks(self, filter_: Dict[str, Any], select: List[str]) -> List[Dict[str, Any]]:
        """tasks.task.list с пагинацией через корневой next."""
        session = self._session
        if session is None:
            raise RuntimeError("BitrixClient must be used as async context manager")

        start = 0
        tasks: List[Dict[str, Any]] = []
        for _ in range(40):
            payload = {
                "filter": filter_,
                "select": select,
                "order": {"ID": "DESC"},
                "start": start,
            }
            url = f"{self.webhook_url}tasks.task.list"
            async with session.post(url, json=payload) as response:
                data = await response.json(content_type=None)
            if isinstance(data, dict) and data.get("error"):
                raise BitrixAPIError(
                    f"tasks.task.list: {data.get('error')} — {data.get('error_description', '')}"
                )
            result = (data or {}).get("result") or {}
            page = result.get("tasks") or []
            tasks.extend(page)
            next_start = data.get("next") if isinstance(data, dict) else None
            if next_start is None:
                break
            start = int(next_start)
            await asyncio.sleep(0.05)
        return tasks

    async def get_task_stages(self, entity_id: int = 0) -> Dict[str, str]:
        """Справочник стадий канбана. entity_id=0 — личный канбан."""
        try:
            result = await self.call("task.stages.get", {"entityId": entity_id})
        except BitrixAPIError as exc:
            logger.warning("task.stages.get failed: %s", exc)
            return {}
        mapping: Dict[str, str] = {}
        if isinstance(result, dict):
            for stage_id, stage in result.items():
                if isinstance(stage, dict):
                    mapping[str(stage.get("ID", stage_id))] = str(stage.get("TITLE") or stage_id)
                else:
                    mapping[str(stage_id)] = str(stage)
        return mapping

    async def list_openline_sessions_v2(
        self,
        *,
        operator_id: int,
        date_from: str,
        date_to: str,
    ) -> List[Dict[str, Any]]:
        """Попытка через imopenlines.v2.Session.list (новые порталы)."""
        try:
            items = await self.call_list(
                "imopenlines.v2.Session.list",
                {
                    "filter": {
                        "operatorId": operator_id,
                        ">=dateCreate": date_from,
                        "<=dateCreate": date_to,
                    }
                },
                items_key="sessions",
            )
            return [item for item in items if isinstance(item, dict)]
        except BitrixAPIError as exc:
            logger.info("imopenlines.v2.Session.list unavailable: %s", exc)
            return []

    async def list_openline_activities(
        self,
        *,
        responsible_id: int,
        date_from: str,
        date_to: str,
    ) -> List[Dict[str, Any]]:
        """Fallback: CRM-активности открытых линий."""
        try:
            items = await self.call_list(
                "crm.activity.list",
                {
                    "filter": {
                        "RESPONSIBLE_ID": responsible_id,
                        "PROVIDER_ID": "IMOPENLINES_SESSION",
                        ">=START_TIME": date_from,
                        "<=START_TIME": date_to,
                    },
                    "select": [
                        "ID",
                        "SUBJECT",
                        "START_TIME",
                        "END_TIME",
                        "COMPLETED",
                        "RESPONSIBLE_ID",
                        "PROVIDER_TYPE_ID",
                        "DESCRIPTION",
                    ],
                    "order": {"ID": "DESC"},
                },
            )
            return [item for item in items if isinstance(item, dict)]
        except BitrixAPIError as exc:
            logger.info("crm.activity.list openlines fallback failed: %s", exc)
            return []
