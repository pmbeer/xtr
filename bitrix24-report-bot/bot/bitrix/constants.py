"""Справочные константы Битрикс24, используемые в отчётах."""

from __future__ import annotations

# Коды статусов задач (поле REAL_STATUS в фильтре / "status" в ответе tasks.task.list).
# https://apidocs.bitrix24.ru/api-reference/tasks/tasks-task-list.html
TASK_STATUS_NEW = 1
TASK_STATUS_PENDING = 2
TASK_STATUS_IN_PROGRESS = 3
TASK_STATUS_SUPPOSEDLY_COMPLETED = 4
TASK_STATUS_COMPLETED = 5
TASK_STATUS_DEFERRED = 6
TASK_STATUS_DECLINED = 7

TASK_STATUS_LABELS: dict[int, str] = {
    TASK_STATUS_NEW: "Новая",
    TASK_STATUS_PENDING: "Ждёт выполнения",
    TASK_STATUS_IN_PROGRESS: "Выполняется",
    TASK_STATUS_SUPPOSEDLY_COMPLETED: "Ждёт контроля",
    TASK_STATUS_COMPLETED: "Завершена",
    TASK_STATUS_DEFERRED: "Отложена",
    TASK_STATUS_DECLINED: "Отклонена (снята)",
}

# Статусы, которые считаются "задачами в работе" (ещё не завершены и не отклонены).
ACTIVE_TASK_STATUSES = (
    TASK_STATUS_NEW,
    TASK_STATUS_PENDING,
    TASK_STATUS_IN_PROGRESS,
    TASK_STATUS_SUPPOSEDLY_COMPLETED,
    TASK_STATUS_DEFERRED,
)

TASK_PRIORITY_LABELS: dict[str, str] = {
    "0": "Низкий",
    "1": "Обычный",
    "2": "Высокий",
}

# PROVIDER_ID активности CRM, которую Битрикс24 создаёт для каждой сессии
# открытой линии, привязанной к элементу CRM (лид/сделка/контакт/компания).
# https://apidocs.bitrix24.com/api-reference/crm/timeline/activities/activity-base/crm-activity-list.html
OPENLINES_ACTIVITY_PROVIDER_ID = "IMOPENLINES_SESSION"

# TYPE_ID активности "дело/чат" в CRM.
CRM_ACTIVITY_TYPE_PROVIDER = 6
