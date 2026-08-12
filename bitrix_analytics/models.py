from dataclasses import dataclass
from datetime import date


@dataclass(frozen=True)
class ReportPeriod:
    start: date
    end: date


@dataclass(frozen=True)
class ActivityMetrics:
    period: ReportPeriod
    closed_tasks: int
    active_tasks: int
    tasks_by_status: dict[str, int]
    handled_open_line_sessions: int
    average_open_line_resolution_minutes: float | None
