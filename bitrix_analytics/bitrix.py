from __future__ import annotations

from collections import Counter
from datetime import datetime
from typing import Any

import httpx

from .models import ActivityMetrics, ReportPeriod

TASK_STATUS_NAMES = {
    "1": "Новая",
    "2": "Ждёт выполнения",
    "3": "В работе",
    "4": "Ждёт контроля",
    "5": "Завершена",
    "6": "Отложена",
    "7": "Отклонена",
}


class Bitrix24Error(RuntimeError):
    pass


class Bitrix24Client:
    """Small REST client for the endpoints required by the personal report."""

    def __init__(self, webhook_url: str, user_id: int, client: httpx.AsyncClient | None = None):
        self.webhook_url = webhook_url.rstrip("/") + "/"
        self.user_id = user_id
        self._client = client

    async def _call(self, method: str, payload: dict[str, Any]) -> Any:
        owns_client = self._client is None
        client = self._client or httpx.AsyncClient(timeout=30)
        try:
            response = await client.post(f"{self.webhook_url}{method}.json", json=payload)
            response.raise_for_status()
            body = response.json()
            if "error" in body:
                raise Bitrix24Error(f"{body['error']}: {body.get('error_description', '')}")
            return body.get("result", [])
        except httpx.HTTPError as exc:
            raise Bitrix24Error("Не удалось получить данные из Bitrix24") from exc
        finally:
            if owns_client:
                await client.aclose()

    async def _all_tasks(self, filters: dict[str, Any]) -> list[dict[str, Any]]:
        tasks: list[dict[str, Any]] = []
        start = 0
        while True:
            result = await self._call(
                "tasks.task.list",
                {
                    "filter": filters,
                    "select": ["ID", "STATUS", "DATE_CREATE", "CLOSED_DATE", "DATE_CLOSED"],
                    "start": start,
                },
            )
            if not result:
                return tasks
            tasks.extend(result)
            if len(result) < 50:
                return tasks
            start += 50

    async def _all_open_line_sessions(self, filters: dict[str, Any]) -> list[dict[str, Any]]:
        sessions: list[dict[str, Any]] = []
        start = 0
        while True:
            result = await self._call(
                "imopenlines.session.list",
                {"FILTER": filters, "SELECT": ["ID", "DATE_CREATE", "DATE_CLOSE", "OPERATOR_ID"], "START": start},
            )
            if not result:
                return sessions
            sessions.extend(result)
            if len(result) < 50:
                return sessions
            start += 50

    async def get_metrics(self, period: ReportPeriod) -> ActivityMetrics:
        date_from = period.start.isoformat()
        date_to = period.end.isoformat()
        closed, active, sessions = await self._collect(date_from, date_to)
        statuses = Counter(
            TASK_STATUS_NAMES.get(str(task.get("status") or task.get("STATUS")), "Неизвестно")
            for task in active
        )
        resolution_minutes = [
            _resolution_minutes(session)
            for session in sessions
            if _resolution_minutes(session) is not None
        ]
        return ActivityMetrics(
            period=period,
            closed_tasks=len(closed),
            active_tasks=len(active),
            tasks_by_status=dict(sorted(statuses.items())),
            handled_open_line_sessions=len(sessions),
            average_open_line_resolution_minutes=(
                sum(resolution_minutes) / len(resolution_minutes) if resolution_minutes else None
            ),
        )

    async def _collect(
        self, date_from: str, date_to: str
    ) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
        import asyncio

        return await asyncio.gather(
            self._all_tasks(
                {
                    "RESPONSIBLE_ID": self.user_id,
                    "STATUS": 5,
                    ">=CLOSED_DATE": date_from,
                    "<=CLOSED_DATE": f"{date_to}T23:59:59",
                }
            ),
            self._all_tasks({"RESPONSIBLE_ID": self.user_id, "!STATUS": 5}),
            self._all_open_line_sessions(
                {
                    "OPERATOR_ID": self.user_id,
                    ">=DATE_CLOSE": date_from,
                    "<=DATE_CLOSE": f"{date_to}T23:59:59",
                }
            ),
        )


def _resolution_minutes(session: dict[str, Any]) -> float | None:
    created = session.get("date_create") or session.get("DATE_CREATE")
    closed = session.get("date_close") or session.get("DATE_CLOSE")
    if not created or not closed:
        return None
    try:
        return (datetime.fromisoformat(closed) - datetime.fromisoformat(created)).total_seconds() / 60
    except ValueError:
        return None
