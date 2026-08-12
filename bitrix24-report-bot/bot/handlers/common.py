"""Команды /start, /help и общая клавиатура выбора периода."""

from __future__ import annotations

from aiogram import Router
from aiogram.filters import Command, CommandStart
from aiogram.types import KeyboardButton, Message, ReplyKeyboardMarkup

router = Router(name="common")

PERIOD_KEYBOARD = ReplyKeyboardMarkup(
    keyboard=[
        [KeyboardButton(text="Сегодня"), KeyboardButton(text="Вчера")],
        [KeyboardButton(text="Неделя"), KeyboardButton(text="Прошлая неделя")],
        [KeyboardButton(text="Месяц"), KeyboardButton(text="Прошлый месяц")],
        [KeyboardButton(text="Квартал"), KeyboardButton(text="Год")],
    ],
    resize_keyboard=True,
    input_field_placeholder="Например: неделя, месяц, 01.08-12.08...",
)

WELCOME_TEXT = (
    "👋 Привет! Я помогу собрать отчёт по вашей активности в Битрикс24:\n\n"
    "• сколько задач закрыто и сколько сейчас в работе, на каких стадиях;\n"
    "• сколько обращений в Открытых линиях обработано и среднее время решения.\n\n"
    "Просто напишите период, за который нужен отчёт — например:\n"
    "«сегодня», «неделя», «прошлый месяц», «квартал» или даты вида "
    "«01.08.2026-12.08.2026». Я подготовлю и пришлю готовый Excel-файл с результатами."
)

HELP_TEXT = (
    "Как пользоваться ботом:\n\n"
    "1️⃣ Напишите период отчёта текстом, например:\n"
    "   • сегодня / вчера / позавчера\n"
    "   • неделя / прошлая неделя\n"
    "   • месяц / прошлый месяц\n"
    "   • квартал / год\n"
    "   • конкретные даты: 01.08.2026-12.08.2026 или просто 05.08\n\n"
    "2️⃣ Бот соберёт данные из Битрикс24 (задачи и Открытые линии) и пришлёт "
    "готовый Excel-файл с отчётом.\n\n"
    "Команды:\n"
    "/start — приветствие и краткая инструкция\n"
    "/help — эта справка\n"
    "/report <период> — то же самое, что и обычное сообщение с периодом"
)


@router.message(CommandStart())
async def cmd_start(message: Message) -> None:
    await message.answer(WELCOME_TEXT, reply_markup=PERIOD_KEYBOARD)


@router.message(Command("help"))
async def cmd_help(message: Message) -> None:
    await message.answer(HELP_TEXT, reply_markup=PERIOD_KEYBOARD)
