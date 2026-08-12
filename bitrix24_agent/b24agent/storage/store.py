"""SQLite-хранилище: привязка Telegram-пользователя к сотруднику Битрикс24.

Хранилище намеренно минимальное: бот работает от одного вебхука, поэтому
персонализировать нужно только «по кому считать отчёт» и формат файла.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

import aiosqlite

from b24agent.analytics.models import ReportFormat

logger = logging.getLogger(__name__)

SCHEMA = """
CREATE TABLE IF NOT EXISTS bot_users (
    telegram_id     INTEGER PRIMARY KEY,
    bitrix_user_id  INTEGER,
    report_format   TEXT NOT NULL DEFAULT 'xlsx',
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS report_log (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    telegram_id     INTEGER NOT NULL,
    query           TEXT,
    period_label    TEXT,
    filename        TEXT,
    created_at      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_report_log_user ON report_log (telegram_id, created_at);
"""


@dataclass(frozen=True, slots=True)
class UserSettings:
    telegram_id: int
    bitrix_user_id: int | None = None
    report_format: ReportFormat = ReportFormat.XLSX


class UserStore:
    def __init__(self, path: Path | str) -> None:
        self._path = Path(path)

    async def init(self) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        async with aiosqlite.connect(self._path) as db:
            await db.executescript(SCHEMA)
            await db.commit()

    async def get(self, telegram_id: int) -> UserSettings:
        async with aiosqlite.connect(self._path) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute(
                "SELECT telegram_id, bitrix_user_id, report_format "
                "FROM bot_users WHERE telegram_id = ?",
                (telegram_id,),
            )
            row = await cursor.fetchone()

        if row is None:
            return UserSettings(telegram_id=telegram_id)
        return UserSettings(
            telegram_id=row["telegram_id"],
            bitrix_user_id=row["bitrix_user_id"],
            report_format=_safe_format(row["report_format"]),
        )

    async def set_bitrix_user(self, telegram_id: int, bitrix_user_id: int | None) -> None:
        await self._upsert(telegram_id, {"bitrix_user_id": bitrix_user_id})

    async def set_format(self, telegram_id: int, report_format: ReportFormat) -> None:
        await self._upsert(telegram_id, {"report_format": report_format.value})

    async def log_report(
        self,
        telegram_id: int,
        *,
        query: str,
        period_label: str,
        filename: str,
    ) -> None:
        async with aiosqlite.connect(self._path) as db:
            await db.execute(
                "INSERT INTO report_log (telegram_id, query, period_label, filename, created_at)"
                " VALUES (?, ?, ?, ?, ?)",
                (telegram_id, query, period_label, filename, _now()),
            )
            await db.commit()

    async def recent_reports(self, telegram_id: int, limit: int = 5) -> list[tuple[str, str]]:
        async with aiosqlite.connect(self._path) as db:
            cursor = await db.execute(
                "SELECT query, created_at FROM report_log WHERE telegram_id = ?"
                " ORDER BY id DESC LIMIT ?",
                (telegram_id, limit),
            )
            rows = await cursor.fetchall()
        return [(row[0] or "", row[1]) for row in rows]

    async def _upsert(self, telegram_id: int, values: dict[str, object]) -> None:
        now = _now()
        columns = ", ".join(values)
        placeholders = ", ".join("?" for _ in values)
        updates = ", ".join(f"{column} = excluded.{column}" for column in values)
        async with aiosqlite.connect(self._path) as db:
            await db.execute(
                f"INSERT INTO bot_users (telegram_id, {columns}, created_at, updated_at)"
                f" VALUES (?, {placeholders}, ?, ?)"
                f" ON CONFLICT(telegram_id) DO UPDATE SET {updates}, updated_at = excluded.updated_at",
                (telegram_id, *values.values(), now, now),
            )
            await db.commit()


def _safe_format(value: str | None) -> ReportFormat:
    try:
        return ReportFormat(str(value or "xlsx"))
    except ValueError:
        return ReportFormat.XLSX


def _now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds")
