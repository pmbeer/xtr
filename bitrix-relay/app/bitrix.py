from __future__ import annotations

import asyncio
import logging
from typing import Any

import httpx

from app.config import Settings
from app.media import MediaFile, build_media, filename_from_content_disposition

logger = logging.getLogger(__name__)


def parse_php_form(flat: dict[str, str]) -> dict[str, Any]:
    """Преобразует плоские ключи data[message][text] в вложенный dict."""

    def set_path(root: dict[str, Any], path: list[str], value: str) -> None:
        cur: Any = root
        for key in path[:-1]:
            if key not in cur or not isinstance(cur[key], dict):
                cur[key] = {}
            cur = cur[key]
        last = path[-1]
        if last in cur:
            existing = cur[last]
            if isinstance(existing, list):
                existing.append(value)
            else:
                cur[last] = [existing, value]
        else:
            cur[last] = value

    result: dict[str, Any] = {}
    for key, value in flat.items():
        parts: list[str] = []
        token = ""
        for ch in key:
            if ch == "[":
                if token:
                    parts.append(token)
                    token = ""
            elif ch == "]":
                if token:
                    parts.append(token)
                    token = ""
            else:
                token += ch
        if token:
            parts.append(token)
        if parts:
            set_path(result, parts, value)
    return result


def extract_file_ids(params: dict[str, Any]) -> list[int]:
    raw = params.get("FILE_ID")
    if raw is None:
        return []
    if isinstance(raw, list):
        values = raw
    else:
        values = [raw]
    ids: list[int] = []
    for item in values:
        try:
            ids.append(int(item))
        except (TypeError, ValueError):
            continue
    return ids


class BitrixClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    async def download_file(self, file_id: int) -> MediaFile:
        last_error: Exception | None = None
        for attempt in range(4):
            try:
                return await self._download_once(file_id)
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                wait = 1.5 * (attempt + 1)
                logger.warning("Retry file %s in %.1fs: %s", file_id, wait, exc)
                await asyncio.sleep(wait)
        raise RuntimeError(f"Cannot download Bitrix file {file_id}: {last_error}")

    async def _download_once(self, file_id: int) -> MediaFile:
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                f"{self.settings.bitrix_webhook_url}imbot.v2.File.download",
                json={
                    "botId": self.settings.bitrix_bot_id,
                    "botToken": self.settings.bitrix_bot_token,
                    "fileId": file_id,
                },
            )
            resp.raise_for_status()
            payload = resp.json()
            if "error" in payload:
                raise RuntimeError(payload.get("error_description") or payload["error"])

            download_url = payload["result"]["downloadUrl"]
            file_resp = await client.get(download_url)
            file_resp.raise_for_status()

            filename = filename_from_content_disposition(
                file_resp.headers.get("content-disposition")
            ) or f"file_{file_id}"
            mime = file_resp.headers.get("content-type")
            return build_media(file_resp.content, filename, mime)
