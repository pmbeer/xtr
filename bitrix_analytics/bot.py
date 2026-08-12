from datetime import date, timedelta
from io import BytesIO

from aiogram import Bot, Dispatcher, F
from aiogram.filters import Command, CommandObject
from aiogram.types import BufferedInputFile, Message

from .bitrix import Bitrix24Client, Bitrix24Error
from .config import Settings
from .models import ReportPeriod
from .report import render_xlsx

HELP = (
    "Запросите Excel-отчёт:\n"
    "/report — за текущий месяц\n"
    "/report 2026-08-01 2026-08-12 — за указанный период"
)


def _period_from_args(args: str | None) -> ReportPeriod:
    if not args:
        today = date.today()
        return ReportPeriod(today.replace(day=1), today)
    values = args.split()
    if len(values) != 2:
        raise ValueError("Укажите две даты в формате ГГГГ-ММ-ДД.")
    start, end = map(date.fromisoformat, values)
    if end < start:
        raise ValueError("Дата окончания не может быть раньше даты начала.")
    if end - start > timedelta(days=366):
        raise ValueError("Максимальный период отчёта — 366 дней.")
    return ReportPeriod(start, end)


def create_dispatcher(settings: Settings) -> Dispatcher:
    dispatcher = Dispatcher()
    client = Bitrix24Client(str(settings.bitrix24_webhook_url), settings.bitrix24_user_id)

    def permitted(message: Message) -> bool:
        return settings.telegram_allowed_user_id is None or message.from_user.id == settings.telegram_allowed_user_id

    @dispatcher.message(Command("start", "help"))
    async def help_command(message: Message) -> None:
        if permitted(message):
            await message.answer(HELP)

    @dispatcher.message(Command("report"))
    async def report_command(message: Message, command: CommandObject) -> None:
        if not permitted(message):
            return
        try:
            period = _period_from_args(command.args)
            await message.answer("Собираю данные Bitrix24…")
            document = _report_document(await client.get_metrics(period), period)
            await message.answer_document(document)
        except ValueError as exc:
            await message.answer(f"{exc}\n\n{HELP}")
        except Bitrix24Error:
            await message.answer(
                "Bitrix24 вернул ошибку. Проверьте URL вебхука и права: задачи и открытые линии."
            )

    @dispatcher.message(F.text)
    async def plain_text(message: Message) -> None:
        if permitted(message):
            await message.answer(f"Пока поддерживается команда /report.\n\n{HELP}")

    return dispatcher


def _report_document(metrics, period: ReportPeriod) -> BufferedInputFile:
    content: BytesIO = render_xlsx(metrics)
    return BufferedInputFile(
        content.getvalue(), filename=f"bitrix24-report-{period.start.isoformat()}-{period.end.isoformat()}.xlsx"
    )


async def run() -> None:
    settings = Settings()
    bot = Bot(settings.telegram_bot_token.get_secret_value())
    await create_dispatcher(settings).start_polling(bot)
