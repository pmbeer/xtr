"""Выбор формата и упаковка отчёта в файл."""

from __future__ import annotations

import re
from dataclasses import dataclass

from b24agent.analytics.models import Report, ReportFormat
from b24agent.reports.tabular import render_csv, render_json
from b24agent.reports.xlsx import render_xlsx

RENDERERS = {
    ReportFormat.XLSX: render_xlsx,
    ReportFormat.CSV: render_csv,
    ReportFormat.JSON: render_json,
}


@dataclass(frozen=True, slots=True)
class GeneratedReport:
    """Готовый файл отчёта в памяти — его сразу отправляем в Telegram."""

    filename: str
    content: bytes
    report_format: ReportFormat

    @property
    def size_kb(self) -> float:
        return round(len(self.content) / 1024, 1)


def build_report_file(report: Report) -> GeneratedReport:
    report_format = report.request.report_format
    renderer = RENDERERS[report_format]
    return GeneratedReport(
        filename=build_filename(report),
        content=renderer(report),
        report_format=report_format,
    )


def build_filename(report: Report) -> str:
    employee = _slug(report.user_name) or f"user{report.user_id}"
    start = report.period.start.strftime("%Y%m%d")
    end = report.period.end.strftime("%Y%m%d")
    extension = report.request.report_format.extension
    return f"bitrix24_{employee}_{start}-{end}.{extension}"


def _slug(text: str) -> str:
    translit = str.maketrans(
        {
            "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ж": "zh",
            "з": "z", "и": "i", "й": "y", "к": "k", "л": "l", "м": "m", "н": "n",
            "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f",
            "х": "h", "ц": "c", "ч": "ch", "ш": "sh", "щ": "sch", "ъ": "", "ы": "y",
            "ь": "", "э": "e", "ю": "yu", "я": "ya", "ё": "e",
        }
    )
    slug = text.strip().lower().translate(translit)
    slug = re.sub(r"[^a-z0-9]+", "_", slug).strip("_")
    return slug[:40]
