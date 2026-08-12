"""Определение пользователя, от имени которого считается статистика."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any

from ..client import Bitrix24Client
from ..errors import AgentError
from ..normalize import iter_records, parse_int, pick


@dataclass(frozen=True)
class User:
    """Сотрудник портала."""

    id: int
    name: str
    position: str = ""
    email: str = ""

    def to_dict(self) -> dict:
        return {"id": self.id, "name": self.name, "position": self.position, "email": self.email}


def _build_user(record: Mapping[str, Any]) -> User | None:
    user_id = parse_int(pick(record, "ID"))
    if user_id is None:
        return None
    parts = [
        str(pick(record, "LAST_NAME", default="") or ""),
        str(pick(record, "NAME", default="") or ""),
        str(pick(record, "SECOND_NAME", default="") or ""),
    ]
    full_name = " ".join(part for part in parts if part).strip()
    return User(
        id=user_id,
        name=full_name or str(pick(record, "EMAIL", default="") or f"Пользователь #{user_id}"),
        position=str(pick(record, "WORK_POSITION", default="") or ""),
        email=str(pick(record, "EMAIL", default="") or ""),
    )


def resolve_user(client: Bitrix24Client, user_id: int | None = None) -> User:
    """Возвращает владельца отчёта.

    Без явного `user_id` берётся владелец вебхука — `user.current`.
    """
    if user_id is None:
        record = client.call("user.current")
        if not isinstance(record, Mapping):
            raise AgentError(
                "Не удалось определить пользователя вебхука: user.current вернул пустой ответ"
            )
        user = _build_user(record)
        if user is None:
            raise AgentError("user.current вернул запись без идентификатора")
        return user

    records = list(iter_records(client.call("user.get", {"ID": user_id})))
    for record in records:
        user = _build_user(record)
        if user is not None and user.id == user_id:
            return user
    raise AgentError(f"Пользователь #{user_id} не найден или недоступен вебхуку")


def resolve_user_names(client: Bitrix24Client, user_ids: list[int]) -> dict[int, str]:
    """Имена сотрудников по идентификаторам; недоступные заменяются заглушкой."""
    unique_ids = sorted({user_id for user_id in user_ids if user_id})
    names: dict[int, str] = {}
    if not unique_ids:
        return names
    records = client.try_call("user.get", {"FILTER": {"ID": unique_ids}, "ADMIN_MODE": "N"})
    for record in iter_records(records):
        user = _build_user(record)
        if user is not None:
            names[user.id] = user.name
    for user_id in unique_ids:
        names.setdefault(user_id, f"Сотрудник #{user_id}")
    return names
