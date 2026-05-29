# ─────────────────────────────────────────────
#  JEDI – Configuration & Settings
#  app/core/config.py
# ─────────────────────────────────────────────
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Centralised settings object.  All values are loaded from `.env`
    (or real environment variables) via pydantic-settings.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ── Server ──────────────────────────────────────────────
    app_env: str = "development"
    log_level: str = "INFO"
    webhook_secret: str = ""

    # ── GitLab ──────────────────────────────────────────────
    gitlab_url: str = "https://gitlab.com"
    gitlab_private_token: str = ""

    # ── Google Cloud / Vertex AI / AI Studio ────────────────
    google_cloud_project: str = ""
    google_cloud_location: str = "us-central1"
    google_application_credentials: str = "./secrets/gcp_service_account.json"
    gemini_model: str = "gemini-2.0-flash"
    gemini_api_key: str = ""

    # ── Firebase ────────────────────────────────────────────
    firebase_credentials_path: str = "./secrets/firebase_service_account.json"

    # ── Thresholds ──────────────────────────────────────────
    risk_score_threshold: float = 0.75


@lru_cache
def get_settings() -> Settings:
    """Return a cached singleton Settings instance."""
    return Settings()
