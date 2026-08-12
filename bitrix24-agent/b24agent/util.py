"""Вспомогательные функции: даты и форматирование."""

from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple

_ISO_RE = re.compile(
    r"^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?"
    r"(Z|[+-]\d{2}:?\d{2})?$"
)


def parse_b24_datetime(value) -> Optional[datetime]:
    """Разбирает дату из ответа Битрикс24 (ISO 8601, например ``2026-08-01T12:00:00+03:00``)."""
    if value is None:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    text = str(value).strip()
    if not text:
        return None
    match = _ISO_RE.match(text)
    if not match:
        # только дата, без времени
        try:
            return datetime.strptime(text[:10], "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    year, month, day, hour, minute, second, tz = match.groups()
    if tz in (None, "", "Z"):
        tzinfo = timezone.utc
    else:
        sign = 1 if tz[0] == "+" else -1
        tz_digits = tz[1:].replace(":", "")
        tzinfo = timezone(sign * timedelta(hours=int(tz_digits[:2]), minutes=int(tz_digits[2:4])))
    return datetime(int(year), int(month), int(day), int(hour), int(minute), int(second), tzinfo=tzinfo)


def format_duration(seconds: Optional[float]) -> str:
    """Человекочитаемая длительность: ``2 д 3 ч``, ``5 мин`` и т.п."""
    if seconds is None:
        return "—"
    seconds = int(seconds)
    if seconds < 60:
        return f"{seconds} сек"
    minutes, _ = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    days, hours = divmod(hours, 24)
    parts = []
    if days:
        parts.append(f"{days} д")
    if hours:
        parts.append(f"{hours} ч")
    if minutes and not days:
        parts.append(f"{minutes} мин")
    return " ".join(parts) or "0 мин"


def resolve_period(
    period: Optional[str],
    date_from: Optional[str],
    date_to: Optional[str],
    now: Optional[datetime] = None,
) -> Tuple[datetime, datetime]:
    """Возвращает границы периода отчёта (aware-datetime, локальный пояс)."""
    now = now or datetime.now().astimezone()
    if date_from or date_to:
        start = _parse_cli_date(date_from) if date_from else now - timedelta(days=30)
        end = _parse_cli_date(date_to, end_of_day=True) if date_to else now
        return start, end

    period = (period or "month").lower()
    midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
    if period == "today":
        return midnight, now
    if period == "week":
        return midnight - timedelta(days=7), now
    if period == "month":
        return midnight - timedelta(days=30), now
    if period == "quarter":
        return midnight - timedelta(days=90), now
    if period == "year":
        return midnight - timedelta(days=365), now
    raise ValueError(f"Неизвестный период: {period!r} (ожидается today/week/month/quarter/year)")


def _parse_cli_date(value: str, end_of_day: bool = False) -> datetime:
    parsed = datetime.strptime(value.strip(), "%Y-%m-%d")
    if end_of_day:
        parsed = parsed.replace(hour=23, minute=59, second=59)
    return parsed.astimezone()
