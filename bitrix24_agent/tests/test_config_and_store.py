from __future__ import annotations

import pytest
from pydantic import ValidationError

from b24agent.analytics.models import ReportFormat
from b24agent.config import Settings
from b24agent.storage import UserStore

BASE_ENV = {
    "telegram_bot_token": "123456:AAtoken-value",
    "bitrix_webhook_url": "https://portal.bitrix24.ru/rest/1/abc123token/",
}


def settings(**overrides) -> Settings:
    return Settings(_env_file=None, **{**BASE_ENV, **overrides})  # type: ignore[arg-type]


def test_webhook_url_keeps_base_and_adds_slash():
    assert (
        settings(bitrix_webhook_url="https://portal.bitrix24.ru/rest/1/abc123token").bitrix_webhook_url
        == "https://portal.bitrix24.ru/rest/1/abc123token/"
    )


def test_webhook_url_strips_pasted_method_name():
    assert (
        settings(
            bitrix_webhook_url="https://portal.bitrix24.ru/rest/1/abc123token/profile.json"
        ).bitrix_webhook_url
        == "https://portal.bitrix24.ru/rest/1/abc123token/"
    )


def test_invalid_webhook_url_is_rejected():
    with pytest.raises(ValidationError):
        settings(bitrix_webhook_url="https://portal.bitrix24.ru/")


def test_portal_url_is_extracted_for_task_links():
    assert settings().portal_url == "https://portal.bitrix24.ru"


@pytest.mark.parametrize(
    ("raw", "expected"),
    [("", set()), ("111", {111}), ("111, 222", {111, 222}), ("111;222 333", {111, 222, 333})],
)
def test_allowed_user_ids_parsing(raw, expected):
    assert set(settings(telegram_allowed_user_ids=raw).allowed_user_ids) == expected


def test_timezone_is_validated():
    with pytest.raises(ValidationError):
        settings(timezone="Mars/Olympus")


def test_report_format_is_validated():
    with pytest.raises(ValidationError):
        settings(default_report_format="pdf")


async def test_store_roundtrip(tmp_path):
    store = UserStore(tmp_path / "bot.sqlite3")
    await store.init()

    default = await store.get(555)
    assert default.bitrix_user_id is None
    assert default.report_format is ReportFormat.XLSX

    await store.set_bitrix_user(555, 42)
    await store.set_format(555, ReportFormat.CSV)
    saved = await store.get(555)
    assert saved.bitrix_user_id == 42
    assert saved.report_format is ReportFormat.CSV

    await store.set_bitrix_user(555, None)
    assert (await store.get(555)).bitrix_user_id is None
    assert (await store.get(555)).report_format is ReportFormat.CSV


async def test_store_logs_history(tmp_path):
    store = UserStore(tmp_path / "bot.sqlite3")
    await store.init()
    await store.log_report(1, query="задачи за месяц", period_label="август 2026", filename="a.xlsx")
    await store.log_report(1, query="обращения", period_label="август 2026", filename="b.xlsx")

    history = await store.recent_reports(1)
    assert [query for query, _ in history] == ["обращения", "задачи за месяц"]
