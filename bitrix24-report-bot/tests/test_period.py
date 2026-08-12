from __future__ import annotations

from datetime import datetime

from bot.utils.period import resolve_period


def _now(tz):
    return datetime(2026, 8, 12, 15, 30, tzinfo=tz)  # среда


def test_today(tz):
    period = resolve_period("сегодня, пожалуйста", tz, now=_now(tz))
    assert period.matched
    assert period.date_from.date().isoformat() == "2026-08-12"
    assert period.date_to == _now(tz)


def test_yesterday(tz):
    period = resolve_period("а что было вчера?", tz, now=_now(tz))
    assert period.matched
    assert period.date_from.date().isoformat() == "2026-08-11"
    assert period.date_to.date().isoformat() == "2026-08-11"


def test_this_week(tz):
    period = resolve_period("сколько задач за эту неделю", tz, now=_now(tz))
    assert period.matched
    # 12 августа 2026 — среда, понедельник этой недели — 10 августа.
    assert period.date_from.date().isoformat() == "2026-08-10"


def test_rolling_week_default_wording(tz):
    period = resolve_period("статистика за неделю", tz, now=_now(tz))
    assert period.matched
    assert period.date_from.date().isoformat() == "2026-08-06"


def test_previous_month(tz):
    period = resolve_period("отчёт за прошлый месяц", tz, now=_now(tz))
    assert period.matched
    assert period.date_from.date().isoformat() == "2026-07-01"
    assert period.date_to.date().isoformat() == "2026-07-31"


def test_explicit_range(tz):
    period = resolve_period("с 01.08.2026 по 10.08.2026", tz, now=_now(tz))
    assert period.matched
    assert period.date_from.date().isoformat() == "2026-08-01"
    assert period.date_to.date().isoformat() == "2026-08-10"


def test_explicit_single_date(tz):
    period = resolve_period("что было 05.08", tz, now=_now(tz))
    assert period.matched
    assert period.date_from.date().isoformat() == "2026-08-05"
    assert period.date_to.date().isoformat() == "2026-08-05"


def test_default_fallback(tz):
    period = resolve_period("покажи мою статистику", tz, now=_now(tz))
    assert not period.matched
    assert (period.date_to - period.date_from).days == 29


def test_quarter(tz):
    period = resolve_period("за квартал", tz, now=_now(tz))
    assert period.matched
    # Август — третий квартал (июль-сентябрь), начало — 1 июля.
    assert period.date_from.date().isoformat() == "2026-07-01"
