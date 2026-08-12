"""Наблюдатель: следит за счётом на экране и после каждого броска
мгновенно выдаёт рекомендацию по следующей ставке.

Логика: счёт каждого игрока распознаётся несколько раз в секунду.
Когда счёт стабильно изменился, разница и есть значение броска.
Бросок добавляется в модель игрока, и по обновлённой статистике
выбирается рынок с лучшим матожиданием. Рекомендация печатается
в терминал и проговаривается голосом (macOS `say`) — на всё уходит
доли секунды, что укладывается в 5-секундное окно ставки.

Запуск:  python3 watcher.py
Остановка: Ctrl+C
"""

import json
import os
import subprocess
import sys
import time

import mss
import numpy as np

from ocr import read_number
from predictor import BULL, PlayerModel, recommend

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "config.json")

VALID_THROWS = set(range(1, 21)) | {BULL, 50}


def load_config() -> dict:
    if not os.path.exists(CONFIG_PATH):
        print("Нет config.json — сначала запустите: python3 calibrate.py")
        sys.exit(1)
    with open(CONFIG_PATH, encoding="utf-8") as f:
        config = json.load(f)
    for key in ("score_left", "score_right"):
        if key not in config:
            print(f"В config.json нет области {key} — перезапустите calibrate.py")
            sys.exit(1)
    return config


def speak(text: str, config: dict) -> None:
    if not config.get("voice", True):
        return
    if sys.platform != "darwin":
        return
    voice = config.get("voice_name", "Milena")
    # Не блокируем основной цикл: озвучка идёт параллельно
    subprocess.Popen(["say", "-v", voice, text],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def voice_text(market: str) -> str:
    replacements = {
        "ЧЕТ": "Ставь чёт",
        "НЕЧЕТ": "Ставь нечет",
        "1-10": "Ставь от одного до десяти",
        "11-20": "Ставь от одиннадцати до двадцати",
        "Буллсай": "Ставь буллсай",
    }
    if market in replacements:
        return replacements[market]
    if market.startswith("Число"):
        return "Ставь " + market.lower()
    return market


class StableReader:
    """Принимает значение только после двух одинаковых чтений подряд,
    чтобы одиночная ошибка OCR не считалась броском."""

    def __init__(self) -> None:
        self.candidate: int | None = None
        self.stable: int | None = None

    def update(self, value: int | None) -> int | None:
        """Возвращает новое стабильное значение или None, если оно не менялось."""
        if value is None:
            self.candidate = None
            return None
        if value == self.stable:
            self.candidate = None
            return None
        if value == self.candidate:
            self.stable = value
            self.candidate = None
            return value
        self.candidate = value
        return None


def main() -> None:
    config = load_config()
    interval = float(config.get("poll_interval_sec", 0.15))
    top_n = int(config.get("top_recommendations", 2))
    odds = config.get("odds", {})

    regions = {"Левый игрок": config["score_left"],
               "Правый игрок": config["score_right"]}
    readers = {name: StableReader() for name in regions}
    models = {name: PlayerModel() for name in regions}

    print("Слежу за экраном... Первые 1-2 броска уйдут на разгон статистики.")
    print("Остановка: Ctrl+C\n")

    with mss.mss() as sct:
        while True:
            t0 = time.monotonic()
            for name, region in regions.items():
                shot = sct.grab(region)
                frame = np.array(shot)[:, :, :3]
                value = read_number(frame)
                new_score = readers[name].update(value)
                if new_score is None:
                    continue

                reader = readers[name]
                prev = getattr(reader, "prev_score", None)
                reader.prev_score = new_score

                if prev is None:
                    print(f"[{name}] стартовый счёт: {new_score}")
                    continue

                delta = new_score - prev
                if delta <= 0:
                    print(f"[{name}] счёт сброшен/уменьшился "
                          f"({prev} -> {new_score}), новая серия.")
                    continue
                if delta not in VALID_THROWS:
                    print(f"[{name}] пропущен кадр или ошибка OCR: "
                          f"+{delta} не похоже на один бросок, пересинхронизация.")
                    continue

                sector = BULL if delta == 50 else delta
                models[name].add_throw(sector)
                recs = recommend(models[name], odds)

                elapsed_ms = (time.monotonic() - t0) * 1000
                print(f"\n>>> [{name}] бросок: {delta}  "
                      f"(счёт {prev} -> {new_score}, анализ {elapsed_ms:.0f} мс)")
                print(f"    история: {models[name].throws[-10:]}")
                for rec in recs[:top_n]:
                    print(f"    {rec}")
                if recs:
                    speak(voice_text(recs[0].market), config)

            time.sleep(max(0.0, interval - (time.monotonic() - t0)))


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nОстановлено.")
