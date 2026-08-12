"""Калибровка: выбор областей экрана со счётом каждого игрока.

Запустите скрипт, откроется скриншот всего экрана. Мышью выделите
прямоугольник вокруг счёта ЛЕВОГО игрока и нажмите Enter, затем то же
для ПРАВОГО игрока. Координаты сохранятся в config.json.

На fon.bet счёт выглядит как «276 - 354» — выделяйте каждое число отдельно,
как можно плотнее, без дефиса и имён игроков.
"""

import json
import os
import sys

import cv2
import mss
import numpy as np

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "config.json")

DEFAULT_CONFIG = {
    "poll_interval_sec": 0.15,
    "voice": True,
    "voice_name": "Milena",
    "top_recommendations": 2,
    "odds": {
        "even": 1.85,
        "odd": 1.85,
        "low": 1.85,
        "high": 1.85,
        "exact_number": 12.0,
        "bull": 15.0
    }
}


def select_region(image: np.ndarray, title: str) -> dict:
    print(f"\n=== {title} ===")
    print("Выделите область мышью и нажмите Enter (Esc — отмена).")
    x, y, w, h = cv2.selectROI(title, image, showCrosshair=True)
    cv2.destroyAllWindows()
    if w == 0 or h == 0:
        print("Область не выбрана, выход.")
        sys.exit(1)
    return {"left": int(x), "top": int(y), "width": int(w), "height": int(h)}


def main() -> None:
    with mss.mss() as sct:
        monitor = sct.monitors[1]
        shot = sct.grab(monitor)
        image = np.array(shot)[:, :, :3].copy()

    # На Retina-дисплеях скриншот больше логического разрешения — уменьшаем
    # для удобства выбора и запоминаем масштаб.
    screen_h = image.shape[0]
    display_scale = 1.0
    if screen_h > 1100:
        display_scale = 1100 / screen_h
        image_small = cv2.resize(image, None, fx=display_scale, fy=display_scale)
    else:
        image_small = image

    regions = {}
    for key, title in (("score_left", "Счёт ЛЕВОГО игрока"),
                       ("score_right", "Счёт ПРАВОГО игрока")):
        r = select_region(image_small, title)
        regions[key] = {k: int(round(v / display_scale)) for k, v in r.items()}

    config = dict(DEFAULT_CONFIG)
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, encoding="utf-8") as f:
            config.update(json.load(f))
    config.update(regions)

    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False, indent=2)

    print(f"\nГотово. Конфигурация сохранена в {CONFIG_PATH}")
    print("Проверьте коэффициенты в секции \"odds\" и запускайте: python3 watcher.py")


if __name__ == "__main__":
    main()
