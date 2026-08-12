"""Периоды отчётов: границы, подписи и календарная арифметика.

Все периоды — полуинтервалы ``[start, end]`` в часовом поясе портала. Границы
всегда с таймзоной, иначе сравнение с датами из Битрикс24 (они приходят со
смещением) даёт неверный результат.
"""

from __future__ import annotations

import calendar
from collections.abc import Iterator
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

MONTHS_NOMINATIVE = (
    "январь",
    "февраль",
    "март",
    "апрель",
    "май",
    "июнь",
    "июль",
    "август",
    "сентябрь",
    "октябрь",
    "ноябрь",
    "декабрь",
)


@dataclass(frozen=True, slots=True)
class Period:
    """Отрезок времени, за который считается отчёт."""

    start: datetime
    end: datetime
    label: str

    def __post_init__(self) -> None:
        if self.start.tzinfo is None or self.end.tzinfo is None:
            raise ValueError("Границы периода должны быть с часовым поясом")
        if self.end < self.start:
            raise ValueError("Конец периода раньше начала")

    @property
    def tz(self) -> ZoneInfo | None:
        tzinfo = self.start.tzinfo
        return tzinfo if isinstance(tzinfo, ZoneInfo) else None

    @property
    def days(self) -> int:
        return (self.end.date() - self.start.date()).days + 1

    def contains(self, moment: datetime | None) -> bool:
        if moment is None:
            return False
        return self.start <= moment <= self.end

    def bitrix_start(self) -> str:
        return self.start.isoformat(timespec="seconds")

    def bitrix_end(self) -> str:
        return self.end.isoformat(timespec="seconds")

    def iter_days(self) -> Iterator[date]:
        current = self.start.date()
        last = self.end.date()
        while current <= last:
            yield current
            current += timedelta(days=1)

    def human(self) -> str:
        return f"{self.label} ({_fmt(self.start)} — {_fmt(self.end)})"


def _fmt(moment: datetime) -> str:
    return moment.strftime("%d.%m.%Y")


def _start_of_day(day: date, tz: ZoneInfo) -> datetime:
    return datetime.combine(day, time.min, tzinfo=tz)


def _end_of_day(day: date, tz: ZoneInfo) -> datetime:
    return datetime.combine(day, time.max.replace(microsecond=0), tzinfo=tz)


def _shift_months(day: date, months: int) -> date:
    total = day.year * 12 + (day.month - 1) + months
    year, month = divmod(total, 12)
    month += 1
    last_day = calendar.monthrange(year, month)[1]
    return date(year, month, min(day.day, last_day))


def from_dates(first: date, second: date, tz: ZoneInfo, label: str | None = None) -> Period:
    """Период по двум календарным датам (порядок не важен)."""
    start, end = sorted((first, second))
    return Period(
        start=_start_of_day(start, tz),
        end=_end_of_day(end, tz),
        label=label or f"{start.strftime('%d.%m.%Y')} — {end.strftime('%d.%m.%Y')}",
    )


def single_day(day: date, tz: ZoneInfo, label: str | None = None) -> Period:
    return Period(
        start=_start_of_day(day, tz),
        end=_end_of_day(day, tz),
        label=label or day.strftime("%d.%m.%Y"),
    )


def today(now: datetime) -> Period:
    return single_day(now.date(), _tz(now), "сегодня")


def yesterday(now: datetime) -> Period:
    return single_day(now.date() - timedelta(days=1), _tz(now), "вчера")


def day_before_yesterday(now: datetime) -> Period:
    return single_day(now.date() - timedelta(days=2), _tz(now), "позавчера")


def this_week(now: datetime) -> Period:
    monday = now.date() - timedelta(days=now.weekday())
    return from_dates(monday, now.date(), _tz(now), "текущая неделя")


def last_week(now: datetime) -> Period:
    monday = now.date() - timedelta(days=now.weekday() + 7)
    return from_dates(monday, monday + timedelta(days=6), _tz(now), "прошлая неделя")


def this_month(now: datetime) -> Period:
    first = now.date().replace(day=1)
    return from_dates(first, now.date(), _tz(now), f"{MONTHS_NOMINATIVE[first.month - 1]} {first.year}")


def last_month(now: datetime) -> Period:
    first = _shift_months(now.date().replace(day=1), -1)
    last = first.replace(day=calendar.monthrange(first.year, first.month)[1])
    return from_dates(
        first, last, _tz(now), f"{MONTHS_NOMINATIVE[first.month - 1]} {first.year}"
    )


def month_of(year: int, month: int, tz: ZoneInfo) -> Period:
    first = date(year, month, 1)
    last = first.replace(day=calendar.monthrange(year, month)[1])
    return from_dates(first, last, tz, f"{MONTHS_NOMINATIVE[month - 1]} {year}")


def this_quarter(now: datetime) -> Period:
    quarter = (now.month - 1) // 3
    first = date(now.year, quarter * 3 + 1, 1)
    return from_dates(first, now.date(), _tz(now), f"{quarter + 1}-й квартал {now.year}")


def last_quarter(now: datetime) -> Period:
    quarter = (now.month - 1) // 3
    first_of_current = date(now.year, quarter * 3 + 1, 1)
    first = _shift_months(first_of_current, -3)
    last = _shift_months(first, 3) - timedelta(days=1)
    previous_quarter = (first.month - 1) // 3 + 1
    return from_dates(first, last, _tz(now), f"{previous_quarter}-й квартал {first.year}")


def this_year(now: datetime) -> Period:
    return from_dates(date(now.year, 1, 1), now.date(), _tz(now), f"{now.year} год")


def last_year(now: datetime) -> Period:
    year = now.year - 1
    return from_dates(date(year, 1, 1), date(year, 12, 31), _tz(now), f"{year} год")


def last_n_days(now: datetime, count: int) -> Period:
    count = max(count, 1)
    start = now.date() - timedelta(days=count - 1)
    return from_dates(start, now.date(), _tz(now), f"последние {count} дн.")


def last_n_months(now: datetime, count: int) -> Period:
    count = max(count, 1)
    start = _shift_months(now.date(), -count)
    return from_dates(start, now.date(), _tz(now), f"последние {count} мес.")


def default_period(now: datetime) -> Period:
    """Период по умолчанию, когда в запросе нет указания на даты."""
    return this_month(now)


def _tz(moment: datetime) -> ZoneInfo:
    tzinfo = moment.tzinfo
    if isinstance(tzinfo, ZoneInfo):
        return tzinfo
    raise ValueError("Ожидается datetime с ZoneInfo")
