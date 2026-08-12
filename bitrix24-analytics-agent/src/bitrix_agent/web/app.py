from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from fastapi import FastAPI, Query, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from bitrix_agent.analytics.openlines import OpenLinesAnalytics
from bitrix_agent.analytics.report import build_activity_report
from bitrix_agent.client import BitrixAPIError, BitrixClient
from bitrix_agent.config import Settings, get_settings
from bitrix_agent.storage import AnalyticsStore

BASE_DIR = Path(__file__).resolve().parent
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    app = FastAPI(title="Bitrix24 Analytics Agent", version="1.0.0")
    app.state.settings = settings
    app.state.store = AnalyticsStore(settings.database_path)

    static_dir = BASE_DIR / "static"
    static_dir.mkdir(parents=True, exist_ok=True)
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

    def _client() -> BitrixClient:
        return BitrixClient(settings.require_webhook())

    @app.get("/", response_class=HTMLResponse)
    async def dashboard(
        request: Request,
        days: int = Query(default=None, ge=1, le=365),
        user_id: int | None = Query(default=None),
    ):
        period = days or settings.report_days
        uid = user_id or settings.bitrix24_user_id
        error = None
        report = None
        try:
            report = build_activity_report(
                _client(),
                user_id=uid,
                days=period,
                store=app.state.store,
            )
        except (BitrixAPIError, ValueError) as exc:
            error = str(exc)

        return templates.TemplateResponse(
            "dashboard.html",
            {
                "request": request,
                "report": report.to_dict() if report else None,
                "error": error,
                "days": period,
                "user_id": uid,
            },
        )

    @app.get("/api/report")
    async def api_report(
        days: int = Query(default=None, ge=1, le=365),
        user_id: int | None = Query(default=None),
    ):
        period = days or settings.report_days
        uid = user_id or settings.bitrix24_user_id
        try:
            report = build_activity_report(
                _client(),
                user_id=uid,
                days=period,
                store=app.state.store,
            )
            return JSONResponse(report.to_dict())
        except (BitrixAPIError, ValueError) as exc:
            return JSONResponse({"error": str(exc)}, status_code=400)

    @app.post("/webhook/bitrix")
    async def bitrix_webhook(request: Request):
        """Приём исходящих событий Bitrix24 (OnSessionStart / OnSessionFinish и др.)."""
        content_type = request.headers.get("content-type", "")
        payload: dict[str, Any]
        if "application/json" in content_type:
            payload = await request.json()
        else:
            form = await request.form()
            payload = {k: form.get(k) for k in form.keys()}
            # Bitrix often sends nested fields as JSON strings
            for key in list(payload.keys()):
                value = payload[key]
                if isinstance(value, str) and value[:1] in "{[":
                    try:
                        payload[key] = json.loads(value)
                    except json.JSONDecodeError:
                        pass

        event_name = str(
            payload.get("event")
            or payload.get("EVENT")
            or payload.get("event_name")
            or "UNKNOWN"
        )
        OpenLinesAnalytics(_client(), app.state.store).ingest_event(event_name, payload)
        return {"ok": True, "event": event_name}

    @app.post("/settings")
    async def save_hint():
        return RedirectResponse("/", status_code=303)

    return app


app = create_app()


def run() -> None:
    import uvicorn

    settings = get_settings()
    uvicorn.run(
        "bitrix_agent.web.app:app",
        host=settings.host,
        port=settings.port,
        reload=False,
    )


if __name__ == "__main__":
    run()
