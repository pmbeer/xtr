"""Мелкие форматтеры, общие для отчёта и сообщений бота."""

from __future__ import annotations

from datetime import datetime


def naive(dt: datetime | None) -> datetime | None:
    """Убирает информацию о часовом поясе (нужно для записи в ячейки Excel)."""
    if dt is None:
        return None
    return dt.replace(tzinfo=None)


def fmt_dt(dt: datetime | None, fmt: str = "%d.%m.%Y %H:%M") -> str:
    if dt is None:
        return "—"
    return dt.strftime(fmt)


def fmt_hours(hours: float | None) -> str:
    if hours is None:
        return "—"
    if hours < 1:
        return f"{round(hours * 60)} мин"
    days, rem_hours = divmod(hours, 24)
    if days >= 1:
        return f"{int(days)} дн {round(rem_hours)} ч"
    return f"{hours:.1f} ч"
