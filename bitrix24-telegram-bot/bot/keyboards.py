from __future__ import annotations

from aiogram.types import KeyboardButton, ReplyKeyboardMarkup


def main_keyboard() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="📊 Отчёт за 7 дней"), KeyboardButton(text="📊 Отчёт за 30 дней")],
            [KeyboardButton(text="✅ Только задачи"), KeyboardButton(text="💬 Только открытые линии")],
            [KeyboardButton(text="📝 Краткая сводка"), KeyboardButton(text="❓ Помощь")],
        ],
        resize_keyboard=True,
    )
