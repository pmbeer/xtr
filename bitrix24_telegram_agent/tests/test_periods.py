from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from bitrix24_agent.periods import parse_period

NOW = datetime(2026, 8, 12, 12, tzinfo=ZoneInfo("Europe/Moscow"))


@pytest.mark.parametrize(
    ("query", "start", "end"),
    [
        ("отчет за сегодня", "2026-08-12", "2026-08-12"),
        ("отчет за вчера", "2026-08-11", "2026-08-11"),
        ("за эту неделю", "2026-08-10", "2026-08-12"),
        ("за прошлую неделю", "2026-08-03", "2026-08-09"),
        ("за месяц", "2026-08-01", "2026-08-12"),
        ("за прошлый месяц", "2026-07-01", "2026-07-31"),
        ("за последние 14 дней", "2026-07-30", "2026-08-12"),
        ("с 01.08.2026 по 10.08.2026", "2026-08-01", "2026-08-10"),
        ("за 01.08", "2026-08-01", "2026-08-01"),
    ],
)
def test_parse_period(query: str, start: str, end: str) -> None:
    period = parse_period(query, "Europe/Moscow", NOW)
    assert period.start.date().isoformat() == start
    assert period.end.date().isoformat() == end


def test_default_is_current_month() -> None:
    period = parse_period("покажи показатели", "Europe/Moscow", NOW)
    assert period.start.date().isoformat() == "2026-08-01"
    assert period.end.date().isoformat() == "2026-08-12"


def test_rejects_reversed_period() -> None:
    with pytest.raises(ValueError, match="Начальная дата"):
        parse_period("с 10.08.2026 по 01.08.2026", "Europe/Moscow", NOW)
