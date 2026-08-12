"""Клавиатуры бота.

Кнопки отправляют обычный текст и проходят через тот же разбор запроса, что и
свободные формулировки: одна логика вместо двух.
"""

from __future__ import annotations

from aiogram.types import KeyboardButton, ReplyKeyboardMarkup

QUICK_QUERIES: tuple[tuple[str, ...], ...] = (
    ("Задачи за сегодня", "Задачи за неделю"),
    ("Задачи за прошлую неделю", "Задачи за месяц"),
    ("Стадии задач в работе", "Открытые линии за месяц"),
    ("Полный отчёт за прошлый месяц",),
)


def main_keyboard() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text=title) for title in row] for row in QUICK_QUERIES
        ],
        resize_keyboard=True,
        input_field_placeholder="Напишите, какой отчёт нужен",
    )
