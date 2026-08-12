from __future__ import annotations

import asyncio
import logging
from typing import Any

from fastapi import FastAPI, Request, Response

from app.bitrix import parse_php_form
from app.config import settings
from app.relay import RelayService

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("bitrix-relay")

app = FastAPI(title="Bitrix24 Relay", version="1.0.0")
relay = RelayService(settings)


@app.get("/health")
async def health() -> dict[str, Any]:
    missing = settings.validate_runtime()
    return {
        "status": "ok" if not missing else "misconfigured",
        "missing_env": missing,
    }


@app.post("/bitrix/webhook")
async def bitrix_webhook(request: Request) -> Response:
    form = await request.form()
    flat = {key: value for key, value in form.multi_items()}
    payload = parse_php_form(flat)

    auth = payload.get("auth") or {}
    app_token = auth.get("application_token")
    if settings.bitrix_app_token:
        if str(app_token) != settings.bitrix_app_token:
            logger.warning("Invalid application_token")
            return Response(content="forbidden", status_code=403)

    event = payload.get("event")
    logger.info("Incoming event: %s", event)

    asyncio.create_task(_safe_handle(payload))
    return Response(content="ok", status_code=200)


async def _safe_handle(payload: dict[str, Any]) -> None:
    try:
        await relay.handle_event(payload)
    except Exception:  # noqa: BLE001
        logger.exception("Relay failed")


def main() -> None:
    import uvicorn

    missing = settings.validate_runtime()
    if missing:
        logger.warning("Missing env vars: %s", ", ".join(missing))

    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=False,
        log_level="info",
    )


if __name__ == "__main__":
    main()
