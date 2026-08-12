"""Исключения слоя Битрикс24."""

from __future__ import annotations

# Коды, которые Битрикс24 возвращает, когда метода нет на портале или он
# ещё не раскатан (новые методы статистики открытых линий).
METHOD_MISSING_CODES = frozenset(
    {
        "ERROR_METHOD_NOT_FOUND",
        "METHOD_NOT_FOUND",
        "METHOD_NOT_YET_AVAILABLE",
        "ERROR_MANIFEST_IS_NOT_AVAILABLE",
    }
)

ACCESS_DENIED_CODES = frozenset(
    {
        "ACCESS_DENIED",
        "INSUFFICIENT_SCOPE",
        "B24_TARIFF_RESTRICTION",
        "ALLOWED_ONLY_INTRANET_USER",
    }
)

AUTH_ERROR_CODES = frozenset(
    {
        "NO_AUTH_FOUND",
        "INVALID_CREDENTIALS",
        "INVALID_TOKEN",
        "EXPIRED_TOKEN",
        "WRONG_AUTH_TYPE",
    }
)


class Bitrix24Error(RuntimeError):
    """Ошибка, о которой сообщил сам Битрикс24."""

    def __init__(self, code: str, description: str = "", method: str = "") -> None:
        self.code = code or "UNKNOWN_ERROR"
        self.description = description or ""
        self.method = method
        message = f"{method}: {self.code}" if method else self.code
        if self.description:
            message = f"{message} — {self.description}"
        super().__init__(message)


class Bitrix24HTTPError(Bitrix24Error):
    """Транспортная ошибка: неожиданный HTTP-статус или нечитаемый ответ."""

    def __init__(self, status_code: int, body: str, method: str = "") -> None:
        self.status_code = status_code
        self.body = body
        super().__init__(f"HTTP_{status_code}", body[:500], method)


class MethodNotAvailableError(Bitrix24Error):
    """Метода нет на портале: не тот тариф, не та версия модуля, нет прав."""


class NotAuthorizedError(Bitrix24Error):
    """Вебхук отозван или указан неверно."""


class AccessDeniedError(Bitrix24Error):
    """У владельца вебхука не хватает прав на данные."""


def build_error(code: str, description: str, method: str) -> Bitrix24Error:
    """Подбирает класс исключения по коду ошибки Битрикс24."""
    normalized = (code or "").upper()
    if normalized in METHOD_MISSING_CODES:
        return MethodNotAvailableError(code, description, method)
    if normalized in AUTH_ERROR_CODES:
        return NotAuthorizedError(code, description, method)
    if normalized in ACCESS_DENIED_CODES:
        return AccessDeniedError(code, description, method)
    return Bitrix24Error(code, description, method)
