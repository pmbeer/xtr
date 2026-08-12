"""Консольный интерфейс агента: `bitrix24-agent report [опции]`."""

from __future__ import annotations

import argparse
import sys
from typing import Optional

from .client import BitrixApiError, BitrixClient
from .config import Config, ConfigError, find_default_env_file
from .period import Period, PeriodError, parse_period
from .report import build_full_report, notify_user, render_json, render_markdown, render_text


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="bitrix24-agent",
        description="Агент анализа продуктивности в Битрикс24: задачи и Открытые линии.",
    )
    parser.add_argument(
        "--period",
        default="week",
        help=(
            "Период отчёта: today, yesterday, week, last_week, month, last_month, "
            "quarter, year, all, либо диапазон YYYY-MM-DD:YYYY-MM-DD. По умолчанию: week."
        ),
    )
    parser.add_argument(
        "--user-id",
        type=int,
        default=None,
        help="ID пользователя Битрикс24. По умолчанию — из .env / BITRIX24_USER_ID, "
        "либо текущий пользователь вебхука.",
    )
    parser.add_argument(
        "--format",
        choices=["text", "markdown", "json"],
        default="text",
        help="Формат вывода отчёта. По умолчанию: text.",
    )
    parser.add_argument(
        "--notify",
        action="store_true",
        help="Дополнительно отправить отчёт пользователю личным уведомлением в Битрикс24.",
    )
    parser.add_argument(
        "--env-file",
        default=None,
        help="Путь к .env файлу с настройками (BITRIX24_WEBHOOK_URL и т.д.).",
    )
    return parser


def main(argv: Optional[list] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        config = Config.load(args.env_file or find_default_env_file())
    except ConfigError as exc:
        print(f"Ошибка конфигурации: {exc}", file=sys.stderr)
        return 2

    client = BitrixClient(config.webhook_url)

    user_id = args.user_id or config.user_id
    try:
        if user_id is None:
            user_id = client.current_user_id()

        period = parse_period(args.period, tz_offset=config.tz_offset)
        report = build_full_report(client, user_id, period)
    except PeriodError as exc:
        print(f"Ошибка периода: {exc}", file=sys.stderr)
        return 2
    except BitrixApiError as exc:
        print(f"Ошибка Битрикс24 API ({exc.method}): {exc.error} — {exc.description}", file=sys.stderr)
        return 1

    renderers = {"text": render_text, "markdown": render_markdown, "json": render_json}
    output = renderers[args.format](report)
    print(output)

    if args.notify or config.notify:
        try:
            notify_user(client, user_id, render_text(report))
        except BitrixApiError as exc:
            print(
                f"Не удалось отправить уведомление ({exc.method}): {exc.error} — {exc.description}",
                file=sys.stderr,
            )

    return 0


if __name__ == "__main__":
    sys.exit(main())
