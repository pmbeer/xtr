"""Приведение разнородных ответов Битрикс24 к единому виду.

Портал отвечает то в `UPPER_SNAKE_CASE` (`crm.*`, `task.stages.get`), то в
`camelCase` (`tasks.task.list`), поэтому поля ищем по нормализованному ключу.
"""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from datetime import datetime, tzinfo
from typing import Any

#: Значения, которые портал использует вместо пустой даты.
EMPTY_DATES = frozenset({"", "0000-00-00", "0000-00-00 00:00:00", "null", "none"})


def norm_key(key: str) -> str:
    """`CLOSED_DATE`, `closedDate` и `closed_date` дают один и тот же ключ."""
    return key.replace("_", "").replace("-", "").lower()


def normalize_record(record: Mapping[str, Any]) -> dict[str, Any]:
    """Строит словарь с нормализованными ключами."""
    return {norm_key(str(key)): value for key, value in record.items()}


def pick(record: Mapping[str, Any], *names: str, default: Any = None) -> Any:
    """Достаёт первое непустое значение по любому из вариантов написания поля."""
    normalized = record if _looks_normalized(record) else normalize_record(record)
    for name in names:
        value = normalized.get(norm_key(name))
        if value not in (None, ""):
            return value
    return default


def _looks_normalized(record: Mapping[str, Any]) -> bool:
    return all(key == norm_key(str(key)) for key in record)


def parse_datetime(value: Any, tz: tzinfo | None = None) -> datetime | None:
    """Разбирает дату Битрикс24 в осознающий пояс `datetime`.

    Портал отдаёт ISO 8601 со смещением (`2026-06-15T14:30:00+03:00`), но в
    отдельных методах встречается формат без пояса — тогда считаем, что дата в
    часовом поясе портала.
    """
    if value in (None, ""):
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo or tz is None else value.replace(tzinfo=tz)
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(float(value), tz=tz) if value > 0 else None

    text = str(value).strip()
    if text.lower() in EMPTY_DATES:
        return None
    candidate = text.replace(" ", "T", 1) if " " in text and "T" not in text else text
    if candidate.endswith("Z"):
        candidate = candidate[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(candidate)
    except ValueError:
        for fmt in ("%d.%m.%Y %H:%M:%S", "%d.%m.%Y"):
            try:
                parsed = datetime.strptime(text, fmt)
                break
            except ValueError:
                continue
        else:
            return None
    if parsed.tzinfo is None and tz is not None:
        parsed = parsed.replace(tzinfo=tz)
    return parsed


def parse_int(value: Any, default: int | None = None) -> int | None:
    if value in (None, "", False):
        return default
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def parse_float(value: Any, default: float | None = None) -> float | None:
    if value in (None, "", False):
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def parse_bool(value: Any) -> bool | None:
    if isinstance(value, bool):
        return value
    if value in (None, ""):
        return None
    text = str(value).strip().lower()
    if text in {"y", "yes", "true", "1"}:
        return True
    if text in {"n", "no", "false", "0"}:
        return False
    return None


def iter_records(payload: Any) -> Iterable[Mapping[str, Any]]:
    """Перебирает записи, как бы портал их ни завернул: список, словарь, `items`."""
    if payload is None:
        return []
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, Mapping)]
    if isinstance(payload, Mapping):
        for key in ("tasks", "items", "sessions", "result"):
            nested = payload.get(key)
            if isinstance(nested, (list, Mapping)):
                return iter_records(nested)
        return [value for value in payload.values() if isinstance(value, Mapping)]
    return []
