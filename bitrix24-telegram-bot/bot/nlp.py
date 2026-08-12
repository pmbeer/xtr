from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional

from services.models import Period


@dataclass
class UserIntent:
    kind: str  # report | help | status | unknown
    period: Period
    want_file: bool = True
    format: str = "xlsx"  # xlsx | txt
    focus: str = "all"  # all | tasks | openlines
    raw: str = ""


_MONTHS = {
    "январ": 1,
    "феврал": 2,
    "март": 3,
    "апрел": 4,
    "ма": 5,
    "июн": 6,
    "июл": 7,
    "август": 8,
    "сентябр": 9,
    "октябр": 10,
    "ноябр": 11,
    "декабр": 12,
}


def parse_user_request(text: str, *, default_days: int = 30, now: Optional[datetime] = None) -> UserIntent:
    now = now or datetime.now()
    raw = (text or "").strip()
    lower = raw.lower()

    if not lower or lower in {"/help", "help", "помощь", "справка"}:
        return UserIntent(kind="help", period=Period.last_days(default_days, now=now), want_file=False, raw=raw)

    if lower.startswith("/start"):
        return UserIntent(kind="help", period=Period.last_days(default_days, now=now), want_file=False, raw=raw)

    period = _extract_period(lower, default_days=default_days, now=now)
    focus = "all"
    if any(word in lower for word in ("открыт", "лини", "обращен", "диалог", "сесси")) and not any(
        word in lower for word in ("задач",)
    ):
        focus = "openlines"
    elif any(word in lower for word in ("задач", "канбан", "стади")) and not any(
        word in lower for word in ("лини", "обращен")
    ):
        focus = "tasks"

    fmt = "txt" if any(word in lower for word in ("txt", "текст", "текстовый")) else "xlsx"
    want_file = True
    if any(word in lower for word in ("без файла", "только текст", "кратко", "сводка")):
        want_file = "файл" in lower or "excel" in lower or "xlsx" in lower or "отчёт" in lower or "отчет" in lower
        if any(word in lower for word in ("без файла", "только текст", "кратко")):
            want_file = False

    report_triggers = (
        "отчёт",
        "отчет",
        "статистик",
        "анализ",
        "сколько",
        "покажи",
        "выгруз",
        "файл",
        "excel",
        "xlsx",
        "/report",
        "/stats",
        "задач",
        "обращен",
        "лини",
        "результат",
    )
    if any(trigger in lower for trigger in report_triggers):
        return UserIntent(kind="report", period=period, want_file=want_file, format=fmt, focus=focus, raw=raw)

    return UserIntent(kind="unknown", period=period, want_file=True, format=fmt, focus=focus, raw=raw)


def _extract_period(text: str, *, default_days: int, now: datetime) -> Period:
    if "сегодня" in text:
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        end = now.replace(hour=23, minute=59, second=59, microsecond=0)
        return Period(date_from=start, date_to=end, label="сегодня")

    if "вчера" in text:
        day = now - timedelta(days=1)
        start = day.replace(hour=0, minute=0, second=0, microsecond=0)
        end = day.replace(hour=23, minute=59, second=59, microsecond=0)
        return Period(date_from=start, date_to=end, label="вчера")

    if "эта недел" in text or "текущ" in text and "недел" in text:
        start = (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
        end = now.replace(hour=23, minute=59, second=59, microsecond=0)
        return Period(date_from=start, date_to=end, label="эта неделя")

    if "прошл" in text and "недел" in text:
        end_week = (now - timedelta(days=now.weekday() + 1)).replace(hour=23, minute=59, second=59, microsecond=0)
        start = (end_week - timedelta(days=6)).replace(hour=0, minute=0, second=0, microsecond=0)
        return Period(date_from=start, date_to=end_week, label="прошлая неделя")

    if "этот месяц" in text or "текущий месяц" in text or "за месяц" in text:
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        end = now.replace(hour=23, minute=59, second=59, microsecond=0)
        return Period(date_from=start, date_to=end, label="текущий месяц")

    if "прошлый месяц" in text or "прошлом месяц" in text:
        first_this = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        end = first_this - timedelta(seconds=1)
        start = end.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        return Period(date_from=start, date_to=end, label="прошлый месяц")

    m = re.search(r"за\s+(\d+)\s*(дн|день|дня|дней)", text)
    if m:
        days = max(1, int(m.group(1)))
        return Period.last_days(days, now=now)

    m = re.search(r"за\s+(\d+)\s*(недел)", text)
    if m:
        days = max(1, int(m.group(1)) * 7)
        return Period.last_days(days, now=now)

    # диапазон дд.мм.гггг - дд.мм.гггг
    m = re.search(
        r"(\d{1,2}[./]\d{1,2}[./]\d{2,4})\s*(?:-|—|до|по)\s*(\d{1,2}[./]\d{1,2}[./]\d{2,4})",
        text,
    )
    if m:
        start = _parse_ru_date(m.group(1), end_of_day=False)
        end = _parse_ru_date(m.group(2), end_of_day=True)
        if start and end:
            return Period(date_from=start, date_to=end, label="произвольный период")

    return Period.last_days(default_days, now=now)


def _parse_ru_date(value: str, *, end_of_day: bool) -> Optional[datetime]:
    value = value.replace("/", ".")
    for fmt in ("%d.%m.%Y", "%d.%m.%y"):
        try:
            dt = datetime.strptime(value, fmt)
            if end_of_day:
                return dt.replace(hour=23, minute=59, second=59)
            return dt.replace(hour=0, minute=0, second=0)
        except ValueError:
            continue
    return None
