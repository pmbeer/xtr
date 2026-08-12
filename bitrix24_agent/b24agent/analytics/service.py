"""Сборка отчёта: обращается к Битрикс24 и считает метрики."""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime
from zoneinfo import ZoneInfo

from b24agent.analytics.models import (
    OpenLineMetrics,
    Report,
    ReportRequest,
    ReportSection,
    TaskMetrics,
)
from b24agent.analytics.openlines_metrics import compute_openline_metrics
from b24agent.analytics.tasks_metrics import compute_task_metrics
from b24agent.bitrix.client import Bitrix24Client
from b24agent.bitrix.errors import Bitrix24Error
from b24agent.bitrix.openlines import OpenLinesRepository
from b24agent.bitrix.tasks import TasksRepository
from b24agent.bitrix.users import PortalUser, UsersRepository

logger = logging.getLogger(__name__)


class AnalyticsService:
    """Фасад над репозиториями Битрикс24 и расчётом метрик."""

    def __init__(
        self,
        client: Bitrix24Client,
        *,
        tz: ZoneInfo,
        portal_url: str = "",
        default_user_id: int | None = None,
        max_records: int = 5000,
    ) -> None:
        self._client = client
        self._tz = tz
        self._portal_url = portal_url
        self._default_user_id = default_user_id
        self._max_records = max_records
        self.users = UsersRepository(client)
        self.tasks = TasksRepository(client, tz, max_records=max_records)
        self.openlines = OpenLinesRepository(client, tz, max_records=max_records)
        self._webhook_owner_id: int | None = None

    async def resolve_user(self, user_id: int | None) -> PortalUser:
        """Определяет, по кому считать отчёт.

        Приоритет: явно указанный id -> id из настроек -> владелец вебхука.
        """
        if user_id:
            return await self.users.get(user_id)
        if self._default_user_id:
            return await self.users.get(self._default_user_id)
        if self._webhook_owner_id:
            return await self.users.get(self._webhook_owner_id)
        owner = await self.users.current()
        self._webhook_owner_id = owner.id
        return owner

    async def build_report(self, request: ReportRequest) -> Report:
        user = await self.resolve_user(request.bitrix_user_id)
        warnings: list[str] = []

        need_tasks = request.wants(ReportSection.TASKS) or request.wants(ReportSection.STAGES)
        need_openlines = request.wants(ReportSection.OPENLINES)

        task_metrics: TaskMetrics | None = None
        openline_metrics: OpenLineMetrics | None = None

        jobs: list[asyncio.Task] = []
        async with asyncio.TaskGroup() as group:
            if need_tasks:
                jobs.append(
                    group.create_task(
                        self._safe(self._task_metrics(user.id, request), "задачам")
                    )
                )
            if need_openlines:
                jobs.append(
                    group.create_task(
                        self._safe(
                            self._openline_metrics(user.id, request), "открытым линиям"
                        )
                    )
                )

        for job in jobs:
            payload, warning = job.result()
            if warning:
                warnings.append(warning)
            if isinstance(payload, TaskMetrics):
                task_metrics = payload
            elif isinstance(payload, OpenLineMetrics):
                openline_metrics = payload
                warnings.extend(payload.notes)

        if task_metrics and task_metrics.truncated:
            warnings.append(
                f"Выгрузка задач ограничена {self._max_records} записями — "
                "сузьте период, если нужны все данные."
            )

        return Report(
            request=request,
            period=request.period,
            generated_at=datetime.now(self._tz),
            user_id=user.id,
            user_name=user.name,
            portal_url=self._portal_url,
            tasks=task_metrics,
            openlines=openline_metrics,
            warnings=warnings,
        )

    async def _task_metrics(self, user_id: int, request: ReportRequest) -> TaskMetrics:
        period = request.period
        closed, created, open_tasks = await asyncio.gather(
            self.tasks.closed_in_period(user_id, period),
            self.tasks.created_in_period(user_id, period),
            self.tasks.open_now(user_id),
        )

        stages: dict = {}
        group_names: dict[int, str] = {}
        if open_tasks:
            entity_ids = {task.group_id for task in open_tasks}
            # Справочник стадий нужен, только если задачи вообще стоят в канбане.
            stages_job = (
                self.tasks.stages(entity_ids)
                if any(task.stage_id for task in open_tasks)
                else _no_stages()
            )
            stages, group_names = await asyncio.gather(
                stages_job, self.tasks.group_names(entity_ids)
            )

        truncated = any(
            len(batch) >= self._max_records for batch in (closed, created, open_tasks)
        )
        return compute_task_metrics(
            closed_tasks=closed,
            created_tasks=created,
            open_tasks=open_tasks,
            period=period,
            stages=stages,
            group_names=group_names,
            truncated=truncated,
        )

    async def _openline_metrics(
        self, user_id: int, request: ReportRequest
    ) -> OpenLineMetrics:
        data = await self.openlines.collect(request.period, user_id)
        return compute_openline_metrics(data, request.period)

    @staticmethod
    async def _safe(coro, subject: str) -> tuple[object | None, str | None]:
        """Ошибка одного раздела не должна ронять весь отчёт."""
        try:
            return await coro, None
        except Bitrix24Error as exc:
            logger.warning("Раздел по %s не собран: %s", subject, exc)
            return None, f"Данные по {subject} получить не удалось: {exc.code}."
        except Exception as exc:
            logger.exception("Непредвиденная ошибка в разделе по %s", subject)
            return None, f"Данные по {subject} получить не удалось: {exc}."


async def _no_stages() -> dict:
    return {}
