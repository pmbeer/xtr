"""Команды настройки и справки."""

from __future__ import annotations

import logging

from aiogram import Router
from aiogram.filters import Command, CommandObject, CommandStart
from aiogram.types import Message

from b24agent.analytics.models import ReportFormat
from b24agent.analytics.service import AnalyticsService
from b24agent.bot import texts
from b24agent.bot.keyboards import main_keyboard
from b24agent.storage import UserStore

logger = logging.getLogger(__name__)


def build_router() -> Router:
    """Создаёт новый роутер: экземпляр Router можно подключить лишь однажды."""
    router = Router(name="common")
    router.message.register(handle_start, CommandStart())
    router.message.register(handle_help, Command("help"))
    router.message.register(handle_id, Command("id"))
    router.message.register(handle_link, Command("link"))
    router.message.register(handle_whoami, Command("whoami"))
    router.message.register(handle_format, Command("format"))
    router.message.register(handle_history, Command("history"))
    return router


async def handle_start(message: Message) -> None:
    await message.answer(texts.START, reply_markup=main_keyboard())


async def handle_help(message: Message) -> None:
    await message.answer(texts.HELP, reply_markup=main_keyboard())


async def handle_id(message: Message) -> None:
    await message.answer(
        f"Ваш Telegram ID: <code>{message.from_user.id if message.from_user else '?'}</code>"
    )


async def handle_link(
    message: Message,
    command: CommandObject,
    store: UserStore,
    service: AnalyticsService,
) -> None:
    """Привязывает чат к сотруднику Битрикс24, по которому считать отчёты."""
    if message.from_user is None:
        return

    argument = (command.args or "").strip()
    if not argument:
        await message.answer(
            "Укажите ID сотрудника Битрикс24: <code>/link 42</code>\n"
            "Сбросить привязку — <code>/link 0</code>"
        )
        return
    if not argument.lstrip("-").isdigit():
        await message.answer("ID сотрудника — это число, например <code>/link 42</code>")
        return

    bitrix_user_id = int(argument)
    if bitrix_user_id <= 0:
        await store.set_bitrix_user(message.from_user.id, None)
        user = await service.resolve_user(None)
        await message.answer(
            f"Привязка сброшена. Отчёты снова считаются по «{user.name}» (ID {user.id})."
        )
        return

    user = await service.users.get(bitrix_user_id)
    await store.set_bitrix_user(message.from_user.id, bitrix_user_id)
    await message.answer(
        f"Готово. Отчёты будут считаться по сотруднику <b>{user.name}</b> (ID {user.id})."
    )


async def handle_whoami(
    message: Message, store: UserStore, service: AnalyticsService
) -> None:
    if message.from_user is None:
        return
    settings = await store.get(message.from_user.id)
    user = await service.resolve_user(settings.bitrix_user_id)
    source = "задан командой /link" if settings.bitrix_user_id else "взят из настроек бота"
    await message.answer(
        f"Отчёты считаются по сотруднику <b>{user.name}</b> (ID {user.id}, {source}).\n"
        f"Формат файла по умолчанию: <b>{settings.report_format.value.upper()}</b>"
    )


async def handle_format(
    message: Message, command: CommandObject, store: UserStore
) -> None:
    if message.from_user is None:
        return
    argument = (command.args or "").strip().lower()
    try:
        report_format = ReportFormat(argument)
    except ValueError:
        await message.answer(
            "Доступные форматы: <code>/format xlsx</code>, "
            "<code>/format csv</code>, <code>/format json</code>"
        )
        return

    await store.set_format(message.from_user.id, report_format)
    await message.answer(
        f"Формат по умолчанию: <b>{report_format.value.upper()}</b>. "
        "Для одного отчёта формат можно указать прямо в запросе."
    )


async def handle_history(message: Message, store: UserStore) -> None:
    if message.from_user is None:
        return
    rows = await store.recent_reports(message.from_user.id)
    if not rows:
        await message.answer("Вы ещё не запрашивали отчёты.")
        return
    lines = ["<b>Последние запросы</b>"]
    lines.extend(
        f"• {query or 'без текста'} — {created_at[:16]}" for query, created_at in rows
    )
    await message.answer("\n".join(lines))
