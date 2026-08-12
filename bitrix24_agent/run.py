#!/usr/bin/env python3
"""Точка входа: запуск телеграм-агента аналитики Битрикс24."""

from __future__ import annotations

import asyncio
import logging
import sys

from pydantic import ValidationError

from b24agent.bot import run_bot
from b24agent.config import Settings
from b24agent.logging_setup import setup_logging


def main() -> int:
    try:
        settings = Settings()  # type: ignore[call-arg]
    except ValidationError as exc:
        print("Не удалось прочитать настройки. Проверьте файл .env:\n", file=sys.stderr)
        for error in exc.errors():
            field = ".".join(str(part) for part in error["loc"])
            print(f"  • {field}: {error['msg']}", file=sys.stderr)
        return 2

    setup_logging(settings.log_level)
    try:
        asyncio.run(run_bot(settings))
    except (KeyboardInterrupt, SystemExit):
        logging.getLogger(__name__).info("Остановка по сигналу")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
