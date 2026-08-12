from __future__ import annotations

from collections import Counter
from datetime import datetime

from bot.bitrix.openlines import OpenLinesStats
from bot.bitrix.tasks import TaskItem, TaskStats
from bot.reports.builder import ReportMeta, build_report_workbook
from bot.utils.period import Period


def _sample_task(tz, task_id=1, status_code=2, status_label="Ждёт выполнения"):
    return TaskItem(
        id=task_id,
        title=f"Задача {task_id}",
        status_code=status_code,
        status_label=status_label,
        priority_label="Обычный",
        created=datetime(2026, 8, 1, 10, 0, tzinfo=tz),
        closed=datetime(2026, 8, 2, 10, 0, tzinfo=tz) if status_code == 5 else None,
        deadline=datetime(2026, 8, 15, 10, 0, tzinfo=tz),
        group_id=10,
        stage_id=100,
        stage_label=status_label,
    )


def test_build_report_workbook_contains_expected_sheets(tz):
    period = Period(
        date_from=datetime(2026, 8, 1, 0, 0, tzinfo=tz),
        date_to=datetime(2026, 8, 12, 23, 59, tzinfo=tz),
        label="1-12 августа",
        matched=True,
    )
    meta = ReportMeta(display_name="Иван Иванов", period=period, generated_at=datetime(2026, 8, 12, 15, 0, tzinfo=tz))

    active_task = _sample_task(tz, task_id=1)
    closed_task = _sample_task(tz, task_id=2, status_code=5, status_label="Завершена")

    task_stats = TaskStats(
        active_count=1,
        closed_count=1,
        overdue_count=0,
        created_count=2,
        avg_completion_hours=24.0,
        by_status=Counter({"Ждёт выполнения": 1}),
        by_stage=Counter({"Ждёт выполнения": 1}),
        active_tasks=[active_task],
        closed_tasks=[closed_task],
    )

    ol_stats = OpenLinesStats(
        total=5,
        completed=4,
        in_progress=1,
        avg_resolution_seconds=1800.0,
        sessions=[],
    )

    wb = build_report_workbook(meta, task_stats, ol_stats)

    assert wb.sheetnames == ["Сводка", "Задачи в работе", "Закрытые задачи", "Открытые линии"]

    summary = wb["Сводка"]
    assert "Иван Иванов" in summary["A1"].value

    active_sheet = wb["Задачи в работе"]
    assert active_sheet["B2"].value == "Задача 1"

    closed_sheet = wb["Закрытые задачи"]
    assert closed_sheet["B2"].value == "Задача 2"
