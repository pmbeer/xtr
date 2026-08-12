"""Человекочитаемое форматирование чисел, длительностей и дат для отчётов."""

from __future__ import annotations

from datetime import date, datetime


def plural(count: int, one: str, few: str, many: str) -> str:
    """Русское склонение существительного при числе."""
    remainder_100 = abs(count) % 100
    remainder_10 = abs(count) % 10
    if 11 <= remainder_100 <= 14:
        return many
    if remainder_10 == 1:
        return one
    if 2 <= remainder_10 <= 4:
        return few
    return many


def duration(seconds: float | None, *, empty: str = "—") -> str:
    """Длительность словами: ``2 ч 15 мин``, ``1 д 4 ч``, ``45 сек``."""
    if seconds is None:
        return empty
    total = round(seconds)
    if total < 0:
        return empty
    if total < 60:
        return f"{total} сек"

    minutes, sec = divmod(total, 60)
    if minutes < 60:
        return f"{minutes} мин {sec} сек" if sec else f"{minutes} мин"

    hours, minutes = divmod(minutes, 60)
    if hours < 24:
        return f"{hours} ч {minutes} мин" if minutes else f"{hours} ч"

    days, hours = divmod(hours, 24)
    return f"{days} д {hours} ч" if hours else f"{days} д"


def hours(seconds: float | None) -> float:
    """Длительность в часах с двумя знаками — для числовых колонок Excel."""
    if not seconds or seconds < 0:
        return 0.0
    return round(seconds / 3600, 2)


def percent(value: float | None, *, empty: str = "—") -> str:
    if value is None:
        return empty
    return f"{value * 100:.1f}%".replace(".0%", "%")


def date_ru(value: date | None, *, empty: str = "—") -> str:
    if value is None:
        return empty
    return value.strftime("%d.%m.%Y")


def datetime_ru(value: datetime | None, *, empty: str = "—") -> str:
    if value is None:
        return empty
    return value.strftime("%d.%m.%Y %H:%M")


def isoformat(value: datetime | date | None) -> str | None:
    if value is None:
        return None
    return value.isoformat(timespec="seconds") if isinstance(value, datetime) else value.isoformat()
