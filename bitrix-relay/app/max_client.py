from __future__ import annotations

import asyncio
import logging

import httpx

from app.config import Settings
from app.media import MediaFile

logger = logging.getLogger(__name__)

MAX_API = "https://platform-api2.max.ru"
MAX_IMAGE_LIMIT_MB = 50
MAX_VIDEO_LIMIT_MB = 250
MAX_AUDIO_LIMIT_MB = 256


class MaxClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def _headers(self) -> dict[str, str]:
        return {"Authorization": self.settings.max_bot_token}

    async def send_post(self, text: str, files: list[MediaFile]) -> None:
        if not files:
            await self._send_text(text)
            return

        first = True
        for media in files:
            caption = text if first else ""
            await self._send_media(caption, media)
            first = False
            await asyncio.sleep(self.settings.max_send_delay)

    async def _send_text(self, text: str) -> None:
        if not text.strip():
            return
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                f"{MAX_API}/messages",
                params={"chat_id": self.settings.max_channel_chat_id},
                headers={**self._headers(), "Content-Type": "application/json"},
                json={"text": text, "notify": True},
            )
            self._ensure_ok(resp, "send text")

    async def _send_media(self, text: str, media: MediaFile) -> None:
        upload_type = self._resolve_upload_type(media)
        token = await self._upload(upload_type, media)
        body = {
            "text": text,
            "notify": True,
            "attachments": [{"type": upload_type, "payload": {"token": token}}],
        }

        for attempt in range(6):
            async with httpx.AsyncClient(timeout=120) as client:
                resp = await client.post(
                    f"{MAX_API}/messages",
                    params={"chat_id": self.settings.max_channel_chat_id},
                    headers={**self._headers(), "Content-Type": "application/json"},
                    json=body,
                )
            if resp.status_code == 200:
                return
            if "attachment.not.ready" in resp.text.lower():
                await asyncio.sleep(2 ** attempt)
                continue
            self._ensure_ok(resp, "send media")
        raise RuntimeError(f"MAX attachment not ready for {media.filename}")

    async def _upload(self, upload_type: str, media: MediaFile) -> str:
        async with httpx.AsyncClient(timeout=300) as client:
            upload_resp = await client.post(
                f"{MAX_API}/uploads",
                params={"type": upload_type},
                headers=self._headers(),
            )
            self._ensure_ok(upload_resp, "uploads")
            upload_data = upload_resp.json()
            upload_url = upload_data["url"]
            pre_token = upload_data.get("token")

            file_resp = await client.post(
                upload_url,
                files={"data": (media.filename, media.content, media.mime_type)},
            )
            if file_resp.status_code >= 400:
                raise RuntimeError(f"MAX file upload failed: {file_resp.text}")

            if pre_token:
                return pre_token

            try:
                payload = file_resp.json()
            except Exception:  # noqa: BLE001
                payload = {}
            token = payload.get("token")
            if not token:
                raise RuntimeError(f"MAX upload token missing for {media.filename}")
            return token

    def _resolve_upload_type(self, media: MediaFile) -> str:
        media_type = media.media_type
        if media_type == "image" and media.size_mb > MAX_IMAGE_LIMIT_MB:
            media_type = "file"
        if media_type == "video" and media.size_mb > MAX_VIDEO_LIMIT_MB:
            media_type = "file"
        if media_type == "audio" and media.size_mb > MAX_AUDIO_LIMIT_MB:
            media_type = "file"
        return media_type

    @staticmethod
    def _ensure_ok(resp: httpx.Response, action: str) -> None:
        if resp.status_code < 400:
            return
        raise RuntimeError(f"MAX {action} failed ({resp.status_code}): {resp.text}")
