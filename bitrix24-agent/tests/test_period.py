from datetime import datetime, timezone, timedelta

import pytest

from bitrix24_agent.period import parse_period, PeriodError


def test_today_period():
    p = parse_period("today", tz_offset="+03:00")
    assert p.date_to - p.date_from == timedelta(days=1)
    assert p.date_from.hour == 0


def test_custom_range():
    p = parse_period("2026-01-01:2026-01-31", tz_offset="+00:00")
    assert p.date_from == datetime(2026, 1, 1, tzinfo=timezone.utc)
    assert p.date_to == datetime(2026, 2, 1, tzinfo=timezone.utc)


def test_week_starts_monday():
    p = parse_period("week", tz_offset="+00:00")
    assert p.date_from.weekday() == 0


def test_unknown_preset_raises():
    with pytest.raises(PeriodError):
        parse_period("not-a-period", tz_offset="+00:00")


def test_as_bitrix_filter_format():
    p = parse_period("2026-03-01:2026-03-02", tz_offset="+03:00")
    filt = p.as_bitrix_filter("CLOSED_DATE")
    assert filt[">=CLOSED_DATE"].startswith("2026-03-01T00:00:00")
    assert filt["<CLOSED_DATE"].startswith("2026-03-03T00:00:00")
