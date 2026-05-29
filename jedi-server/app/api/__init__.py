# app/api/__init__.py
from app.api.webhook import router as webhook_router

__all__ = ["webhook_router"]
