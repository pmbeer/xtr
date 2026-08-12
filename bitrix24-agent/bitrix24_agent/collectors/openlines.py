"""Метрики по Открытым линиям: обработанные обращения, время ответа и решения.

Основной источник — `imopenlines.v2.Session.list` (появился в обновлении
`imopenlines 26.700.0`). Пока обновление не приехало на портал или тариф не
включает статистику Открытых линий, метод отвечает ошибкой — тогда агент
переходит на приблизительный подсчёт по делам CRM.
"""

from __future__ import annotations

import logging
from collections.abc import Mapping
from dataclasses import dataclass, field
from datetime import datetime, tzinfo
from typing import Any

from ..client import Bitrix24Client
from ..errors import Bitrix24Error
from ..metrics import Summary, summarize
from ..normalize import iter_records, parse_bool, parse_datetime, parse_float, parse_int, pick
from ..period import Period
from .base import ERROR, PARTIAL, UNAVAILABLE, Section

log = logging.getLogger(__name__)

SESSION_LIST_METHOD = "imopenlines.v2.Session.list"
CONFIG_LIST_METHOD = "imopenlines.config.list.get"
#: Дела CRM, которыми Открытые линии отмечают сессию, — запасной источник.
ACTIVITY_PROVIDER = "IMOPENLINES_SESSION"

#: Максимальный размер страницы `imopenlines.v2.Session.list`.
SESSION_PAGE_SIZE = 200
MAX_SESSION_PAGES = 50

STATUS_LABELS = {
    "new": "Новое",
    "answered": "В работе",
    "closed": "Закрыто",
    "spam": "Спам",
    "paused": "На паузе",
}
CLOSE_REASON_LABELS = {
    "operator": "Закрыл оператор",
    "auto": "Закрыто автоматически",
    "spam": "Спам",
    "client": "Закрыл клиент",
    "replyLimit": "Исчерпан лимит ответов",
}


@dataclass(frozen=True)
class Session:
    """Сессия (обращение) Открытой линии."""

    id: int
    config_id: int = 0
    source: str = ""
    operator_id: int = 0
    status: str = ""
    close_reason: str = ""
    created: datetime | None = None
    closed: datetime | None = None
    first_answer: datetime | None = None
    wait_answer: float | None = None
    wait_close: float | None = None
    vote: str = ""
    kpi_first_answer: bool | None = None
    message_count: int = 0
    crm_entity_type: str = ""

    @classmethod
    def from_raw(cls, record: Mapping[str, Any], tz: tzinfo) -> Session | None:
        session_id = parse_int(pick(record, "ID", "SESSION_ID"))
        if session_id is None:
            return None
        return cls(
            id=session_id,
            config_id=parse_int(pick(record, "CONFIG_ID"), 0) or 0,
            source=str(pick(record, "SOURCE", default="") or ""),
            operator_id=parse_int(pick(record, "OPERATOR_ID"), 0) or 0,
            status=str(pick(record, "STATUS", default="") or ""),
            close_reason=str(pick(record, "CLOSE_REASON", default="") or ""),
            created=parse_datetime(pick(record, "DATE_CREATE"), tz),
            closed=parse_datetime(pick(record, "DATE_CLOSE"), tz),
            first_answer=parse_datetime(pick(record, "DATE_FIRST_ANSWER"), tz),
            wait_answer=parse_float(pick(record, "WAIT_ANSWER")),
            wait_close=parse_float(pick(record, "WAIT_CLOSE")),
            vote=str(pick(record, "VOTE", default="") or ""),
            kpi_first_answer=parse_bool(pick(record, "KPI_FIRST_ANSWER")),
            message_count=parse_int(pick(record, "MESSAGE_COUNT"), 0) or 0,
            crm_entity_type=str(pick(record, "CRM_ENTITY_TYPE", default="") or ""),
        )

    def duration_seconds(self) -> float | None:
        """Время решения вопроса: хранимая метрика, иначе разница дат."""
        if self.wait_close is not None:
            return self.wait_close
        if self.created and self.closed:
            seconds = (self.closed - self.created).total_seconds()
            return seconds if seconds >= 0 else None
        return None

    def response_seconds(self) -> float | None:
        if self.wait_answer is not None:
            return self.wait_answer
        if self.created and self.first_answer:
            seconds = (self.first_answer - self.created).total_seconds()
            return seconds if seconds >= 0 else None
        return None


@dataclass
class OpenLinesSection(Section):
    """Сводка по обращениям в Открытых линиях."""

    name: str = "openlines"
    title: str = "Открытые линии"

    source_method: str = ""
    handled_count: int = 0
    closed_count: int = 0
    analyzed_count: int = 0
    resolution: Summary = field(default_factory=Summary)
    first_response: Summary = field(default_factory=Summary)
    messages_total: int = 0
    messages_per_session: float | None = None

    likes: int = 0
    dislikes: int = 0
    rated_count: int = 0
    satisfaction_rate: float | None = None

    kpi_ok: int = 0
    kpi_failed: int = 0

    by_status: dict[str, int] = field(default_factory=dict)
    by_source: dict[str, int] = field(default_factory=dict)
    by_line: dict[str, int] = field(default_factory=dict)
    by_hour: list[int] = field(default_factory=lambda: [0] * 24)
    with_crm: int = 0


def collect_openlines(
    client: Bitrix24Client,
    *,
    user_id: int,
    period: Period,
    tz: tzinfo,
    max_sessions: int = 2000,
) -> OpenLinesSection:
    """Собирает раздел «Открытые линии» с деградацией до приблизительных данных."""
    section = OpenLinesSection()

    try:
        sessions = _fetch_sessions(
            client, user_id=user_id, period=period, tz=tz, limit=max_sessions
        )
    except Bitrix24Error as exc:
        return _fallback(client, section, user_id=user_id, period=period, tz=tz, reason=exc)

    if sessions is None:
        reason = Bitrix24Error(SESSION_LIST_METHOD, "METHOD_NOT_YET_AVAILABLE")
        return _fallback(client, section, user_id=user_id, period=period, tz=tz, reason=reason)

    section.source_method = SESSION_LIST_METHOD
    _fill_metrics(section, sessions)
    _fill_line_names(client, section, sessions)

    if len(sessions) >= max_sessions:
        section.status = PARTIAL
        section.note(
            f"Разобрано {max_sessions} обращений — достигнут лимит выгрузки, "
            "средние значения посчитаны по этой выборке."
        )
    elif not sessions:
        section.note("За период нет обращений, где вы указаны оператором.")
    return section


def _fetch_sessions(
    client: Bitrix24Client, *, user_id: int, period: Period, tz: tzinfo, limit: int
) -> list[Session] | None:
    """Постранично забирает сессии оператора; `None` — метода нет на портале."""
    sessions: list[Session] = []
    offset = 0
    for _ in range(MAX_SESSION_PAGES):
        params = {
            "operatorId": user_id,
            "dateCreateFrom": period.iso_start(),
            "dateCreateTo": period.iso_end(),
            "order": "dateCreate",
            "orderDirection": "asc",
            "limit": min(SESSION_PAGE_SIZE, max(1, limit - len(sessions))),
            "offset": offset,
        }
        try:
            payload = client.call(SESSION_LIST_METHOD, params)
        except Bitrix24Error as exc:
            if exc.is_method_missing or exc.is_access_denied:
                return None
            raise

        page = [
            session
            for session in (Session.from_raw(record, tz) for record in iter_records(payload))
            if session is not None
        ]
        sessions.extend(page)
        has_next = _has_next_page(payload)
        if not page or not has_next or len(sessions) >= limit:
            break
        offset += len(page)
    return sessions[:limit]


def _has_next_page(payload: Any) -> bool:
    if isinstance(payload, Mapping):
        flag = parse_bool(pick(payload, "HAS_NEXT_PAGE"))
        if flag is not None:
            return flag
    return False


def _fill_metrics(section: OpenLinesSection, sessions: list[Session]) -> None:
    section.handled_count = len(sessions)
    section.analyzed_count = len(sessions)
    section.closed_count = sum(1 for session in sessions if session.status == "closed")
    section.resolution = summarize(
        [value for value in (session.duration_seconds() for session in sessions) if value is not None]
    )
    section.first_response = summarize(
        [value for value in (session.response_seconds() for session in sessions) if value is not None]
    )
    section.messages_total = sum(session.message_count for session in sessions)
    if sessions:
        section.messages_per_session = round(section.messages_total / len(sessions), 1)

    section.likes = sum(1 for session in sessions if session.vote == "like")
    section.dislikes = sum(1 for session in sessions if session.vote == "dislike")
    section.rated_count = section.likes + section.dislikes
    if section.rated_count:
        section.satisfaction_rate = round(section.likes / section.rated_count * 100, 1)

    section.kpi_ok = sum(1 for session in sessions if session.kpi_first_answer is True)
    section.kpi_failed = sum(1 for session in sessions if session.kpi_first_answer is False)
    section.with_crm = sum(1 for session in sessions if session.crm_entity_type)

    for session in sessions:
        status_label = STATUS_LABELS.get(session.status, session.status or "Без статуса")
        section.by_status[status_label] = section.by_status.get(status_label, 0) + 1
        source = session.source or "Не указан"
        section.by_source[source] = section.by_source.get(source, 0) + 1
        if session.created is not None:
            section.by_hour[session.created.hour] += 1

    section.by_status = dict(
        sorted(section.by_status.items(), key=lambda item: item[1], reverse=True)
    )
    section.by_source = dict(
        sorted(section.by_source.items(), key=lambda item: item[1], reverse=True)
    )


def _fill_line_names(
    client: Bitrix24Client, section: OpenLinesSection, sessions: list[Session]
) -> None:
    config_ids = {session.config_id for session in sessions if session.config_id}
    if not config_ids:
        return
    payload = client.try_call(CONFIG_LIST_METHOD, {})
    names: dict[int, str] = {}
    for record in iter_records(payload):
        config_id = parse_int(pick(record, "ID"))
        if config_id is not None:
            names[config_id] = str(pick(record, "LINE_NAME", "NAME", default="") or f"Линия #{config_id}")
    counts: dict[str, int] = {}
    for session in sessions:
        if not session.config_id:
            continue
        title = names.get(session.config_id, f"Линия #{session.config_id}")
        counts[title] = counts.get(title, 0) + 1
    section.by_line = dict(sorted(counts.items(), key=lambda item: item[1], reverse=True))


def _fallback(
    client: Bitrix24Client,
    section: OpenLinesSection,
    *,
    user_id: int,
    period: Period,
    tz: tzinfo,
    reason: Bitrix24Error,
) -> OpenLinesSection:
    """Приблизительный подсчёт по делам CRM, созданным Открытыми линиями."""
    section.note(
        f"{SESSION_LIST_METHOD} недоступен ({reason.code}). Статистика Открытых линий "
        "появляется в обновлении imopenlines 26.700.0 и требует права report_open_lines."
    )
    try:
        envelope = client.call_envelope(
            "crm.activity.list",
            {
                "filter": {
                    "PROVIDER_ID": ACTIVITY_PROVIDER,
                    "RESPONSIBLE_ID": user_id,
                    ">=CREATED": period.iso_start(),
                    "<=CREATED": period.iso_end(),
                },
                "select": ["ID", "CREATED", "END_TIME", "COMPLETED"],
                "start": 0,
            },
        )
    except Bitrix24Error as exc:
        section.status = UNAVAILABLE if exc.is_method_missing or exc.is_access_denied else ERROR
        section.note(f"Запасной источник тоже недоступен: {exc}")
        return section

    records = list(iter_records(envelope.get("result")))
    total = envelope.get("total")
    section.source_method = "crm.activity.list (приблизительно)"
    section.handled_count = int(total) if total is not None else len(records)
    section.analyzed_count = len(records)

    durations: list[float] = []
    for record in records:
        started = parse_datetime(pick(record, "CREATED"), tz)
        finished = parse_datetime(pick(record, "END_TIME"), tz)
        if started and finished and finished >= started:
            durations.append((finished - started).total_seconds())
        if started is not None:
            section.by_hour[started.hour] += 1
    section.resolution = summarize(durations)

    if section.handled_count:
        section.status = PARTIAL
        section.note(
            "Учтены только обращения, привязанные к CRM: время решения оценено по делу, "
            "оценки клиентов и время первого ответа недоступны."
        )
    else:
        section.status = UNAVAILABLE
        section.note("Обращений Открытых линий за период не найдено.")
    return section
