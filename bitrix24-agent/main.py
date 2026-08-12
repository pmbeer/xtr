#!/usr/bin/env python3
"""CLI для агента аналитики Bitrix24."""

from __future__ import annotations

import argparse
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src.agent import Bitrix24AnalyticsAgent
from src.config import Settings


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Агент аналитики Bitrix24: задачи, открытые линии, KPI",
    )
    parser.add_argument(
        "--from",
        dest="date_from",
        type=str,
        help="Начало периода (YYYY-MM-DD)",
    )
    parser.add_argument(
        "--to",
        dest="date_to",
        type=str,
        help="Конец периода (YYYY-MM-DD)",
    )
    parser.add_argument(
        "--user-id",
        type=int,
        help="ID пользователя Bitrix24 (переопределяет .env)",
    )
    parser.add_argument(
        "--json",
        dest="json_path",
        type=str,
        help="Сохранить отчёт в JSON-файл",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Проверить подключение к Bitrix24",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    overrides: dict = {}
    if args.date_from:
        overrides["analytics_date_from"] = date.fromisoformat(args.date_from)
    if args.date_to:
        overrides["analytics_date_to"] = date.fromisoformat(args.date_to)
    if args.user_id:
        overrides["bitrix24_user_id"] = args.user_id

    try:
        settings = Settings(**overrides)
    except Exception as exc:
        print(f"Ошибка конфигурации: {exc}", file=sys.stderr)
        print("Скопируйте .env.example в .env и заполните BITRIX24_WEBHOOK_URL", file=sys.stderr)
        return 1

    with Bitrix24AnalyticsAgent(settings) as agent:
        if args.check:
            user = agent.client.get_current_user()
            print(f"Подключение OK. Пользователь: {user.get('NAME')} {user.get('LAST_NAME')} (ID={user.get('ID')})")
            return 0

        result = agent.run()

        if args.json_path:
            agent.save_report(args.json_path, result)
            print(f"Отчёт сохранён: {args.json_path}")

        agent.print_report(result)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
