"""Аналитика по открытым линиям Битрикс24 (методы ``imopenlines.v2.*``).

Методы статистики открытых линий выходят в обновлении ``imopenlines 26.700.0``
и требуют тарифа с правом ``report_open_lines``. Если на портале они ещё не
доступны, отчёт формируется без блока открытых линий с пояснением.
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime
from statistics import median
from typing import Any, Dict, List, Optional

from .client import Bitrix24Client, Bitrix24Error, MethodNotAvailableError


@dataclass
class OpenLinesReport:
    """Метрики оператора открытых линий за период."""

    available: bool = True
    unavailable_reason: str = ""
    handled_sessions: int = 0
    avg_resolution_seconds: Optional[float] = None
    median_resolution_seconds: Optional[float] = None
    avg_first_answer_seconds: Optional[float] = None
    likes: int = 0
    dislikes: int = 0
    sessions_by_source: Dict[str, int] = field(default_factory=dict)
    line_totals: Dict[str, Any] = field(default_factory=dict)
    sessions: List[Dict[str, Any]] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)


def aggregate_sessions(sessions: List[Dict[str, Any]]) -> OpenLinesReport:
    """Чистая агрегация метрик по списку сессий (без обращений к API)."""
    report = OpenLinesReport()
    report.sessions = sessions
    report.handled_sessions = len(sessions)

    resolution = [_as_seconds(s.get("waitClose")) for s in sessions]
    resolution = [v for v in resolution if v is not None]
    if resolution:
        report.avg_resolution_seconds = sum(resolution) / len(resolution)
        report.median_resolution_seconds = median(resolution)

    first_answer = [_as_seconds(s.get("waitAnswer")) for s in sessions]
    first_answer = [v for v in first_answer if v is not None]
    if first_answer:
        report.avg_first_answer_seconds = sum(first_answer) / len(first_answer)

    by_source: Counter = Counter()
    for session in sessions:
        vote = str(session.get("vote", "") or "").lower()
        if vote == "like":
            report.likes += 1
        elif vote == "dislike":
            report.dislikes += 1
        source = str(session.get("source", "") or "неизвестно")
        by_source[source] += 1
    report.sessions_by_source = dict(by_source.most_common())
    return report


class OpenLinesAnalytics:
    """Собирает метрики открытых линий через REST."""

    def __init__(self, client: Bitrix24Client):
        self.client = client

    def collect(self, operator_id: int, date_from: datetime, date_to: datetime) -> OpenLinesReport:
        try:
            sessions = list(
                self.client.iter_offset_list(
                    "imopenlines.v2.Session.list",
                    {
                        "operatorId": operator_id,
                        "status": "closed",
                        "dateCloseFrom": date_from.isoformat(),
                        "dateCloseTo": date_to.isoformat(),
                        "order": "dateClose",
                        "orderDirection": "asc",
                    },
                    items_key="sessions",
                )
            )
        except MethodNotAvailableError:
            return OpenLinesReport(
                available=False,
                unavailable_reason=(
                    "Методы статистики открытых линий недоступны на портале: "
                    "требуется обновление imopenlines 26.700.0 и тариф с правом "
                    "report_open_lines. Блок открытых линий пропущен."
                ),
            )
        except Bitrix24Error as exc:
            return OpenLinesReport(
                available=False,
                unavailable_reason=f"Не удалось получить сессии открытых линий: {exc}",
            )

        report = aggregate_sessions(sessions)
        report.line_totals = self._line_totals(operator_id, date_from, date_to)
        return report

    def _line_totals(self, operator_id: int, date_from: datetime, date_to: datetime) -> Dict[str, Any]:
        """Сводные агрегаты по оператору через ``imopenlines.v2.Stat.get`` (если доступен)."""
        try:
            result = self.client.call(
                "imopenlines.v2.Stat.get",
                {
                    "dateFrom": date_from.isoformat(),
                    "dateTo": date_to.isoformat(),
                    "operatorId": operator_id,
                },
            )
        except Bitrix24Error:
            return {}
        return result if isinstance(result, dict) else {}


def _as_seconds(value) -> Optional[float]:
    try:
        seconds = float(value)
    except (TypeError, ValueError):
        return None
    return seconds if seconds >= 0 else None
