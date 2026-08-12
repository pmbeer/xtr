"""Тесты отчёта, конфигурации и хранилища снимков."""

from __future__ import annotations

import json
import tempfile
import unittest
from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from bitrix24_agent.agent import Bitrix24Agent, Report
from bitrix24_agent.collectors import User
from bitrix24_agent.collectors.tasks import StageBucket, TasksSection
from bitrix24_agent.config import Config
from bitrix24_agent.errors import ConfigError
from bitrix24_agent.metrics import summarize
from bitrix24_agent.period import parse_period
from bitrix24_agent.report import render
from bitrix24_agent.storage import SnapshotStore

from .fakes import FakePortal
from .test_collectors import CLOSED_TASKS, OPEN_TASKS, SESSIONS, STAGES

TZ = ZoneInfo("Europe/Moscow")
TODAY = date(2026, 6, 17)
PERIOD = parse_period("2026-06-01..2026-06-30", TZ, today=TODAY)
WEBHOOK = "https://demo.bitrix24.ru/rest/1/abcdef123456"


def make_report(*, with_previous: bool = False) -> Report:
    tasks = TasksSection(
        closed_count=42,
        closed_analyzed=42,
        closed_late=3,
        created_count=15,
        resolution=summarize([86400, 172800, 259200]),
        open_count=23,
        in_progress_count=12,
        open_by_status={"Выполняется": 12, "Ждёт выполнения": 11},
        open_overdue=4,
        stages=[StageBucket(stage_id=10, title="В работе", count=12, scope="Мой план")],
    )
    report = Report(
        portal="demo.bitrix24.ru",
        user=User(id=1, name="Иванов Иван", position="Менеджер"),
        period=PERIOD,
        generated_at=datetime(2026, 6, 17, 13, 0, tzinfo=TZ),
        tasks=tasks,
        api_calls=14,
        elapsed_seconds=6.2,
    )
    if with_previous:
        report.previous = Report(
            portal=report.portal,
            user=report.user,
            period=PERIOD.previous(),
            generated_at=report.generated_at,
            tasks=TasksSection(closed_count=35, open_count=15),
        )
    return report


class RenderTests(unittest.TestCase):
    def test_text_report_contains_key_numbers(self) -> None:
        output = render(make_report(), "text")
        self.assertIn("ЗАДАЧИ", output)
        self.assertIn("Закрыто за период", output)
        self.assertIn("42", output)
        self.assertIn("Иванов Иван", output)
        self.assertIn("2 д", output)  # медиана времени решения

    def test_comparison_marks_growth_as_good_or_bad_by_metric(self) -> None:
        output = render(make_report(with_previous=True), "text")
        closed_line = next(line for line in output.splitlines() if "Закрыто за период" in line)
        open_line = next(line for line in output.splitlines() if "Сейчас не закрыто" in line)

        self.assertIn("▲", closed_line)  # закрывать больше — хорошо
        self.assertNotIn("⚠", closed_line)
        self.assertIn("⚠", open_line)  # рост незакрытых задач — тревожный знак

    def test_markdown_report_is_a_valid_table(self) -> None:
        output = render(make_report(), "markdown")
        self.assertIn("# Отчёт по работе в Битрикс24", output)
        self.assertIn("| Показатель | Значение | Комментарий |", output)
        self.assertIn("## Задачи", output)

    def test_json_report_is_machine_readable(self) -> None:
        payload = json.loads(render(make_report(with_previous=True), "json"))
        self.assertEqual(payload["sections"]["tasks"]["closed_count"], 42)
        self.assertEqual(payload["user"]["name"], "Иванов Иван")
        self.assertEqual(payload["previous"]["sections"]["tasks"]["closed_count"], 35)
        self.assertIn("start", payload["period"])

    def test_unknown_format_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            render(make_report(), "pdf")


class AgentTests(unittest.TestCase):
    def _config(self) -> Config:
        return Config.from_env(env={"B24_WEBHOOK_URL": WEBHOOK, "B24_TIMEZONE": "Europe/Moscow"})

    def test_full_report_is_built_from_portal_data(self) -> None:
        portal = FakePortal(tasks=CLOSED_TASKS + OPEN_TASKS, sessions=SESSIONS, stages=STAGES)
        agent = Bitrix24Agent(self._config(), transport=portal)

        report = agent.build_report(PERIOD, sections=("tasks", "openlines"))

        self.assertEqual(report.tasks.closed_count, 3)
        self.assertEqual(report.openlines.handled_count, 4)
        self.assertEqual(report.user.name, "Иванов Иван")
        self.assertGreater(report.api_calls, 0)

    def test_broken_section_does_not_break_the_report(self) -> None:
        portal = FakePortal(tasks=CLOSED_TASKS + OPEN_TASKS, stages=STAGES)
        agent = Bitrix24Agent(self._config(), transport=portal)

        report = agent.build_report(PERIOD, sections=("tasks", "crm"))

        self.assertEqual(report.tasks.closed_count, 3)
        self.assertFalse(report.crm.available)
        self.assertTrue(render(report, "text"))

    def test_compare_collects_previous_period(self) -> None:
        portal = FakePortal(tasks=CLOSED_TASKS + OPEN_TASKS, stages=STAGES)
        agent = Bitrix24Agent(self._config(), transport=portal)

        report = agent.build_report(PERIOD, sections=("tasks",), compare=True)

        self.assertIsNotNone(report.previous)
        self.assertEqual(report.previous.tasks.closed_count, 0)

    def test_diagnose_marks_missing_methods(self) -> None:
        portal = FakePortal()
        statuses = {
            probe["method"]: probe["status"]
            for probe in Bitrix24Agent(self._config(), transport=portal).diagnose()
        }
        self.assertEqual(statuses["user.current"], "ok")
        self.assertEqual(statuses["crm.deal.list"], "missing")


class ConfigTests(unittest.TestCase):
    def test_webhook_is_required(self) -> None:
        with self.assertRaises(ConfigError) as error:
            Config.from_env(env={})
        self.assertIn("B24_WEBHOOK_URL", str(error.exception))

    def test_malformed_webhook_is_rejected(self) -> None:
        with self.assertRaises(ConfigError):
            Config.from_env(env={"B24_WEBHOOK_URL": "https://demo.bitrix24.ru"})

    def test_portal_is_derived_from_webhook(self) -> None:
        config = Config.from_env(env={"B24_WEBHOOK_URL": WEBHOOK + "/"})
        self.assertEqual(config.portal, "demo.bitrix24.ru")
        self.assertFalse(config.webhook_url.endswith("/"))

    def test_environment_overrides_dotenv(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            env_file = Path(folder) / ".env"
            env_file.write_text(
                "# комментарий\n"
                f'B24_WEBHOOK_URL="{WEBHOOK}"\n'
                "export B24_TIMEZONE=Asia/Yekaterinburg\n"
                "B24_RATE_LIMIT=5\n",
                encoding="utf-8",
            )
            config = Config.from_env(env={"B24_TIMEZONE": "Europe/Moscow"}, dotenv_path=env_file)

        self.assertEqual(config.webhook_url, WEBHOOK)
        self.assertEqual(config.timezone, "Europe/Moscow")
        self.assertEqual(config.rate_limit, 5.0)

    def test_llm_is_disabled_without_full_settings(self) -> None:
        config = Config.from_env(env={"B24_WEBHOOK_URL": WEBHOOK, "B24_LLM_MODEL": "gpt-4o-mini"})
        self.assertFalse(config.llm_enabled)


class StorageTests(unittest.TestCase):
    def test_snapshots_are_saved_and_listed(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            store = SnapshotStore(Path(folder) / "history" / "snapshots.sqlite3")
            store.save(make_report())
            store.save(make_report())

            snapshots = store.history(portal="demo.bitrix24.ru")

            self.assertEqual(len(snapshots), 2)
            self.assertEqual(snapshots[0].metric("tasks", "closed_count"), 42)
            self.assertEqual(snapshots[0].period_key, PERIOD.key)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
