from __future__ import annotations

from datetime import date

import pytest

from b24agent.analytics.models import ReportFormat, ReportSection
from b24agent.nlu import parse_query
from b24agent.nlu.parser import parse_period


@pytest.mark.parametrize(
    ("text", "expected_start", "expected_end"),
    [
        ("сколько задач я закрыл сегодня", date(2026, 8, 12), date(2026, 8, 12)),
        ("что было вчера", date(2026, 8, 11), date(2026, 8, 11)),
        ("отчёт за прошлую неделю", date(2026, 8, 3), date(2026, 8, 9)),
        ("задачи за эту неделю", date(2026, 8, 10), date(2026, 8, 12)),
        ("итоги за прошлый месяц", date(2026, 7, 1), date(2026, 7, 31)),
        ("статистика за месяц", date(2026, 8, 1), date(2026, 8, 12)),
        ("за последние 14 дней", date(2026, 7, 30), date(2026, 8, 12)),
        ("за последние 2 недели", date(2026, 7, 30), date(2026, 8, 12)),
        ("покажи июнь", date(2026, 6, 1), date(2026, 6, 30)),
        ("данные за декабрь", date(2025, 12, 1), date(2025, 12, 31)),
        ("с 01.06.2026 по 15.06.2026", date(2026, 6, 1), date(2026, 6, 15)),
        ("с 2026-03-01 по 2026-03-10", date(2026, 3, 1), date(2026, 3, 10)),
        ("за прошлый квартал", date(2026, 4, 1), date(2026, 6, 30)),
        ("за прошлый год", date(2025, 1, 1), date(2025, 12, 31)),
    ],
)
def test_period_recognition(text, expected_start, expected_end, now):
    period = parse_period(text, now=now)
    assert period.start.date() == expected_start
    assert period.end.date() == expected_end


def test_period_defaults_to_current_month(now):
    period = parse_period("сколько у меня задач в работе", now=now)
    assert period.start.date() == date(2026, 8, 1)
    assert period.end.date() == date(2026, 8, 12)


def test_sections_from_task_query(now):
    request = parse_query("сколько задач я закрыл за неделю", now=now)
    assert request.sections == frozenset({ReportSection.TASKS})


def test_stage_query_also_pulls_tasks(now):
    request = parse_query("на какой стадии мои задачи", now=now)
    assert request.sections == frozenset({ReportSection.TASKS, ReportSection.STAGES})


def test_openlines_query(now):
    request = parse_query("сколько обращений в открытой линии я обработал", now=now)
    assert request.sections == frozenset({ReportSection.OPENLINES})


def test_query_without_hints_asks_everything(now):
    request = parse_query("дай отчёт за июль", now=now)
    assert request.sections == frozenset(ReportSection)


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("отчёт в csv", ReportFormat.CSV),
        ("выгрузи json", ReportFormat.JSON),
        ("нужна таблица excel", ReportFormat.XLSX),
    ],
)
def test_format_recognition(text, expected, now):
    assert parse_query(text, now=now).report_format == expected


def test_format_falls_back_to_default(now):
    request = parse_query("задачи за месяц", now=now, default_format=ReportFormat.CSV)
    assert request.report_format == ReportFormat.CSV


def test_summary_only_disables_details(now):
    request = parse_query("задачи за месяц, только сводка", now=now)
    assert request.include_details is False


def test_yo_and_case_are_normalized(now):
    request = parse_query("СКОЛЬКО ЗАДАЧ Я ЗАКРЫЛ ЗА ПРОШЛУЮ НЕДЕЛЮ", now=now)
    assert request.period.start.date() == date(2026, 8, 3)


def test_raw_query_is_preserved(now):
    request = parse_query("  задачи за месяц  ", now=now)
    assert request.raw_query == "задачи за месяц"
