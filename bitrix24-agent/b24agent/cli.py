"""Командная строка агента аналитики Битрикс24."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any, Dict, Optional

from . import config
from .client import Bitrix24Client, Bitrix24Error
from .openlines import OpenLinesAnalytics
from .report import build_json, build_text
from .tasks import TaskAnalytics
from .util import resolve_period


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="b24agent",
        description=(
            "Агент аналитики активности в Битрикс24: задачи (закрытые, в работе, "
            "стадии, просрочка, среднее время выполнения) и открытые линии "
            "(обработанные обращения, среднее время решения, оценки клиентов)."
        ),
    )
    parser.add_argument(
        "--period",
        choices=["today", "week", "month", "quarter", "year"],
        default="month",
        help="Период отчёта (по умолчанию month — последние 30 дней)",
    )
    parser.add_argument("--from", dest="date_from", metavar="YYYY-MM-DD", help="Начало периода")
    parser.add_argument("--to", dest="date_to", metavar="YYYY-MM-DD", help="Конец периода")
    parser.add_argument(
        "--user-id",
        type=int,
        help="ID пользователя Битрикс24 (по умолчанию — владелец вебхука)",
    )
    parser.add_argument("--json", action="store_true", help="Вывести отчёт в формате JSON")
    parser.add_argument(
        "--details",
        action="store_true",
        help="Включить в JSON списки задач и сессий (только вместе с --json)",
    )
    parser.add_argument("--output", metavar="FILE", help="Сохранить отчёт в файл")
    parser.add_argument(
        "--webhook-url",
        help="URL входящего вебхука (иначе берётся из BITRIX24_WEBHOOK_URL / .env)",
    )
    return parser


def resolve_user(client: Bitrix24Client, user_id: Optional[int]) -> Dict[str, Any]:
    """Возвращает профиль пользователя, за которого строится отчёт."""
    if user_id is None:
        profile = client.call("profile") or {}
        user_id = int(profile.get("ID", 0))
        if not user_id:
            raise Bitrix24Error("NO_USER", "Не удалось определить пользователя вебхука")
    result = client.call("user.get", {"ID": user_id}) or []
    if isinstance(result, list) and result:
        return result[0]
    return {"ID": user_id}


def main(argv: Optional[list] = None) -> int:
    config.load_dotenv()
    args = build_parser().parse_args(argv)

    webhook_url = args.webhook_url or config.get_webhook_url()
    user_id = args.user_id if args.user_id is not None else config.get_default_user_id()
    date_from, date_to = resolve_period(args.period, args.date_from, args.date_to)

    client = Bitrix24Client(webhook_url)
    try:
        user = resolve_user(client, user_id)
        uid = int(user.get("ID"))
        print(
            f"Собираю данные за {date_from:%d.%m.%Y} — {date_to:%d.%m.%Y} "
            f"для пользователя #{uid}...",
            file=sys.stderr,
        )
        tasks_report = TaskAnalytics(client).collect(uid, date_from, date_to)
        openlines_report = OpenLinesAnalytics(client).collect(uid, date_from, date_to)
    except Bitrix24Error as exc:
        print(f"Ошибка Битрикс24: {exc}", file=sys.stderr)
        return 1

    if args.json:
        output = build_json(user, tasks_report, openlines_report, include_details=args.details)
    else:
        output = build_text(user, tasks_report, openlines_report)

    if args.output:
        Path(args.output).write_text(output + "\n", encoding="utf-8")
        print(f"Отчёт сохранён: {args.output}", file=sys.stderr)
    else:
        print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
