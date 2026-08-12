from __future__ import annotations

from datetime import date

from b24agent.analytics import period as periods
from b24agent.analytics.humanize import duration, plural
from b24agent.analytics.openlines_metrics import compute_openline_metrics
from b24agent.analytics.tasks_metrics import compute_task_metrics
from b24agent.bitrix.openlines import OpenLinesData, OpenLinesDataSource, Session
from b24agent.bitrix.tasks import Task, TaskStage
from tests.fake_portal import session_payload, task_payload


def _task(tz, **kwargs) -> Task:
    return Task.from_api(task_payload(**kwargs), tz)


def test_task_metrics_counts_and_times(tz, now):
    period = periods.last_week(now)
    closed = [
        _task(
            tz,
            task_id=1,
            created="2026-08-03T10:00:00+03:00",
            closed="2026-08-03T12:00:00+03:00",
            deadline="2026-08-04T18:00:00+03:00",
            spent=1800,
        ),
        _task(
            tz,
            task_id=2,
            created="2026-08-04T10:00:00+03:00",
            closed="2026-08-04T16:00:00+03:00",
            deadline="2026-08-04T12:00:00+03:00",
        ),
        _task(
            tz,
            task_id=3,
            created="2026-08-05T10:00:00+03:00",
            closed="2026-08-05T14:00:00+03:00",
        ),
    ]
    open_tasks = [
        _task(tz, task_id=10, status=3, closed=None, stage_id=11, group_id=12),
        _task(tz, task_id=11, status=2, closed=None, stage_id=11),
        _task(tz, task_id=12, status=3, closed=None, deadline="2020-01-01T10:00:00+03:00"),
    ]

    metrics = compute_task_metrics(
        closed_tasks=closed,
        created_tasks=closed[:2],
        open_tasks=open_tasks,
        period=period,
        stages={11: TaskStage(id=11, title="В работе", entity_id=0)},
        group_names={12: "Поддержка"},
    )

    assert metrics.closed_count == 3
    assert metrics.created_count == 2
    assert metrics.open_count == 3
    assert metrics.by_status == {"Ждёт выполнения": 1, "Выполняется": 2}
    assert metrics.by_stage == {"В работе": 2, "Без стадии": 1}
    assert metrics.by_group == {"Вне проектов": 2, "Поддержка": 1}
    assert metrics.overdue_open_count == 1
    assert metrics.closed_on_time_count == 1
    assert metrics.closed_overdue_count == 1
    assert metrics.without_deadline_count == 1
    assert metrics.avg_lead_time_seconds == 4 * 3600
    assert metrics.median_lead_time_seconds == 4 * 3600
    assert metrics.fastest_lead_time_seconds == 2 * 3600
    assert metrics.slowest_lead_time_seconds == 6 * 3600
    assert metrics.total_time_spent_seconds == 1800


def test_closed_per_day_covers_every_day_of_period(tz, now):
    period = periods.last_week(now)
    metrics = compute_task_metrics(
        closed_tasks=[_task(tz, task_id=1, closed="2026-08-05T14:00:00+03:00")],
        created_tasks=[],
        open_tasks=[],
        period=period,
    )
    assert len(metrics.closed_per_day) == 7
    assert metrics.closed_per_day[date(2026, 8, 5)] == 1
    assert metrics.closed_per_day[date(2026, 8, 6)] == 0


def test_task_metrics_on_empty_data(tz, now):
    metrics = compute_task_metrics(
        closed_tasks=[], created_tasks=[], open_tasks=[], period=periods.today(now)
    )
    assert metrics.closed_count == 0
    assert metrics.avg_lead_time_seconds is None
    assert metrics.by_status == {}


def _session(tz, **kwargs) -> Session:
    return Session.from_v2(session_payload(**kwargs), tz)


def test_openline_metrics_from_sessions(tz, now):
    period = periods.last_week(now)
    data = OpenLinesData(
        source=OpenLinesDataSource.STATS_V2,
        sessions=[
            _session(tz, session_id=1, wait_answer=30, wait_close=600, vote="like"),
            _session(tz, session_id=2, wait_answer=90, wait_close=1800, vote="dislike"),
            _session(
                tz,
                session_id=3,
                wait_answer=None,
                wait_close=None,
                vote="",
                status="answered",
                closed=None,
                source="telegrambot",
            ),
        ],
        line_names={3: "Поддержка"},
    )

    metrics = compute_openline_metrics(data, period)

    assert metrics.total_sessions == 3
    assert metrics.closed_sessions == 2
    assert metrics.open_sessions == 1
    assert metrics.avg_first_answer_seconds == 60
    assert metrics.avg_resolution_seconds == 1200
    assert metrics.likes == 1
    assert metrics.dislikes == 1
    assert metrics.positive_rate == 0.5
    assert metrics.by_source == {"Онлайн-чат на сайте": 2, "Telegram": 1}
    assert metrics.by_line == {"Поддержка": 3}
    assert sum(metrics.by_hour) == 3


def test_portal_aggregate_overrides_client_side_numbers(tz, now):
    data = OpenLinesData(
        source=OpenLinesDataSource.STATS_V2,
        sessions=[_session(tz, session_id=1, wait_answer=30, wait_close=600)],
        aggregate={
            "totalSessions": 340,
            "closedSessions": 318,
            "avgWaitAnswer": 42.7,
            "avgSessionDuration": 612.3,
            "likeCount": 210,
            "dislikeCount": 15,
            "positiveRate": 0.9333,
            "sessionsBySource": [{"source": "whatsapp", "count": 140}],
            "sessionsByHour": list(range(24)),
        },
    )

    metrics = compute_openline_metrics(data, periods.last_week(now))

    assert metrics.total_sessions == 340
    assert metrics.closed_sessions == 318
    assert metrics.avg_first_answer_seconds == 42.7
    assert metrics.avg_resolution_seconds == 612.3
    assert metrics.likes == 210
    assert metrics.by_source == {"WhatsApp": 140}
    assert metrics.by_hour[5] == 5


def test_approximate_source_is_flagged(tz, now):
    data = OpenLinesData(
        source=OpenLinesDataSource.CRM_ACTIVITIES, sessions=[], notes=["приблизительно"]
    )
    metrics = compute_openline_metrics(data, periods.today(now))
    assert metrics.is_approximate
    assert metrics.notes == ["приблизительно"]


def test_duration_is_human_readable():
    assert duration(None) == "—"
    assert duration(45) == "45 сек"
    assert duration(90) == "1 мин 30 сек"
    assert duration(3600) == "1 ч"
    assert duration(8100) == "2 ч 15 мин"
    assert duration(93600) == "1 д 2 ч"


def test_plural_forms():
    assert plural(1, "задача", "задачи", "задач") == "задача"
    assert plural(3, "задача", "задачи", "задач") == "задачи"
    assert plural(11, "задача", "задачи", "задач") == "задач"
    assert plural(22, "задача", "задачи", "задач") == "задачи"
    assert plural(25, "задача", "задачи", "задач") == "задач"
    assert plural(0, "задача", "задачи", "задач") == "задач"
