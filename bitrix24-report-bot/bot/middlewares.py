"""Middleware для ограничения доступа к боту."""

from __future__ import annotations

import logging
from typing import Any, Awaitable, Callable

from aiogram import BaseMiddleware
from aiogram.types import TelegramObject, User

from .config import Config

logger = logging.getLogger(__name__)


class AccessControlMiddleware(BaseMiddleware):
    """Пропускает только пользователей из TELEGRAM_ALLOWED_USER_IDS (если задан)."""

    def __init__(self, config: Config) -> None:
        self._config = config

    async def __call__(
        self,
        handler: Callable[[TelegramObject, dict[str, Any]], Awaitable[Any]],
        event: TelegramObject,
        data: dict[str, Any],
    ) -> Any:
        user: User | None = data.get("event_from_user")
        if user is not None and not self._config.is_allowed(user.id):
            logger.warning("Отказано в доступе пользователю Telegram id=%s", user.id)
            message = getattr(event, "message", None) or (
                event if hasattr(event, "answer") else None
            )
            answerable = message if message is not None else event
            if hasattr(answerable, "answer"):
                await answerable.answer(
                    "⛔ У вас нет доступа к этому боту.\n"
                    "Обратитесь к администратору, чтобы добавить ваш Telegram ID "
                    f"({user.id}) в список разрешённых."
                )
            return None
        return await handler(event, data)
