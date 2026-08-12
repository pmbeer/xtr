#!/usr/bin/env python3
"""Локальная генерация отчёта без Telegram (для проверки)."""
from __future__ import annotations

import argparse
import asyncio
import logging
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from config import settings
from services.analytics import AnalyticsService
from services.bitrix import BitrixClient
from services.models import Period
from services.report import ReportGenerator


async def _run(days: int) -> Path:
    settings.ensure_dirs()
    period = Period.last_days(days)
    if settings.demo_mode or not settings.bitrix_webhook_url:
        service = AnalyticsService(None, settings.bitrix_user_id or 1, demo_mode=True)
        report = await service.build_report(period)
    else:
        async with BitrixClient(settings.bitrix_webhook_url) as client:
            service = AnalyticsService(client, settings.bitrix_user_id, demo_mode=False)
            report = await service.build_report(period)

    generator = ReportGenerator(settings.reports_dir)
    xlsx = generator.generate_excel(report)
    txt = generator.generate_txt(report)
    print("\n".join(report.summary_lines))
    print(f"\nExcel: {xlsx}")
    print(f"TXT:   {txt}")
    return xlsx


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    parser = argparse.ArgumentParser(description="Generate Bitrix24 analytics report")
    parser.add_argument("--days", type=int, default=settings.default_period_days)
    args = parser.parse_args()
    asyncio.run(_run(args.days))


if __name__ == "__main__":
    main()
