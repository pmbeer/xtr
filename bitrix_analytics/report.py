from io import BytesIO

from openpyxl import Workbook
from openpyxl.styles import Font

from .models import ActivityMetrics


def render_xlsx(metrics: ActivityMetrics) -> BytesIO:
    """Create a compact Excel workbook ready to send through Telegram."""
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Отчёт"
    sheet.append(["Показатель", "Значение"])
    rows = [
        ("Период", f"{metrics.period.start:%d.%m.%Y} — {metrics.period.end:%d.%m.%Y}"),
        ("Закрыто задач", metrics.closed_tasks),
        ("Задач в работе", metrics.active_tasks),
        ("Обработано обращений ОЛ", metrics.handled_open_line_sessions),
        (
            "Среднее время решения ОЛ, мин.",
            round(metrics.average_open_line_resolution_minutes, 1)
            if metrics.average_open_line_resolution_minutes is not None
            else "Нет закрытых обращений",
        ),
    ]
    for row in rows:
        sheet.append(row)
    sheet.append([])
    sheet.append(["Стадия задачи", "Количество"])
    for status, total in metrics.tasks_by_status.items():
        sheet.append([status, total])

    for cell in sheet[1]:
        cell.font = Font(bold=True)
    for cell in sheet[8]:
        cell.font = Font(bold=True)
    sheet.column_dimensions["A"].width = 36
    sheet.column_dimensions["B"].width = 34

    output = BytesIO()
    workbook.save(output)
    output.seek(0)
    return output
