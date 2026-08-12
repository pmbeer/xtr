import unittest
from datetime import datetime, timedelta, timezone

from b24agent.util import format_duration, parse_b24_datetime, resolve_period


class ParseDatetimeTest(unittest.TestCase):
    def test_iso_with_offset(self):
        parsed = parse_b24_datetime("2026-08-01T12:30:00+03:00")
        self.assertEqual(parsed, datetime(2026, 8, 1, 12, 30, tzinfo=timezone(timedelta(hours=3))))

    def test_iso_utc_z(self):
        parsed = parse_b24_datetime("2026-08-01T12:30:00Z")
        self.assertEqual(parsed, datetime(2026, 8, 1, 12, 30, tzinfo=timezone.utc))

    def test_date_only(self):
        parsed = parse_b24_datetime("2026-08-01")
        self.assertEqual(parsed, datetime(2026, 8, 1, tzinfo=timezone.utc))

    def test_empty_and_none(self):
        self.assertIsNone(parse_b24_datetime(None))
        self.assertIsNone(parse_b24_datetime(""))
        self.assertIsNone(parse_b24_datetime("не дата"))


class FormatDurationTest(unittest.TestCase):
    def test_none(self):
        self.assertEqual(format_duration(None), "—")

    def test_seconds(self):
        self.assertEqual(format_duration(45), "45 сек")

    def test_minutes(self):
        self.assertEqual(format_duration(5 * 60), "5 мин")

    def test_hours_minutes(self):
        self.assertEqual(format_duration(3 * 3600 + 20 * 60), "3 ч 20 мин")

    def test_days_hours(self):
        self.assertEqual(format_duration(2 * 86400 + 5 * 3600 + 10 * 60), "2 д 5 ч")


class ResolvePeriodTest(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 8, 12, 15, 0, tzinfo=timezone.utc)

    def test_week(self):
        start, end = resolve_period("week", None, None, now=self.now)
        self.assertEqual(end, self.now)
        self.assertEqual(start, datetime(2026, 8, 5, 0, 0, tzinfo=timezone.utc))

    def test_explicit_dates(self):
        start, end = resolve_period(None, "2026-07-01", "2026-07-31", now=self.now)
        self.assertEqual((start.year, start.month, start.day), (2026, 7, 1))
        self.assertEqual((end.hour, end.minute, end.second), (23, 59, 59))

    def test_unknown_period(self):
        with self.assertRaises(ValueError):
            resolve_period("decade", None, None, now=self.now)


if __name__ == "__main__":
    unittest.main()
