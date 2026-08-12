"""Статистическая модель бросков и выбор ставки.

Модель для каждого игрока хранит историю бросков и оценивает вероятность
каждого сектора (1-20 и буллсай) с экспоненциальным затуханием: недавние
броски весят больше, потому что игрок мог сменить точку прицеливания.
Оценки сглаживаются по Лапласу, чтобы не выдавать нулевые вероятности.

Рекомендация — рынок с максимальным матожиданием EV = p * коэффициент - 1
при заданных в конфиге коэффициентах.
"""

from dataclasses import dataclass, field

BULL = 25
SECTORS = list(range(1, 21)) + [BULL]


@dataclass
class Recommendation:
    market: str          # человекочитаемое название ставки
    probability: float   # оценка вероятности захода
    odds: float          # коэффициент из конфига
    ev: float            # матожидание на 1 единицу ставки

    def __str__(self) -> str:
        return (f"{self.market}: p={self.probability:.0%}, "
                f"кэф={self.odds:.2f}, EV={self.ev:+.2f}")


@dataclass
class PlayerModel:
    decay: float = 0.93          # вес истории: чем меньше, тем быстрее забываем
    smoothing: float = 0.6       # сглаживание Лапласа
    weights: dict[int, float] = field(default_factory=lambda: {s: 0.0 for s in SECTORS})
    throws: list[int] = field(default_factory=list)

    def add_throw(self, sector: int) -> None:
        if sector not in self.weights:
            return
        for s in self.weights:
            self.weights[s] *= self.decay
        self.weights[sector] += 1.0
        self.throws.append(sector)

    def probabilities(self) -> dict[int, float]:
        total = sum(self.weights.values()) + self.smoothing * len(SECTORS)
        return {s: (w + self.smoothing) / total for s, w in self.weights.items()}


def recommend(model: PlayerModel, odds: dict, top_n: int = 3) -> list[Recommendation]:
    """Возвращает рекомендации, отсортированные по EV (лучшая первой)."""
    p = model.probabilities()

    candidates: list[Recommendation] = []

    def add(market: str, probability: float, odds_key: str) -> None:
        k = float(odds.get(odds_key, 0))
        if k > 1:
            candidates.append(Recommendation(market, probability, k, probability * k - 1))

    add("ЧЕТ", sum(v for s, v in p.items() if s <= 20 and s % 2 == 0), "even")
    add("НЕЧЕТ", sum(v for s, v in p.items() if s <= 20 and s % 2 == 1), "odd")
    add("1-10", sum(v for s, v in p.items() if 1 <= s <= 10), "low")
    add("11-20", sum(v for s, v in p.items() if 11 <= s <= 20), "high")
    add("Буллсай", p[BULL], "bull")

    numbers = sorted(((s, v) for s, v in p.items() if s <= 20),
                     key=lambda x: x[1], reverse=True)
    for sector, prob in numbers[:top_n]:
        add(f"Число {sector}", prob, "exact_number")

    candidates.sort(key=lambda r: r.ev, reverse=True)
    return candidates
