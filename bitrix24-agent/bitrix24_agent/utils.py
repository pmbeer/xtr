"""Общие вспомогательные функции."""

from __future__ import annotations

from datetime import datetime
from typing import Optional


def parse_bitrix_datetime(value: Optional[str]) -> Optional[datetime]:
    """Разбирает дату/время в формате Битрикс24 (ISO 8601 с таймзоной) в datetime."""
    if not value:
        return None
    value = value.strip()
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None
