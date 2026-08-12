#!/usr/bin/env python3
from __future__ import annotations

import asyncio
import logging
import sys
from pathlib import Path

# Позволяет запускать как `python main.py` из папки проекта
ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from bot.handlers import run_bot


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )
    asyncio.run(run_bot())


if __name__ == "__main__":
    main()
