#!/usr/bin/env python3
"""Локальный smoke-тест логики ансамбля (без Swift runtime)."""

from __future__ import annotations

NUMBERS = list(range(1, 21)) + [25]


def normalize(scores: dict[int, float]) -> dict[int, float]:
    clipped = {k: max(0.0, v) for k, v in scores.items() if k in NUMBERS}
    s = sum(clipped.values())
    if s <= 1e-12:
        u = 1.0 / len(NUMBERS)
        return {n: u for n in NUMBERS}
    return {k: v / s for k, v in clipped.items()}


def top_n(probs: dict[int, float], n: int = 4) -> list[tuple[int, float]]:
    top = sorted(probs.items(), key=lambda kv: kv[1], reverse=True)[:n]
    s = sum(v for _, v in top)
    return [(k, v / s) for k, v in top]


def test_top4_sum():
    scores = {17: 2.0, 7: 1.2, 19: 1.0, 12: 0.8, 3: 0.2}
    for n in NUMBERS:
        scores.setdefault(n, 0.05)
    top = top_n(normalize(scores), 4)
    assert len(top) == 4
    assert abs(sum(p for _, p in top) - 1.0) < 1e-9
    assert all(num in NUMBERS for num, _ in top)


def test_transition_learns():
    table: dict[int, dict[int, int]] = {}
    for _ in range(20):
        table.setdefault(14, {})
        table[14][7] = table[14].get(7, 0) + 1
    row = table[14]
    total = sum(row.values())
    assert row[7] / total == 1.0


def test_weight_smoothing():
    weights = {"sequence": 0.2, "frequency": 0.15, "transition": 0.2, "player": 0.3, "timing": 0.15}
    # Явный перекос: player почти всегда прав, sequence почти всегда нет.
    hits = {"sequence": (2, 40), "frequency": (10, 40), "transition": (12, 40), "player": (32, 40), "timing": (11, 40)}
    smooth = 0.12
    raw = {k: (s + 2) / (t + 10) for k, (s, t) in hits.items()}
    s = sum(raw.values())
    target = {k: v / s for k, v in raw.items()}
    new = {k: weights[k] * (1 - smooth) + target[k] * smooth for k in weights}
    assert abs(sum(new.values()) - 1.0) < 1e-9
    assert new["player"] > weights["player"]
    assert new["sequence"] < weights["sequence"]


if __name__ == "__main__":
    test_top4_sum()
    test_transition_learns()
    test_weight_smoothing()
    print("logic_smoke_test: OK")
