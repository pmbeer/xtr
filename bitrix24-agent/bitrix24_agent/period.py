"""Разбор периодов отчёта: `месяц`, `30d`, `2026-06`, `2026-06-01..2026-06-30`."""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, tzinfo
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from .errors import ConfigError

MONTH_RE = re.compile(r"^(\d{4})-(\d{2})$")
DAY_RE = re.compile(r"^(\d{4})-(\d{2})-(\d{2})$")
RANGE_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})\.\.(\d{4}-\d{2}-\d{2})$")
LAST_DAYS_RE = re.compile(r"^(\d+)\s*(?:d|д|дн|дней|day|days)$", re.IGNORECASE)

MONTH_NAMES_GENITIVE = (
    "января",
    "февраля",
    "марта",
    "апреля",
    "мая",
    "июня",
    "июля",
    "августа",
    "сентября",
    "октября",
    "ноября",
    "декабря",
)

#: Синонимы периодов: русские и английские названия приводятся к одному ключу.
ALIASES = {
    "today": "today",
    "сегодня": "today",
    "yesterday": "yesterday",
    "вчера": "yesterday",
    "week": "week",
    "неделя": "week",
    "last-week": "last-week",
    "прошлая-неделя": "last-week",
    "month": "month",
    "месяц": "month",
    "last-month": "last-month",
    "прошлый-месяц": "last-month",
    "quarter": "quarter",
    "квартал": "quarter",
    "year": "year",
    "год": "year",
    "all": "all",
    "всё": "all",
    "все": "all",
}


def resolve_timezone(name: str) -> tzinfo:
    """Возвращает часовой пояс портала; при неизвестном имени — понятная ошибка."""
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError) as exc:
        raise ConfigError(
            f"Неизвестный часовой пояс {name!r}. Укажите B24_TIMEZONE в формате IANA, "
            "например Europe/Moscow."
        ) from exc


@dataclass(frozen=True)
class Period:
    """Полуинтервал отчёта с учётом часового пояса портала."""

    start: datetime
    end: datetime
    label: str

    @property
    def days(self) -> float:
        return (self.end - self.start).total_seconds() / 86400

    @property
    def key(self) -> str:
        """Стабильный идентификатор периода — для хранения снимков."""
        return f"{self.start.date().isoformat()}..{self.end.date().isoformat()}"

    def iso_start(self) -> str:
        return self.start.isoformat()

    def iso_end(self) -> str:
        return self.end.isoformat()

    def contains(self, moment: datetime | None) -> bool:
        return moment is not None and self.start <= moment <= self.end

    def previous(self) -> Period:
        """Предыдущий период такой же длительности — база для сравнения."""
        duration = self.end - self.start
        new_end = self.start - timedelta(seconds=1)
        new_start = new_end - duration
        return Period(new_start, new_end, f"предыдущий период ({_short_range(new_start, new_end)})")

    def to_dict(self) -> dict:
        return {
            "label": self.label,
            "start": self.iso_start(),
            "end": self.iso_end(),
            "days": round(self.days, 2),
        }


def _short_range(start: datetime, end: datetime) -> str:
    if start.year == end.year:
        return f"{start.day} {MONTH_NAMES_GENITIVE[start.month - 1]} — {end.day} {MONTH_NAMES_GENITIVE[end.month - 1]} {end.year}"
    return f"{start.date().isoformat()} — {end.date().isoformat()}"


def _day_bounds(day: date, tz: tzinfo) -> tuple[datetime, datetime]:
    start = datetime.combine(day, time.min, tzinfo=tz)
    end = datetime.combine(day, time.max, tzinfo=tz)
    return start, end


def _span(first_day: date, last_day: date, tz: tzinfo, label: str) -> Period:
    start, _ = _day_bounds(first_day, tz)
    _, end = _day_bounds(last_day, tz)
    return Period(start, end, label)


def _last_day_of_month(year: int, month: int) -> date:
    if month == 12:
        return date(year, 12, 31)
    return date(year, month + 1, 1) - timedelta(days=1)


def parse_period(spec: str, tz: tzinfo, today: date | None = None) -> Period:
    """Превращает пользовательскую строку периода в интервал дат.

    Поддерживаются: `today`/`сегодня`, `yesterday`, `week`, `last-week`, `month`,
    `last-month`, `quarter`, `year`, `all`, `30d`, `2026-06`, `2026-06-01`,
    `2026-06-01..2026-06-30`.
    """
    today = today or datetime.now(tz).date()
    raw = (spec or "month").strip().lower()
    alias = ALIASES.get(raw)

    if alias == "today":
        return _span(today, today, tz, f"сегодня, {today.day} {MONTH_NAMES_GENITIVE[today.month - 1]}")
    if alias == "yesterday":
        day = today - timedelta(days=1)
        return _span(day, day, tz, f"вчера, {day.day} {MONTH_NAMES_GENITIVE[day.month - 1]}")
    if alias == "week":
        first = today - timedelta(days=today.weekday())
        return _span(first, today, tz, "текущая неделя")
    if alias == "last-week":
        this_monday = today - timedelta(days=today.weekday())
        first = this_monday - timedelta(days=7)
        return _span(first, first + timedelta(days=6), tz, "прошлая неделя")
    if alias == "month":
        first = today.replace(day=1)
        return _span(first, today, tz, f"{MONTH_NAMES_GENITIVE[first.month - 1]} {first.year}")
    if alias == "last-month":
        first_of_this = today.replace(day=1)
        last = first_of_this - timedelta(days=1)
        first = last.replace(day=1)
        return _span(first, last, tz, f"{MONTH_NAMES_GENITIVE[first.month - 1]} {first.year}")
    if alias == "quarter":
        quarter_first_month = 3 * ((today.month - 1) // 3) + 1
        first = date(today.year, quarter_first_month, 1)
        return _span(first, today, tz, f"{(quarter_first_month - 1) // 3 + 1} квартал {today.year}")
    if alias == "year":
        first = date(today.year, 1, 1)
        return _span(first, today, tz, f"{today.year} год")
    if alias == "all":
        return _span(date(2000, 1, 1), today, tz, "за всё время")

    match = LAST_DAYS_RE.match(raw)
    if match:
        days = int(match.group(1))
        if days < 1:
            raise ConfigError("Количество дней в периоде должно быть больше нуля")
        first = today - timedelta(days=days - 1)
        return _span(first, today, tz, f"последние {days} дн.")

    match = RANGE_RE.match(raw)
    if match:
        first = date.fromisoformat(match.group(1))
        last = date.fromisoformat(match.group(2))
        if last < first:
            raise ConfigError(f"Начало периода позже конца: {spec!r}")
        start_dt, _ = _day_bounds(first, tz)
        _, end_dt = _day_bounds(last, tz)
        return Period(start_dt, end_dt, _short_range(start_dt, end_dt))

    match = MONTH_RE.match(raw)
    if match:
        year, month = int(match.group(1)), int(match.group(2))
        if not 1 <= month <= 12:
            raise ConfigError(f"Некорректный месяц в периоде: {spec!r}")
        first = date(year, month, 1)
        return _span(first, _last_day_of_month(year, month), tz, f"{MONTH_NAMES_GENITIVE[month - 1]} {year}")

    if DAY_RE.match(raw):
        day = date.fromisoformat(raw)
        return _span(day, day, tz, f"{day.day} {MONTH_NAMES_GENITIVE[day.month - 1]} {day.year}")

    raise ConfigError(
        f"Не удалось разобрать период {spec!r}. Допустимо: today, yesterday, week, "
        "last-week, month, last-month, quarter, year, all, 30d, 2026-06, "
        "2026-06-01..2026-06-30."
    )
