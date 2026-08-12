"""Необязательный слой: вопросы к отчёту на естественном языке.

Работает с любым сервисом, совместимым с Chat Completions API. Без настроек
агент остаётся полностью рабочим — просто без команды `ask`.
"""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from collections.abc import Mapping
from typing import Any

from .config import Config
from .errors import AgentError, ConfigError

SYSTEM_PROMPT = (
    "Ты — аналитик, который помогает сотруднику разобраться в его работе в Битрикс24. "
    "Тебе дают JSON с показателями за период: задачи, обращения Открытых линий, CRM, звонки. "
    "Отвечай по-русски, коротко и по существу, опираясь только на переданные цифры. "
    "Все длительности в JSON — в секундах, переводи их в часы и дни. "
    "Если данных для ответа нет, прямо скажи об этом и не выдумывай значения."
)


def ask(config: Config, report_payload: Mapping[str, Any], question: str, *, timeout: float = 60.0) -> str:
    """Задаёт вопрос модели, передав ей отчёт как контекст."""
    if not config.llm_enabled:
        raise ConfigError(
            "Команда `ask` требует настройки модели: задайте B24_LLM_BASE_URL, "
            "B24_LLM_API_KEY и B24_LLM_MODEL в .env."
        )

    payload = {
        "model": config.llm_model,
        "temperature": 0.2,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    f"Показатели:\n```json\n"
                    f"{json.dumps(report_payload, ensure_ascii=False, indent=2)}\n```\n\n"
                    f"Вопрос: {question}"
                ),
            },
        ],
    }
    request = urllib.request.Request(
        f"{config.llm_base_url}/chat/completions",
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {config.llm_api_key}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:300]
        raise AgentError(f"Модель вернула ошибку HTTP {exc.code}: {detail}") from exc
    except urllib.error.URLError as exc:
        raise AgentError(f"Не удалось обратиться к модели: {exc.reason}") from exc
    except json.JSONDecodeError as exc:
        raise AgentError("Модель вернула не JSON") from exc

    choices = body.get("choices") or []
    if not choices:
        raise AgentError("Модель вернула пустой ответ")
    return str(choices[0].get("message", {}).get("content", "")).strip()
