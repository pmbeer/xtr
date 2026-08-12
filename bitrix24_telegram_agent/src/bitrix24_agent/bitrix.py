import asyncio
from typing import Any

import httpx


class BitrixAPIError(RuntimeError):
    def __init__(self, method: str, code: str, message: str) -> None:
        super().__init__(f"{method}: {code}: {message}")
        self.method = method
        self.code = code
        self.message = message


class BitrixClient:
    def __init__(self, webhook_url: str, timeout: float = 30) -> None:
        self._webhook_url = webhook_url.rstrip("/") + "/"
        self._client = httpx.AsyncClient(timeout=timeout)

    async def __aenter__(self) -> "BitrixClient":
        return self

    async def __aexit__(self, *_: object) -> None:
        await self.aclose()

    async def aclose(self) -> None:
        await self._client.aclose()

    async def call(self, method: str, params: dict[str, Any] | None = None) -> Any:
        url = f"{self._webhook_url}{method}.json"
        for attempt in range(3):
            try:
                response = await self._client.post(url, json=params or {})
                if response.status_code == 429 or response.status_code >= 500:
                    response.raise_for_status()
                response.raise_for_status()
                payload = response.json()
            except (httpx.TimeoutException, httpx.NetworkError, httpx.HTTPStatusError):
                if attempt == 2:
                    raise
                await asyncio.sleep(2**attempt)
                continue

            if "error" in payload:
                raise BitrixAPIError(
                    method,
                    str(payload["error"]),
                    str(payload.get("error_description", "Bitrix24 returned an error")),
                )
            return payload.get("result")
        raise RuntimeError("Unreachable")

    async def list_tasks(
        self,
        task_filter: dict[str, Any],
        select: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        tasks: list[dict[str, Any]] = []
        start = 0
        while True:
            result = await self.call(
                "tasks.task.list",
                {
                    "filter": task_filter,
                    "select": select or ["*"],
                    "order": {"ID": "ASC"},
                    "start": start,
                },
            )
            page = result.get("tasks", []) if isinstance(result, dict) else []
            tasks.extend(page)
            if len(page) < 50:
                break
            start += 50
        return tasks

    async def get_current_user_id(self) -> int:
        profile = await self.call("profile")
        return int(profile["ID"])

    async def get_stages(self, entity_id: int) -> dict[str, str]:
        result = await self.call("task.stages.get", {"entityId": entity_id})
        if not isinstance(result, dict):
            return {}
        return {
            str(stage.get("ID", stage_id)): str(stage.get("TITLE", "Без названия"))
            for stage_id, stage in result.items()
            if isinstance(stage, dict)
        }
