"""Общий контракт сборщиков метрик."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field, is_dataclass
from datetime import datetime
from typing import Any

#: Раздел собран полностью.
OK = "ok"
#: Раздел собран частично — часть данных недоступна.
PARTIAL = "partial"
#: Раздела нет на портале: не подключён модуль, тариф или скоуп вебхука.
UNAVAILABLE = "unavailable"
#: Сбор упал с ошибкой, остальные разделы отчёта это не ломает.
ERROR = "error"


@dataclass
class Section:
    """Результат работы одного сборщика.

    Раздел всегда возвращается, даже если данные получить не удалось: отчёт
    честно показывает, что именно и почему осталось незаполненным.
    """

    name: str
    title: str
    status: str = OK
    notes: list[str] = field(default_factory=list)

    @property
    def available(self) -> bool:
        return self.status in (OK, PARTIAL)

    def note(self, text: str) -> None:
        if text not in self.notes:
            self.notes.append(text)

    def to_dict(self) -> dict[str, Any]:
        return _to_jsonable(asdict(self))


def _to_jsonable(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _to_jsonable(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_to_jsonable(item) for item in value]
    if isinstance(value, datetime):
        return value.isoformat()
    if is_dataclass(value) and not isinstance(value, type):
        return _to_jsonable(asdict(value))
    return value
