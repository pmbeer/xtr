from __future__ import annotations

import mimetypes
import re
from dataclasses import dataclass

IMAGE_EXT = {"jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "tiff"}
VIDEO_EXT = {"mp4", "mov", "mkv", "webm", "avi", "m4v"}
AUDIO_EXT = {"mp3", "wav", "m4a", "ogg", "opus", "aac", "flac", "oga"}
VOICE_EXT = {"ogg", "opus"}


@dataclass
class MediaFile:
    content: bytes
    filename: str
    media_type: str  # image | video | audio | file
    mime_type: str
    size: int

    @property
    def size_mb(self) -> float:
        return self.size / (1024 * 1024)


def sanitize_filename(name: str, fallback: str = "file.bin") -> str:
    cleaned = re.sub(r"[^\w.\- ()\[\]]+", "_", name, flags=re.UNICODE).strip("._ ")
    return cleaned or fallback


def detect_media_type(filename: str, mime_type: str | None = None) -> str:
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    mime = (mime_type or mimetypes.guess_type(filename)[0] or "").lower()

    if ext in IMAGE_EXT or mime.startswith("image/"):
        return "image"
    if ext in VIDEO_EXT or mime.startswith("video/"):
        return "video"
    if ext in AUDIO_EXT or mime.startswith("audio/"):
        return "audio"
    return "file"


def filename_from_content_disposition(header: str | None) -> str | None:
    if not header:
        return None
    match = re.search(r"filename\*=UTF-8''([^;]+)", header, re.IGNORECASE)
    if match:
        return sanitize_filename(match.group(1))
    match = re.search(r'filename="?([^";]+)"?', header, re.IGNORECASE)
    if match:
        return sanitize_filename(match.group(1))
    return None


def build_media(content: bytes, filename: str, mime_type: str | None = None) -> MediaFile:
    safe_name = sanitize_filename(filename)
    media_type = detect_media_type(safe_name, mime_type)
    mime = mime_type or mimetypes.guess_type(safe_name)[0] or "application/octet-stream"
    return MediaFile(
        content=content,
        filename=safe_name,
        media_type=media_type,
        mime_type=mime,
        size=len(content),
    )
