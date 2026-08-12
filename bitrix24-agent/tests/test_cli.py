"""Тесты разбора аргументов командной строки."""

from __future__ import annotations

import contextlib
import io
import unittest
from pathlib import Path

from bitrix24_agent.cli import build_parser


class ParserTests(unittest.TestCase):
    def setUp(self) -> None:
        self.parser = build_parser()

    def test_defaults_are_sensible(self) -> None:
        args = self.parser.parse_args(["report"])
        self.assertEqual(args.period, "month")
        self.assertEqual(args.format, "text")
        self.assertEqual(args.env_file, Path(".env"))
        self.assertFalse(args.compare)

    def test_common_options_work_before_the_subcommand(self) -> None:
        args = self.parser.parse_args(["--env-file", "prod.env", "-v", "report"])
        self.assertEqual(args.env_file, Path("prod.env"))
        self.assertTrue(args.verbose)

    def test_common_options_work_after_the_subcommand(self) -> None:
        args = self.parser.parse_args(["report", "--env-file", "prod.env", "-v"])
        self.assertEqual(args.env_file, Path("prod.env"))
        self.assertTrue(args.verbose)

    def test_subcommand_does_not_reset_options_given_earlier(self) -> None:
        args = self.parser.parse_args(["--env-file", "prod.env", "report", "--period", "week"])
        self.assertEqual(args.env_file, Path("prod.env"))
        self.assertEqual(args.period, "week")

    def test_ask_requires_a_question(self) -> None:
        args = self.parser.parse_args(["ask", "Сколько задач я закрыл?", "--period", "30d"])
        self.assertEqual(args.question, "Сколько задач я закрыл?")
        self.assertEqual(args.period, "30d")

    def test_command_is_required(self) -> None:
        # argparse печатает подсказку в stderr — в выводе тестов она лишняя.
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            self.parser.parse_args([])


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
