"""Хранение снимков отчётов в SQLite — чтобы видеть динамику между запусками."""

from __future__ import annotations

import json
import sqlite3
from contextlib import closing
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from .agent import Report

SCHEMA = """
CREATE TABLE IF NOT EXISTS snapshots (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    portal        TEXT    NOT NULL,
    user_id       INTEGER NOT NULL,
    period_key    TEXT    NOT NULL,
    period_label  TEXT    NOT NULL,
    generated_at  TEXT    NOT NULL,
    payload       TEXT    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_snapshots_lookup
    ON snapshots (portal, user_id, period_key, generated_at);
"""


@dataclass(frozen=True)
class Snapshot:
    """Сохранённый отчёт."""

    id: int
    portal: str
    user_id: int
    period_key: str
    period_label: str
    generated_at: datetime
    payload: dict[str, Any]

    def metric(self, section: str, name: str) -> Any:
        return (self.payload.get("sections", {}).get(section) or {}).get(name)


class SnapshotStore:
    """Небольшой журнал отчётов: пишется по `--save`, читается командой `history`."""

    def __init__(self, path: Path):
        self.path = Path(path).expanduser()
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with closing(self._connect()) as connection:
            connection.executescript(SCHEMA)
            connection.commit()

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path)
        connection.row_factory = sqlite3.Row
        return connection

    def save(self, report: Report) -> int:
        payload = report.to_dict(include_previous=False)
        with closing(self._connect()) as connection:
            cursor = connection.execute(
                "INSERT INTO snapshots (portal, user_id, period_key, period_label, "
                "generated_at, payload) VALUES (?, ?, ?, ?, ?, ?)",
                (
                    report.portal,
                    report.user.id,
                    report.period.key,
                    report.period.label,
                    report.generated_at.isoformat(),
                    json.dumps(payload, ensure_ascii=False),
                ),
            )
            connection.commit()
            return int(cursor.lastrowid or 0)

    def history(
        self,
        *,
        portal: str | None = None,
        user_id: int | None = None,
        limit: int = 20,
    ) -> list[Snapshot]:
        query = "SELECT * FROM snapshots"
        conditions: list[str] = []
        params: list[Any] = []
        if portal:
            conditions.append("portal = ?")
            params.append(portal)
        if user_id is not None:
            conditions.append("user_id = ?")
            params.append(user_id)
        if conditions:
            query += " WHERE " + " AND ".join(conditions)
        query += " ORDER BY generated_at DESC LIMIT ?"
        params.append(limit)

        with closing(self._connect()) as connection:
            rows = connection.execute(query, params).fetchall()
        return [_row_to_snapshot(row) for row in rows]


def _row_to_snapshot(row: sqlite3.Row) -> Snapshot:
    return Snapshot(
        id=int(row["id"]),
        portal=str(row["portal"]),
        user_id=int(row["user_id"]),
        period_key=str(row["period_key"]),
        period_label=str(row["period_label"]),
        generated_at=datetime.fromisoformat(str(row["generated_at"])),
        payload=json.loads(row["payload"]),
    )
