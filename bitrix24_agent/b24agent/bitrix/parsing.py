"""Разбор значений, приходящих из REST Битрикс24.

Битрикс24 отдаёт числа строками, пустые значения — то ``null``, то ``""``,
то ``"0"``, а имена полей в ответе бывают и в camelCase, и в UPPER_CASE
(зависит от метода и версии портала). Все эти особенности гасятся здесь.
"""

from __future__ import annotations

from collections.abc import Mapping
from datetime import datetime
from typing import Any
from zoneinfo import ZoneInfo

EMPTY_VALUES = frozenset({None, "", "0", 0, "null", "None"})


def pick(raw: Mapping[str, Any], *names: str) -> Any:
    """Возвращает первое непустое значение среди перечисленных имён полей."""
    for name in names:
        if name in raw:
            value = raw[name]
            if value not in ("", None):
                return value
    return None


def as_int(value: Any, default: int = 0) -> int:
    if value is None or value == "":
        return default
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def as_opt_int(value: Any) -> int | None:
    if value in EMPTY_VALUES:
        return None
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return None


def as_float(value: Any, default: float = 0.0) -> float:
    if value is None or value == "":
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        return value.strip().upper() in {"Y", "YES", "TRUE", "1"}
    return False


def as_str(value: Any, default: str = "") -> str:
    if value is None:
        return default
    return str(value).strip() or default


def parse_datetime(value: Any, tz: ZoneInfo) -> datetime | None:
    """Разбирает дату Битрикс24 и приводит её к часовому поясу ``tz``.

    Понимает ISO 8601 со смещением (``2026-06-04T16:15:55+03:00``), формат без
    смещения и unix-timestamp. Возвращает ``None`` для пустых значений — это
    штатная ситуация: например, у незакрытой задачи нет ``closedDate``.
    """
    if value in EMPTY_VALUES:
        return None

    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(float(value), tz=tz)

    text = str(value).strip()
    if not text or text.startswith("0000-00-00"):
        return None

    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        parsed = _parse_legacy(text)
        if parsed is None:
            return None

    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=tz)
    return parsed.astimezone(tz)


def _parse_legacy(text: str) -> datetime | None:
    # Старые методы (например, crm.*) умеют отдавать «дд.мм.гггг чч:мм:сс».
    for fmt in ("%d.%m.%Y %H:%M:%S", "%d.%m.%Y %H:%M", "%d.%m.%Y", "%Y-%m-%d %H:%M:%S"):
        try:
            # Часовой пояс в таких строках не приходит: его подставляет
            # parse_datetime, поэтому здесь datetime намеренно наивный.
            return datetime.strptime(text, fmt)  # noqa: DTZ007
        except ValueError:
            continue
    return None
