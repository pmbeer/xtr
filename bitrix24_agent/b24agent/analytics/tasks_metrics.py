"""Расчёт метрик по задачам.

Разделение по смыслу: «сколько закрыл» и «сколько поставили» — это события
внутри периода, а «сколько в работе» и «на какой стадии» — срез на текущий
момент, потому что стадия у задачи одна и истории стадий REST не отдаёт.
"""

from __future__ import annotations

from collections import Counter
from collections.abc import Sequence
from datetime import date

from b24agent.analytics import stats
from b24agent.analytics.models import TaskMetrics
from b24agent.analytics.period import Period
from b24agent.bitrix.tasks import Task, TaskStage, status_name

NO_STAGE_LABEL = "Без стадии"
NO_GROUP_LABEL = "Вне проектов"


def compute_task_metrics(
    *,
    closed_tasks: Sequence[Task],
    created_tasks: Sequence[Task],
    open_tasks: Sequence[Task],
    period: Period,
    stages: dict[int, TaskStage] | None = None,
    group_names: dict[int, str] | None = None,
    truncated: bool = False,
) -> TaskMetrics:
    stages = stages or {}
    group_names = group_names or {}

    lead_times = stats.clean(task.lead_time_seconds for task in closed_tasks)
    spent = [float(task.time_spent) for task in closed_tasks if task.time_spent > 0]

    metrics = TaskMetrics(
        closed_count=len(closed_tasks),
        created_count=len(created_tasks),
        open_count=len(open_tasks),
        by_status=_by_status(open_tasks),
        by_stage=_by_stage(open_tasks, stages),
        by_group=_by_group(open_tasks, group_names),
        stage_titles={stage_id: stage.title for stage_id, stage in stages.items()},
        overdue_open_count=sum(1 for task in open_tasks if task.is_overdue),
        avg_lead_time_seconds=stats.mean(lead_times),
        median_lead_time_seconds=stats.median(lead_times),
        p90_lead_time_seconds=stats.percentile(lead_times, 0.9),
        fastest_lead_time_seconds=min(lead_times) if lead_times else None,
        slowest_lead_time_seconds=max(lead_times) if lead_times else None,
        total_time_spent_seconds=sum(spent),
        avg_time_spent_seconds=stats.mean(spent),
        closed_per_day=_closed_per_day(closed_tasks, period),
        closed_tasks=list(closed_tasks),
        open_tasks=list(open_tasks),
        truncated=truncated,
    )

    for task in closed_tasks:
        if task.deadline is None:
            metrics.without_deadline_count += 1
        elif task.is_overdue:
            metrics.closed_overdue_count += 1
        else:
            metrics.closed_on_time_count += 1

    return metrics


def _by_status(open_tasks: Sequence[Task]) -> dict[str, int]:
    counter = Counter(task.status for task in open_tasks)
    return {
        status_name(status): count
        for status, count in sorted(counter.items(), key=lambda item: item[0])
    }


def _by_stage(open_tasks: Sequence[Task], stages: dict[int, TaskStage]) -> dict[str, int]:
    counter: Counter[str] = Counter()
    for task in open_tasks:
        if not task.stage_id:
            counter[NO_STAGE_LABEL] += 1
            continue
        stage = stages.get(task.stage_id)
        counter[stage.title if stage else f"Стадия {task.stage_id}"] += 1
    return dict(counter.most_common())


def _by_group(open_tasks: Sequence[Task], group_names: dict[int, str]) -> dict[str, int]:
    counter: Counter[str] = Counter()
    for task in open_tasks:
        if not task.group_id:
            counter[NO_GROUP_LABEL] += 1
        else:
            counter[group_names.get(task.group_id, f"Проект {task.group_id}")] += 1
    return dict(counter.most_common())


def _closed_per_day(closed_tasks: Sequence[Task], period: Period) -> dict[date, int]:
    per_day: dict[date, int] = {day: 0 for day in period.iter_days()}
    for task in closed_tasks:
        if task.closed_at is None:
            continue
        day = task.closed_at.date()
        if day in per_day:
            per_day[day] += 1
        else:  # задача закрыта на границе периода в другом часовом поясе
            per_day.setdefault(day, 0)
            per_day[day] += 1
    return dict(sorted(per_day.items()))
