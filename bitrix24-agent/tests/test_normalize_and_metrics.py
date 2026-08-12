"""Тесты нормализации полей портала и расчёта показателей."""

from __future__ import annotations

import unittest
from datetime import datetime
from zoneinfo import ZoneInfo

from bitrix24_agent.metrics import (
    format_delta,
    humanize_duration,
    humanize_number,
    percentile,
    plural,
    share,
    summarize,
)
from bitrix24_agent.normalize import iter_records, parse_bool, parse_datetime, parse_int, pick

TZ = ZoneInfo("Europe/Moscow")


class NormalizeTests(unittest.TestCase):
    def test_pick_finds_field_in_any_naming_style(self) -> None:
        camel = {"closedDate": "2026-06-01T10:00:00+03:00"}
        upper = {"CLOSED_DATE": "2026-06-01T10:00:00+03:00"}
        self.assertEqual(pick(camel, "CLOSED_DATE"), pick(upper, "closedDate"))

    def test_pick_skips_empty_values_and_falls_back(self) -> None:
        record = {"title": "", "TITLE": "Задача"}
        self.assertEqual(pick(record, "title", default="—"), "Задача")
        self.assertEqual(pick({}, "title", default="—"), "—")

    def test_parse_datetime_handles_portal_formats(self) -> None:
        with_offset = parse_datetime("2026-06-15T14:30:00+03:00", TZ)
        without_offset = parse_datetime("2026-06-15 14:30:00", TZ)
        self.assertEqual(with_offset, without_offset)
        self.assertIsNotNone(with_offset.tzinfo)

    def test_parse_datetime_treats_portal_placeholders_as_missing(self) -> None:
        for empty in ("", None, "0000-00-00", "0000-00-00 00:00:00"):
            self.assertIsNone(parse_datetime(empty, TZ))

    def test_parse_datetime_accepts_datetime_and_timestamp(self) -> None:
        moment = datetime(2026, 6, 15, 14, 30, tzinfo=TZ)
        self.assertEqual(parse_datetime(moment, TZ), moment)
        self.assertEqual(parse_datetime(moment.timestamp(), TZ), moment)

    def test_parse_int_and_bool(self) -> None:
        self.assertEqual(parse_int("42"), 42)
        self.assertEqual(parse_int("не число", 0), 0)
        self.assertTrue(parse_bool("Y"))
        self.assertFalse(parse_bool("N"))
        self.assertIsNone(parse_bool(""))

    def test_iter_records_unwraps_any_container(self) -> None:
        self.assertEqual(len(list(iter_records([{"ID": 1}, {"ID": 2}]))), 2)
        self.assertEqual(len(list(iter_records({"tasks": [{"ID": 1}]}))), 1)
        self.assertEqual(len(list(iter_records({"3": {"ID": 3}}))), 1)
        self.assertEqual(len(list(iter_records(None))), 0)


class MetricsTests(unittest.TestCase):
    def test_summarize_computes_average_and_median(self) -> None:
        summary = summarize([10, 20, 30, 40])
        self.assertEqual(summary.count, 4)
        self.assertEqual(summary.avg, 25)
        self.assertEqual(summary.median, 25)
        self.assertEqual(summary.minimum, 10)
        self.assertEqual(summary.maximum, 40)

    def test_median_resists_single_outlier(self) -> None:
        summary = summarize([60, 60, 60, 60, 100000])
        self.assertEqual(summary.median, 60)
        self.assertGreater(summary.avg, 1000)

    def test_summarize_of_nothing_is_empty(self) -> None:
        self.assertTrue(summarize([]).empty)

    def test_percentile_interpolates(self) -> None:
        self.assertEqual(percentile([0, 10], 50), 5)
        self.assertEqual(percentile([5], 90), 5)
        self.assertIsNone(percentile([], 50))

    def test_humanize_duration_uses_two_largest_units(self) -> None:
        self.assertEqual(humanize_duration(45), "45 сек")
        self.assertEqual(humanize_duration(3600), "1 ч")
        self.assertEqual(humanize_duration(3900), "1 ч 5 мин")
        self.assertEqual(humanize_duration(93780), "1 д 2 ч")
        self.assertEqual(humanize_duration(None), "—")

    def test_humanize_number_groups_thousands(self) -> None:
        self.assertEqual(humanize_number(12345), "12 345")
        self.assertEqual(humanize_number(12.5), "12,5")

    def test_plural_picks_russian_form(self) -> None:
        self.assertEqual(plural(1, "задача", "задачи", "задач"), "задача")
        self.assertEqual(plural(3, "задача", "задачи", "задач"), "задачи")
        self.assertEqual(plural(11, "задача", "задачи", "задач"), "задач")

    def test_share_guards_against_zero(self) -> None:
        self.assertEqual(share(1, 4), 25.0)
        self.assertIsNone(share(1, 0))

    def test_format_delta_marks_worse_direction(self) -> None:
        self.assertEqual(format_delta(10, None), "")
        self.assertIn("= без изменений", format_delta(10, 10))
        self.assertIn("⚠", format_delta(10, 5, higher_is_better=False))
        self.assertNotIn("⚠", format_delta(10, 5, higher_is_better=True))


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
