"""Оркестратор агента аналитики Bitrix24."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .bitrix_client import Bitrix24Client
from .config import Settings
from .openlines_analyzer import OpenLinesAnalytics, OpenLinesAnalyzer
from .report import export_json, render_report, save_json_report
from .tasks_analyzer import TaskAnalytics, TasksAnalyzer


@dataclass
class AnalyticsResult:
    user_id: int
    user_name: str | None
    tasks: TaskAnalytics
    openlines: OpenLinesAnalytics

    def to_dict(self) -> dict[str, Any]:
        return export_json(self.tasks, self.openlines, self.user_name)


class Bitrix24AnalyticsAgent:
    def __init__(self, settings: Settings):
        self.settings = settings
        self.client = Bitrix24Client(settings.bitrix24_webhook_url)

    def close(self) -> None:
        self.client.close()

    def __enter__(self) -> Bitrix24AnalyticsAgent:
        return self

    def __exit__(self, *args: object) -> None:
        self.close()

    def run(self) -> AnalyticsResult:
        date_from, date_to = self.settings.resolve_period()
        user_id = self.settings.bitrix24_user_id

        user_name = self._resolve_user_name(user_id)

        tasks_analyzer = TasksAnalyzer(self.client)
        openlines_analyzer = OpenLinesAnalyzer(self.client)

        tasks = tasks_analyzer.analyze(user_id, date_from, date_to)
        openlines = openlines_analyzer.analyze(user_id, date_from, date_to)

        return AnalyticsResult(
            user_id=user_id,
            user_name=user_name,
            tasks=tasks,
            openlines=openlines,
        )

    def _resolve_user_name(self, user_id: int) -> str | None:
        try:
            current = self.client.get_current_user()
            if int(current.get("ID", 0)) == user_id:
                parts = [current.get("NAME", ""), current.get("LAST_NAME", "")]
                return " ".join(p for p in parts if p).strip() or None

            users = self.client.call("user.get", {"ID": user_id})
            if users:
                user = users[0] if isinstance(users, list) else users
                parts = [user.get("NAME", ""), user.get("LAST_NAME", "")]
                return " ".join(p for p in parts if p).strip() or None
        except Exception:
            return None
        return None

    def print_report(self, result: AnalyticsResult | None = None) -> AnalyticsResult:
        result = result or self.run()
        render_report(result.tasks, result.openlines, result.user_name)
        return result

    def save_report(self, path: str, result: AnalyticsResult | None = None) -> AnalyticsResult:
        result = result or self.run()
        save_json_report(path, result.tasks, result.openlines, result.user_name)
        return result
