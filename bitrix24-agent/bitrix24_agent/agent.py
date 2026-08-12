"""Оркестратор: собирает разделы отчёта и складывает их в один результат."""

from __future__ import annotations

import logging
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime, tzinfo
from typing import Any

from .client import Bitrix24Client
from .collectors import (
    CallsSection,
    CrmSection,
    OpenLinesSection,
    Section,
    TasksSection,
    User,
    collect_calls,
    collect_crm,
    collect_openlines,
    collect_tasks,
    resolve_user,
)
from .collectors.base import ERROR
from .config import Config
from .errors import AgentError, Bitrix24Error
from .period import Period, resolve_timezone
from .transport import Transport, WebhookTransport

log = logging.getLogger(__name__)

#: Разделы, которые агент умеет собирать.
ALL_SECTIONS = ("tasks", "openlines", "crm", "calls")


@dataclass
class Report:
    """Готовый отчёт по одному пользователю за один период."""

    portal: str
    user: User
    period: Period
    generated_at: datetime
    tasks: TasksSection | None = None
    openlines: OpenLinesSection | None = None
    crm: CrmSection | None = None
    calls: CallsSection | None = None
    api_calls: int = 0
    elapsed_seconds: float = 0.0
    warnings: list[str] = field(default_factory=list)
    previous: Report | None = None

    @property
    def sections(self) -> list[Section]:
        found = [self.tasks, self.openlines, self.crm, self.calls]
        return [section for section in found if section is not None]

    def section(self, name: str) -> Section | None:
        return next((item for item in self.sections if item.name == name), None)

    def to_dict(self, *, include_previous: bool = True) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "portal": self.portal,
            "user": self.user.to_dict(),
            "period": self.period.to_dict(),
            "generated_at": self.generated_at.isoformat(),
            "api_calls": self.api_calls,
            "elapsed_seconds": round(self.elapsed_seconds, 2),
            "warnings": list(self.warnings),
            "sections": {section.name: section.to_dict() for section in self.sections},
        }
        if include_previous and self.previous is not None:
            payload["previous"] = self.previous.to_dict(include_previous=False)
        return payload


class Bitrix24Agent:
    """Точка входа: подключение к порталу и сбор отчётов."""

    def __init__(self, config: Config, transport: Transport | None = None):
        self.config = config
        self.timezone: tzinfo = resolve_timezone(config.timezone)
        self.transport = transport or WebhookTransport(
            config.webhook_url,
            timeout=config.timeout,
            rate_limit=config.rate_limit,
            max_retries=config.max_retries,
        )
        self.client = Bitrix24Client(self.transport)
        self._user: User | None = None

    @property
    def user(self) -> User:
        """Владелец отчёта; определяется один раз за сессию."""
        if self._user is None:
            self._user = resolve_user(self.client, self.config.user_id)
        return self._user

    def build_report(
        self,
        period: Period,
        *,
        sections: tuple[str, ...] = ALL_SECTIONS,
        compare: bool = False,
    ) -> Report:
        """Собирает отчёт за период, при необходимости — и за предыдущий."""
        report = self._build_single(period, sections=sections)
        if compare:
            previous_period = period.previous()
            log.info("собираю данные за %s для сравнения", previous_period.label)
            try:
                report.previous = self._build_single(previous_period, sections=sections)
            except AgentError as exc:
                report.warnings.append(f"Не удалось собрать предыдущий период: {exc}")
        return report

    def _build_single(self, period: Period, *, sections: tuple[str, ...]) -> Report:
        started_at = time.monotonic()
        calls_before = getattr(self.transport, "calls_made", 0)
        user = self.user
        report = Report(
            portal=self.config.portal,
            user=user,
            period=period,
            generated_at=datetime.now(self.timezone),
        )

        builders: dict[str, Callable[[], Section]] = {
            "tasks": lambda: collect_tasks(
                self.client,
                user_id=user.id,
                period=period,
                tz=self.timezone,
                max_tasks=self.config.max_tasks,
            ),
            "openlines": lambda: collect_openlines(
                self.client,
                user_id=user.id,
                period=period,
                tz=self.timezone,
                max_sessions=self.config.max_sessions,
            ),
            "crm": lambda: collect_crm(
                self.client,
                user_id=user.id,
                period=period,
                tz=self.timezone,
                max_deals=self.config.max_tasks,
            ),
            "calls": lambda: collect_calls(
                self.client, user_id=user.id, period=period, max_calls=self.config.max_tasks
            ),
        }

        for name in sections:
            builder = builders.get(name)
            if builder is None:
                report.warnings.append(f"Неизвестный раздел отчёта: {name}")
                continue
            log.info("собираю раздел «%s»", name)
            setattr(report, name, self._safe_collect(name, builder))

        report.api_calls = getattr(self.transport, "calls_made", 0) - calls_before
        report.elapsed_seconds = time.monotonic() - started_at
        return report

    def _safe_collect(self, name: str, builder: Callable[[], Section]) -> Section:
        """Падение одного раздела не должно лишать пользователя всего отчёта."""
        try:
            return builder()
        except Bitrix24Error as exc:
            log.warning("раздел «%s» не собран: %s", name, exc)
            section = Section(name=name, title=name, status=ERROR)
            section.note(f"Портал вернул ошибку: {exc}")
            return section
        except Exception as exc:  # noqa: BLE001 — отчёт важнее одного раздела
            log.exception("раздел «%s» упал с ошибкой", name)
            section = Section(name=name, title=name, status=ERROR)
            section.note(f"Внутренняя ошибка сбора: {exc}")
            return section

    def diagnose(self) -> list[dict[str, Any]]:
        """Проверяет доступность методов, на которых держится отчёт."""
        probes: list[tuple[str, str, dict[str, Any]]] = [
            ("Профиль пользователя", "user.current", {}),
            ("Задачи", "tasks.task.list", {"select": ["ID"], "start": 0}),
            ("Стадии канбана", "task.stages.get", {"entityId": 0}),
            ("Открытые линии (статистика)", "imopenlines.v2.Session.list", {"limit": 1}),
            ("Открытые линии (настройки)", "imopenlines.config.list.get", {}),
            ("CRM: дела", "crm.activity.list", {"select": ["ID"], "start": 0}),
            ("CRM: сделки", "crm.deal.list", {"select": ["ID"], "start": 0}),
            ("Телефония", "voximplant.statistic.get", {"start": 0}),
        ]
        results: list[dict[str, Any]] = []
        for title, method, params in probes:
            entry: dict[str, Any] = {"title": title, "method": method}
            try:
                self.client.call(method, params)
                entry["status"] = "ok"
                entry["detail"] = "доступен"
            except Bitrix24Error as exc:
                if exc.is_method_missing:
                    entry["status"] = "missing"
                    entry["detail"] = f"метод недоступен ({exc.code})"
                elif exc.is_access_denied:
                    entry["status"] = "denied"
                    entry["detail"] = f"нет прав или тарифа ({exc.code})"
                else:
                    entry["status"] = "error"
                    entry["detail"] = f"{exc.code}: {exc.description}".strip(": ")
            except AgentError as exc:
                entry["status"] = "error"
                entry["detail"] = str(exc)
            results.append(entry)
        return results
