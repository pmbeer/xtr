from __future__ import annotations

from zoneinfo import ZoneInfo

import pytest


@pytest.fixture()
def tz() -> ZoneInfo:
    return ZoneInfo("Europe/Moscow")
