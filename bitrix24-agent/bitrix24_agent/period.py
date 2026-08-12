"""Разбор пресетов периода (today/yesterday/week/month/...) в даты для фильтров Битрикс24."""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

_PRESETS = (
    "today",
    "yesterday",
    "week",
    "last_week",
    "month",
    "last_month",
    "quarter",
    "year",
    "all",
)

_CUSTOM_RANGE_RE = re.compile(
    r"^(?P<start>\d{4}-\d{2}-\d{2})(?::|\.\.)(?P<end>\d{4}-\d{2}-\d{2})$"
)


class PeriodError(ValueError):
    pass


@dataclass(frozen=True)
class Period:
    name: str
    date_from: datetime  # включительно, с таймзоной
    date_to: datetime  # исключительно (конец периода), с таймзоной

    def as_bitrix_filter(self, field_from: str, field_to: str = None) -> dict:
        """Готовит фильтр для tasks.task.list / crm.activity.list по датам."""
        field_to = field_to or field_from
        return {
            f">={field_from}": self.date_from.strftime("%Y-%m-%dT%H:%M:%S%z"),
            f"<{field_to}": self.date_to.strftime("%Y-%m-%dT%H:%M:%S%z"),
        }

    def __str__(self) -> str:
        return f"{self.date_from.date()} — {(self.date_to - timedelta(seconds=1)).date()}"


def _tz_from_offset(offset: str) -> timezone:
    sign = 1 if offset.startswith("+") else -1
    offset = offset.lstrip("+-")
    hours, minutes = offset.split(":")
    return timezone(sign * timedelta(hours=int(hours), minutes=int(minutes)))


def parse_period(preset_or_range: str, tz_offset: str = "+00:00") -> Period:
    """Преобразует строку пресета или диапазон `YYYY-MM-DD:YYYY-MM-DD` в Period."""
    tz = _tz_from_offset(tz_offset)
    now = datetime.now(tz)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    name = preset_or_range.strip().lower()

    match = _CUSTOM_RANGE_RE.match(preset_or_range.strip())
    if match:
        start = datetime.strptime(match.group("start"), "%Y-%m-%d").replace(tzinfo=tz)
        end = datetime.strptime(match.group("end"), "%Y-%m-%d").replace(tzinfo=tz) + timedelta(days=1)
        return Period(name=preset_or_range, date_from=start, date_to=end)

    if name == "today":
        return Period(name, today_start, today_start + timedelta(days=1))
    if name == "yesterday":
        start = today_start - timedelta(days=1)
        return Period(name, start, today_start)
    if name == "week":
        start = today_start - timedelta(days=today_start.weekday())
        return Period(name, start, today_start + timedelta(days=1))
    if name == "last_week":
        this_week_start = today_start - timedelta(days=today_start.weekday())
        start = this_week_start - timedelta(days=7)
        return Period(name, start, this_week_start)
    if name == "month":
        start = today_start.replace(day=1)
        return Period(name, start, today_start + timedelta(days=1))
    if name == "last_month":
        first_of_this_month = today_start.replace(day=1)
        last_month_end = first_of_this_month
        last_month_start = (first_of_this_month - timedelta(days=1)).replace(day=1)
        return Period(name, last_month_start, last_month_end)
    if name == "quarter":
        quarter_index = (today_start.month - 1) // 3
        start_month = quarter_index * 3 + 1
        start = today_start.replace(month=start_month, day=1)
        return Period(name, start, today_start + timedelta(days=1))
    if name == "year":
        start = today_start.replace(month=1, day=1)
        return Period(name, start, today_start + timedelta(days=1))
    if name == "all":
        start = datetime(2000, 1, 1, tzinfo=tz)
        return Period(name, start, today_start + timedelta(days=1))

    raise PeriodError(
        f"Неизвестный период '{preset_or_range}'. Доступные пресеты: {', '.join(_PRESETS)} "
        "или диапазон в формате YYYY-MM-DD:YYYY-MM-DD"
    )
