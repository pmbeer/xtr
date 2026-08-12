"""Расчёт метрик по обращениям открытых линий.

Если портал отдал готовые агрегаты (``imopenlines.v2.Stat.get``), они имеют
приоритет над клиентским подсчётом: там метрики считаются по всей истории
сессии, включая переназначения между операторами.
"""

from __future__ import annotations

from collections import Counter
from collections.abc import Sequence

from b24agent.analytics import stats
from b24agent.analytics.models import OpenLineMetrics
from b24agent.analytics.period import Period
from b24agent.bitrix.openlines import (
    VOTE_DISLIKE,
    VOTE_LIKE,
    OpenLinesData,
    OpenLinesDataSource,
    Session,
    source_title,
)


def compute_openline_metrics(data: OpenLinesData, period: Period) -> OpenLineMetrics:
    sessions = data.sessions
    metrics = OpenLineMetrics(
        data_source=data.source,
        total_sessions=len(sessions),
        closed_sessions=sum(1 for session in sessions if session.is_closed),
        sessions=list(sessions),
        portal_aggregate=data.aggregate,
        by_source=_by_source(sessions),
        by_line=_by_line(sessions, data.line_names),
        by_day=_by_day(sessions, period),
        by_hour=_by_hour(sessions),
        notes=list(data.notes),
    )
    metrics.open_sessions = metrics.total_sessions - metrics.closed_sessions

    first_answers = stats.clean(session.wait_answer_seconds for session in sessions)
    resolutions = stats.clean(session.resolution_seconds for session in sessions)
    messages = [float(s.message_count) for s in sessions if s.message_count > 0]

    metrics.avg_first_answer_seconds = stats.mean(first_answers)
    metrics.median_first_answer_seconds = stats.median(first_answers)
    metrics.avg_resolution_seconds = stats.mean(resolutions)
    metrics.median_resolution_seconds = stats.median(resolutions)
    metrics.p90_resolution_seconds = stats.percentile(resolutions, 0.9)
    metrics.avg_messages = stats.mean(messages)

    votes = Counter(session.vote for session in sessions if session.vote)
    metrics.likes = votes.get(VOTE_LIKE, 0)
    metrics.dislikes = votes.get(VOTE_DISLIKE, 0)
    metrics.voted_sessions = metrics.likes + metrics.dislikes
    metrics.positive_rate = stats.share(metrics.likes, metrics.voted_sessions)

    metrics.kpi_first_answer_ok = sum(
        1 for session in sessions if session.kpi_first_answer is True
    )
    metrics.kpi_first_answer_fail = sum(
        1 for session in sessions if session.kpi_first_answer is False
    )

    if data.aggregate:
        _apply_portal_aggregate(metrics, data.aggregate)
    return metrics


def _apply_portal_aggregate(metrics: OpenLineMetrics, aggregate: dict) -> None:
    """Перекрывает клиентские оценки цифрами портала, где они есть."""
    mapping = {
        "totalSessions": "total_sessions",
        "closedSessions": "closed_sessions",
        "avgWaitAnswer": "avg_first_answer_seconds",
        "avgSessionDuration": "avg_resolution_seconds",
        "likeCount": "likes",
        "dislikeCount": "dislikes",
        "votedSessions": "voted_sessions",
        "positiveRate": "positive_rate",
        "kpiFirstAnswerOk": "kpi_first_answer_ok",
        "kpiFirstAnswerFail": "kpi_first_answer_fail",
    }
    for source_key, attribute in mapping.items():
        value = aggregate.get(source_key)
        if value is None:
            continue
        current = getattr(metrics, attribute)
        setattr(metrics, attribute, type(current)(value) if current is not None else value)

    if isinstance(aggregate.get("sessionsBySource"), list):
        by_source = {
            source_title(str(item.get("source", ""))): int(item.get("count", 0))
            for item in aggregate["sessionsBySource"]
            if isinstance(item, dict)
        }
        if by_source:
            metrics.by_source = dict(
                sorted(by_source.items(), key=lambda pair: pair[1], reverse=True)
            )

    hourly = aggregate.get("sessionsByHour")
    if isinstance(hourly, list) and len(hourly) == 24:
        metrics.by_hour = [int(value or 0) for value in hourly]

    if metrics.total_sessions:
        metrics.open_sessions = max(metrics.total_sessions - metrics.closed_sessions, 0)


def _by_source(sessions: Sequence[Session]) -> dict[str, int]:
    counter = Counter(source_title(session.source) for session in sessions)
    return dict(counter.most_common())


def _by_line(sessions: Sequence[Session], line_names: dict[int, str]) -> dict[str, int]:
    counter: Counter[str] = Counter()
    for session in sessions:
        if not session.config_id:
            counter["Линия не определена"] += 1
        else:
            counter[line_names.get(session.config_id, f"Линия {session.config_id}")] += 1
    return dict(counter.most_common())


def _by_day(sessions: Sequence[Session], period: Period) -> dict:
    per_day = {day: 0 for day in period.iter_days()}
    for session in sessions:
        if session.created_at is None:
            continue
        day = session.created_at.date()
        per_day[day] = per_day.get(day, 0) + 1
    return dict(sorted(per_day.items()))


def _by_hour(sessions: Sequence[Session]) -> list[int]:
    hours = [0] * 24
    for session in sessions:
        if session.created_at is not None:
            hours[session.created_at.hour] += 1
    return hours


def empty_metrics(source: OpenLinesDataSource = OpenLinesDataSource.UNAVAILABLE) -> OpenLineMetrics:
    return OpenLineMetrics(data_source=source)
