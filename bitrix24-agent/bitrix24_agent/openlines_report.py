"""Аналитика по обращениям в Открытых линиях (imopenlines).

Официальный классический REST API Битрикс24 не предоставляет отдельного
метода для агрегированной статистики по операторам Открытых линий
(количество обращений, среднее время решения и т.п.) без модуля отдельного
приложения из Маркетплейса. Рабочий и полностью официальный способ получить
эти цифры через REST — это диалоги Открытых линий, привязанные к CRM: каждый
такой диалог создаёт в CRM активность с PROVIDER_ID = "IMOPENLINES_SESSION"
(см. https://apidocs.bitrix24.com/api-reference/crm/activities/crm-activity-list.html
и справочник провайдеров активностей Битрикс24).

Ограничение: если в вашем портале Открытые линии используются без привязки к
CRM (диалоги не создают лид/сделку/контакт), эти обращения не будут видны
через REST API вообще — Битрикс24 не отдаёт их списком никаким официальным
методом. В этом случае остаётся either включить привязку к CRM в настройках
линии, либо использовать нативный отчёт в интерфейсе Битрикс24
(CRM -> Аналитика -> Открытые линии).

ВАЖНО: при поиске решения в интернете можно наткнуться на сторонний домен
"vibecode.bitrix24.tech", предлагающий методы вроде "POST /v1/openlines/stats"
или "imopenlines.v2.Stat.get" через отдельный API-ключ. Это НЕ официальный
REST API Битрикс24 (проверено — такого метода нет в apidocs.bitrix24.com,
запрос к нему возвращает 404), а сторонний сервис, требующий передачи ему
данных вашего портала через ЕГО СОБСТВЕННЫЙ API-ключ. Использовать его не
следует — этот модуль его не вызывает.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional

from .client import BitrixClient
from .period import Period
from .utils import parse_bitrix_datetime

PROVIDER_ID = "IMOPENLINES_SESSION"

ACTIVITY_SELECT = [
    "ID",
    "SUBJECT",
    "RESPONSIBLE_ID",
    "CREATED",
    "START_TIME",
    "END_TIME",
    "COMPLETED",
    "ASSOCIATED_ENTITY_ID",
]


@dataclass
class SessionInfo:
    id: int
    subject: str
    completed: bool
    start_time: Optional[datetime]
    end_time: Optional[datetime]

    @property
    def duration_minutes(self) -> Optional[float]:
        if self.start_time is None or self.end_time is None:
            return None
        delta = self.end_time - self.start_time
        return delta.total_seconds() / 60.0


@dataclass
class OpenLinesReport:
    user_id: int
    period: Period
    sessions: List[SessionInfo] = field(default_factory=list)
    crm_binding_available: bool = True

    @property
    def total_count(self) -> int:
        return len(self.sessions)

    @property
    def closed_count(self) -> int:
        return sum(1 for s in self.sessions if s.completed)

    @property
    def open_count(self) -> int:
        return self.total_count - self.closed_count

    @property
    def avg_resolution_minutes(self) -> Optional[float]:
        durations = [s.duration_minutes for s in self.sessions if s.completed and s.duration_minutes is not None]
        if not durations:
            return None
        return sum(durations) / len(durations)


def _to_bool(value) -> bool:
    return str(value).strip().upper() == "Y"


def build_openlines_report(client: BitrixClient, user_id: int, period: Period) -> OpenLinesReport:
    """Собирает отчёт по обращениям в Открытых линиях за период (через CRM-активности)."""
    report = OpenLinesReport(user_id=user_id, period=period)

    activity_filter: Dict[str, object] = {
        "PROVIDER_ID": PROVIDER_ID,
        "RESPONSIBLE_ID": user_id,
    }
    activity_filter.update(period.as_bitrix_filter("CREATED"))

    for activity in client.call_list(
        "crm.activity.list",
        filter_=activity_filter,
        select=ACTIVITY_SELECT,
        order={"CREATED": "asc"},
    ):
        report.sessions.append(
            SessionInfo(
                id=int(activity.get("ID", activity.get("id"))),
                subject=activity.get("SUBJECT", activity.get("subject", "")),
                completed=_to_bool(activity.get("COMPLETED", activity.get("completed", "N"))),
                start_time=parse_bitrix_datetime(activity.get("START_TIME") or activity.get("start_time")),
                end_time=parse_bitrix_datetime(activity.get("END_TIME") or activity.get("end_time")),
            )
        )

    return report
