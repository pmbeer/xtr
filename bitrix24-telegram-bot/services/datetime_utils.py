from __future__ import annotations

from datetime import datetime
from typing import Any, Optional


def parse_bitrix_datetime(value: Any) -> Optional[datetime]:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None

    text = text.replace("Z", "+00:00")
    # +03:00 already ok for fromisoformat; also handle space separator
    if " " in text and "T" not in text:
        text = text.replace(" ", "T", 1)

    try:
        dt = datetime.fromisoformat(text)
        return dt.replace(tzinfo=None)
    except ValueError:
        pass

    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%d.%m.%Y %H:%M:%S", "%Y-%m-%d"):
        try:
            return datetime.strptime(text[:19] if len(text) >= 19 and "T" in text else text, fmt)
        except ValueError:
            continue
    return None
