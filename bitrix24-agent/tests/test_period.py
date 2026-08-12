"""Тесты разбора периодов."""

from __future__ import annotations

import unittest
from datetime import date
from zoneinfo import ZoneInfo

from bitrix24_agent.errors import ConfigError
from bitrix24_agent.period import parse_period

TZ = ZoneInfo("Europe/Moscow")
TODAY = date(2026, 6, 17)  # среда


class ParsePeriodTests(unittest.TestCase):
    def test_month_starts_at_first_day_and_ends_today(self) -> None:
        period = parse_period("month", TZ, today=TODAY)
        self.assertEqual(period.start.date(), date(2026, 6, 1))
        self.assertEqual(period.end.date(), TODAY)
        self.assertEqual(period.label, "июня 2026")

    def test_last_month_covers_whole_previous_month(self) -> None:
        period = parse_period("last-month", TZ, today=TODAY)
        self.assertEqual(period.start.date(), date(2026, 5, 1))
        self.assertEqual(period.end.date(), date(2026, 5, 31))

    def test_week_starts_on_monday(self) -> None:
        period = parse_period("week", TZ, today=TODAY)
        self.assertEqual(period.start.date(), date(2026, 6, 15))

    def test_russian_aliases_work(self) -> None:
        self.assertEqual(
            parse_period("месяц", TZ, today=TODAY).start,
            parse_period("month", TZ, today=TODAY).start,
        )

    def test_last_n_days_includes_today(self) -> None:
        period = parse_period("30d", TZ, today=TODAY)
        self.assertEqual(period.start.date(), date(2026, 5, 19))
        self.assertEqual(period.end.date(), TODAY)

    def test_explicit_month(self) -> None:
        period = parse_period("2026-02", TZ, today=TODAY)
        self.assertEqual(period.start.date(), date(2026, 2, 1))
        self.assertEqual(period.end.date(), date(2026, 2, 28))

    def test_explicit_range(self) -> None:
        period = parse_period("2026-01-10..2026-01-20", TZ, today=TODAY)
        self.assertEqual(period.start.date(), date(2026, 1, 10))
        self.assertEqual(period.end.date(), date(2026, 1, 20))

    def test_quarter(self) -> None:
        period = parse_period("quarter", TZ, today=TODAY)
        self.assertEqual(period.start.date(), date(2026, 4, 1))
        self.assertIn("2 квартал", period.label)

    def test_previous_period_has_same_length_and_does_not_overlap(self) -> None:
        period = parse_period("2026-06-01..2026-06-30", TZ, today=TODAY)
        previous = period.previous()
        self.assertLess(previous.end, period.start)
        self.assertAlmostEqual(previous.days, period.days, places=3)
        self.assertEqual(previous.end.date(), date(2026, 5, 31))

    def test_timezone_is_applied_to_boundaries(self) -> None:
        period = parse_period("today", TZ, today=TODAY)
        self.assertEqual(period.start.utcoffset().total_seconds(), 3 * 3600)
        self.assertTrue(period.iso_start().endswith("+03:00"))

    def test_unknown_period_reports_supported_values(self) -> None:
        with self.assertRaises(ConfigError) as error:
            parse_period("позавчера", TZ, today=TODAY)
        self.assertIn("2026-06", str(error.exception))


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
