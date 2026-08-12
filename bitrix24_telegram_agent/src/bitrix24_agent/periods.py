import re
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo


@dataclass(frozen=True)
class ReportPeriod:
    start: datetime
    end: datetime
    label: str


def _bounds(start: date, end: date, timezone: ZoneInfo, label: str) -> ReportPeriod:
    return ReportPeriod(
        start=datetime.combine(start, time.min, timezone),
        end=datetime.combine(end, time.max, timezone),
        label=label,
    )


def _parse_date(value: str, default_year: int) -> date:
    day, month, *year = (int(part) for part in value.split("."))
    resolved_year = year[0] if year else default_year
    if resolved_year < 100:
        resolved_year += 2000
    return date(resolved_year, month, day)


def parse_period(text: str, timezone_name: str, now: datetime | None = None) -> ReportPeriod:
    timezone = ZoneInfo(timezone_name)
    today = (now or datetime.now(timezone)).astimezone(timezone).date()
    normalized = text.lower().replace("ё", "е")

    dates = re.findall(r"\b\d{1,2}\.\d{1,2}(?:\.\d{2,4})?\b", normalized)
    if len(dates) >= 2:
        start, end = _parse_date(dates[0], today.year), _parse_date(dates[1], today.year)
        if start > end:
            raise ValueError("Начальная дата позже конечной")
        return _bounds(start, end, timezone, f"{start:%d.%m.%Y}–{end:%d.%m.%Y}")
    if len(dates) == 1:
        selected = _parse_date(dates[0], today.year)
        return _bounds(selected, selected, timezone, f"{selected:%d.%m.%Y}")

    if "сегодня" in normalized:
        return _bounds(today, today, timezone, "сегодня")
    if "вчера" in normalized:
        yesterday = today - timedelta(days=1)
        return _bounds(yesterday, yesterday, timezone, "вчера")
    if "прошл" in normalized and "месяц" in normalized:
        last_day = today.replace(day=1) - timedelta(days=1)
        first_day = last_day.replace(day=1)
        return _bounds(first_day, last_day, timezone, "прошлый месяц")
    if "месяц" in normalized:
        return _bounds(today.replace(day=1), today, timezone, "текущий месяц")
    if "прошл" in normalized and "недел" in normalized:
        this_monday = today - timedelta(days=today.weekday())
        start = this_monday - timedelta(days=7)
        return _bounds(start, start + timedelta(days=6), timezone, "прошлая неделя")
    if "недел" in normalized:
        return _bounds(today - timedelta(days=today.weekday()), today, timezone, "эта неделя")

    days_match = re.search(r"(?:за\s+)?(?:последн\w*\s+)?(\d+)\s*(?:дн|день|дня|дней)", normalized)
    if days_match:
        days = max(1, min(int(days_match.group(1)), 366))
        return _bounds(today - timedelta(days=days - 1), today, timezone, f"последние {days} дн.")

    return _bounds(today.replace(day=1), today, timezone, "текущий месяц")
