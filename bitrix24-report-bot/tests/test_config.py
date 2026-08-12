from __future__ import annotations

from pathlib import Path

import pytest

from bot.config import ConfigError, _parse_int_list, _parse_user_map, load_config


def test_parse_int_list():
    assert _parse_int_list("123, 456;789") == [123, 456, 789]
    assert _parse_int_list("") == []
    assert _parse_int_list("abc, 42") == [42]


def test_parse_user_map():
    assert _parse_user_map('{"111": 5, "222": 6}') == {111: 5, 222: 6}
    assert _parse_user_map("") == {}
    assert _parse_user_map("not-json") == {}


def test_load_config_success(tmp_path: Path, monkeypatch):
    env_file = tmp_path / ".env"
    env_file.write_text(
        "\n".join(
            [
                "TELEGRAM_BOT_TOKEN=123:ABC",
                "TELEGRAM_ALLOWED_USER_IDS=111,222",
                "BITRIX_WEBHOOK_URL=https://example.bitrix24.ru/rest/1/abc",
                "BITRIX_DEFAULT_USER_ID=1",
                'TELEGRAM_TO_BITRIX_USER_MAP={"111": 5}',
                "BITRIX_TIMEZONE=Europe/Moscow",
                f"REPORTS_DIR={tmp_path / 'reports'}",
            ]
        )
    )
    for key in [
        "TELEGRAM_BOT_TOKEN",
        "TELEGRAM_ALLOWED_USER_IDS",
        "BITRIX_WEBHOOK_URL",
        "BITRIX_DEFAULT_USER_ID",
        "TELEGRAM_TO_BITRIX_USER_MAP",
        "BITRIX_TIMEZONE",
        "REPORTS_DIR",
    ]:
        monkeypatch.delenv(key, raising=False)

    config = load_config(env_file)

    assert config.telegram_bot_token == "123:ABC"
    assert config.telegram_allowed_user_ids == [111, 222]
    assert config.bitrix_webhook_url.endswith("/")
    assert config.bitrix_default_user_id == 1
    assert config.bitrix_user_id_for(111) == 5
    assert config.bitrix_user_id_for(999) == 1
    assert config.is_allowed(111) is True
    assert config.is_allowed(333) is False


def test_load_config_missing_token(tmp_path: Path, monkeypatch):
    env_file = tmp_path / ".env"
    env_file.write_text("BITRIX_WEBHOOK_URL=https://example.bitrix24.ru/rest/1/abc\n")
    monkeypatch.delenv("TELEGRAM_BOT_TOKEN", raising=False)

    with pytest.raises(ConfigError):
        load_config(env_file)
