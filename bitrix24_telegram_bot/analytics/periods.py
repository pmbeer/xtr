"""Периоды отчётов: 'сегодня', 'неделя', 'месяц' и т.п."""

from dataclasses import dataclass
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo


@dataclass(frozen=True)
class Period:
    date_from: datetime
    date_to: datetime
    label: str

    def contains(self, moment: datetime | None) -> bool:
        if moment is None:
            return False
        return self.date_from <= moment <= self.date_to


def resolve_period(name: str, tz: ZoneInfo) -> Period:
    """Вернуть границы периода по его имени (по умолчанию — текущий месяц)."""
    now = datetime.now(tz)
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)

    if name == "today":
        return Period(today, now, "сегодня")
    if name == "yesterday":
        start = today - timedelta(days=1)
        return Period(start, today - timedelta(microseconds=1), "вчера")
    if name == "week":
        start = today - timedelta(days=today.weekday())
        return Period(start, now, "текущая неделя")
    if name == "prev_week":
        end = today - timedelta(days=today.weekday())
        start = end - timedelta(days=7)
        return Period(start, end - timedelta(microseconds=1), "прошлая неделя")
    if name == "month":
        start = today.replace(day=1)
        return Period(start, now, "текущий месяц")
    if name == "prev_month":
        first_of_month = today.replace(day=1)
        end = first_of_month - timedelta(microseconds=1)
        start = end.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        return Period(start, end, "прошлый месяц")
    if name == "quarter":
        quarter_start_month = 3 * ((today.month - 1) // 3) + 1
        start = today.replace(month=quarter_start_month, day=1)
        return Period(start, now, "текущий квартал")
    if name == "year":
        start = today.replace(month=1, day=1)
        return Period(start, now, "текущий год")

    # По умолчанию — текущий месяц.
    start = today.replace(day=1)
    return Period(start, now, "текущий месяц")


def format_timedelta(seconds: float | None) -> str:
    """Человекочитаемое представление длительности: '2 д 3 ч 15 мин'."""
    if seconds is None:
        return "—"
    seconds = int(seconds)
    days, seconds = divmod(seconds, 86400)
    hours, seconds = divmod(seconds, 3600)
    minutes = seconds // 60
    parts = []
    if days:
        parts.append(f"{days} д")
    if hours:
        parts.append(f"{hours} ч")
    parts.append(f"{minutes} мин")
    return " ".join(parts)
