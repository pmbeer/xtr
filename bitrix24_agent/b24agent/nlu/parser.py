"""Правиловый разбор русскоязычных запросов к боту.

Задача разбора — превратить фразу «сколько задач я закрыл за прошлую неделю,
дай в excel» в :class:`ReportRequest`. Правила выбраны вместо языковой модели
сознательно: разбор офлайновый, предсказуемый и не требует внешних ключей,
а набор формулировок в этой предметной области ограничен.
"""

from __future__ import annotations

import re
from collections.abc import Callable
from datetime import date, datetime
from zoneinfo import ZoneInfo

from b24agent.analytics import period as periods
from b24agent.analytics.models import (
    ALL_SECTIONS,
    ReportFormat,
    ReportRequest,
    ReportSection,
)
from b24agent.analytics.period import Period

# --------------------------------------------------------------------- периоды

MONTH_PATTERNS: tuple[tuple[str, int], ...] = (
    (r"январ[ьяе]|\bянв\b", 1),
    (r"феврал[ьяе]|\bфев\b", 2),
    (r"март[ае]?\b|\bмар\b", 3),
    (r"апрел[ьяе]|\bапр\b", 4),
    (r"\bма[йяе]\b", 5),
    (r"июн[ьяе]", 6),
    (r"июл[ьяе]", 7),
    (r"август[ае]?\b|\bавг\b", 8),
    (r"сентябр[ьяе]|\bсент?\b", 9),
    (r"октябр[ьяе]|\bокт\b", 10),
    (r"ноябр[ьяе]|\bноя\b", 11),
    (r"декабр[ьяе]|\bдек\b", 12),
)

DATE_RE = r"(\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4}|\d{4}-\d{2}-\d{2})"
RANGE_RE = re.compile(rf"(?:с|от)\s*{DATE_RE}\s*(?:по|до|-|—|–)\s*{DATE_RE}")
DASH_RANGE_RE = re.compile(rf"{DATE_RE}\s*(?:-|—|–)\s*{DATE_RE}")
SINGLE_DATE_RE = re.compile(rf"(?:за|на)?\s*{DATE_RE}")

LAST_N_DAYS_RE = re.compile(r"(?:за\s+)?(?:последни[еий]|прошедши[ей])?\s*(\d{1,3})\s*(?:кален[а-я]*\s*)?(дн|день|дня|дней|сут)")
LAST_N_WEEKS_RE = re.compile(r"(?:за\s+)?(?:последни[еих]|прошедши[ех])?\s*(\d{1,2})\s*(недел)")
LAST_N_MONTHS_RE = re.compile(r"(?:за\s+)?(?:последни[еих]|прошедши[ех])?\s*(\d{1,2})\s*(месяц)")

# --------------------------------------------------------------------- разделы

TASK_HINTS = ("задач", "task", "поручен", "дедлайн", "просроч")
STAGE_HINTS = ("стади", "этап", "канбан", "kanban", "воронк", "колонк")
OPENLINE_HINTS = (
    "лини",
    "обращен",
    "чат",
    "оператор",
    "csat",
    "диалог",
    "openline",
    "клиентск",
    "мессендж",
    "телеграм",
    "whatsapp",
    "ватсап",
    "оценк",
)

FORMAT_HINTS: tuple[tuple[tuple[str, ...], ReportFormat], ...] = (
    (("xlsx", "excel", "эксель", "таблиц", "экс"), ReportFormat.XLSX),
    (("csv",), ReportFormat.CSV),
    (("json", "джсон"), ReportFormat.JSON),
)

SUMMARY_ONLY_HINTS = ("только сводк", "без детал", "без списк", "коротко", "кратко", "сводка")


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", (text or "").lower().replace("ё", "е")).strip()


def parse_query(
    text: str,
    *,
    now: datetime,
    tz: ZoneInfo | None = None,
    default_format: ReportFormat = ReportFormat.XLSX,
    bitrix_user_id: int | None = None,
) -> ReportRequest:
    """Строит запрос на отчёт по свободному тексту пользователя."""
    tz = tz or _tz_of(now)
    normalized = normalize(text)

    return ReportRequest(
        period=parse_period(normalized, now=now, tz=tz),
        sections=parse_sections(normalized),
        report_format=parse_format(normalized, default_format),
        bitrix_user_id=bitrix_user_id,
        include_details=not any(hint in normalized for hint in SUMMARY_ONLY_HINTS),
        raw_query=(text or "").strip(),
    )


def parse_sections(normalized: str) -> frozenset[ReportSection]:
    """Определяет запрошенные разделы; при отсутствии подсказок — все."""
    sections: set[ReportSection] = set()
    if any(hint in normalized for hint in TASK_HINTS):
        sections.add(ReportSection.TASKS)
    if any(hint in normalized for hint in STAGE_HINTS):
        sections.add(ReportSection.STAGES)
        # Стадии считаются по срезу задач, поэтому раздел задач тоже нужен.
        sections.add(ReportSection.TASKS)
    if any(hint in normalized for hint in OPENLINE_HINTS):
        sections.add(ReportSection.OPENLINES)
    return frozenset(sections) if sections else ALL_SECTIONS


def parse_format(normalized: str, default: ReportFormat = ReportFormat.XLSX) -> ReportFormat:
    for hints, report_format in FORMAT_HINTS:
        if any(hint in normalized for hint in hints):
            return report_format
    return default


def parse_period(text: str, *, now: datetime, tz: ZoneInfo | None = None) -> Period:
    """Находит период в тексте; если ничего не нашлось — текущий месяц.

    Стратегии применяются по порядку: явные даты сильнее относительных
    формулировок, а название месяца — слабее, чем «за последние N дней».
    """
    tz = tz or _tz_of(now)
    normalized = normalize(text)

    for strategy in _STRATEGIES:
        found = strategy(normalized, now, tz)
        if found is not None:
            return found
    return periods.default_period(now)


def describe_request(request: ReportRequest) -> str:
    """Короткое описание того, как бот понял запрос."""
    sections = ", ".join(
        section.title
        for section in sorted(request.sections, key=lambda item: item.value)
    )
    details = "с детализацией" if request.include_details else "только сводка"
    return (
        f"Период: {request.period.human()}\n"
        f"Разделы: {sections}\n"
        f"Формат: {request.report_format.value.upper()} ({details})"
    )


# ------------------------------------------------------------------ внутреннее


def _parse_explicit_range(normalized: str, now: datetime, tz: ZoneInfo) -> Period | None:
    for pattern in (RANGE_RE, DASH_RANGE_RE):
        match = pattern.search(normalized)
        if not match:
            continue
        first = _parse_date(match.group(1))
        second = _parse_date(match.group(2))
        if first and second:
            return periods.from_dates(first, second, tz)
    return None


def _parse_relative(normalized: str, now: datetime, tz: ZoneInfo) -> Period | None:
    """Ищет период по таблице правил; порядок правил задаёт приоритет.

    «Прошлый месяц» проверяется раньше «за месяц», иначе первое же совпадение
    съело бы уточнение, а «за месяц» без уточнения означает текущий месяц —
    от 1-го числа до сегодня, чтобы человек видел свой прогресс.
    """
    for pattern, builder in RELATIVE_RULES:
        if re.search(pattern, normalized):
            return builder(now)
    return None


_PREVIOUS = r"(?:прошл\w*|прошедш\w*|предыдущ\w*|минувш\w*)"
_CURRENT = r"(?:эт\w*|текущ\w*|нынешн\w*)"

RELATIVE_RULES: tuple[tuple[str, Callable[[datetime], Period]], ...] = (
    (r"позавчера", periods.day_before_yesterday),
    (r"вчера|вчерашн", periods.yesterday),
    (r"сегодня|за день|текущий день", periods.today),
    (rf"{_PREVIOUS}\s+недел|недел\w*\s+{_PREVIOUS}", periods.last_week),
    (rf"{_PREVIOUS}\s+месяц|месяц\w*\s+{_PREVIOUS}", periods.last_month),
    (rf"{_PREVIOUS}\s+квартал", periods.last_quarter),
    (rf"{_PREVIOUS}\s+год|в прошлом году", periods.last_year),
    (rf"{_CURRENT}\s+недел|на этой неделе|за\s+недел", periods.this_week),
    (rf"{_CURRENT}\s+месяц|в этом месяце|за\s+месяц", periods.this_month),
    (rf"{_CURRENT}\s+квартал|за\s+квартал", periods.this_quarter),
    (rf"{_CURRENT}\s+год|в этом году|за\s+год", periods.this_year),
)


def _parse_counted(normalized: str, now: datetime, tz: ZoneInfo) -> Period | None:
    match = LAST_N_DAYS_RE.search(normalized)
    if match:
        return periods.last_n_days(now, int(match.group(1)))
    match = LAST_N_WEEKS_RE.search(normalized)
    if match:
        return periods.last_n_days(now, int(match.group(1)) * 7)
    match = LAST_N_MONTHS_RE.search(normalized)
    if match:
        return periods.last_n_months(now, int(match.group(1)))
    if re.search(r"последн\w*\s+недел", normalized):
        return periods.last_n_days(now, 7)
    if re.search(r"последн\w*\s+месяц", normalized):
        return periods.last_n_days(now, 30)
    return None


def _parse_month(normalized: str, now: datetime, tz: ZoneInfo) -> Period | None:
    for pattern, month in MONTH_PATTERNS:
        if not re.search(pattern, normalized):
            continue
        year_match = re.search(r"(20\d{2})", normalized)
        if year_match:
            year = int(year_match.group(1))
        else:
            # Без года: ближайший прошедший месяц с таким номером.
            year = now.year if month <= now.month else now.year - 1
        return periods.month_of(year, month, tz)
    return None


def _parse_all_time(normalized: str, now: datetime, tz: ZoneInfo) -> Period | None:
    # Битрикс24 ограничивает статистику открытых линий годом, поэтому
    # «за всё время» разворачивается в последние 12 месяцев.
    if re.search(r"за\s+(все|всю историю|весь период)", normalized):
        return periods.last_n_months(now, 12)
    return None


def _parse_single_date(normalized: str, now: datetime, tz: ZoneInfo) -> Period | None:
    match = SINGLE_DATE_RE.search(normalized)
    if not match:
        return None
    parsed = _parse_date(match.group(1))
    return periods.single_day(parsed, tz) if parsed else None


_STRATEGIES: tuple[Callable[[str, datetime, ZoneInfo], Period | None], ...] = (
    _parse_explicit_range,
    _parse_relative,
    _parse_counted,
    _parse_month,
    _parse_all_time,
    _parse_single_date,
)


def _parse_date(raw: str) -> date | None:
    text = raw.strip().replace("/", ".").replace("-", ".")
    if re.match(r"^\d{4}\.\d{2}\.\d{2}$", text):
        year, month, day = (int(part) for part in text.split("."))
    else:
        parts = text.split(".")
        if len(parts) != 3:
            return None
        day, month, year = (int(part) for part in parts)
        if year < 100:
            year += 2000
    try:
        return date(year, month, day)
    except ValueError:
        return None


def _tz_of(moment: datetime) -> ZoneInfo:
    tzinfo = moment.tzinfo
    if isinstance(tzinfo, ZoneInfo):
        return tzinfo
    raise ValueError("Для разбора периода нужен datetime с ZoneInfo")
