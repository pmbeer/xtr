"""Исключения агента."""

from __future__ import annotations


class AgentError(Exception):
    """Базовая ошибка агента."""


class ConfigError(AgentError):
    """Некорректная или неполная конфигурация."""


class TransportError(AgentError):
    """Сетевая ошибка или некорректный ответ портала."""


class Bitrix24Error(AgentError):
    """Портал вернул ошибку REST."""

    def __init__(self, method: str, code: str, description: str = "", status: int = 0):
        self.method = method
        self.code = code or "UNKNOWN_ERROR"
        self.description = description or ""
        self.status = status
        message = f"{method}: {self.code}"
        if self.description:
            message += f" — {self.description}"
        super().__init__(message)

    @property
    def is_method_missing(self) -> bool:
        """Метод не существует на портале или не входит в разрешённые скоупы."""
        return self.code in {
            "ERROR_METHOD_NOT_FOUND",
            "METHOD_NOT_FOUND",
            "METHOD_NOT_YET_AVAILABLE",
            "INVALID_REQUEST",
        }

    @property
    def is_access_denied(self) -> bool:
        """Не хватает прав пользователя или тарифа."""
        return self.code in {
            "ACCESS_DENIED",
            "INSUFFICIENT_SCOPE",
            "B24_TARIFF_RESTRICTION",
            "TARIFF_RESTRICTION",
            "NOT_ALLOWED",
            "ALLOWED_ONLY_INTRANET_USER",
        }
