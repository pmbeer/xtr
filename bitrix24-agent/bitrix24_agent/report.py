"""Представление отчёта: текст для консоли, Markdown и JSON."""

from __future__ import annotations

import json
from collections.abc import Iterable
from dataclasses import dataclass, field
from typing import Any

from .agent import Report
from .collectors import CallsSection, CrmSection, OpenLinesSection, Section, TasksSection
from .collectors.base import ERROR, PARTIAL, UNAVAILABLE
from .metrics import Summary, format_delta, humanize_duration, humanize_number, plural, share

LABEL_WIDTH = 36
VALUE_WIDTH = 12
SPARK_CHARS = "▁▂▃▄▅▆▇█"

STATUS_NOTE = {
    PARTIAL: "данные неполные",
    UNAVAILABLE: "раздел недоступен",
    ERROR: "ошибка сбора",
}


@dataclass
class Row:
    """Строка «показатель — значение — примечание»."""

    label: str
    value: str
    note: str = ""


@dataclass
class Table:
    """Разбивка по категориям: стадии, каналы, проекты."""

    title: str
    items: list[tuple[str, str]] = field(default_factory=list)


@dataclass
class Block:
    """Раздел отчёта, подготовленный к выводу."""

    title: str
    status: str
    rows: list[Row] = field(default_factory=list)
    tables: list[Table] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)

    @property
    def empty(self) -> bool:
        return not self.rows and not self.tables


def render(report: Report, fmt: str = "text") -> str:
    """Возвращает отчёт в выбранном формате: `text`, `markdown` или `json`."""
    if fmt == "json":
        return json.dumps(report.to_dict(), ensure_ascii=False, indent=2)
    blocks = build_blocks(report)
    if fmt in ("markdown", "md"):
        return _render_markdown(report, blocks)
    if fmt == "text":
        return _render_text(report, blocks)
    raise ValueError(f"Неизвестный формат отчёта: {fmt!r}")


def build_blocks(report: Report) -> list[Block]:
    """Готовит разделы к выводу, подмешивая сравнение с прошлым периодом."""
    blocks: list[Block] = []
    if report.tasks is not None:
        blocks.append(_tasks_block(report.tasks, _previous(report, "tasks")))
    if report.openlines is not None:
        blocks.append(_openlines_block(report.openlines, _previous(report, "openlines")))
    if report.crm is not None:
        blocks.append(_crm_block(report.crm, _previous(report, "crm")))
    if report.calls is not None:
        blocks.append(_calls_block(report.calls, _previous(report, "calls")))
    return blocks


def _previous(report: Report, name: str) -> Section | None:
    if report.previous is None:
        return None
    return report.previous.section(name)


def _delta(
    current: float, previous_section: Section | None, attribute: str, *, higher_is_better: bool = True
) -> str:
    if previous_section is None:
        return ""
    previous_value = getattr(previous_section, attribute, None)
    if previous_value is None:
        return ""
    return format_delta(current, float(previous_value), higher_is_better=higher_is_better)


def _summary_rows(title: str, summary: Summary, *, previous: Summary | None = None) -> list[Row]:
    """Три числа, которых достаточно, чтобы понять распределение времени."""
    if summary.empty:
        return [Row(title, "нет данных")]
    rows = [
        Row(
            f"{title}: среднее",
            humanize_duration(summary.avg),
            format_delta(summary.avg or 0, previous.avg if previous and not previous.empty else None, higher_is_better=False),
        ),
        Row(f"{title}: медиана", humanize_duration(summary.median)),
        Row(f"{title}: 90-й перцентиль", humanize_duration(summary.p90)),
    ]
    return rows


def _tasks_block(section: TasksSection, previous: Section | None) -> Block:
    block = Block(title="Задачи", status=section.status, notes=list(section.notes))
    if not section.available and not section.closed_count and not section.open_count:
        return block

    block.rows.extend(
        [
            Row(
                "Закрыто за период",
                humanize_number(section.closed_count),
                _delta(section.closed_count, previous, "closed_count"),
            ),
            Row("Поставлено мной за период", humanize_number(section.created_count)),
            Row(
                "Сейчас не закрыто",
                humanize_number(section.open_count),
                _delta(section.open_count, previous, "open_count", higher_is_better=False),
            ),
            Row("Из них в работе", humanize_number(section.in_progress_count)),
        ]
    )
    if section.open_overdue:
        block.rows.append(
            Row(
                "Просрочено сейчас",
                humanize_number(section.open_overdue),
                _percent_note(section.open_overdue, section.open_count),
            )
        )
    if section.closed_late:
        block.rows.append(
            Row(
                "Закрыто с нарушением срока",
                humanize_number(section.closed_late),
                _percent_note(section.closed_late, section.closed_analyzed),
            )
        )
    if section.open_without_deadline:
        block.rows.append(Row("Открытых задач без срока", humanize_number(section.open_without_deadline)))
    if section.open_stale_count:
        block.rows.append(Row("Висят дольше двух недель", humanize_number(section.open_stale_count)))
    if section.time_spent_seconds:
        block.rows.append(Row("Списано времени по таймеру", humanize_duration(section.time_spent_seconds)))

    previous_resolution = getattr(previous, "resolution", None) if previous else None
    block.rows.extend(_summary_rows("Время решения", section.resolution, previous=previous_resolution))

    if section.open_by_status:
        block.tables.append(
            Table("Открытые задачи по статусам", _counter_items(section.open_by_status, section.open_count))
        )
    if section.stages:
        block.tables.append(
            Table(
                "Открытые задачи по стадиям",
                [
                    (
                        f"{bucket.title}{f' ({bucket.scope})' if bucket.scope else ''}",
                        _count_with_share(bucket.count, section.open_count),
                    )
                    for bucket in section.stages[:10]
                ],
            )
        )
    if section.groups:
        block.tables.append(
            Table(
                "Проекты и группы",
                [
                    (bucket.title, f"закрыто {bucket.closed}, открыто {bucket.open}")
                    for bucket in section.groups
                ],
            )
        )
    if section.longest_open:
        block.tables.append(
            Table(
                "Дольше всего в работе",
                [
                    (_shorten(item["title"]), humanize_duration(item.get("age_seconds")))
                    for item in section.longest_open
                ],
            )
        )
    if section.slowest_closed:
        block.tables.append(
            Table(
                "Самые долгие из закрытых",
                [
                    (_shorten(item["title"]), humanize_duration(item.get("resolution_seconds")))
                    for item in section.slowest_closed
                ],
            )
        )
    return block


def _openlines_block(section: OpenLinesSection, previous: Section | None) -> Block:
    block = Block(title="Открытые линии", status=section.status, notes=list(section.notes))
    if not section.handled_count:
        return block

    block.rows.append(
        Row(
            "Обработано обращений",
            humanize_number(section.handled_count),
            _delta(section.handled_count, previous, "handled_count"),
        )
    )
    if section.closed_count:
        block.rows.append(
            Row(
                "Закрыто обращений",
                humanize_number(section.closed_count),
                _percent_note(section.closed_count, section.handled_count),
            )
        )

    previous_resolution = getattr(previous, "resolution", None) if previous else None
    block.rows.extend(
        _summary_rows("Решение вопроса", section.resolution, previous=previous_resolution)
    )
    if not section.first_response.empty:
        previous_response = getattr(previous, "first_response", None) if previous else None
        block.rows.extend(
            _summary_rows("Первый ответ", section.first_response, previous=previous_response)
        )
    if section.kpi_ok or section.kpi_failed:
        total_kpi = section.kpi_ok + section.kpi_failed
        block.rows.append(
            Row("Уложились в норматив первого ответа", f"{section.kpi_ok} из {total_kpi}", _percent_note(section.kpi_ok, total_kpi))
        )
    if section.messages_total:
        block.rows.append(Row("Сообщений всего", humanize_number(section.messages_total)))
        block.rows.append(Row("Сообщений на обращение", humanize_number(section.messages_per_session)))
    if section.rated_count:
        block.rows.append(
            Row(
                "Оценки клиентов",
                f"👍 {section.likes} / 👎 {section.dislikes}",
                f"довольны {humanize_number(section.satisfaction_rate)}%",
            )
        )
    if section.with_crm:
        block.rows.append(
            Row("Связано с CRM", humanize_number(section.with_crm), _percent_note(section.with_crm, section.handled_count))
        )

    if section.by_source:
        block.tables.append(Table("Каналы обращений", _counter_items(section.by_source, section.handled_count)))
    if section.by_line:
        block.tables.append(
            Table("Распределение по линиям", _counter_items(section.by_line, section.handled_count))
        )
    if section.by_status:
        block.tables.append(Table("Статусы обращений", _counter_items(section.by_status, section.handled_count)))
    if any(section.by_hour):
        block.rows.append(Row("Обращения по часам, 00→23", _sparkline(section.by_hour)))
        block.tables.append(Table("Пиковые часы", _peak_hours(section.by_hour)))
    return block


def _crm_block(section: CrmSection, previous: Section | None) -> Block:
    block = Block(title="CRM", status=section.status, notes=list(section.notes))
    if section.activities_done:
        block.rows.append(
            Row(
                "Выполнено дел",
                humanize_number(section.activities_done),
                _delta(section.activities_done, previous, "activities_done"),
            )
        )
    if section.deals_closed:
        block.rows.append(Row("Закрыто сделок", humanize_number(section.deals_closed)))
        block.rows.append(
            Row("Успешных", humanize_number(section.deals_won), _percent_note(section.deals_won, section.deals_closed))
        )
        block.rows.append(Row("Проваленных", humanize_number(section.deals_lost)))
        if section.deals_won_amount:
            block.rows.append(
                Row("Сумма успешных сделок", f"{humanize_number(section.deals_won_amount)} {section.currency}".strip())
            )
        block.rows.extend(_summary_rows("Цикл сделки", section.deal_cycle))
    if section.deals_open:
        block.rows.append(Row("Сделок в работе", humanize_number(section.deals_open)))
        if section.deals_open_amount:
            block.rows.append(
                Row("Сумма сделок в работе", f"{humanize_number(section.deals_open_amount)} {section.currency}".strip())
            )
    if section.activities_by_type:
        block.tables.append(Table("Дела по типам", _counter_items(section.activities_by_type, section.activities_done)))
    if section.deals_by_stage:
        block.tables.append(Table("Сделки по стадиям", _counter_items(section.deals_by_stage, section.deals_open)))
    return block


def _calls_block(section: CallsSection, previous: Section | None) -> Block:
    block = Block(title="Телефония", status=section.status, notes=list(section.notes))
    if not section.total:
        return block
    block.rows.append(Row("Звонков всего", humanize_number(section.total), _delta(section.total, previous, "total")))
    block.rows.append(
        Row("Успешных", humanize_number(section.succeeded), _percent_note(section.succeeded, section.total))
    )
    if section.missed:
        block.rows.append(Row("Несостоявшихся", humanize_number(section.missed)))
    block.rows.append(Row("Общая длительность", humanize_duration(section.total_duration_seconds)))
    block.rows.extend(_summary_rows("Длительность звонка", section.duration))
    if section.by_type:
        block.tables.append(Table("Звонки по типам", _counter_items(section.by_type, section.total)))
    return block


def _counter_items(counter: dict[str, int], total: int) -> list[tuple[str, str]]:
    return [(name, _count_with_share(count, total)) for name, count in counter.items()]


def _count_with_share(count: int, total: int) -> str:
    percent = share(count, total)
    if percent is None:
        return humanize_number(count)
    return f"{humanize_number(count)} ({humanize_number(percent)}%)"


def _percent_note(part: int, whole: int) -> str:
    percent = share(part, whole)
    return f"{humanize_number(percent)}% от общего" if percent is not None else ""


def _shorten(text: str, limit: int = 48) -> str:
    text = " ".join(str(text).split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def _sparkline(values: Iterable[int]) -> str:
    data = list(values)
    peak = max(data) if data else 0
    if not peak:
        return ""
    return "".join(SPARK_CHARS[min(len(SPARK_CHARS) - 1, value * (len(SPARK_CHARS) - 1) // peak)] for value in data)


def _peak_hours(by_hour: list[int]) -> list[tuple[str, str]]:
    ranked = sorted(((hour, count) for hour, count in enumerate(by_hour) if count), key=lambda item: item[1], reverse=True)
    total = sum(by_hour)
    return [(f"{hour:02d}:00—{hour:02d}:59", _count_with_share(count, total)) for hour, count in ranked[:3]]


def _render_text(report: Report, blocks: list[Block]) -> str:
    width = 72
    lines: list[str] = []
    lines.append("═" * width)
    lines.append("  ОТЧЁТ ПО РАБОТЕ В БИТРИКС24")
    lines.append("═" * width)
    for label, value in _header_pairs(report):
        lines.append(f"  {label + ':':<20}{value}")
    lines.append("═" * width)

    for block in blocks:
        lines.append("")
        suffix = STATUS_NOTE.get(block.status, "")
        heading = block.title.upper() + (f"  ({suffix})" if suffix else "")
        lines.append(heading)
        lines.append("─" * width)
        if block.empty:
            lines.append("  нет данных за период")
        for row in block.rows:
            value = row.value.rjust(VALUE_WIDTH) if len(row.value) < VALUE_WIDTH else row.value
            line = f"  {row.label:.<{LABEL_WIDTH}} {value}"
            if row.note:
                line += f"   {row.note}"
            lines.append(line.rstrip())
        for table in block.tables:
            lines.append("")
            lines.append(f"  {table.title}:")
            for name, value in table.items:
                lines.append(f"    {_shorten(name, 44):.<46} {value}")
        for note in block.notes:
            lines.append(f"  ! {note}")

    if report.warnings:
        lines.append("")
        lines.append("ПРЕДУПРЕЖДЕНИЯ")
        lines.append("─" * width)
        for warning in report.warnings:
            lines.append(f"  ! {warning}")
    lines.append("")
    return "\n".join(lines)


def _render_markdown(report: Report, blocks: list[Block]) -> str:
    lines: list[str] = ["# Отчёт по работе в Битрикс24", ""]
    for label, value in _header_pairs(report):
        lines.append(f"- **{label}:** {value}")
    lines.append("")

    for block in blocks:
        suffix = STATUS_NOTE.get(block.status, "")
        lines.append(f"## {block.title}" + (f" _({suffix})_" if suffix else ""))
        lines.append("")
        if block.empty:
            lines.append("_Нет данных за период._")
            lines.append("")
        if block.rows:
            lines.append("| Показатель | Значение | Комментарий |")
            lines.append("| --- | ---: | --- |")
            for row in block.rows:
                lines.append(f"| {row.label} | {row.value} | {row.note} |")
            lines.append("")
        for table in block.tables:
            lines.append(f"**{table.title}**")
            lines.append("")
            lines.append("| | |")
            lines.append("| --- | ---: |")
            for name, value in table.items:
                lines.append(f"| {name} | {value} |")
            lines.append("")
        for note in block.notes:
            lines.append(f"> {note}")
            lines.append("")

    if report.warnings:
        lines.append("## Предупреждения")
        lines.append("")
        for warning in report.warnings:
            lines.append(f"- {warning}")
        lines.append("")
    return "\n".join(lines)


def _header_pairs(report: Report) -> list[tuple[str, Any]]:
    period = report.period
    pairs = [
        ("Портал", report.portal),
        ("Сотрудник", report.user.name + (f", {report.user.position}" if report.user.position else "")),
        ("Период", f"{period.label} ({period.start:%d.%m.%Y} — {period.end:%d.%m.%Y})"),
        ("Сформирован", f"{report.generated_at:%d.%m.%Y %H:%M}"),
        (
            "Запросов к API",
            f"{report.api_calls} за {report.elapsed_seconds:.1f} с",
        ),
    ]
    if report.previous is not None:
        pairs.append(("Сравнение с", report.previous.period.label))
    return pairs


def render_diagnostics(portal: str, probes: list[dict[str, Any]]) -> str:
    """Человекочитаемый вывод команды `doctor`."""
    icons = {"ok": "✓", "missing": "—", "denied": "✗", "error": "!"}
    lines = [f"Проверка доступа к порталу {portal}", "─" * 72]
    for probe in probes:
        icon = icons.get(probe["status"], "?")
        lines.append(f"  {icon} {probe['title']:.<40} {probe['method']:<32} {probe['detail']}")
    failed = [probe for probe in probes if probe["status"] in ("denied", "error")]
    missing = [probe for probe in probes if probe["status"] == "missing"]
    lines.append("─" * 72)
    if not failed and not missing:
        lines.append("Все проверки пройдены — агент соберёт полный отчёт.")
    else:
        available = len(probes) - len(failed) - len(missing)
        lines.append(
            f"Доступно {available} из {len(probes)} "
            f"{plural(len(probes), 'источника', 'источников', 'источников')}. "
            "Разделы без доступа будут помечены в отчёте."
        )
    return "\n".join(lines)
