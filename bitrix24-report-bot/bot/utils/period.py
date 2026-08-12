"""Определение периода отчёта по свободному тексту запроса пользователя.

Бот должен понимать как простые ключевые слова ("сегодня", "неделя",
"прошлый месяц"), так и явные даты ("с 01.08.2026 по 12.08.2026").
Если период не распознан, используется период по умолчанию (последние 30 дней),
о чём пользователь предупреждается в ответе бота.
"""

from __future__ import annotations

import calendar
import re
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from dateutil import parser as date_parser

_DATE_TOKEN_RE = re.compile(
    r"(?<!\d)(\d{4}-\d{1,2}-\d{1,2}|\d{1,2}[./]\d{1,2}(?:[./]\d{2,4})?)(?!\d)"
)


@dataclass(frozen=True)
class Period:
    date_from: datetime
    date_to: datetime
    label: str
    matched: bool  # False, если период определён по умолчанию, а не из текста


def _day_bounds(day: date, tz: ZoneInfo) -> tuple[datetime, datetime]:
    start = datetime.combine(day, time.min, tzinfo=tz)
    end = datetime.combine(day, time.max, tzinfo=tz)
    return start, end


def _clamp_to_now(end: datetime, now: datetime) -> datetime:
    return min(end, now)


def _quarter_bounds(d: date) -> tuple[date, date]:
    quarter = (d.month - 1) // 3
    start_month = quarter * 3 + 1
    start = date(d.year, start_month, 1)
    end_month = start_month + 2
    last_day = calendar.monthrange(d.year, end_month)[1]
    end = date(d.year, end_month, last_day)
    return start, end


def _prev_quarter_bounds(d: date) -> tuple[date, date]:
    start_of_current, _ = _quarter_bounds(d)
    prev_last_day = start_of_current - timedelta(days=1)
    return _quarter_bounds(prev_last_day)


def _try_parse_explicit_dates(text: str, tz: ZoneInfo) -> Period | None:
    tokens = _DATE_TOKEN_RE.findall(text)
    if not tokens:
        return None

    parsed: list[date] = []
    for token in tokens[:4]:
        try:
            dt = date_parser.parse(token, dayfirst=True, fuzzy=True)
            parsed.append(dt.date())
        except (ValueError, OverflowError):
            continue

    if not parsed:
        return None

    if len(parsed) == 1:
        start, end = _day_bounds(parsed[0], tz)
        return Period(start, end, f"{parsed[0]:%d.%m.%Y}", True)

    start_date, end_date = min(parsed), max(parsed)
    start, _ = _day_bounds(start_date, tz)
    _, end = _day_bounds(end_date, tz)
    return Period(start, end, f"{start_date:%d.%m.%Y} — {end_date:%d.%m.%Y}", True)


# Каждое правило: (регулярное выражение, функция(today, now, tz) -> Period)
_KEYWORD_RULES: list[tuple[re.Pattern[str], object]] = []


def _rule(pattern: str):
    def decorator(func):
        _KEYWORD_RULES.append((re.compile(pattern, re.IGNORECASE), func))
        return func

    return decorator


@_rule(r"позавчера")
def _r_day_before_yesterday(today: date, now: datetime, tz: ZoneInfo) -> Period:
    day = today - timedelta(days=2)
    start, end = _day_bounds(day, tz)
    return Period(start, end, "позавчера", True)


@_rule(r"\bвчера\b")
def _r_yesterday(today: date, now: datetime, tz: ZoneInfo) -> Period:
    day = today - timedelta(days=1)
    start, end = _day_bounds(day, tz)
    return Period(start, end, "вчера", True)


@_rule(r"\bсегодня\b|\bсейчас\b")
def _r_today(today: date, now: datetime, tz: ZoneInfo) -> Period:
    start, _ = _day_bounds(today, tz)
    return Period(start, now, "сегодня", True)


@_rule(r"прошл\w*\s+недел\w*")
def _r_prev_week(today: date, now: datetime, tz: ZoneInfo) -> Period:
    this_monday = today - timedelta(days=today.weekday())
    prev_monday = this_monday - timedelta(days=7)
    prev_sunday = this_monday - timedelta(days=1)
    start, _ = _day_bounds(prev_monday, tz)
    _, end = _day_bounds(prev_sunday, tz)
    return Period(start, end, f"прошлая неделя ({prev_monday:%d.%m} — {prev_sunday:%d.%m})", True)


@_rule(r"эт\w*\s+недел\w*|текущ\w*\s+недел\w*")
def _r_this_week(today: date, now: datetime, tz: ZoneInfo) -> Period:
    monday = today - timedelta(days=today.weekday())
    start, _ = _day_bounds(monday, tz)
    return Period(start, now, f"текущая неделя (с {monday:%d.%m})", True)


@_rule(r"недел\w*")
def _r_week_rolling(today: date, now: datetime, tz: ZoneInfo) -> Period:
    day = today - timedelta(days=6)
    start, _ = _day_bounds(day, tz)
    return Period(start, now, "последние 7 дней", True)


@_rule(r"прошл\w*\s+месяц\w*")
def _r_prev_month(today: date, now: datetime, tz: ZoneInfo) -> Period:
    first_of_this_month = today.replace(day=1)
    last_of_prev_month = first_of_this_month - timedelta(days=1)
    first_of_prev_month = last_of_prev_month.replace(day=1)
    start, _ = _day_bounds(first_of_prev_month, tz)
    _, end = _day_bounds(last_of_prev_month, tz)
    label = f"прошлый месяц ({first_of_prev_month:%m.%Y})"
    return Period(start, end, label, True)


@_rule(r"эт\w*\s+месяц\w*|текущ\w*\s+месяц\w*")
def _r_this_month(today: date, now: datetime, tz: ZoneInfo) -> Period:
    first = today.replace(day=1)
    start, _ = _day_bounds(first, tz)
    return Period(start, now, f"текущий месяц ({first:%m.%Y})", True)


@_rule(r"месяц\w*")
def _r_month_rolling(today: date, now: datetime, tz: ZoneInfo) -> Period:
    day = today - timedelta(days=29)
    start, _ = _day_bounds(day, tz)
    return Period(start, now, "последние 30 дней", True)


@_rule(r"прошл\w*\s+квартал\w*")
def _r_prev_quarter(today: date, now: datetime, tz: ZoneInfo) -> Period:
    q_start, q_end = _prev_quarter_bounds(today)
    start, _ = _day_bounds(q_start, tz)
    _, end = _day_bounds(q_end, tz)
    return Period(start, end, f"прошлый квартал ({q_start:%d.%m} — {q_end:%d.%m.%Y})", True)


@_rule(r"квартал\w*")
def _r_quarter(today: date, now: datetime, tz: ZoneInfo) -> Period:
    q_start, _ = _quarter_bounds(today)
    start, _ = _day_bounds(q_start, tz)
    return Period(start, now, f"текущий квартал (с {q_start:%d.%m})", True)


@_rule(r"прошл\w*\s+год\w*")
def _r_prev_year(today: date, now: datetime, tz: ZoneInfo) -> Period:
    start_of_prev_year = date(today.year - 1, 1, 1)
    end_of_prev_year = date(today.year - 1, 12, 31)
    start, _ = _day_bounds(start_of_prev_year, tz)
    _, end = _day_bounds(end_of_prev_year, tz)
    return Period(start, end, f"прошлый год ({today.year - 1})", True)


@_rule(r"год\w*")
def _r_year(today: date, now: datetime, tz: ZoneInfo) -> Period:
    start_of_year = date(today.year, 1, 1)
    start, _ = _day_bounds(start_of_year, tz)
    return Period(start, now, f"текущий год ({today.year})", True)


DEFAULT_PERIOD_DAYS = 30


def resolve_period(text: str, tz: ZoneInfo, now: datetime | None = None) -> Period:
    """Определяет период отчёта на основе текста запроса пользователя.

    Порядок разбора:
    1. Явные даты в тексте (например, "01.08.2026-12.08.2026" или "05.08").
    2. Ключевые слова ("сегодня", "неделя", "прошлый месяц" и т.п.).
    3. Период по умолчанию — последние 30 дней (Period.matched=False).
    """
    now = now or datetime.now(tz)
    today = now.date()
    text = (text or "").strip().lower()

    explicit = _try_parse_explicit_dates(text, tz)
    if explicit is not None:
        return explicit

    for pattern, handler in _KEYWORD_RULES:
        if pattern.search(text):
            return handler(today, now, tz)  # type: ignore[misc]

    day = today - timedelta(days=DEFAULT_PERIOD_DAYS - 1)
    start, _ = _day_bounds(day, tz)
    return Period(start, now, f"последние {DEFAULT_PERIOD_DAYS} дней", False)
