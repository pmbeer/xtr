from __future__ import annotations

import logging
from typing import Any

from app.bitrix import BitrixClient, extract_file_ids
from app.config import Settings
from app.max_client import MaxClient
from app.storage import DedupStorage
from app.telegram_client import TelegramClient

logger = logging.getLogger(__name__)


class RelayService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.bitrix = BitrixClient(settings)
        self.telegram = TelegramClient(settings)
        self.max_client = MaxClient(settings)
        self.storage = DedupStorage(settings.dedup_db_path)

    async def handle_event(self, payload: dict[str, Any]) -> None:
        event = payload.get("event")
        if event != "ONIMBOTV2MESSAGEADD":
            return

        data = payload.get("data") or {}
        message = data.get("message") or {}
        chat = data.get("chat") or {}
        user = data.get("user") or {}
        bot = data.get("bot") or {}

        if self._is_true(message.get("isSystem")):
            logger.info("Skip system message")
            return

        author_id = str(message.get("authorId", ""))
        bot_id = str(bot.get("id", ""))
        if author_id and bot_id and author_id == bot_id:
            logger.info("Skip bot own message")
            return

        chat_id = str(chat.get("id", ""))
        if chat_id != str(self.settings.bitrix_source_chat_id):
            logger.info("Skip chat %s", chat_id)
            return

        message_id = int(message.get("id") or 0)
        if not message_id:
            logger.warning("Message without id")
            return

        if self.storage.is_processed(message_id):
            logger.info("Skip duplicate message %s", message_id)
            return

        text = (message.get("text") or "").strip()
        if self.settings.message_author_prefix:
            author_name = (user.get("name") or "").strip()
            if author_name and text:
                text = f"{author_name}:\n{text}"
            elif author_name and not text:
                text = author_name

        params = message.get("params") or {}
        file_ids = extract_file_ids(params)

        files = []
        for file_id in file_ids:
            try:
                files.append(await self.bitrix.download_file(file_id))
            except Exception as exc:  # noqa: BLE001
                logger.exception("Failed to download file %s: %s", file_id, exc)
                text = f"{text}\n\n⚠️ Не удалось скачать вложение (file_id={file_id})".strip()

        if not text and not files:
            logger.info("Empty message %s", message_id)
            return

        errors: list[str] = []
        try:
            await self.telegram.send_post(text, files)
        except Exception as exc:  # noqa: BLE001
            logger.exception("Telegram error: %s", exc)
            errors.append(f"Telegram: {exc}")

        try:
            await self.max_client.send_post(text, files)
        except Exception as exc:  # noqa: BLE001
            logger.exception("MAX error: %s", exc)
            errors.append(f"MAX: {exc}")

        if errors:
            raise RuntimeError("; ".join(errors))

        self.storage.mark_processed(message_id)
        logger.info("Relayed message %s with %s files", message_id, len(files))

    @staticmethod
    def _is_true(value: Any) -> bool:
        return str(value).lower() in {"1", "true", "yes", "y"}
