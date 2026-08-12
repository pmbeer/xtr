from datetime import date

from openpyxl import load_workbook

from bitrix_analytics.bot import _period_from_args
from bitrix_analytics.models import ActivityMetrics, ReportPeriod
from bitrix_analytics.report import render_xlsx


def test_period_from_explicit_arguments() -> None:
    assert _period_from_args("2026-08-01 2026-08-12") == ReportPeriod(
        date(2026, 8, 1), date(2026, 8, 12)
    )


def test_report_contains_metrics_and_statuses() -> None:
    metrics = ActivityMetrics(
        period=ReportPeriod(date(2026, 8, 1), date(2026, 8, 12)),
        closed_tasks=7,
        active_tasks=3,
        tasks_by_status={"В работе": 2, "Новая": 1},
        handled_open_line_sessions=8,
        average_open_line_resolution_minutes=12.34,
    )

    sheet = load_workbook(render_xlsx(metrics)).active

    assert sheet["B3"].value == 7
    assert sheet["B6"].value == 12.3
    assert sheet["A9"].value == "В работе"
