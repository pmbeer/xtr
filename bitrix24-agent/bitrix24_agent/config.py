"""Конфигурация агента: чтение .env и переменных окружения."""

from __future__ import annotations

import os
import re
from collections.abc import Mapping, MutableMapping
from dataclasses import dataclass, field
from pathlib import Path

from .errors import ConfigError

WEBHOOK_RE = re.compile(r"^https://[^/]+/rest/\d+/[A-Za-z0-9]+/?$")

DEFAULT_TIMEZONE = "Europe/Moscow"
DEFAULT_RATE_LIMIT = 2.0
DEFAULT_TIMEOUT = 30.0
DEFAULT_MAX_RETRIES = 4
DEFAULT_MAX_TASKS = 2000
DEFAULT_MAX_SESSIONS = 2000


def load_dotenv(path: Path) -> dict[str, str]:
    """Разбирает .env: `KEY=value`, `export KEY=value`, `#` — комментарий."""
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].strip()
        key, sep, value = line.partition("=")
        if not sep:
            continue
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        if key:
            values[key] = value
    return values


def _as_float(source: Mapping[str, str], key: str, default: float) -> float:
    raw = source.get(key, "").strip()
    if not raw:
        return default
    try:
        return float(raw)
    except ValueError as exc:
        raise ConfigError(f"{key}: ожидается число, получено {raw!r}") from exc


def _as_int(source: Mapping[str, str], key: str, default: int) -> int:
    return int(_as_float(source, key, float(default)))


def _as_optional_int(source: Mapping[str, str], key: str) -> int | None:
    raw = source.get(key, "").strip()
    if not raw:
        return None
    try:
        return int(raw)
    except ValueError as exc:
        raise ConfigError(f"{key}: ожидается целое число, получено {raw!r}") from exc


@dataclass
class Config:
    """Настройки подключения к порталу и поведения агента."""

    webhook_url: str
    user_id: int | None = None
    timezone: str = DEFAULT_TIMEZONE
    rate_limit: float = DEFAULT_RATE_LIMIT
    timeout: float = DEFAULT_TIMEOUT
    max_retries: int = DEFAULT_MAX_RETRIES
    max_tasks: int = DEFAULT_MAX_TASKS
    max_sessions: int = DEFAULT_MAX_SESSIONS
    storage_path: Path | None = None
    llm_base_url: str = ""
    llm_api_key: str = ""
    llm_model: str = ""
    extra: MutableMapping[str, str] = field(default_factory=dict, repr=False)

    @property
    def portal(self) -> str:
        """Домен портала, например `mycompany.bitrix24.ru`."""
        without_scheme = self.webhook_url.split("://", 1)[-1]
        return without_scheme.split("/", 1)[0]

    @property
    def llm_enabled(self) -> bool:
        return bool(self.llm_base_url and self.llm_api_key and self.llm_model)

    @classmethod
    def from_env(
        cls,
        env: Mapping[str, str] | None = None,
        dotenv_path: Path | None = None,
    ) -> Config:
        """Собирает конфиг: переменные окружения имеют приоритет над .env."""
        env = os.environ if env is None else env
        merged: dict[str, str] = {}
        if dotenv_path is not None:
            merged.update(load_dotenv(dotenv_path))
        merged.update({k: v for k, v in env.items() if k.startswith("B24_")})

        webhook = merged.get("B24_WEBHOOK_URL", "").strip()
        if not webhook:
            raise ConfigError(
                "Не задан B24_WEBHOOK_URL. Создайте входящий вебхук в Битрикс24 "
                "(Разработчикам → Другое → Входящий вебхук) и укажите его адрес "
                "в .env или переменной окружения."
            )
        webhook = webhook.rstrip("/")
        if not WEBHOOK_RE.match(webhook + "/"):
            raise ConfigError(
                "B24_WEBHOOK_URL должен иметь вид "
                "https://portal.bitrix24.ru/rest/<id пользователя>/<код вебхука>/, "
                f"получено: {webhook!r}"
            )

        storage_raw = merged.get("B24_STORAGE_PATH", "").strip()
        return cls(
            webhook_url=webhook,
            user_id=_as_optional_int(merged, "B24_USER_ID"),
            timezone=merged.get("B24_TIMEZONE", "").strip() or DEFAULT_TIMEZONE,
            rate_limit=_as_float(merged, "B24_RATE_LIMIT", DEFAULT_RATE_LIMIT),
            timeout=_as_float(merged, "B24_TIMEOUT", DEFAULT_TIMEOUT),
            max_retries=_as_int(merged, "B24_MAX_RETRIES", DEFAULT_MAX_RETRIES),
            max_tasks=_as_int(merged, "B24_MAX_TASKS", DEFAULT_MAX_TASKS),
            max_sessions=_as_int(merged, "B24_MAX_SESSIONS", DEFAULT_MAX_SESSIONS),
            storage_path=Path(storage_raw).expanduser() if storage_raw else None,
            llm_base_url=merged.get("B24_LLM_BASE_URL", "").strip().rstrip("/"),
            llm_api_key=merged.get("B24_LLM_API_KEY", "").strip(),
            llm_model=merged.get("B24_LLM_MODEL", "").strip(),
            extra=merged,
        )
