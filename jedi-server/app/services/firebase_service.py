# ─────────────────────────────────────────────────────────────
#  JEDI – Firebase Firestore Sync Service
#  app/services/firebase_service.py
# ─────────────────────────────────────────────────────────────
"""
Synchronises every security analysis result to Firebase Firestore
in real-time so the Flutter dashboard can stream live events.

Collection schema  →  `security_events/{auto-id}`
{
  "timestamp":     Firestore server timestamp,
  "repo_name":     str,
  "author":        str,
  "diff_snippet":  str  (first 100 chars of combined diff),
  "risk_score":    float,
  "threat_level":  str,
  "ai_reasoning":  str,
  "status_code":   str  ("intercepted" | "approved"),
  "mr_url":        str | None,
  "mr_iid":        int | None,
}
"""
from __future__ import annotations

import firebase_admin
from firebase_admin import credentials, firestore

from app.core.config import get_settings
from app.core.logging import get_logger
from app.schemas.gitlab_events import SecurityAnalysis

logger = get_logger(__name__)

# ── Singleton initialisation guard ────────────────────────────
_firebase_initialised = False


def _init_firebase() -> None:
    global _firebase_initialised
    if _firebase_initialised:
        return

    settings = get_settings()
    cred = credentials.Certificate(settings.firebase_credentials_path)
    firebase_admin.initialize_app(cred)
    _firebase_initialised = True
    logger.info("Firebase Admin SDK initialised")


class FirebaseService:
    """
    Thin wrapper around the Firestore Admin client.
    Writes are synchronous (Firestore Admin SDK does not provide
    native asyncio support; for high-throughput use-cases, offload
    to a thread pool via asyncio.to_thread).
    """

    COLLECTION = "security_events"

    def __init__(self) -> None:
        _init_firebase()
        self._db = firestore.client()

    def push_security_event(
        self,
        *,
        repo_name: str,
        author: str,
        diff_text: str,
        analysis: SecurityAnalysis,
        status_code: str,
        mr_url: str | None = None,
        mr_iid: int | None = None,
    ) -> str:
        """
        Write a security event document to Firestore.
        Returns the auto-generated document ID.
        """
        doc_ref = self._db.collection(self.COLLECTION).document()

        payload = {
            "timestamp": firestore.SERVER_TIMESTAMP,
            "repo_name": repo_name,
            "author": author,
            "diff_snippet": diff_text[:100],
            "risk_score": analysis.risk_score,
            "threat_level": analysis.threat_level,
            "ai_reasoning": analysis.reasoning,
            "action": analysis.action,
            "status_code": status_code,
            "mr_url": mr_url,
            "mr_iid": mr_iid,
        }

        doc_ref.set(payload)

        logger.info(
            "Security event pushed to Firestore",
            doc_id=doc_ref.id,
            collection=self.COLLECTION,
            repo=repo_name,
            threat_level=analysis.threat_level,
        )
        return doc_ref.id
