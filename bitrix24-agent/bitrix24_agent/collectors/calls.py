"""Метрики по телефонии: количество и длительность звонков."""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

from ..client import Bitrix24Client
from ..errors import Bitrix24Error
from ..metrics import Summary, summarize
from ..normalize import parse_float, parse_int, pick
from ..period import Period
from .base import ERROR, PARTIAL, UNAVAILABLE, Section

log = logging.getLogger(__name__)

STATISTIC_METHOD = "voximplant.statistic.get"

#: Типы звонков в статистике телефонии (`CALL_TYPE`).
CALL_TYPES = {
    1: "Исходящие",
    2: "Входящие",
    3: "Входящие с перенаправлением",
    4: "Обратный звонок",
}
#: Успешным считается звонок с кодом завершения 200.
SUCCESS_CODE = "200"


@dataclass
class CallsSection(Section):
    """Сводка по звонкам сотрудника за период."""

    name: str = "calls"
    title: str = "Телефония"

    total: int = 0
    succeeded: int = 0
    missed: int = 0
    duration: Summary = field(default_factory=Summary)
    total_duration_seconds: float = 0.0
    by_type: dict[str, int] = field(default_factory=dict)

    @property
    def success_rate(self) -> float | None:
        if not self.total:
            return None
        return round(self.succeeded / self.total * 100, 1)


def collect_calls(
    client: Bitrix24Client,
    *,
    user_id: int,
    period: Period,
    max_calls: int = 2000,
) -> CallsSection:
    """Собирает раздел «Телефония». Если телефонии нет — раздел помечается пустым."""
    section = CallsSection()
    try:
        records = list(
            client.paginate(
                STATISTIC_METHOD,
                {
                    "FILTER": {
                        "PORTAL_USER_ID": user_id,
                        ">=CALL_START_DATE": period.iso_start(),
                        "<=CALL_START_DATE": period.iso_end(),
                    },
                    "SORT": "CALL_START_DATE",
                    "ORDER": "ASC",
                },
                max_items=max_calls,
            )
        )
    except Bitrix24Error as exc:
        section.status = UNAVAILABLE if exc.is_method_missing or exc.is_access_denied else ERROR
        section.note(
            "Телефония недоступна: "
            + (
                "модуль не подключён или у вебхука нет скоупа `telephony`."
                if section.status == UNAVAILABLE
                else str(exc)
            )
        )
        return section

    durations: list[float] = []
    for record in records:
        section.total += 1
        duration = parse_float(pick(record, "CALL_DURATION"), 0.0) or 0.0
        durations.append(duration)
        section.total_duration_seconds += duration

        failed_code = str(pick(record, "CALL_FAILED_CODE", default="") or "")
        if failed_code in ("", SUCCESS_CODE):
            section.succeeded += 1
        else:
            section.missed += 1

        call_type = parse_int(pick(record, "CALL_TYPE"), 0) or 0
        label = CALL_TYPES.get(call_type, f"Тип {call_type}")
        section.by_type[label] = section.by_type.get(label, 0) + 1

    section.duration = summarize(durations)
    section.by_type = dict(sorted(section.by_type.items(), key=lambda item: item[1], reverse=True))

    if not section.total:
        section.status = UNAVAILABLE
        section.note("Звонков за период не найдено.")
    elif len(records) >= max_calls:
        section.status = PARTIAL
        section.note(f"Разобрано {max_calls} звонков — достигнут лимит выгрузки.")
    return section
