# ─────────────────────────────────────────────────────────────
#  JEDI – FastAPI Application Entry Point
#  app/main.py
# ─────────────────────────────────────────────────────────────
"""
JEDI – Just-in-time Execution & Defense Interface
Autonomous AI Security Sentinel for CI/CD pipelines.

Start with:
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
"""
from __future__ import annotations

import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.webhook import router as webhook_router
from app.core.config import get_settings
from app.core.logging import get_logger, setup_logging

# ── Boot logging FIRST before any imports that might log ─────
setup_logging()
logger = get_logger(__name__)


# ── Lifespan (startup / shutdown) ────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    logger.info(
        "[JEDI] Sentinel starting",
        env=settings.app_env,
        project=settings.google_cloud_project,
        gemini_model=settings.gemini_model,
    )
    yield
    logger.info("[JEDI] Sentinel shutting down")


# ── App factory ───────────────────────────────────────────────

def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title="JEDI – Security Sentinel API",
        description=(
            "Autonomous AI security sentinel that intercepts code "
            "vulnerabilities in real-time via GitLab CI/CD webhooks."
        ),
        version="1.0.0",
        docs_url="/docs" if settings.app_env != "production" else None,
        redoc_url="/redoc" if settings.app_env != "production" else None,
        lifespan=lifespan,
    )

    # ── CORS (allow GitLab + ngrok origins) ──────────────────
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # Tighten in production
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ── Request logging middleware ────────────────────────────
    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        start = time.perf_counter()
        response = await call_next(request)
        duration_ms = (time.perf_counter() - start) * 1000
        logger.info(
            "HTTP request",
            method=request.method,
            path=request.url.path,
            status=response.status_code,
            duration_ms=round(duration_ms, 2),
        )
        return response

    # ── Global exception handler ──────────────────────────────
    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        logger.error(
            "Unhandled exception",
            path=request.url.path,
            error=str(exc),
            exc_info=True,
        )
        return JSONResponse(
            status_code=500,
            content={
                "error": "Internal server error",
                "detail": str(exc) if get_settings().app_env != "production" else None,
            },
        )

    # ── Routes ────────────────────────────────────────────────
    app.include_router(webhook_router)

    from fastapi.responses import RedirectResponse

    @app.get("/", include_in_schema=False)
    async def root():
        """Redirect the root URL to the API documentation."""
        return RedirectResponse(url="/docs")

    # ── Health check ──────────────────────────────────────────
    @app.get(
        "/health",
        tags=["Status"],
        summary="Health check",
        description="Returns the server status and configuration summary.",
    )
    async def health_check() -> dict:
        settings = get_settings()
        return {
            "status": "operational",
            "service": "JEDI Security Sentinel",
            "version": "1.0.0",
            "environment": settings.app_env,
            "ai_model": settings.gemini_model,
            "risk_threshold": settings.risk_score_threshold,
        }

    return app


app = create_app()
