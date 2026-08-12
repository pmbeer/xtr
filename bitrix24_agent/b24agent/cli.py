"""Консольный режим: тот же отчёт, но без Telegram.

Полезно при настройке — проверить вебхук и права, не поднимая бота::

    python -m b24agent.cli "задачи за прошлый месяц"
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from datetime import datetime
from pathlib import Path

from b24agent.analytics.models import ReportFormat
from b24agent.analytics.service import AnalyticsService
from b24agent.bitrix.client import Bitrix24Client
from b24agent.config import Settings
from b24agent.logging_setup import setup_logging
from b24agent.nlu import describe_request, parse_query
from b24agent.reports import build_report_file


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="b24agent.cli",
        description="Сформировать отчёт по Битрикс24 в файл, без Telegram",
    )
    parser.add_argument("query", nargs="?", default="отчёт за текущий месяц", help="Запрос на естественном языке")
    parser.add_argument("--format", dest="report_format", choices=[item.value for item in ReportFormat])
    parser.add_argument("--user-id", dest="user_id", type=int, help="ID сотрудника Битрикс24")
    parser.add_argument("--out", dest="out", type=Path, help="Путь к файлу отчёта")
    return parser


async def _run(args: argparse.Namespace) -> int:
    settings = Settings()  # type: ignore[call-arg]
    setup_logging(settings.log_level)
    settings.ensure_directories()

    request = parse_query(
        args.query,
        now=datetime.now(settings.tz),
        tz=settings.tz,
        default_format=ReportFormat(args.report_format or settings.default_report_format),
        bitrix_user_id=args.user_id or settings.bitrix_default_user_id,
    )
    print(describe_request(request))

    async with Bitrix24Client(
        settings.bitrix_webhook_url,
        timeout=settings.bitrix_timeout,
        rate_limit=settings.bitrix_rate_limit,
    ) as client:
        service = AnalyticsService(
            client,
            tz=settings.tz,
            portal_url=settings.portal_url,
            default_user_id=settings.bitrix_default_user_id,
            max_records=settings.bitrix_max_records,
        )
        report = await service.build_report(request)

    document = build_report_file(report)
    destination = args.out or settings.reports_dir / document.filename
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(document.content)

    print(f"\nСотрудник: {report.user_name} (ID {report.user_id})")
    if report.tasks:
        print(
            f"Задачи: закрыто {report.tasks.closed_count}, "
            f"в работе {report.tasks.open_count}, "
            f"просрочено {report.tasks.overdue_open_count}"
        )
    if report.openlines:
        print(
            f"Открытые линии: обращений {report.openlines.total_sessions}, "
            f"источник данных — {report.openlines.data_source.title}"
        )
    for warning in report.warnings:
        print(f"! {warning}")
    print(f"\nФайл: {destination} ({document.size_kb} КБ)")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return asyncio.run(_run(args))
    except KeyboardInterrupt:
        return 130
    except Exception as exc:
        print(f"Ошибка: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
