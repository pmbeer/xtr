from __future__ import annotations

import logging

import httpx

from app.config import Settings
from app.media import MediaFile

logger = logging.getLogger(__name__)

TELEGRAM_FILE_LIMIT_MB = 50


class TelegramClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.base = f"https://api.telegram.org/bot{settings.telegram_bot_token}"

    async def send_post(self, text: str, files: list[MediaFile]) -> None:
        if not files:
            await self._send_text(text)
            return

        caption = text[:1024] if text else None
        for index, media in enumerate(files):
            current_caption = caption if index == 0 else None
            if media.size_mb > TELEGRAM_FILE_LIMIT_MB:
                await self._send_text(
                    self._oversize_notice(text if index == 0 else "", media)
                )
                continue
            await self._send_media(media, current_caption)
            caption = None

    async def _send_text(self, text: str) -> None:
        if not text.strip():
            return
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                f"{self.base}/sendMessage",
                json={
                    "chat_id": self.settings.telegram_channel_id,
                    "text": text,
                    "disable_web_page_preview": False,
                },
            )
            self._ensure_ok(resp, "sendMessage")

    async def _send_media(self, media: MediaFile, caption: str | None) -> None:
        method, field = self._resolve_method(media)
        data = {"chat_id": self.settings.telegram_channel_id}
        if caption:
            data["caption"] = caption

        async with httpx.AsyncClient(timeout=300) as client:
            resp = await client.post(
                f"{self.base}/{method}",
                data=data,
                files={field: (media.filename, media.content, media.mime_type)},
            )
            self._ensure_ok(resp, method)

    @staticmethod
    def _resolve_method(media: MediaFile) -> tuple[str, str]:
        if media.media_type == "image":
            return "sendPhoto", "photo"
        if media.media_type == "video":
            return "sendVideo", "video"
        if media.media_type == "audio":
            return "sendAudio", "audio"
        return "sendDocument", "document"

    @staticmethod
    def _oversize_notice(text: str, media: MediaFile) -> str:
        notice = (
            f"📎 {media.filename} ({media.size_mb:.1f} МБ) — "
            f"слишком большой для Telegram-бота (лимит {TELEGRAM_FILE_LIMIT_MB} МБ). "
            f"Смотрите полный файл в MAX."
        )
        return f"{text}\n\n{notice}".strip()

    @staticmethod
    def _ensure_ok(resp: httpx.Response, action: str) -> None:
        try:
            payload = resp.json()
        except Exception:  # noqa: BLE001
            resp.raise_for_status()
            return
        if not payload.get("ok"):
            raise RuntimeError(f"Telegram {action} failed: {payload}")
        resp.raise_for_status()
