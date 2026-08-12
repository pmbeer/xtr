from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional

from services.datetime_utils import parse_bitrix_datetime

TASK_STATUS_LABELS: Dict[int, str] = {
    2: "Ждёт выполнения",
    3: "В работе",
    4: "Ждёт контроля",
    5: "Завершена",
    6: "Отложена",
}


@dataclass
class Period:
    date_from: datetime
    date_to: datetime
    label: str = ""

    @classmethod
    def last_days(cls, days: int, *, now: Optional[datetime] = None) -> "Period":
        now = now or datetime.now()
        start = (now - timedelta(days=days - 1)).replace(hour=0, minute=0, second=0, microsecond=0)
        end = now.replace(hour=23, minute=59, second=59, microsecond=0)
        return cls(date_from=start, date_to=end, label=f"последние {days} дн.")

    def to_bitrix_from(self) -> str:
        return self.date_from.strftime("%Y-%m-%dT%H:%M:%S")

    def to_bitrix_to(self) -> str:
        return self.date_to.strftime("%Y-%m-%dT%H:%M:%S")


@dataclass
class TaskStats:
    total: int = 0
    closed: int = 0
    in_progress: int = 0
    pending: int = 0
    awaiting_control: int = 0
    deferred: int = 0
    overdue: int = 0
    by_status: Dict[str, int] = field(default_factory=dict)
    by_stage: Dict[str, int] = field(default_factory=dict)
    closed_titles: List[str] = field(default_factory=list)
    in_progress_titles: List[str] = field(default_factory=list)
    avg_close_hours: Optional[float] = None


@dataclass
class OpenLineStats:
    total_sessions: int = 0
    closed_sessions: int = 0
    active_sessions: int = 0
    avg_answer_seconds: Optional[float] = None
    avg_close_seconds: Optional[float] = None
    avg_close_hours: Optional[float] = None
    by_source: Dict[str, int] = field(default_factory=dict)
    notes: str = ""


@dataclass
class AnalyticsReport:
    user_id: int
    user_name: str
    period: Period
    generated_at: datetime
    tasks: TaskStats
    open_lines: OpenLineStats
    summary_lines: List[str] = field(default_factory=list)

    def build_summary(self) -> List[str]:
        t = self.tasks
        o = self.open_lines
        lines = [
            f"Сотрудник: {self.user_name} (ID {self.user_id})",
            f"Период: {self.period.date_from:%d.%m.%Y} — {self.period.date_to:%d.%m.%Y}"
            + (f" ({self.period.label})" if self.period.label else ""),
            "",
            "Задачи:",
            f"  • Всего за период / в зоне ответственности: {t.total}",
            f"  • Закрыто: {t.closed}",
            f"  • В работе: {t.in_progress}",
            f"  • Ждут выполнения: {t.pending}",
            f"  • Ждут контроля: {t.awaiting_control}",
            f"  • Отложены: {t.deferred}",
            f"  • Просрочены: {t.overdue}",
        ]
        if t.avg_close_hours is not None:
            lines.append(f"  • Среднее время закрытия задачи: {t.avg_close_hours:.1f} ч")
        if t.by_stage:
            lines.append("  • По стадиям:")
            for stage, count in sorted(t.by_stage.items(), key=lambda x: (-x[1], x[0])):
                lines.append(f"      — {stage}: {count}")

        lines.extend(
            [
                "",
                "Открытые линии:",
                f"  • Обработано сессий: {o.total_sessions}",
                f"  • Закрыто: {o.closed_sessions}",
                f"  • В работе: {o.active_sessions}",
            ]
        )
        if o.avg_answer_seconds is not None:
            lines.append(f"  • Среднее время первого ответа: {_fmt_duration(o.avg_answer_seconds)}")
        if o.avg_close_seconds is not None:
            lines.append(f"  • Среднее время решения: {_fmt_duration(o.avg_close_seconds)}")
        if o.by_source:
            lines.append("  • По каналам:")
            for source, count in sorted(o.by_source.items(), key=lambda x: (-x[1], x[0])):
                lines.append(f"      — {source}: {count}")
        if o.notes:
            lines.append(f"  • Примечание: {o.notes}")

        self.summary_lines = lines
        return lines


def _fmt_duration(seconds: float) -> str:
    seconds = max(0, int(seconds))
    hours, rem = divmod(seconds, 3600)
    minutes, secs = divmod(rem, 60)
    if hours:
        return f"{hours} ч {minutes} мин"
    if minutes:
        return f"{minutes} мин {secs} сек"
    return f"{secs} сек"


__all__ = [
    "TASK_STATUS_LABELS",
    "Period",
    "TaskStats",
    "OpenLineStats",
    "AnalyticsReport",
    "parse_bitrix_datetime",
]
