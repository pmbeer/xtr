"""Открытые линии: обращения, время реакции и оценки клиентов.

У портов Битрикс24 два разных пути получить эти данные:

1. методы статистики ``imopenlines.v2.*`` (обновление ``imopenlines 26.700.0``)
   — дают готовые агрегаты и хранимые метрики сессий;
2. если обновление на портал ещё не пришло или тариф не включает статистику
   открытых линий — остаётся приблизительный путь через дела CRM
   (``crm.activity.list`` с провайдером ``IMOPENLINES``).

Репозиторий пробует первый путь, при отказе переключается на второй и
сообщает об этом в ``notes``, чтобы в отчёте было видно происхождение цифр.
"""

from __future__ import annotations

import logging
from collections.abc import Sequence
from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum
from typing import Any
from zoneinfo import ZoneInfo

from b24agent.analytics.period import Period
from b24agent.bitrix.client import Bitrix24Client
from b24agent.bitrix.errors import (
    AccessDeniedError,
    Bitrix24Error,
    MethodNotAvailableError,
)
from b24agent.bitrix.parsing import (
    as_bool,
    as_float,
    as_int,
    as_opt_int,
    as_str,
    parse_datetime,
    pick,
)

logger = logging.getLogger(__name__)

METHOD_SESSION_LIST = "imopenlines.v2.Session.list"
METHOD_STAT_GET = "imopenlines.v2.Stat.get"
METHOD_CONFIG_LIST = "imopenlines.config.list.get"

ACTIVITY_PROVIDERS = ("IMOPENLINES", "IMOPENLINES_SESSION")
SESSION_PAGE_SIZE = 200

VOTE_LIKE = "like"
VOTE_DISLIKE = "dislike"

SOURCE_TITLES: dict[str, str] = {
    "livechat": "Онлайн-чат на сайте",
    "telegrambot": "Telegram",
    "telegram": "Telegram",
    "whatsappbyedna": "WhatsApp",
    "whatsapp": "WhatsApp",
    "vkgroup": "ВКонтакте",
    "network": "Битрикс24.Network",
    "facebook": "Facebook",
    "instagram": "Instagram",
    "viber": "Viber",
    "avito": "Avito",
    "imessage": "iMessage",
    "notifications": "Уведомления",
    "olx": "OLX",
}


class OpenLinesDataSource(StrEnum):
    """Откуда взяты данные по обращениям."""

    STATS_V2 = "imopenlines.v2"
    CRM_ACTIVITIES = "crm.activity"
    UNAVAILABLE = "unavailable"

    @property
    def title(self) -> str:
        return {
            OpenLinesDataSource.STATS_V2: "Статистика открытых линий (imopenlines.v2)",
            OpenLinesDataSource.CRM_ACTIVITIES: "Дела CRM по открытым линиям (приблизительно)",
            OpenLinesDataSource.UNAVAILABLE: "Данные недоступны",
        }[self]

    @property
    def is_approximate(self) -> bool:
        return self is OpenLinesDataSource.CRM_ACTIVITIES


def source_title(code: str) -> str:
    normalized = (code or "").strip().lower()
    return SOURCE_TITLES.get(normalized, code or "не определён")


@dataclass(frozen=True, slots=True)
class Session:
    """Обращение (сессия) открытой линии."""

    id: int
    config_id: int
    source: str
    operator_id: int
    created_at: datetime | None
    closed_at: datetime | None
    first_answer_at: datetime | None
    status: str
    close_reason: str
    vote: str
    wait_answer_seconds: float | None
    wait_close_seconds: float | None
    kpi_first_answer: bool | None
    message_count: int
    crm_entity_type: str = ""
    crm_entity_id: int | None = None
    queue_transfers: int = 0

    @property
    def is_closed(self) -> bool:
        return self.status.lower() in {"closed", "spam"} or self.closed_at is not None

    @property
    def resolution_seconds(self) -> float | None:
        """Время решения вопроса: от создания обращения до его закрытия."""
        if self.wait_close_seconds is not None:
            return self.wait_close_seconds
        if self.created_at and self.closed_at:
            delta = (self.closed_at - self.created_at).total_seconds()
            return delta if delta >= 0 else None
        return None

    @classmethod
    def from_v2(cls, raw: dict[str, Any], tz: ZoneInfo) -> Session:
        return cls(
            id=as_int(pick(raw, "id", "ID", "sessionId", "SESSION_ID")),
            config_id=as_int(pick(raw, "configId", "CONFIG_ID")),
            source=as_str(pick(raw, "source", "SOURCE")),
            operator_id=as_int(pick(raw, "operatorId", "OPERATOR_ID")),
            created_at=parse_datetime(pick(raw, "dateCreate", "DATE_CREATE"), tz),
            closed_at=parse_datetime(pick(raw, "dateClose", "DATE_CLOSE"), tz),
            first_answer_at=parse_datetime(
                pick(raw, "dateFirstAnswer", "DATE_FIRST_ANSWER"), tz
            ),
            status=as_str(pick(raw, "status", "STATUS")),
            close_reason=as_str(pick(raw, "closeReason", "CLOSE_REASON")),
            vote=as_str(pick(raw, "vote", "VOTE")).lower(),
            wait_answer_seconds=_opt_seconds(pick(raw, "waitAnswer", "WAIT_ANSWER")),
            wait_close_seconds=_opt_seconds(pick(raw, "waitClose", "WAIT_CLOSE")),
            kpi_first_answer=_opt_bool(pick(raw, "kpiFirstAnswer", "KPI_FIRST_ANSWER")),
            message_count=as_int(pick(raw, "messageCount", "MESSAGE_COUNT")),
            crm_entity_type=as_str(pick(raw, "crmEntityType", "CRM_ENTITY_TYPE")),
            crm_entity_id=as_opt_int(pick(raw, "crmEntityId", "CRM_ENTITY_ID")),
            queue_transfers=as_int(pick(raw, "queueTransfers", "QUEUE_TRANSFERS")),
        )

    @classmethod
    def from_activity(cls, raw: dict[str, Any], tz: ZoneInfo) -> Session:
        """Собирает сессию из дела CRM — приблизительный источник данных."""
        created = parse_datetime(pick(raw, "CREATED", "created"), tz)
        completed = as_bool(pick(raw, "COMPLETED", "completed"))
        closed = parse_datetime(pick(raw, "END_TIME", "endTime"), tz) or parse_datetime(
            pick(raw, "LAST_UPDATED", "lastUpdated"), tz
        )
        return cls(
            id=as_int(pick(raw, "ID", "id")),
            config_id=0,
            source=as_str(pick(raw, "PROVIDER_TYPE_ID", "providerTypeId")),
            operator_id=as_int(pick(raw, "RESPONSIBLE_ID", "responsibleId")),
            created_at=created,
            closed_at=closed if completed else None,
            first_answer_at=None,
            status="closed" if completed else "answered",
            close_reason="",
            vote="",
            wait_answer_seconds=None,
            wait_close_seconds=None,
            kpi_first_answer=None,
            message_count=0,
            crm_entity_type=as_str(pick(raw, "OWNER_TYPE_ID", "ownerTypeId")),
            crm_entity_id=as_opt_int(pick(raw, "OWNER_ID", "ownerId")),
        )


@dataclass(slots=True)
class OpenLinesData:
    """Сырые данные по обращениям плюс сведения о том, откуда они взяты."""

    source: OpenLinesDataSource
    sessions: list[Session] = field(default_factory=list)
    aggregate: dict[str, Any] | None = None
    line_names: dict[int, str] = field(default_factory=dict)
    notes: list[str] = field(default_factory=list)


class OpenLinesRepository:
    def __init__(
        self,
        client: Bitrix24Client,
        tz: ZoneInfo,
        *,
        max_records: int = 5000,
    ) -> None:
        self._client = client
        self._tz = tz
        self._max_records = max_records

    async def collect(self, period: Period, operator_id: int) -> OpenLinesData:
        """Собирает обращения оператора за период доступным способом."""
        try:
            sessions = await self._sessions_v2(period, operator_id)
        except MethodNotAvailableError as exc:
            logger.info("Методы статистики открытых линий недоступны: %s", exc)
            return await self._collect_fallback(
                period,
                operator_id,
                note=(
                    "Статистика открытых линий (imopenlines.v2) на портале недоступна — "
                    "цифры по обращениям посчитаны по делам CRM и являются приблизительными."
                ),
            )
        except AccessDeniedError as exc:
            logger.info("Нет прав на статистику открытых линий: %s", exc)
            return await self._collect_fallback(
                period,
                operator_id,
                note=(
                    "У владельца вебхука нет права на статистику открытых линий "
                    f"({exc.code}) — использованы дела CRM, цифры приблизительные."
                ),
            )
        except Bitrix24Error as exc:
            logger.warning("Ошибка выгрузки сессий открытых линий: %s", exc)
            return await self._collect_fallback(
                period,
                operator_id,
                note=f"Открытые линии: {exc.code}. Использован обходной путь через дела CRM.",
            )

        data = OpenLinesData(source=OpenLinesDataSource.STATS_V2, sessions=sessions)
        data.aggregate = await self._aggregate_v2(period, operator_id)
        data.line_names = await self.line_names()
        return data

    async def line_names(self) -> dict[int, str]:
        """Названия открытых линий (configId -> название)."""
        try:
            result = await self._client.call(METHOD_CONFIG_LIST)
        except Bitrix24Error as exc:
            logger.debug("Список открытых линий недоступен: %s", exc)
            return {}

        names: dict[int, str] = {}
        for item in _as_items(result):
            config_id = as_opt_int(pick(item, "ID", "id"))
            if config_id is not None:
                names[config_id] = as_str(
                    pick(item, "LINE_NAME", "lineName", "NAME", "name"),
                    f"Линия {config_id}",
                )
        return names

    async def _sessions_v2(self, period: Period, operator_id: int) -> list[Session]:
        collected: list[Session] = []
        offset = 0

        while True:
            envelope = await self._client.call_raw(
                METHOD_SESSION_LIST,
                {
                    "operatorId": operator_id,
                    "dateCreateFrom": period.bitrix_start(),
                    "dateCreateTo": period.bitrix_end(),
                    "order": "dateCreate",
                    "orderDirection": "asc",
                    "limit": SESSION_PAGE_SIZE,
                    "offset": offset,
                },
            )
            result = envelope.get("result") or {}
            items = _extract_sessions(result)
            collected.extend(Session.from_v2(item, self._tz) for item in items)

            if len(collected) >= self._max_records:
                return collected[: self._max_records]

            has_next = _has_next_page(result, envelope)
            if not items or not has_next:
                return collected
            offset += len(items)

    async def _aggregate_v2(
        self, period: Period, operator_id: int
    ) -> dict[str, Any] | None:
        """Готовые агрегаты портала — считаются на стороне Битрикс24."""
        try:
            result = await self._client.call(
                METHOD_STAT_GET,
                {
                    "dateFrom": period.bitrix_start(),
                    "dateTo": period.bitrix_end(),
                    "operatorId": operator_id,
                },
            )
        except Bitrix24Error as exc:
            logger.debug("Агрегаты открытых линий не получены: %s", exc)
            return None
        return result if isinstance(result, dict) else None

    async def _collect_fallback(
        self, period: Period, operator_id: int, *, note: str
    ) -> OpenLinesData:
        try:
            sessions = await self._sessions_from_activities(period, operator_id)
        except Bitrix24Error as exc:
            logger.warning("Обходной путь через дела CRM тоже недоступен: %s", exc)
            return OpenLinesData(
                source=OpenLinesDataSource.UNAVAILABLE,
                notes=[
                    note,
                    f"Дела CRM по открытым линиям получить не удалось: {exc.code}.",
                ],
            )
        return OpenLinesData(
            source=OpenLinesDataSource.CRM_ACTIVITIES,
            sessions=sessions,
            notes=[note],
        )

    async def _sessions_from_activities(
        self, period: Period, operator_id: int
    ) -> list[Session]:
        raw_items = await self._client.fetch_all(
            "crm.activity.list",
            {
                "filter": {
                    "PROVIDER_ID": list(ACTIVITY_PROVIDERS),
                    "RESPONSIBLE_ID": operator_id,
                    ">=CREATED": period.bitrix_start(),
                    "<=CREATED": period.bitrix_end(),
                },
                "select": [
                    "ID",
                    "SUBJECT",
                    "CREATED",
                    "START_TIME",
                    "END_TIME",
                    "LAST_UPDATED",
                    "COMPLETED",
                    "RESPONSIBLE_ID",
                    "PROVIDER_ID",
                    "PROVIDER_TYPE_ID",
                    "OWNER_ID",
                    "OWNER_TYPE_ID",
                ],
                "order": {"CREATED": "ASC"},
            },
            max_records=self._max_records,
        )
        return [Session.from_activity(item, self._tz) for item in raw_items if item]


def _opt_seconds(value: Any) -> float | None:
    if value in (None, ""):
        return None
    seconds = as_float(value, -1.0)
    return seconds if seconds >= 0 else None


def _opt_bool(value: Any) -> bool | None:
    if value is None or value == "":
        return None
    return as_bool(value)


def _extract_sessions(result: Any) -> Sequence[dict[str, Any]]:
    if isinstance(result, dict):
        for key in ("sessions", "items", "SESSIONS", "result"):
            value = result.get(key)
            if isinstance(value, list):
                return [item for item in value if isinstance(item, dict)]
        return []
    if isinstance(result, list):
        return [item for item in result if isinstance(item, dict)]
    return []


def _has_next_page(result: Any, envelope: dict[str, Any]) -> bool:
    if isinstance(result, dict):
        for key in ("hasNextPage", "has_next_page", "HAS_NEXT_PAGE"):
            if key in result:
                return as_bool(result[key])
    return envelope.get("next") is not None


def _as_items(result: Any) -> Sequence[dict[str, Any]]:
    if isinstance(result, list):
        return [item for item in result if isinstance(item, dict)]
    if isinstance(result, dict):
        values = [value for value in result.values() if isinstance(value, dict)]
        if values:
            return values
    return []
