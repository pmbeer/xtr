from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from bitrix_agent.client import BitrixAPIError, BitrixClient
from bitrix_agent.storage import AnalyticsStore


@dataclass
class OpenLinesReport:
    user_id: int
    period_from: str
    period_to: str
    source: str
    processed_count: int = 0
    closed_count: int = 0
    open_count: int = 0
    spam_count: int = 0
    avg_resolution_sec: Optional[float] = None
    avg_wait_answer_sec: Optional[float] = None
    avg_resolution_human: Optional[str] = None
    by_source: dict[str, int] = field(default_factory=dict)
    by_status: dict[str, int] = field(default_factory=dict)
    notes: list[str] = field(default_factory=list)
    sessions: list[dict[str, Any]] = field(default_factory=list)
    portal_stats: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def _human_seconds(seconds: float | None) -> str | None:
    if seconds is None:
        return None
    total = int(round(seconds))
    hours, rem = divmod(total, 3600)
    minutes, secs = divmod(rem, 60)
    if hours:
        return f"{hours} ч {minutes} мин"
    if minutes:
        return f"{minutes} мин {secs} сек"
    return f"{secs} сек"


def _iso(dt: datetime) -> str:
    return dt.astimezone().replace(microsecond=0).isoformat()


def _parse_session_item(item: dict[str, Any]) -> dict[str, Any]:
    """Normalize heterogeneous Bitrix session payloads."""
    session_id = (
        item.get("id")
        or item.get("ID")
        or item.get("sessionId")
        or item.get("SESSION_ID")
    )
    operator_id = (
        item.get("operatorId")
        or item.get("OPERATOR_ID")
        or item.get("userId")
        or item.get("USER_ID")
    )
    date_create = (
        item.get("dateCreate")
        or item.get("DATE_CREATE")
        or item.get("date_create")
    )
    date_close = (
        item.get("dateClose")
        or item.get("DATE_CLOSE")
        or item.get("date_close")
        or item.get("closedAt")
    )
    duration = (
        item.get("timeDialog")
        or item.get("TIME_DIALOG")
        or item.get("duration")
        or item.get("sessionDuration")
    )
    wait = (
        item.get("timeAnswer")
        or item.get("TIME_ANSWER")
        or item.get("waitAnswer")
        or item.get("avgWaitAnswer")
    )
    status = item.get("status") or item.get("STATUS") or item.get("mode")
    source = item.get("source") or item.get("SOURCE") or item.get("connector")
    spam = item.get("spam") or item.get("SPAM") or 0
    chat_id = item.get("chatId") or item.get("CHAT_ID")
    config_id = item.get("configId") or item.get("CONFIG_ID") or item.get("lineId")

    return {
        "session_id": int(session_id) if session_id is not None else None,
        "chat_id": int(chat_id) if chat_id not in (None, "") else None,
        "config_id": int(config_id) if config_id not in (None, "") else None,
        "operator_id": int(operator_id) if operator_id not in (None, "") else None,
        "status": str(status) if status is not None else None,
        "source": str(source) if source is not None else None,
        "date_create": str(date_create) if date_create else None,
        "date_close": str(date_close) if date_close else None,
        "wait_answer_sec": float(wait) if wait not in (None, "") else None,
        "duration_sec": float(duration) if duration not in (None, "") else None,
        "vote": item.get("vote") or item.get("VOTE"),
        "spam": int(spam) if spam not in (None, "") else 0,
        "raw": item,
    }


class OpenLinesAnalytics:
    def __init__(self, client: BitrixClient, store: AnalyticsStore | None = None) -> None:
        self.client = client
        self.store = store

    def build_report(
        self,
        user_id: int,
        *,
        days: int = 7,
        now: datetime | None = None,
    ) -> OpenLinesReport:
        now = now or datetime.now().astimezone()
        period_from = now - timedelta(days=days)
        period_to = now
        from_iso = _iso(period_from)
        to_iso = _iso(period_to)

        notes: list[str] = []
        portal_stats: dict[str, Any] = {}

        # 1) Prefer new statistics API (imopenlines 26.700.0+)
        sessions, source = self._try_v2_sessions(user_id, from_iso, to_iso, notes)
        if not sessions:
            # 2) Local event store (webhook collector)
            sessions, source = self._from_local_store(user_id, from_iso, to_iso, notes, source)
        if not sessions and source != "imopenlines.v2":
            # 3) Best-effort via recent open-line dialogs
            sessions, source = self._from_recent_dialogs(user_id, notes, source)

        # Optional aggregate stats for the whole line (not only current user)
        try:
            portal_stats = self._try_v2_stats(from_iso, to_iso) or {}
        except BitrixAPIError as exc:
            notes.append(f"Агрегаты портала недоступны: {exc.error or exc}")

        return self._compose_report(
            user_id=user_id,
            period_from=from_iso,
            period_to=to_iso,
            sessions=sessions,
            source=source or "unavailable",
            notes=notes,
            portal_stats=portal_stats,
        )

    def _try_v2_sessions(
        self,
        user_id: int,
        date_from: str,
        date_to: str,
        notes: list[str],
    ) -> tuple[list[dict[str, Any]], str | None]:
        methods = (
            "imopenlines.v2.Session.list",
            "imopenlines.session.list",
        )
        for method in methods:
            try:
                result = self.client.call(
                    method,
                    {
                        "filter": {
                            "OPERATOR_ID": user_id,
                            ">=DATE_CREATE": date_from,
                            "<=DATE_CREATE": date_to,
                        },
                        "order": {"ID": "DESC"},
                        # Newer wrappers also accept camelCase body:
                        "dateCreateFrom": date_from,
                        "dateCreateTo": date_to,
                        "operatorId": user_id,
                        "limit": 100,
                        "offset": 0,
                    },
                )
            except BitrixAPIError as exc:
                notes.append(f"{method}: {exc.error or exc}")
                continue

            items = self._extract_items(result)
            normalized = []
            for item in items:
                if not isinstance(item, dict):
                    continue
                row = _parse_session_item(item)
                if row["session_id"] is None:
                    continue
                if row["operator_id"] is None:
                    row["operator_id"] = user_id
                if self.store:
                    self.store.upsert_session(row)
                normalized.append(row)
            if normalized:
                notes.append(f"Данные открытых линий получены через {method}")
                return normalized, "imopenlines.v2"
        return [], None

    def _try_v2_stats(self, date_from: str, date_to: str) -> dict[str, Any] | None:
        for method in ("imopenlines.v2.Stat.get", "imopenlines.stat.get"):
            try:
                result = self.client.call(
                    method,
                    {
                        "dateFrom": date_from,
                        "dateTo": date_to,
                        "DATE_FROM": date_from,
                        "DATE_TO": date_to,
                    },
                )
                if isinstance(result, dict):
                    return result
            except BitrixAPIError:
                continue
        return None

    def _from_local_store(
        self,
        user_id: int,
        date_from: str,
        date_to: str,
        notes: list[str],
        source: str | None,
    ) -> tuple[list[dict[str, Any]], str | None]:
        if not self.store:
            return [], source
        rows = self.store.sessions_for_operator(
            user_id, date_from=date_from, date_to=date_to
        )
        if not rows:
            notes.append(
                "Локальная БД пуста. Подключите исходящий вебхук OnSessionStart/OnSessionFinish "
                "на /webhook/bitrix для накопления истории обращений."
            )
            return [], source
        notes.append("Данные открытых линий взяты из локального хранилища событий")
        sessions = [
            {
                "session_id": r.session_id,
                "chat_id": r.chat_id,
                "config_id": r.config_id,
                "operator_id": r.operator_id,
                "status": r.status,
                "source": r.source,
                "date_create": r.date_create,
                "date_close": r.date_close,
                "wait_answer_sec": r.wait_answer_sec,
                "duration_sec": r.duration_sec,
                "vote": r.vote,
                "spam": r.spam,
            }
            for r in rows
        ]
        return sessions, "local_store"

    def _from_recent_dialogs(
        self,
        user_id: int,
        notes: list[str],
        source: str | None,
    ) -> tuple[list[dict[str, Any]], str | None]:
        try:
            recent = self.client.call("im.recent.list", {"SKIP_OPENLINES": "N"})
        except BitrixAPIError as exc:
            notes.append(f"im.recent.list недоступен: {exc.error or exc}")
            return [], source or "unavailable"

        items = []
        if isinstance(recent, dict):
            items = recent.get("items") or recent.get("chats") or []
        elif isinstance(recent, list):
            items = recent

        sessions: list[dict[str, Any]] = []
        for item in items:
            if not isinstance(item, dict):
                continue
            chat = item.get("chat") or item
            entity_type = str(chat.get("entity_type") or chat.get("type") or "").upper()
            if "LINES" not in entity_type and "OPENLINES" not in entity_type:
                # Keep open-line looking chats by prefix
                chat_id = chat.get("id") or item.get("id")
                if not str(chat_id).startswith("chat"):
                    continue
            chat_id_raw = chat.get("id") or item.get("chat_id") or item.get("id")
            try:
                chat_num = int(str(chat_id_raw).replace("chat", ""))
            except (TypeError, ValueError):
                continue
            try:
                history = self.client.call(
                    "imopenlines.session.history.get", {"CHAT_ID": chat_num}
                )
            except BitrixAPIError:
                continue
            if not isinstance(history, dict):
                continue
            session = history.get("session") or history
            row = _parse_session_item(session if isinstance(session, dict) else {})
            if row["session_id"] is None:
                row["session_id"] = int(history.get("sessionId") or 0) or None
            if row["session_id"] is None:
                continue
            row["chat_id"] = row["chat_id"] or chat_num
            if row["operator_id"] not in (None, user_id):
                continue
            row["operator_id"] = row["operator_id"] or user_id
            if self.store:
                self.store.upsert_session(row)
            sessions.append(row)

        if sessions:
            notes.append(
                "Часть данных собрана из текущих диалогов (im.recent + session.history). "
                "Для полной истории за период подключите события или API статистики."
            )
            return sessions, "recent_dialogs"
        notes.append("Не удалось получить обращения открытых линий")
        return [], source or "unavailable"

    @staticmethod
    def _extract_items(result: Any) -> list[Any]:
        if isinstance(result, list):
            return result
        if isinstance(result, dict):
            for key in ("items", "sessions", "list", "result"):
                if isinstance(result.get(key), list):
                    return result[key]
            # dict of id -> session
            values = list(result.values())
            if values and all(isinstance(v, dict) for v in values):
                return values
        return []

    def _compose_report(
        self,
        *,
        user_id: int,
        period_from: str,
        period_to: str,
        sessions: list[dict[str, Any]],
        source: str,
        notes: list[str],
        portal_stats: dict[str, Any],
    ) -> OpenLinesReport:
        by_source: dict[str, int] = {}
        by_status: dict[str, int] = {}
        durations: list[float] = []
        waits: list[float] = []
        closed = open_count = spam = 0

        brief: list[dict[str, Any]] = []
        for s in sessions:
            src = s.get("source") or "unknown"
            by_source[src] = by_source.get(src, 0) + 1
            status = str(s.get("status") or "unknown")
            by_status[status] = by_status.get(status, 0) + 1
            if s.get("spam"):
                spam += 1
            if s.get("date_close") or status.lower() in {"close", "closed", "2"}:
                closed += 1
            else:
                open_count += 1
            if s.get("duration_sec") is not None:
                durations.append(float(s["duration_sec"]))
            elif s.get("date_create") and s.get("date_close"):
                try:
                    start = datetime.fromisoformat(str(s["date_create"]).replace("Z", "+00:00"))
                    end = datetime.fromisoformat(str(s["date_close"]).replace("Z", "+00:00"))
                    durations.append((end - start).total_seconds())
                except ValueError:
                    pass
            if s.get("wait_answer_sec") is not None:
                waits.append(float(s["wait_answer_sec"]))

            brief.append(
                {
                    "session_id": s.get("session_id"),
                    "status": s.get("status"),
                    "source": s.get("source"),
                    "date_create": s.get("date_create"),
                    "date_close": s.get("date_close"),
                    "duration_sec": s.get("duration_sec"),
                }
            )

        avg_resolution = round(sum(durations) / len(durations), 1) if durations else None
        avg_wait = round(sum(waits) / len(waits), 1) if waits else None

        return OpenLinesReport(
            user_id=user_id,
            period_from=period_from,
            period_to=period_to,
            source=source,
            processed_count=len(sessions),
            closed_count=closed,
            open_count=open_count,
            spam_count=spam,
            avg_resolution_sec=avg_resolution,
            avg_wait_answer_sec=avg_wait,
            avg_resolution_human=_human_seconds(avg_resolution),
            by_source=by_source,
            by_status=by_status,
            notes=notes,
            sessions=brief[:50],
            portal_stats=portal_stats,
        )

    def ingest_event(self, event_name: str, data: dict[str, Any]) -> None:
        """Store OnSessionStart / OnSessionFinish webhook payloads."""
        if not self.store:
            return
        payload = data.get("data") if isinstance(data.get("data"), dict) else data
        session = payload.get("SESSION") if isinstance(payload, dict) else None
        if not isinstance(session, dict):
            session = payload if isinstance(payload, dict) else {}

        row = _parse_session_item(session)
        if event_name.upper().endswith("FINISH") or "FINISH" in event_name.upper():
            row["status"] = row["status"] or "closed"
            if not row.get("date_close"):
                row["date_close"] = datetime.now(timezone.utc).isoformat()
        else:
            row["status"] = row["status"] or "open"
            if not row.get("date_create"):
                row["date_create"] = datetime.now(timezone.utc).isoformat()

        if row.get("session_id") is not None:
            self.store.upsert_session(row)
        self.store.add_event(
            event_name,
            data,
            entity_id=str(row.get("session_id") or ""),
            user_id=row.get("operator_id"),
        )
