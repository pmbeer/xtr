"""Аналитика открытых линий Bitrix24."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from statistics import mean
from typing import Any

from .bitrix_client import Bitrix24Client, Bitrix24Error

SESSION_STATUS_LABELS = {
    "open": "Открыта",
    "close": "Закрыта",
    "answer": "Ожидает ответа оператора",
    "new": "Новая",
}


@dataclass
class OpenLinesAnalytics:
    user_id: int
    period_from: date
    period_to: date
    sessions_processed: int = 0
    sessions_open: int = 0
    avg_first_response_sec: float | None = None
    avg_resolution_sec: float | None = None
    avg_messages_per_session: float | None = None
    positive_votes: int = 0
    negative_votes: int = 0
    no_vote: int = 0
    by_line: dict[str, int] = field(default_factory=dict)
    by_source: dict[str, int] = field(default_factory=dict)
    method_used: str = ""
    warnings: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "user_id": self.user_id,
            "period": {
                "from": self.period_from.isoformat(),
                "to": self.period_to.isoformat(),
            },
            "method_used": self.method_used,
            "warnings": self.warnings,
            "summary": {
                "sessions_processed": self.sessions_processed,
                "sessions_open": self.sessions_open,
                "avg_first_response_sec": self.avg_first_response_sec,
                "avg_resolution_sec": self.avg_resolution_sec,
                "avg_messages_per_session": self.avg_messages_per_session,
                "positive_votes": self.positive_votes,
                "negative_votes": self.negative_votes,
                "no_vote": self.no_vote,
            },
            "by_line": self.by_line,
            "by_source": self.by_source,
        }


def _parse_datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00").split("+")[0])
    except ValueError:
        return None


def _seconds_between(start: str | None, end: str | None) -> float | None:
    start_dt = _parse_datetime(start)
    end_dt = _parse_datetime(end)
    if not start_dt or not end_dt:
        return None
    delta = (end_dt - start_dt).total_seconds()
    return delta if delta >= 0 else None


class OpenLinesAnalyzer:
    def __init__(self, client: Bitrix24Client):
        self.client = client

    def analyze(self, user_id: int, date_from: date, date_to: date) -> OpenLinesAnalytics:
        analytics = OpenLinesAnalytics(
            user_id=user_id,
            period_from=date_from,
            period_to=date_to,
        )

        sessions = self._fetch_sessions(user_id, date_from, date_to, analytics)
        if not sessions:
            return analytics

        first_response_times: list[float] = []
        resolution_times: list[float] = []
        message_counts: list[float] = []

        for session in sessions:
            line_id = session.get("configId") or session.get("CONFIG_ID") or "неизвестно"
            source = session.get("source") or session.get("SOURCE") or "неизвестно"
            analytics.by_line[f"Линия {line_id}"] = analytics.by_line.get(f"Линия {line_id}", 0) + 1
            analytics.by_source[source] = analytics.by_source.get(source, 0) + 1

            status = (session.get("status") or session.get("STATUS") or "").lower()
            if status in ("open", "answer", "new"):
                analytics.sessions_open += 1
            else:
                analytics.sessions_processed += 1

            vote = (session.get("vote") or session.get("VOTE") or "none").lower()
            if vote == "like":
                analytics.positive_votes += 1
            elif vote == "dislike":
                analytics.negative_votes += 1
            else:
                analytics.no_vote += 1

            first_answer = _seconds_between(
                session.get("dateCreate") or session.get("DATE_CREATE"),
                session.get("dateFirstAnswer") or session.get("DATE_FIRST_ANSWER"),
            )
            if first_answer is not None:
                first_response_times.append(first_answer)

            resolution = _seconds_between(
                session.get("dateCreate") or session.get("DATE_CREATE"),
                session.get("dateClose") or session.get("DATE_CLOSE"),
            )
            if resolution is not None:
                resolution_times.append(resolution)

            msg_count = session.get("messagesCount") or session.get("MESSAGE_COUNT")
            if msg_count is not None:
                message_counts.append(float(msg_count))

        stats = self._fetch_session_stats([s.get("id") or s.get("ID") for s in sessions if s.get("id") or s.get("ID")])
        for stat in stats:
            wait_answer = stat.get("waitAnswer")
            wait_close = stat.get("waitClose")
            messages = stat.get("messagesCount")

            if wait_answer is not None:
                first_response_times.append(float(wait_answer))
            if wait_close is not None:
                resolution_times.append(float(wait_close))
            if messages is not None:
                message_counts.append(float(messages))

        if first_response_times:
            analytics.avg_first_response_sec = round(mean(first_response_times), 1)
        if resolution_times:
            analytics.avg_resolution_sec = round(mean(resolution_times), 1)
        if message_counts:
            analytics.avg_messages_per_session = round(mean(message_counts), 1)

        return analytics

    def _fetch_sessions(
        self,
        user_id: int,
        date_from: date,
        date_to: date,
        analytics: OpenLinesAnalytics,
    ) -> list[dict[str, Any]]:
        date_from_iso = f"{date_from.isoformat()}T00:00:00"
        date_to_iso = f"{date_to.isoformat()}T23:59:59"

        strategies: list[tuple[str, str, dict[str, Any]]] = [
            (
                "imopenlines.v2.Session.list",
                "imopenlines.v2.Session.list",
                {
                    "filter": {
                        "operatorId": user_id,
                        "dateCreateFrom": date_from_iso,
                        "dateCreateTo": date_to_iso,
                    },
                },
            ),
            (
                "imopenlines.session.list",
                "imopenlines.session.list",
                {
                    "FILTER": {
                        "OPERATOR_ID": user_id,
                        ">=DATE_CREATE": date_from_iso,
                        "<=DATE_CREATE": date_to_iso,
                    },
                },
            ),
            (
                "crm.activity.list (open line)",
                "crm.activity.list",
                {
                    "filter": {
                        "RESPONSIBLE_ID": user_id,
                        "PROVIDER_ID": "IMOPENLINES_SESSION",
                        ">=CREATED": date_from_iso,
                        "<=CREATED": date_to_iso,
                    },
                    "select": ["ID", "SUBJECT", "CREATED", "LAST_UPDATED", "COMPLETED", "PROVIDER_TYPE_ID"],
                },
            ),
        ]

        for label, method, params in strategies:
            try:
                result = self.client.call_all(method, params)
                analytics.method_used = label

                if method == "crm.activity.list":
                    return self._activities_to_sessions(result)

                return result
            except Bitrix24Error as exc:
                analytics.warnings.append(f"{label}: {exc}")
            except Exception as exc:
                analytics.warnings.append(f"{label}: {exc}")

        analytics.warnings.append(
            "Не удалось получить данные открытых линий. "
            "Проверьте права вебхука (imopenlines, crm) и тариф (report_open_lines)."
        )
        return []

    def _activities_to_sessions(self, activities: list[dict[str, Any]]) -> list[dict[str, Any]]:
        sessions: list[dict[str, Any]] = []
        for activity in activities:
            sessions.append({
                "id": activity.get("ID"),
                "dateCreate": activity.get("CREATED"),
                "dateClose": activity.get("LAST_UPDATED") if activity.get("COMPLETED") == "Y" else None,
                "status": "close" if activity.get("COMPLETED") == "Y" else "open",
                "source": activity.get("PROVIDER_TYPE_ID") or "crm",
                "vote": "none",
            })
        return sessions

    def _fetch_session_stats(self, session_ids: list[Any]) -> list[dict[str, Any]]:
        if not session_ids:
            return []

        numeric_ids = [int(sid) for sid in session_ids if str(sid).isdigit()]
        if not numeric_ids:
            return []

        all_stats: list[dict[str, Any]] = []

        for i in range(0, len(numeric_ids), 100):
            batch = numeric_ids[i : i + 100]
            try:
                result = self.client.call("imopenlines.v2.Session.Stat.get", {"sessionId": batch})
                if isinstance(result, dict):
                    sessions = result.get("sessions") or result.get("items") or []
                    all_stats.extend(sessions)
            except Bitrix24Error:
                try:
                    result = self.client.call("imopenlines.session.stat.get", {"SESSION_ID": batch})
                    if isinstance(result, list):
                        all_stats.extend(result)
                    elif isinstance(result, dict):
                        all_stats.append(result)
                except Bitrix24Error:
                    break
            except Exception:
                break

        return all_stats
