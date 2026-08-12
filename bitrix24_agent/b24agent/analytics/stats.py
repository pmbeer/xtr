"""Небольшие статистические функции без внешних зависимостей."""

from __future__ import annotations

from collections.abc import Iterable, Sequence


def clean(values: Iterable[float | None]) -> list[float]:
    return [float(value) for value in values if value is not None]


def mean(values: Sequence[float]) -> float | None:
    return sum(values) / len(values) if values else None


def median(values: Sequence[float]) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    middle = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[middle]
    return (ordered[middle - 1] + ordered[middle]) / 2


def percentile(values: Sequence[float], share: float) -> float | None:
    """Персентиль методом линейной интерполяции (``share`` в диапазоне 0..1)."""
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = min(max(share, 0.0), 1.0) * (len(ordered) - 1)
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    weight = position - lower
    return ordered[lower] * (1 - weight) + ordered[upper] * weight


def share(part: int, total: int) -> float | None:
    return part / total if total else None
