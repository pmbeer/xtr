"""Агрегация чисел и человекочитаемое форматирование на русском."""

from __future__ import annotations

import math
from collections.abc import Iterable, Sequence
from dataclasses import asdict, dataclass


@dataclass(frozen=True)
class Summary:
    """Сводка по набору длительностей или любых числовых значений."""

    count: int = 0
    total: float = 0.0
    avg: float | None = None
    median: float | None = None
    p90: float | None = None
    minimum: float | None = None
    maximum: float | None = None

    @property
    def empty(self) -> bool:
        return self.count == 0

    def to_dict(self) -> dict:
        return asdict(self)


def summarize(values: Iterable[float]) -> Summary:
    """Считает среднее, медиану и 90-й перцентиль.

    Медиана важнее среднего: одна забытая на месяц задача сильно смещает
    среднее время решения, а медиана показывает типичный случай.
    """
    data = sorted(float(value) for value in values if value is not None)
    if not data:
        return Summary()
    return Summary(
        count=len(data),
        total=math.fsum(data),
        avg=math.fsum(data) / len(data),
        median=percentile(data, 50),
        p90=percentile(data, 90),
        minimum=data[0],
        maximum=data[-1],
    )


def percentile(sorted_values: Sequence[float], percent: float) -> float | None:
    """Перцентиль методом линейной интерполяции по уже отсортированным данным."""
    if not sorted_values:
        return None
    if len(sorted_values) == 1:
        return float(sorted_values[0])
    position = (len(sorted_values) - 1) * (percent / 100.0)
    lower_index = math.floor(position)
    upper_index = math.ceil(position)
    if lower_index == upper_index:
        return float(sorted_values[int(position)])
    lower = sorted_values[lower_index] * (upper_index - position)
    upper = sorted_values[upper_index] * (position - lower_index)
    return float(lower + upper)


def share(part: float, whole: float) -> float | None:
    """Доля от целого в процентах; `None`, если целое нулевое."""
    if not whole:
        return None
    return round(part / whole * 100, 1)


def plural(number: int, one: str, few: str, many: str) -> str:
    """Русская форма слова: 1 задача, 2 задачи, 5 задач."""
    absolute = abs(number) % 100
    if 11 <= absolute <= 14:
        return many
    remainder = absolute % 10
    if remainder == 1:
        return one
    if 2 <= remainder <= 4:
        return few
    return many


def humanize_duration(seconds: float | None) -> str:
    """`93780` → `1 д 2 ч`. Показываем не больше двух старших единиц."""
    if seconds is None:
        return "—"
    seconds = float(seconds)
    if seconds < 0:
        return "—"
    if seconds < 60:
        return f"{int(round(seconds))} сек"

    minutes, remainder_seconds = divmod(int(round(seconds)), 60)
    hours, minutes = divmod(minutes, 60)
    days, hours = divmod(hours, 24)

    if days:
        return f"{days} д {hours} ч" if hours else f"{days} д"
    if hours:
        return f"{hours} ч {minutes} мин" if minutes else f"{hours} ч"
    return f"{minutes} мин {remainder_seconds} сек" if remainder_seconds else f"{minutes} мин"


def humanize_number(value: float | None) -> str:
    """Целые — без дробной части, дробные — с одним знаком, тысячи — с разделителем."""
    if value is None:
        return "—"
    if isinstance(value, float) and not value.is_integer():
        return f"{value:,.1f}".replace(",", " ").replace(".", ",")
    return f"{int(value):,}".replace(",", " ")


def format_delta(current: float, previous: float | None, *, higher_is_better: bool = True) -> str:
    """Стрелка изменения относительно прошлого периода: `+3 (▲ 12%)`."""
    if previous is None:
        return ""
    difference = current - previous
    if abs(difference) < 1e-9:
        return "= без изменений"
    percent = share(abs(difference), abs(previous)) if previous else None
    direction = "▲" if difference > 0 else "▼"
    good = (difference > 0) == higher_is_better
    marker = "" if good else " ⚠"
    sign = "+" if difference > 0 else "−"
    body = f"{sign}{humanize_number(abs(difference))}"
    if percent is not None:
        body += f" ({direction} {humanize_number(percent)}%)"
    else:
        body += f" {direction}"
    return body + marker
