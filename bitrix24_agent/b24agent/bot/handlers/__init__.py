"""Хендлеры бота."""

from aiogram import Router

from b24agent.bot.handlers import common, reports


def build_router() -> Router:
    """Собирает корневой роутер из свежих экземпляров дочерних роутеров."""
    router = Router(name="root")
    router.include_router(common.build_router())
    router.include_router(reports.build_router())
    return router


__all__ = ["build_router"]
