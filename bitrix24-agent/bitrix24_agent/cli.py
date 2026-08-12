"""Командный интерфейс агента."""

from __future__ import annotations

import argparse
import json
import logging
import sys
from collections.abc import Sequence
from pathlib import Path

from . import __version__
from .agent import ALL_SECTIONS, Bitrix24Agent, Report
from .config import Config
from .errors import AgentError
from .period import parse_period, resolve_timezone
from .report import render, render_diagnostics
from .storage import SnapshotStore

DEFAULT_ENV_FILE = Path(".env")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="b24-agent",
        description="Агент аналитики по вашей работе в облачном Битрикс24.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Примеры:\n"
            "  b24-agent doctor\n"
            "  b24-agent report --period month --compare\n"
            "  b24-agent report --period 2026-06 --format markdown --output june.md\n"
            "  b24-agent report --period week --sections tasks,openlines\n"
            "  b24-agent ask 'Где я теряю больше всего времени?' --period 30d\n"
        ),
    )
    parser.add_argument("--version", action="version", version=f"b24-agent {__version__}")
    _add_common_arguments(parser, suppress_defaults=False)

    # Те же общие опции повторяются у подкоманд, чтобы работало и
    # `b24-agent --env-file X report`, и `b24-agent report --env-file X`.
    common = argparse.ArgumentParser(add_help=False)
    _add_common_arguments(common, suppress_defaults=True)

    subparsers = parser.add_subparsers(dest="command", required=True)

    doctor = subparsers.add_parser(
        "doctor", parents=[common], help="проверить подключение и доступные источники данных"
    )
    doctor.add_argument("--format", choices=("text", "json"), default="text")

    report = subparsers.add_parser("report", parents=[common], help="собрать отчёт за период")
    _add_report_arguments(report)
    report.add_argument(
        "--format", choices=("text", "markdown", "md", "json"), default="text", help="формат вывода"
    )
    report.add_argument("--output", type=Path, help="сохранить отчёт в файл вместо вывода в консоль")
    report.add_argument("--save", action="store_true", help="сохранить снимок отчёта в базу истории")

    ask = subparsers.add_parser("ask", parents=[common], help="задать вопрос по своим показателям")
    ask.add_argument("question", help="вопрос на естественном языке")
    _add_report_arguments(ask)

    history = subparsers.add_parser(
        "history", parents=[common], help="показать сохранённые снимки отчётов"
    )
    history.add_argument("--limit", type=int, default=10, help="сколько записей показать")
    history.add_argument("--format", choices=("text", "json"), default="text")

    return parser


def _add_common_arguments(parser: argparse.ArgumentParser, *, suppress_defaults: bool) -> None:
    """Опции, доступные и до подкоманды, и после неё.

    У подкоманд значения по умолчанию подавляются: иначе argparse затёр бы
    ими то, что пользователь указал перед именем подкоманды.
    """
    parser.add_argument(
        "--env-file",
        type=Path,
        default=argparse.SUPPRESS if suppress_defaults else DEFAULT_ENV_FILE,
        help="файл с настройками (по умолчанию ./.env)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        default=argparse.SUPPRESS if suppress_defaults else False,
        help="подробный лог обращений к API",
    )


def _add_report_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--period",
        default="month",
        help="период: today, yesterday, week, last-week, month, last-month, quarter, "
        "year, 30d, 2026-06, 2026-06-01..2026-06-30 (по умолчанию month)",
    )
    parser.add_argument("--user", type=int, help="идентификатор сотрудника (по умолчанию владелец вебхука)")
    parser.add_argument(
        "--sections",
        default=",".join(ALL_SECTIONS),
        help="разделы через запятую: " + ", ".join(ALL_SECTIONS),
    )
    parser.add_argument(
        "--compare", action="store_true", help="сравнить с предыдущим периодом такой же длины"
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    logging.basicConfig(
        level=logging.INFO if args.verbose else logging.WARNING,
        format="%(levelname)s %(name)s: %(message)s",
        stream=sys.stderr,
    )

    try:
        return _dispatch(args)
    except AgentError as exc:
        print(f"Ошибка: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Прервано пользователем", file=sys.stderr)
        return 130


def _dispatch(args: argparse.Namespace) -> int:
    if args.command == "history":
        return _run_history(args)

    config = Config.from_env(dotenv_path=args.env_file)
    if getattr(args, "user", None):
        config.user_id = args.user

    if args.command == "doctor":
        return _run_doctor(args, config)
    if args.command == "report":
        return _run_report(args, config)
    if args.command == "ask":
        return _run_ask(args, config)
    raise AgentError(f"Неизвестная команда: {args.command}")


def _run_doctor(args: argparse.Namespace, config: Config) -> int:
    agent = Bitrix24Agent(config)
    probes = agent.diagnose()
    if args.format == "json":
        print(json.dumps({"portal": config.portal, "probes": probes}, ensure_ascii=False, indent=2))
    else:
        print(render_diagnostics(config.portal, probes))
    return 0 if all(probe["status"] != "error" for probe in probes) else 1


def _run_report(args: argparse.Namespace, config: Config) -> int:
    report = _collect(args, config)
    output = render(report, args.format)

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output + "\n", encoding="utf-8")
        print(f"Отчёт сохранён: {args.output}")
    else:
        print(output)

    if args.save:
        store = _open_store(config)
        snapshot_id = store.save(report)
        print(f"Снимок сохранён в {store.path} (запись #{snapshot_id})", file=sys.stderr)
    return 0


def _run_ask(args: argparse.Namespace, config: Config) -> int:
    from .llm import ask as ask_model

    report = _collect(args, config)
    answer = ask_model(config, report.to_dict(), args.question)
    print(answer)
    return 0


def _run_history(args: argparse.Namespace) -> int:
    config = Config.from_env(dotenv_path=args.env_file)
    store = _open_store(config)
    snapshots = store.history(portal=config.portal, limit=args.limit)
    if args.format == "json":
        print(
            json.dumps(
                [
                    {
                        "id": snapshot.id,
                        "period": snapshot.period_label,
                        "generated_at": snapshot.generated_at.isoformat(),
                        "payload": snapshot.payload,
                    }
                    for snapshot in snapshots
                ],
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    if not snapshots:
        print("История пуста. Запустите `b24-agent report --save`, чтобы начать её вести.")
        return 0

    print(f"{'Дата':<18}{'Период':<28}{'Закрыто задач':>14}{'Обращений':>12}")
    print("─" * 72)
    for snapshot in snapshots:
        closed = snapshot.metric("tasks", "closed_count")
        handled = snapshot.metric("openlines", "handled_count")
        print(
            f"{snapshot.generated_at:%d.%m.%Y %H:%M} "
            f"{snapshot.period_label:<28}"
            f"{'—' if closed is None else closed:>14}"
            f"{'—' if handled is None else handled:>12}"
        )
    return 0


def _collect(args: argparse.Namespace, config: Config) -> Report:
    timezone = resolve_timezone(config.timezone)
    period = parse_period(args.period, timezone)
    sections = tuple(name.strip() for name in args.sections.split(",") if name.strip())
    agent = Bitrix24Agent(config)
    return agent.build_report(period, sections=sections, compare=args.compare)


def _open_store(config: Config) -> SnapshotStore:
    path = config.storage_path or Path.home() / ".bitrix24-agent" / "snapshots.sqlite3"
    return SnapshotStore(path)


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
