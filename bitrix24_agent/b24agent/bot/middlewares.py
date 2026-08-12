"""Middleware: контроль доступа и защита от параллельных запросов."""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Awaitable, Callable
from typing import Any

from aiogram import BaseMiddleware
from aiogram.types import Message, TelegramObject, User

from b24agent.bot import texts

logger = logging.getLogger(__name__)


class AccessMiddleware(BaseMiddleware):
    """Пропускает только разрешённых пользователей.

    Пустой список разрешённых id означает «без ограничений» — это удобно при
    первом запуске, когда свой Telegram ID ещё неизвестен, поэтому такой
    случай логируется предупреждением.
    """

    def __init__(self, allowed_user_ids: frozenset[int]) -> None:
        self._allowed = allowed_user_ids
        if not allowed_user_ids:
            logger.warning(
                "TELEGRAM_ALLOWED_USER_IDS не задан: отчёты сможет запросить любой, "
                "кто найдёт бота"
            )

    async def __call__(
        self,
        handler: Callable[[TelegramObject, dict[str, Any]], Awaitable[Any]],
        event: TelegramObject,
        data: dict[str, Any],
    ) -> Any:
        user: User | None = data.get("event_from_user")
        if not self._allowed or (user and user.id in self._allowed):
            return await handler(event, data)

        logger.info("Отказано в доступе telegram_id=%s", user.id if user else "?")
        if isinstance(event, Message):
            await event.answer(
                texts.ACCESS_DENIED.format(user_id=user.id if user else "?")
            )
        return None


class SingleFlightMiddleware(BaseMiddleware):
    """Не даёт одному пользователю запустить два отчёта одновременно.

    Отчёт — это десятки запросов к REST Битрикс24, и параллельные сборки
    быстро упираются в лимит частоты запросов портала.
    """

    def __init__(self) -> None:
        self._busy: set[int] = set()
        self._lock = asyncio.Lock()

    async def __call__(
        self,
        handler: Callable[[TelegramObject, dict[str, Any]], Awaitable[Any]],
        event: TelegramObject,
        data: dict[str, Any],
    ) -> Any:
        user: User | None = data.get("event_from_user")
        if user is None:
            return await handler(event, data)

        async with self._lock:
            if user.id in self._busy:
                if isinstance(event, Message):
                    await event.answer(texts.ALREADY_RUNNING)
                return None
            self._busy.add(user.id)

        try:
            return await handler(event, data)
        finally:
            async with self._lock:
                self._busy.discard(user.id)
