from __future__ import annotations

import json
import sqlite3
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator, Optional


SCHEMA = """
CREATE TABLE IF NOT EXISTS openline_sessions (
    session_id INTEGER PRIMARY KEY,
    chat_id INTEGER,
    config_id INTEGER,
    operator_id INTEGER,
    status TEXT,
    source TEXT,
    date_create TEXT,
    date_close TEXT,
    wait_answer_sec REAL,
    duration_sec REAL,
    vote INTEGER,
    spam INTEGER DEFAULT 0,
    raw_json TEXT,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS activity_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_name TEXT NOT NULL,
    entity_id TEXT,
    user_id INTEGER,
    payload_json TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_operator ON openline_sessions(operator_id);
CREATE INDEX IF NOT EXISTS idx_sessions_dates ON openline_sessions(date_create, date_close);
CREATE INDEX IF NOT EXISTS idx_events_name ON activity_events(event_name, created_at);
"""


@dataclass
class SessionRow:
    session_id: int
    chat_id: Optional[int]
    config_id: Optional[int]
    operator_id: Optional[int]
    status: Optional[str]
    source: Optional[str]
    date_create: Optional[str]
    date_close: Optional[str]
    wait_answer_sec: Optional[float]
    duration_sec: Optional[float]
    vote: Optional[int]
    spam: int = 0


class AnalyticsStore:
    def __init__(self, path: Path) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as conn:
            conn.executescript(SCHEMA)

    @contextmanager
    def _connect(self) -> Iterator[sqlite3.Connection]:
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        finally:
            conn.close()

    def upsert_session(self, session: dict[str, Any]) -> None:
        now = datetime.now(timezone.utc).isoformat()
        session_id = int(session["session_id"])
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO openline_sessions (
                    session_id, chat_id, config_id, operator_id, status, source,
                    date_create, date_close, wait_answer_sec, duration_sec,
                    vote, spam, raw_json, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(session_id) DO UPDATE SET
                    chat_id=excluded.chat_id,
                    config_id=excluded.config_id,
                    operator_id=excluded.operator_id,
                    status=excluded.status,
                    source=excluded.source,
                    date_create=COALESCE(excluded.date_create, openline_sessions.date_create),
                    date_close=COALESCE(excluded.date_close, openline_sessions.date_close),
                    wait_answer_sec=COALESCE(excluded.wait_answer_sec, openline_sessions.wait_answer_sec),
                    duration_sec=COALESCE(excluded.duration_sec, openline_sessions.duration_sec),
                    vote=COALESCE(excluded.vote, openline_sessions.vote),
                    spam=COALESCE(excluded.spam, openline_sessions.spam),
                    raw_json=excluded.raw_json,
                    updated_at=excluded.updated_at
                """,
                (
                    session_id,
                    session.get("chat_id"),
                    session.get("config_id"),
                    session.get("operator_id"),
                    session.get("status"),
                    session.get("source"),
                    session.get("date_create"),
                    session.get("date_close"),
                    session.get("wait_answer_sec"),
                    session.get("duration_sec"),
                    session.get("vote"),
                    int(session.get("spam") or 0),
                    json.dumps(session.get("raw") or session, ensure_ascii=False),
                    now,
                ),
            )

    def add_event(
        self,
        event_name: str,
        payload: dict[str, Any],
        *,
        entity_id: str | None = None,
        user_id: int | None = None,
    ) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO activity_events (event_name, entity_id, user_id, payload_json, created_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    event_name,
                    entity_id,
                    user_id,
                    json.dumps(payload, ensure_ascii=False),
                    datetime.now(timezone.utc).isoformat(),
                ),
            )

    def sessions_for_operator(
        self,
        operator_id: int,
        *,
        date_from: str | None = None,
        date_to: str | None = None,
    ) -> list[SessionRow]:
        clauses = ["operator_id = ?"]
        args: list[Any] = [operator_id]
        if date_from:
            clauses.append("COALESCE(date_close, date_create) >= ?")
            args.append(date_from)
        if date_to:
            clauses.append("COALESCE(date_create, date_close) <= ?")
            args.append(date_to)

        sql = f"SELECT * FROM openline_sessions WHERE {' AND '.join(clauses)} ORDER BY date_create DESC"
        with self._connect() as conn:
            rows = conn.execute(sql, args).fetchall()
        return [
            SessionRow(
                session_id=row["session_id"],
                chat_id=row["chat_id"],
                config_id=row["config_id"],
                operator_id=row["operator_id"],
                status=row["status"],
                source=row["source"],
                date_create=row["date_create"],
                date_close=row["date_close"],
                wait_answer_sec=row["wait_answer_sec"],
                duration_sec=row["duration_sec"],
                vote=row["vote"],
                spam=row["spam"] or 0,
            )
            for row in rows
        ]
