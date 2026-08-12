"""Быстрое распознавание числа (счёта игрока) в небольшом участке экрана."""

import cv2
import numpy as np
import pytesseract

_TESS_CONFIG = "--oem 3 --psm 7 -c tessedit_char_whitelist=0123456789"


def read_number(bgr_image: np.ndarray) -> int | None:
    """Распознаёт целое число в изображении. Возвращает None, если не удалось.

    Изображение — маленький фрагмент экрана с одним числом (счёт игрока).
    Обработка: увеличение, перевод в ч/б, бинаризация. На тёмной теме сайта
    текст светлый, поэтому при тёмном фоне инвертируем.
    """
    gray = cv2.cvtColor(bgr_image, cv2.COLOR_BGR2GRAY)

    scale = max(1, int(round(48 / max(gray.shape[0], 1))))
    if scale > 1:
        gray = cv2.resize(gray, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)

    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    # Tesseract лучше работает с тёмным текстом на светлом фоне
    if np.mean(binary) < 127:
        binary = cv2.bitwise_not(binary)
    binary = cv2.copyMakeBorder(binary, 10, 10, 10, 10, cv2.BORDER_CONSTANT, value=255)

    text = pytesseract.image_to_string(binary, config=_TESS_CONFIG).strip()
    digits = "".join(ch for ch in text if ch.isdigit())
    if not digits:
        return None
    try:
        return int(digits)
    except ValueError:
        return None
