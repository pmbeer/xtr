"""Пользователи портала: владелец вебхука и имена сотрудников."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

from b24agent.bitrix.client import Bitrix24Client
from b24agent.bitrix.errors import Bitrix24Error
from b24agent.bitrix.parsing import as_int, as_str, pick

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class PortalUser:
    id: int
    name: str
    position: str = ""
    email: str = ""

    @classmethod
    def from_api(cls, raw: dict[str, Any]) -> PortalUser:
        parts = [
            as_str(pick(raw, "LAST_NAME", "lastName")),
            as_str(pick(raw, "NAME", "name")),
            as_str(pick(raw, "SECOND_NAME", "secondName")),
        ]
        full_name = " ".join(part for part in parts if part)
        user_id = as_int(pick(raw, "ID", "id"))
        return cls(
            id=user_id,
            name=full_name or as_str(pick(raw, "EMAIL", "email")) or f"ID {user_id}",
            position=as_str(pick(raw, "WORK_POSITION", "workPosition")),
            email=as_str(pick(raw, "EMAIL", "email")),
        )


class UsersRepository:
    def __init__(self, client: Bitrix24Client) -> None:
        self._client = client
        self._cache: dict[int, PortalUser] = {}

    async def current(self) -> PortalUser:
        """Владелец вебхука — пользователь, от имени которого идут запросы."""
        raw = await self._client.call("profile")
        return PortalUser.from_api(raw or {})

    async def get(self, user_id: int) -> PortalUser:
        if user_id in self._cache:
            return self._cache[user_id]
        try:
            result = await self._client.call("user.get", {"ID": user_id})
        except Bitrix24Error as exc:
            logger.info("Не удалось получить пользователя %s: %s", user_id, exc)
            return PortalUser(id=user_id, name=f"ID {user_id}")

        items = result if isinstance(result, list) else [result]
        if not items or not items[0]:
            return PortalUser(id=user_id, name=f"ID {user_id}")
        user = PortalUser.from_api(items[0])
        self._cache[user.id] = user
        return user

    async def names(self, user_ids: set[int]) -> dict[int, str]:
        """Имена сразу для набора идентификаторов (один batch на 50 штук)."""
        missing = sorted(uid for uid in user_ids if uid and uid not in self._cache)
        if missing:
            commands = {str(uid): ("user.get", {"ID": uid}) for uid in missing}
            results, errors = await self._client.batch(commands)
            for key, value in results.items():
                items = value if isinstance(value, list) else [value]
                if items and items[0]:
                    user = PortalUser.from_api(items[0])
                    self._cache[user.id] = user
                else:
                    self._cache[int(key)] = PortalUser(id=int(key), name=f"ID {key}")
            for key in errors:
                self._cache.setdefault(int(key), PortalUser(id=int(key), name=f"ID {key}"))

        return {
            uid: self._cache.get(uid, PortalUser(id=uid, name=f"ID {uid}")).name
            for uid in user_ids
        }
