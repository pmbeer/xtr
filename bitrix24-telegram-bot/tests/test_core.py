from __future__ import annotations

from datetime import datetime
from pathlib import Path

import pytest

from bot.nlp import parse_user_request
from services.analytics import AnalyticsService
from services.datetime_utils import parse_bitrix_datetime
from services.models import Period
from services.report import ReportGenerator


def test_parse_period_last_days():
    now = datetime(2026, 8, 12, 15, 0, 0)
    intent = parse_user_request("отчёт за 7 дней", default_days=30, now=now)
    assert intent.kind == "report"
    assert intent.period.date_from.date().isoformat() == "2026-08-06"
    assert intent.want_file is True


def test_parse_today_and_focus():
    now = datetime(2026, 8, 12, 15, 0, 0)
    intent = parse_user_request("сколько обращений в открытых линиях сегодня", default_days=30, now=now)
    assert intent.kind == "report"
    assert intent.focus == "openlines"
    assert intent.period.label == "сегодня"


def test_parse_custom_range():
    now = datetime(2026, 8, 12, 15, 0, 0)
    intent = parse_user_request("отчёт 01.07.2026 — 31.07.2026", default_days=30, now=now)
    assert intent.period.date_from.day == 1
    assert intent.period.date_to.day == 31
    assert intent.period.date_from.month == 7


def test_parse_bitrix_datetime_iso():
    dt = parse_bitrix_datetime("2026-08-01T12:30:00+03:00")
    assert dt is not None
    assert dt.hour == 12
    assert dt.day == 1


@pytest.mark.asyncio
async def test_demo_report_and_excel(tmp_path: Path):
    service = AnalyticsService(None, user_id=1, demo_mode=True)
    report = await service.build_report(Period.last_days(7, now=datetime(2026, 8, 12)))
    assert report.tasks.total > 0
    assert report.open_lines.total_sessions > 0
    assert report.summary_lines

    generator = ReportGenerator(tmp_path)
    xlsx = generator.generate_excel(report)
    txt = generator.generate_txt(report)
    assert xlsx.exists() and xlsx.stat().st_size > 0
    assert txt.exists()
    assert "Задачи:" in txt.read_text(encoding="utf-8")
