# ─────────────────────────────────────────────
#  JEDI – Structured Logging Setup
#  app/core/logging.py
# ─────────────────────────────────────────────
import logging
import sys
import structlog

from app.core.config import get_settings


def setup_logging() -> None:
    """
    Configure stdlib logging + structlog for JSON-structured output.
    JSON logs are machine-parseable and Cloud Logging–compatible.
    """
    settings = get_settings()
    log_level = getattr(logging, settings.log_level.upper(), logging.INFO)

    # ── stdlib handler ───────────────────────────────────────
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=log_level,
    )

    # ── structlog processors ─────────────────────────────────
    shared_processors = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
    ]

    if settings.app_env == "production":
        renderer = structlog.processors.JSONRenderer()
    else:
        renderer = structlog.dev.ConsoleRenderer(colors=True)

    structlog.configure(
        processors=shared_processors + [renderer],
        wrapper_class=structlog.make_filtering_bound_logger(log_level),
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str) -> structlog.stdlib.BoundLogger:
    """Return a structlog logger bound to the given name."""
    return structlog.get_logger(name)
