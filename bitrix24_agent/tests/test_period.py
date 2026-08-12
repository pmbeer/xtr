from __future__ import annotations

from datetime import date

from b24agent.analytics import period as periods


def test_today_covers_whole_day(now):
    result = periods.today(now)
    assert result.start.date() == date(2026, 8, 12)
    assert result.start.hour == 0
    assert result.end.hour == 23
    assert result.days == 1


def test_this_week_starts_on_monday(now):
    result = periods.this_week(now)
    assert result.start.date() == date(2026, 8, 10)
    assert result.end.date() == date(2026, 8, 12)


def test_last_week_is_full_previous_week(now):
    result = periods.last_week(now)
    assert result.start.date() == date(2026, 8, 3)
    assert result.end.date() == date(2026, 8, 9)
    assert result.days == 7


def test_last_month_handles_month_boundary(now):
    result = periods.last_month(now)
    assert result.start.date() == date(2026, 7, 1)
    assert result.end.date() == date(2026, 7, 31)
    assert result.label == "июль 2026"


def test_last_quarter(now):
    result = periods.last_quarter(now)
    assert result.start.date() == date(2026, 4, 1)
    assert result.end.date() == date(2026, 6, 30)
    assert result.label == "2-й квартал 2026"


def test_last_n_days_includes_today(now):
    result = periods.last_n_days(now, 7)
    assert result.start.date() == date(2026, 8, 6)
    assert result.end.date() == date(2026, 8, 12)
    assert result.days == 7


def test_month_of_january_leap_safe(tz):
    result = periods.month_of(2024, 2, tz)
    assert result.end.date() == date(2024, 2, 29)


def test_bitrix_format_includes_offset(now):
    result = periods.today(now)
    assert result.bitrix_start().endswith("+03:00")
    assert "T00:00:00" in result.bitrix_start()


def test_iter_days_is_inclusive(now):
    result = periods.last_n_days(now, 3)
    assert list(result.iter_days()) == [
        date(2026, 8, 10),
        date(2026, 8, 11),
        date(2026, 8, 12),
    ]
