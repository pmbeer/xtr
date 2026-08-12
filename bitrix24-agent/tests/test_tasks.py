import unittest
from datetime import datetime, timezone

from b24agent.tasks import aggregate_tasks, completion_seconds, is_overdue

NOW = datetime(2026, 8, 12, 12, 0, tzinfo=timezone.utc)
FROM = datetime(2026, 7, 12, 0, 0, tzinfo=timezone.utc)


def task(**kwargs):
    base = {"id": "1", "title": "Задача", "status": "3"}
    base.update(kwargs)
    return base


class CompletionSecondsTest(unittest.TestCase):
    def test_basic(self):
        t = task(createdDate="2026-08-01T10:00:00+03:00", closedDate="2026-08-01T12:30:00+03:00")
        self.assertEqual(completion_seconds(t), 2.5 * 3600)

    def test_missing_dates(self):
        self.assertIsNone(completion_seconds(task()))

    def test_closed_before_created(self):
        t = task(createdDate="2026-08-02T10:00:00+03:00", closedDate="2026-08-01T10:00:00+03:00")
        self.assertIsNone(completion_seconds(t))


class OverdueTest(unittest.TestCase):
    def test_overdue(self):
        self.assertTrue(is_overdue(task(deadline="2026-08-01T10:00:00Z"), NOW))

    def test_not_overdue(self):
        self.assertFalse(is_overdue(task(deadline="2026-09-01T10:00:00Z"), NOW))

    def test_no_deadline(self):
        self.assertFalse(is_overdue(task(), NOW))


class AggregateTasksTest(unittest.TestCase):
    def test_full_report(self):
        closed = [
            task(id="1", status="5", createdDate="2026-08-01T10:00:00Z", closedDate="2026-08-01T12:00:00Z"),
            task(id="2", status="5", createdDate="2026-08-02T10:00:00Z", closedDate="2026-08-02T14:00:00Z"),
        ]
        open_tasks = [
            task(id="3", status="3", deadline="2026-08-01T00:00:00Z"),  # просрочена
            task(id="4", status="3", groupId="7", stageId="15"),
            task(id="5", status="2"),
            task(id="6", status="6"),
        ]
        report = aggregate_tasks(
            closed_tasks=closed,
            open_tasks=open_tasks,
            created_count=5,
            date_from=FROM,
            date_to=NOW,
            stage_names={"15": "В разработке"},
            now=NOW,
        )
        self.assertEqual(report.closed_count, 2)
        self.assertEqual(report.created_count, 5)
        self.assertEqual(report.open_count, 4)
        self.assertEqual(report.overdue_count, 1)
        self.assertEqual(report.avg_completion_seconds, 3 * 3600)
        self.assertEqual(report.median_completion_seconds, 3 * 3600)
        self.assertEqual(report.open_by_status, {"Выполняется": 2, "Ждёт выполнения": 1, "Отложена": 1})
        self.assertEqual(report.open_by_stage, {"В разработке": 1})

    def test_empty(self):
        report = aggregate_tasks([], [], 0, FROM, NOW, now=NOW)
        self.assertEqual(report.closed_count, 0)
        self.assertIsNone(report.avg_completion_seconds)
        self.assertEqual(report.open_by_status, {})


if __name__ == "__main__":
    unittest.main()
