"""Сквозные проверки телеграм-слоя на поддельной сессии Bot API."""

from __future__ import annotations

from collections.abc import AsyncGenerator
from datetime import UTC, datetime
from typing import Any

import httpx
import pytest
from aiogram import Bot
from aiogram.client.default import DefaultBotProperties
from aiogram.client.session.base import BaseSession
from aiogram.enums import ParseMode
from aiogram.methods import EditMessageText, SendDocument, SendMessage, TelegramMethod
from aiogram.types import Chat, Message, Update, User

from b24agent.analytics.service import AnalyticsService
from b24agent.bitrix.client import Bitrix24Client
from b24agent.bot.app import build_dispatcher
from b24agent.config import Settings
from b24agent.storage import UserStore
from tests.fake_portal import WEBHOOK
from tests.test_service import portal_with_tasks_and_lines

CHAT_ID = 555
BOT_ID = 424242


class FakeSession(BaseSession):
    """Ловит вызовы Bot API вместо реальных запросов в Telegram."""

    def __init__(self) -> None:
        super().__init__()
        self.requests: list[TelegramMethod[Any]] = []
        self._message_id = 100

    async def close(self) -> None:
        return None

    async def make_request(
        self, bot: Bot, method: TelegramMethod[Any], timeout: int | None = None
    ) -> Any:
        self.requests.append(method)
        if isinstance(method, (SendMessage, EditMessageText, SendDocument)):
            self._message_id += 1
            response = Message(
                message_id=self._message_id,
                date=datetime.now(UTC),
                chat=Chat(id=CHAT_ID, type="private"),
                from_user=User(id=BOT_ID, is_bot=True, first_name="Bot"),
                text=getattr(method, "text", None) or getattr(method, "caption", None),
            )
            # Настоящая сессия привязывает ответ к боту — иначе у объекта
            # Message не работают методы вида edit_text().
            return response.as_(bot)
        return True

    async def stream_content(self, *args: Any, **kwargs: Any) -> AsyncGenerator[bytes, None]:
        yield b""

    def sent(self, method_type: type) -> list[Any]:
        return [method for method in self.requests if isinstance(method, method_type)]


def make_message(text: str, user_id: int = CHAT_ID) -> Message:
    return Message(
        message_id=1,
        date=datetime.now(UTC),
        chat=Chat(id=CHAT_ID, type="private"),
        from_user=User(id=user_id, is_bot=False, first_name="Иван"),
        text=text,
    )


@pytest.fixture
def settings(tmp_path) -> Settings:
    return Settings(  # type: ignore[call-arg]
        _env_file=None,
        telegram_bot_token="123456:AAtoken-value",
        bitrix_webhook_url="https://example.bitrix24.ru/rest/1/testtoken/",
        database_path=tmp_path / "bot.sqlite3",
        reports_dir=tmp_path / "reports",
        telegram_allowed_user_ids=str(CHAT_ID),
    )


@pytest.fixture
async def bot() -> AsyncGenerator[Bot, None]:
    session = FakeSession()
    instance = Bot(
        token=f"{BOT_ID}:AAtoken-value",
        session=session,
        default=DefaultBotProperties(parse_mode=ParseMode.HTML),
    )
    yield instance
    await instance.session.close()


async def feed(dispatcher, bot: Bot, text: str, user_id: int = CHAT_ID) -> None:
    await dispatcher.feed_update(bot, Update(update_id=1, message=make_message(text, user_id)))


async def build(settings: Settings, tz, client: Bitrix24Client | None = None):
    client = client or portal_with_tasks_and_lines().client()
    store = UserStore(settings.database_path)
    await store.init()
    service = AnalyticsService(client, tz=tz, portal_url=settings.portal_url)
    return build_dispatcher(settings, service, store), client, store


async def test_start_answers_with_keyboard(settings, bot, tz):
    dispatcher, client, _ = await build(settings, tz)
    try:
        await feed(dispatcher, bot, "/start")
    finally:
        await client.aclose()

    messages = bot.session.sent(SendMessage)
    assert len(messages) == 1
    assert "Привет" in messages[0].text
    assert messages[0].reply_markup is not None


async def test_free_text_query_returns_document(settings, bot, tz):
    dispatcher, client, store = await build(settings, tz)
    try:
        await feed(dispatcher, bot, "сколько задач я закрыл за прошлую неделю")
    finally:
        await client.aclose()

    documents = bot.session.sent(SendDocument)
    assert len(documents) == 1
    assert documents[0].document.filename.endswith(".xlsx")

    edits = bot.session.sent(EditMessageText)
    assert edits, "сводка должна заменить сообщение о сборке"
    assert "закрыто: <b>2</b>" in edits[-1].text

    history = await store.recent_reports(CHAT_ID)
    assert history[0][0] == "сколько задач я закрыл за прошлую неделю"


async def test_csv_request_changes_file_extension(settings, bot, tz):
    dispatcher, client, _ = await build(settings, tz)
    try:
        await feed(dispatcher, bot, "обращения в открытой линии за прошлую неделю в csv")
    finally:
        await client.aclose()

    documents = bot.session.sent(SendDocument)
    assert documents[0].document.filename.endswith(".csv")


async def test_link_command_binds_employee(settings, bot, tz):
    dispatcher, client, store = await build(settings, tz)
    try:
        await feed(dispatcher, bot, "/link 42")
    finally:
        await client.aclose()

    assert (await store.get(CHAT_ID)).bitrix_user_id == 42
    assert "42" in bot.session.sent(SendMessage)[0].text


async def test_format_command_persists_choice(settings, bot, tz):
    dispatcher, client, store = await build(settings, tz)
    try:
        await feed(dispatcher, bot, "/format json")
    finally:
        await client.aclose()

    assert (await store.get(CHAT_ID)).report_format.value == "json"


async def test_stranger_gets_access_denied(settings, bot, tz):
    dispatcher, client, _ = await build(settings, tz)
    try:
        await feed(dispatcher, bot, "отчёт за месяц", user_id=999)
    finally:
        await client.aclose()

    messages = bot.session.sent(SendMessage)
    assert len(messages) == 1
    assert "Доступ" in messages[0].text
    assert not bot.session.sent(SendDocument)


async def test_portal_failure_is_reported_to_user(settings, bot, tz):
    def unreachable(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("портал недоступен", request=request)

    offline = Bitrix24Client(
        WEBHOOK,
        rate_limit=1000.0,
        max_retries=0,
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(unreachable)),
    )
    dispatcher, client, _ = await build(settings, tz, client=offline)
    try:
        await feed(dispatcher, bot, "задачи за месяц")
    finally:
        await client.aclose()

    edits = bot.session.sent(EditMessageText)
    assert edits and "Не удалось собрать отчёт" in edits[-1].text
    assert not bot.session.sent(SendDocument)
