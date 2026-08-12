"""Модели запроса на отчёт и посчитанных метрик."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from enum import StrEnum
from typing import Any

from b24agent.analytics.humanize import isoformat
from b24agent.analytics.period import Period
from b24agent.bitrix.openlines import OpenLinesDataSource, Session
from b24agent.bitrix.tasks import Task


class ReportSection(StrEnum):
    """Разделы, которые можно запросить у бота по отдельности."""

    TASKS = "tasks"
    STAGES = "stages"
    OPENLINES = "openlines"

    @property
    def title(self) -> str:
        return {
            ReportSection.TASKS: "Задачи",
            ReportSection.STAGES: "Стадии задач",
            ReportSection.OPENLINES: "Открытые линии",
        }[self]


ALL_SECTIONS: frozenset[ReportSection] = frozenset(ReportSection)


class ReportFormat(StrEnum):
    XLSX = "xlsx"
    CSV = "csv"
    JSON = "json"

    @property
    def extension(self) -> str:
        return self.value

    @property
    def mime(self) -> str:
        return {
            ReportFormat.XLSX: (
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            ),
            ReportFormat.CSV: "text/csv",
            ReportFormat.JSON: "application/json",
        }[self]


@dataclass(frozen=True, slots=True)
class ReportRequest:
    """Что именно нужно посчитать — результат разбора запроса пользователя."""

    period: Period
    sections: frozenset[ReportSection] = ALL_SECTIONS
    report_format: ReportFormat = ReportFormat.XLSX
    bitrix_user_id: int | None = None
    include_details: bool = True
    raw_query: str = ""

    def wants(self, section: ReportSection) -> bool:
        return section in self.sections


@dataclass(slots=True)
class TaskMetrics:
    """Метрики по задачам сотрудника."""

    closed_count: int = 0
    created_count: int = 0
    open_count: int = 0
    by_status: dict[str, int] = field(default_factory=dict)
    by_stage: dict[str, int] = field(default_factory=dict)
    by_group: dict[str, int] = field(default_factory=dict)
    stage_titles: dict[int, str] = field(default_factory=dict)
    overdue_open_count: int = 0
    closed_overdue_count: int = 0
    closed_on_time_count: int = 0
    without_deadline_count: int = 0
    avg_lead_time_seconds: float | None = None
    median_lead_time_seconds: float | None = None
    p90_lead_time_seconds: float | None = None
    fastest_lead_time_seconds: float | None = None
    slowest_lead_time_seconds: float | None = None
    total_time_spent_seconds: float = 0.0
    avg_time_spent_seconds: float | None = None
    closed_per_day: dict[date, int] = field(default_factory=dict)
    closed_tasks: list[Task] = field(default_factory=list)
    open_tasks: list[Task] = field(default_factory=list)
    truncated: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "closed_count": self.closed_count,
            "created_count": self.created_count,
            "open_count": self.open_count,
            "by_status": self.by_status,
            "by_stage": self.by_stage,
            "by_group": self.by_group,
            "overdue_open_count": self.overdue_open_count,
            "closed_overdue_count": self.closed_overdue_count,
            "closed_on_time_count": self.closed_on_time_count,
            "without_deadline_count": self.without_deadline_count,
            "avg_lead_time_seconds": self.avg_lead_time_seconds,
            "median_lead_time_seconds": self.median_lead_time_seconds,
            "p90_lead_time_seconds": self.p90_lead_time_seconds,
            "fastest_lead_time_seconds": self.fastest_lead_time_seconds,
            "slowest_lead_time_seconds": self.slowest_lead_time_seconds,
            "total_time_spent_seconds": self.total_time_spent_seconds,
            "avg_time_spent_seconds": self.avg_time_spent_seconds,
            "closed_per_day": {
                day.isoformat(): count for day, count in self.closed_per_day.items()
            },
        }


@dataclass(slots=True)
class OpenLineMetrics:
    """Метрики по обращениям открытых линий."""

    data_source: OpenLinesDataSource = OpenLinesDataSource.UNAVAILABLE
    total_sessions: int = 0
    closed_sessions: int = 0
    open_sessions: int = 0
    avg_first_answer_seconds: float | None = None
    median_first_answer_seconds: float | None = None
    avg_resolution_seconds: float | None = None
    median_resolution_seconds: float | None = None
    p90_resolution_seconds: float | None = None
    likes: int = 0
    dislikes: int = 0
    voted_sessions: int = 0
    positive_rate: float | None = None
    kpi_first_answer_ok: int = 0
    kpi_first_answer_fail: int = 0
    avg_messages: float | None = None
    by_source: dict[str, int] = field(default_factory=dict)
    by_line: dict[str, int] = field(default_factory=dict)
    by_day: dict[date, int] = field(default_factory=dict)
    by_hour: list[int] = field(default_factory=lambda: [0] * 24)
    sessions: list[Session] = field(default_factory=list)
    portal_aggregate: dict[str, Any] | None = None
    notes: list[str] = field(default_factory=list)

    @property
    def is_approximate(self) -> bool:
        return self.data_source.is_approximate

    def to_dict(self) -> dict[str, Any]:
        return {
            "data_source": self.data_source.value,
            "is_approximate": self.is_approximate,
            "total_sessions": self.total_sessions,
            "closed_sessions": self.closed_sessions,
            "open_sessions": self.open_sessions,
            "avg_first_answer_seconds": self.avg_first_answer_seconds,
            "median_first_answer_seconds": self.median_first_answer_seconds,
            "avg_resolution_seconds": self.avg_resolution_seconds,
            "median_resolution_seconds": self.median_resolution_seconds,
            "p90_resolution_seconds": self.p90_resolution_seconds,
            "likes": self.likes,
            "dislikes": self.dislikes,
            "voted_sessions": self.voted_sessions,
            "positive_rate": self.positive_rate,
            "kpi_first_answer_ok": self.kpi_first_answer_ok,
            "kpi_first_answer_fail": self.kpi_first_answer_fail,
            "avg_messages": self.avg_messages,
            "by_source": self.by_source,
            "by_line": self.by_line,
            "by_day": {day.isoformat(): count for day, count in self.by_day.items()},
            "by_hour": self.by_hour,
            "portal_aggregate": self.portal_aggregate,
            "notes": self.notes,
        }


@dataclass(slots=True)
class Report:
    """Готовый отчёт: метрики, метаданные и предупреждения."""

    request: ReportRequest
    period: Period
    generated_at: datetime
    user_id: int
    user_name: str
    portal_url: str = ""
    tasks: TaskMetrics | None = None
    openlines: OpenLineMetrics | None = None
    warnings: list[str] = field(default_factory=list)

    @property
    def is_empty(self) -> bool:
        return self.tasks is None and self.openlines is None

    def to_dict(self) -> dict[str, Any]:
        return {
            "meta": {
                "generated_at": isoformat(self.generated_at),
                "portal": self.portal_url,
                "employee": {"id": self.user_id, "name": self.user_name},
                "period": {
                    "label": self.period.label,
                    "from": isoformat(self.period.start),
                    "to": isoformat(self.period.end),
                    "days": self.period.days,
                },
                "query": self.request.raw_query,
                "sections": sorted(section.value for section in self.request.sections),
                "warnings": self.warnings,
            },
            "tasks": self.tasks.to_dict() if self.tasks else None,
            "openlines": self.openlines.to_dict() if self.openlines else None,
        }
