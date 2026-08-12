from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Allow running without installation: python -m bitrix_agent.cli from src/
SRC_ROOT = Path(__file__).resolve().parents[1]
if str(SRC_ROOT) not in sys.path:
    sys.path.insert(0, str(SRC_ROOT))

from bitrix_agent.analytics.report import build_activity_report
from bitrix_agent.client import BitrixClient
from bitrix_agent.config import get_settings
from bitrix_agent.storage import AnalyticsStore


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Агент аналитики личной активности в облачном Bitrix24",
    )
    parser.add_argument(
        "--days",
        type=int,
        default=None,
        help="Период отчёта в днях (по умолчанию из .env / 7)",
    )
    parser.add_argument(
        "--user-id",
        type=int,
        default=None,
        help="ID пользователя Bitrix24 (по умолчанию владелец вебхука)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Вывести отчёт в JSON",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Сохранить отчёт в файл",
    )
    args = parser.parse_args(argv)

    settings = get_settings()
    webhook = settings.require_webhook()
    days = args.days or settings.report_days
    user_id = args.user_id or settings.bitrix24_user_id

    client = BitrixClient(webhook)
    store = AnalyticsStore(settings.database_path)
    report = build_activity_report(
        client,
        user_id=user_id,
        days=days,
        store=store,
    )

    if args.json:
        payload = json.dumps(report.to_dict(), ensure_ascii=False, indent=2)
    else:
        payload = report.to_text()

    print(payload)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload + "\n", encoding="utf-8")
        print(f"\nСохранено: {args.output}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
