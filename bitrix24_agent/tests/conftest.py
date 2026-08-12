from __future__ import annotations

import sys
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

TZ = ZoneInfo("Europe/Moscow")


@pytest.fixture
def tz() -> ZoneInfo:
    return TZ


@pytest.fixture
def now() -> datetime:
    """Фиксированный «сейчас»: среда, 12 августа 2026, 15:30 по Москве."""
    return datetime(2026, 8, 12, 15, 30, tzinfo=TZ)
