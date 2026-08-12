"""Простой разбор запросов на русском языке: период и интересующие метрики."""

import re
from dataclasses import dataclass, field

ALL_SECTIONS = frozenset(
    {"tasks_closed", "tasks_open", "stages", "openlines", "avg_time"}
)

_PERIOD_PATTERNS: list[tuple[str, str]] = [
    (r"\bпозавчера\b", "yesterday"),
    (r"\bвчера\b", "yesterday"),
    (r"\bсегодня\b|\bза день\b", "today"),
    (r"прошл\w*\s+недел|предыдущ\w*\s+недел", "prev_week"),
    (r"недел", "week"),
    (r"прошл\w*\s+месяц|предыдущ\w*\s+месяц", "prev_month"),
    (r"месяц", "month"),
    (r"квартал", "quarter"),
    (r"\bгод\b|\bза год\b|годов", "year"),
]

_SECTION_PATTERNS: list[tuple[str, str]] = [
    (r"закрыл|закрыт\w*\s+задач|заверш\w*\s+задач|выполнен\w*\s+задач|сделал", "tasks_closed"),
    (r"в работе|открыт\w*\s+задач|текущ\w*\s+задач|активн\w*\s+задач|незаверш", "tasks_open"),
    (r"стади|этап|канбан|kanban", "stages"),
    (r"обращен|открыт\w*\s+лини|диалог|чат|клиент", "openlines"),
    (r"средн\w*\s+время|время\s+решени|как\s+быстро|скорост", "avg_time"),
]


@dataclass
class ParsedQuery:
    period_name: str = "month"
    sections: frozenset[str] = field(default_factory=lambda: ALL_SECTIONS)

    @property
    def is_full_report(self) -> bool:
        return self.sections == ALL_SECTIONS


def parse_query(text: str) -> ParsedQuery:
    lowered = text.lower()

    period_name = "month"
    for pattern, name in _PERIOD_PATTERNS:
        if re.search(pattern, lowered):
            period_name = name
            break

    sections = {
        section
        for pattern, section in _SECTION_PATTERNS
        if re.search(pattern, lowered)
    }
    # "Стадии" и "среднее время" сами по себе требуют данных по задачам.
    if "stages" in sections:
        sections.add("tasks_open")
    if "avg_time" in sections and "openlines" not in sections:
        sections.add("tasks_closed")

    if not sections:
        return ParsedQuery(period_name=period_name)
    return ParsedQuery(period_name=period_name, sections=frozenset(sections))
