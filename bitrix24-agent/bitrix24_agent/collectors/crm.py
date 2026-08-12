"""Метрики по CRM: выполненные дела и движение сделок."""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import tzinfo

from ..client import Bitrix24Client
from ..errors import Bitrix24Error
from ..metrics import Summary, summarize
from ..normalize import parse_datetime, parse_float, pick
from ..period import Period
from .base import ERROR, PARTIAL, UNAVAILABLE, Section

log = logging.getLogger(__name__)

#: Типы дел CRM (`TYPE_ID`).
ACTIVITY_TYPES = {
    1: "Встречи",
    2: "Звонки",
    3: "Задачи",
    4: "Письма",
    5: "Действия",
    6: "Внешние каналы",
}
#: Семантика стадии сделки.
SEMANTIC_WON = "S"
SEMANTIC_LOST = "F"


@dataclass
class CrmSection(Section):
    """Сводка по работе в CRM за период."""

    name: str = "crm"
    title: str = "CRM"

    activities_done: int = 0
    activities_by_type: dict[str, int] = field(default_factory=dict)

    deals_closed: int = 0
    deals_won: int = 0
    deals_lost: int = 0
    deals_won_amount: float = 0.0
    currency: str = ""
    deal_cycle: Summary = field(default_factory=Summary)

    deals_open: int = 0
    deals_open_amount: float = 0.0
    deals_by_stage: dict[str, int] = field(default_factory=dict)

    @property
    def win_rate(self) -> float | None:
        if not self.deals_closed:
            return None
        return round(self.deals_won / self.deals_closed * 100, 1)


def collect_crm(
    client: Bitrix24Client,
    *,
    user_id: int,
    period: Period,
    tz: tzinfo,
    max_deals: int = 2000,
) -> CrmSection:
    """Собирает раздел «CRM». Отсутствие модуля не считается ошибкой."""
    section = CrmSection()
    touched = False

    try:
        touched |= _fill_activities(client, section, user_id=user_id, period=period)
        touched |= _fill_closed_deals(
            client, section, user_id=user_id, period=period, tz=tz, limit=max_deals
        )
        touched |= _fill_open_deals(client, section, user_id=user_id, limit=max_deals)
    except Bitrix24Error as exc:
        if exc.is_method_missing or exc.is_access_denied:
            section.status = UNAVAILABLE
            section.note(f"CRM недоступна вебхуку: {exc.code}. Добавьте скоуп `crm`.")
            return section
        section.status = ERROR
        section.note(f"Ошибка при сборе данных CRM: {exc}")
        return section

    if not touched:
        section.status = UNAVAILABLE
        section.note("Данные CRM недоступны: проверьте скоуп `crm` у вебхука.")
    return section


def _fill_activities(
    client: Bitrix24Client, section: CrmSection, *, user_id: int, period: Period
) -> bool:
    """Считает завершённые дела по типам одним пакетным запросом."""
    base_filter = {
        "RESPONSIBLE_ID": user_id,
        "COMPLETED": "Y",
        ">=END_TIME": period.iso_start(),
        "<=END_TIME": period.iso_end(),
    }
    commands: dict[str, tuple[str, dict]] = {
        "total": ("crm.activity.list", {"filter": base_filter, "select": ["ID"], "start": 0})
    }
    for type_id in ACTIVITY_TYPES:
        commands[f"type_{type_id}"] = (
            "crm.activity.list",
            {"filter": {**base_filter, "TYPE_ID": type_id}, "select": ["ID"], "start": 0},
        )

    results = client.batch(commands)
    if not results.get("total") or not results["total"].ok:
        error = results["total"].error if results.get("total") else "нет ответа"
        log.info("crm.activity.list недоступен: %s", error)
        return False

    section.activities_done = results["total"].total or 0
    for type_id, label in ACTIVITY_TYPES.items():
        result = results.get(f"type_{type_id}")
        if result and result.ok and result.total:
            section.activities_by_type[label] = result.total
    section.activities_by_type = dict(
        sorted(section.activities_by_type.items(), key=lambda item: item[1], reverse=True)
    )
    return True


def _fill_closed_deals(
    client: Bitrix24Client,
    section: CrmSection,
    *,
    user_id: int,
    period: Period,
    tz: tzinfo,
    limit: int,
) -> bool:
    records = list(
        client.paginate(
            "crm.deal.list",
            {
                "filter": {
                    "ASSIGNED_BY_ID": user_id,
                    "CLOSED": "Y",
                    ">=CLOSEDATE": period.iso_start(),
                    "<=CLOSEDATE": period.iso_end(),
                },
                "select": [
                    "ID",
                    "STAGE_SEMANTIC_ID",
                    "OPPORTUNITY",
                    "CURRENCY_ID",
                    "DATE_CREATE",
                    "CLOSEDATE",
                ],
                "order": {"CLOSEDATE": "desc"},
            },
            max_items=limit,
        )
    )
    if not records:
        return True

    cycles: list[float] = []
    for record in records:
        semantic = str(pick(record, "STAGE_SEMANTIC_ID", default="") or "")
        section.deals_closed += 1
        if semantic == SEMANTIC_WON:
            section.deals_won += 1
            section.deals_won_amount += parse_float(pick(record, "OPPORTUNITY"), 0.0) or 0.0
            section.currency = section.currency or str(pick(record, "CURRENCY_ID", default="") or "")
        elif semantic == SEMANTIC_LOST:
            section.deals_lost += 1
        created = parse_datetime(pick(record, "DATE_CREATE"), tz)
        closed = parse_datetime(pick(record, "CLOSEDATE"), tz)
        if created and closed and closed >= created:
            cycles.append((closed - created).total_seconds())
    section.deal_cycle = summarize(cycles)

    if len(records) >= limit:
        section.status = PARTIAL
        section.note(f"Разобрано {limit} закрытых сделок — достигнут лимит выгрузки.")
    return True


def _fill_open_deals(
    client: Bitrix24Client, section: CrmSection, *, user_id: int, limit: int
) -> bool:
    records = list(
        client.paginate(
            "crm.deal.list",
            {
                "filter": {"ASSIGNED_BY_ID": user_id, "CLOSED": "N"},
                "select": ["ID", "STAGE_ID", "OPPORTUNITY"],
                "order": {"ID": "desc"},
            },
            max_items=limit,
        )
    )
    if not records:
        return True

    stage_names = _fetch_stage_names(client)
    counts: dict[str, int] = {}
    for record in records:
        section.deals_open += 1
        section.deals_open_amount += parse_float(pick(record, "OPPORTUNITY"), 0.0) or 0.0
        stage_id = str(pick(record, "STAGE_ID", default="") or "—")
        title = stage_names.get(stage_id, stage_id)
        counts[title] = counts.get(title, 0) + 1
    section.deals_by_stage = dict(sorted(counts.items(), key=lambda item: item[1], reverse=True))
    return True


def _fetch_stage_names(client: Bitrix24Client) -> dict[str, str]:
    """Человеческие названия стадий сделок из справочника статусов CRM."""
    names: dict[str, str] = {}
    try:
        records = client.paginate("crm.status.list", {"filter": {"ENTITY_ID": "DEAL_STAGE"}})
        for record in records:
            status_id = pick(record, "STATUS_ID")
            if status_id:
                names[str(status_id)] = str(pick(record, "NAME", default="") or status_id)
    except Bitrix24Error as exc:
        log.info("справочник стадий сделок недоступен: %s", exc.code)
    return names
