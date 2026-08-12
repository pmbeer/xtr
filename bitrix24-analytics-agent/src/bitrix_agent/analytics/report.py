from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime
from typing import Any, Optional

from bitrix_agent.analytics.openlines import OpenLinesAnalytics, OpenLinesReport
from bitrix_agent.analytics.tasks import TasksAnalytics, TasksReport
from bitrix_agent.client import BitrixClient
from bitrix_agent.storage import AnalyticsStore


@dataclass
class ActivityReport:
    generated_at: str
    user_id: int
    user_name: str
    days: int
    tasks: dict[str, Any]
    openlines: dict[str, Any]
    summary: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    def to_text(self) -> str:
        t = self.tasks
        o = self.openlines
        lines = [
            f"Отчёт активности Bitrix24 — {self.user_name} (ID {self.user_id})",
            f"Сформирован: {self.generated_at}",
            f"Период: последние {self.days} дн.",
            "",
            "=== Задачи ===",
            f"Закрыто за период: {t.get('closed_count', 0)}",
            f"В работе: {t.get('in_progress_count', 0)}",
            f"Ожидают: {t.get('waiting_count', 0)}",
            f"Отложены: {t.get('deferred_count', 0)}",
            f"Просрочены: {t.get('overdue_count', 0)}",
            f"Создано (назначено) за период: {t.get('created_count', 0)}",
            f"Среднее время закрытия: {t.get('avg_close_hours')} ч"
            if t.get("avg_close_hours") is not None
            else "Среднее время закрытия: н/д",
        ]
        if t.get("by_status"):
            lines.append("По статусам:")
            for name, count in t["by_status"].items():
                lines.append(f"  • {name}: {count}")
        if t.get("by_stage"):
            lines.append("По стадиям:")
            for name, count in t["by_stage"].items():
                lines.append(f"  • {name}: {count}")

        lines.extend(
            [
                "",
                "=== Открытые линии ===",
                f"Источник данных: {o.get('source')}",
                f"Обработано обращений: {o.get('processed_count', 0)}",
                f"Закрыто: {o.get('closed_count', 0)}",
                f"Открыто сейчас: {o.get('open_count', 0)}",
                f"Спам: {o.get('spam_count', 0)}",
                f"Среднее время решения: {o.get('avg_resolution_human') or 'н/д'}",
                f"Среднее ожидание ответа: {o.get('avg_wait_answer_sec')} сек"
                if o.get("avg_wait_answer_sec") is not None
                else "Среднее ожидание ответа: н/д",
            ]
        )
        for note in o.get("notes") or []:
            lines.append(f"  ℹ {note}")

        lines.extend(
            [
                "",
                "=== Сводка ===",
                f"Закрытых задач: {self.summary.get('closed_tasks')}",
                f"Активных задач: {self.summary.get('active_tasks')}",
                f"Обращений ОЛ: {self.summary.get('openline_sessions')}",
                f"Среднее решение ОЛ: {self.summary.get('avg_resolution_human') or 'н/д'}",
            ]
        )
        return "\n".join(lines)


def build_activity_report(
    client: BitrixClient,
    *,
    user_id: Optional[int] = None,
    days: int = 7,
    store: AnalyticsStore | None = None,
) -> ActivityReport:
    resolved_user_id = client.resolve_user_id(user_id)
    user = client.current_user()
    # If analyzing another user, try to fetch their profile.
    user_name = _format_user_name(user)
    if user_id and int(user.get("ID", 0)) != resolved_user_id:
        try:
            others = client.call("user.get", {"ID": resolved_user_id})
            if isinstance(others, list) and others:
                user_name = _format_user_name(others[0])
            elif isinstance(others, dict):
                user_name = _format_user_name(others)
        except Exception:
            user_name = f"User #{resolved_user_id}"

    tasks_report: TasksReport = TasksAnalytics(client).build_report(
        resolved_user_id, days=days
    )
    openlines_report: OpenLinesReport = OpenLinesAnalytics(client, store).build_report(
        resolved_user_id, days=days
    )

    summary = {
        "closed_tasks": tasks_report.closed_count,
        "active_tasks": (
            tasks_report.in_progress_count
            + tasks_report.waiting_count
            + tasks_report.deferred_count
        ),
        "openline_sessions": openlines_report.processed_count,
        "avg_resolution_human": openlines_report.avg_resolution_human,
        "overdue_tasks": tasks_report.overdue_count,
    }

    return ActivityReport(
        generated_at=datetime.now().astimezone().replace(microsecond=0).isoformat(),
        user_id=resolved_user_id,
        user_name=user_name,
        days=days,
        tasks=tasks_report.to_dict(),
        openlines=openlines_report.to_dict(),
        summary=summary,
    )


def _format_user_name(user: dict[str, Any]) -> str:
    parts = [
        str(user.get("NAME") or user.get("name") or "").strip(),
        str(user.get("LAST_NAME") or user.get("lastName") or "").strip(),
    ]
    name = " ".join(p for p in parts if p)
    return name or f"User #{user.get('ID') or user.get('id') or '?'}"
