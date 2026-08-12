"""Сборщики метрик по разделам Битрикс24."""

from .base import ERROR, OK, PARTIAL, UNAVAILABLE, Section
from .calls import CallsSection, collect_calls
from .crm import CrmSection, collect_crm
from .identity import User, resolve_user, resolve_user_names
from .openlines import OpenLinesSection, collect_openlines
from .tasks import TasksSection, collect_tasks

__all__ = [
    "ERROR",
    "OK",
    "PARTIAL",
    "UNAVAILABLE",
    "Section",
    "CallsSection",
    "CrmSection",
    "OpenLinesSection",
    "TasksSection",
    "User",
    "collect_calls",
    "collect_crm",
    "collect_openlines",
    "collect_tasks",
    "resolve_user",
    "resolve_user_names",
]
