# ─────────────────────────────────────────────────────────────
#  JEDI – Webhook Router
#  app/api/webhook.py
# ─────────────────────────────────────────────────────────────
"""
Secure GitLab webhook endpoint.

Security:
  - X-Gitlab-Token header validation (HMAC-free shared-secret approach
    as per GitLab's own spec) — constant-time comparison prevents
    timing attacks.
  - Event routing: only MR and Push events are processed.

Pipeline per MR event:
  1. Validate webhook secret
  2. Route event type
  3. Fetch full MR diff from GitLab API
  4. Send diff to Gemini AI for analysis
  5. If high-risk → intercept MR (comment + close)
  6. Push event to Firestore
  7. Return 200 OK quickly (heavy work is async)
"""
from __future__ import annotations

import asyncio
import hashlib
import hmac

from fastapi import APIRouter, BackgroundTasks, Header, HTTPException, Request, status
from pydantic import ValidationError

from app.core.config import get_settings
from app.core.logging import get_logger
from app.schemas.gitlab_events import GitLabMREvent, GitLabPushEvent
from app.services.ai_service import AISecurityService
from app.services.firebase_service import FirebaseService
from app.services.gitlab_service import GitLabService

router = APIRouter(prefix="/webhook", tags=["Webhook"])
logger = get_logger(__name__)

# ── Service singletons (lazy-initialised once per worker) ─────
_ai_service: AISecurityService | None = None
_gitlab_service: GitLabService | None = None
_firebase_service: FirebaseService | None = None


def _get_services() -> tuple[AISecurityService, GitLabService, FirebaseService]:
    global _ai_service, _gitlab_service, _firebase_service
    if _ai_service is None:
        _ai_service = AISecurityService()
    if _gitlab_service is None:
        _gitlab_service = GitLabService()
    if _firebase_service is None:
        _firebase_service = FirebaseService()
    return _ai_service, _gitlab_service, _firebase_service


# ── Secret validation ─────────────────────────────────────────

def _validate_gitlab_token(provided: str | None) -> None:
    """
    Constant-time comparison of the X-Gitlab-Token header.
    Raises HTTP 401 if the token is missing or wrong.
    """
    settings = get_settings()
    expected = settings.webhook_secret

    # Skip validation if no secret is configured (dev mode only)
    if not expected:
        logger.warning("No WEBHOOK_SECRET configured — skipping token validation")
        return

    if not provided:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing X-Gitlab-Token header",
        )

    # hmac.compare_digest is constant-time
    if not hmac.compare_digest(provided.encode(), expected.encode()):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid webhook token",
        )


# ── Background pipeline ───────────────────────────────────────

async def _run_mr_pipeline(
    ai: AISecurityService,
    gl: GitLabService,
    fb: FirebaseService,
    event: GitLabMREvent,
) -> None:
    """
    Full async pipeline for a Merge Request event.
    Runs in the background so the HTTP response returns immediately.
    """
    settings = get_settings()
    project_id = event.project_id
    mr_iid = event.mr_iid
    repo_name = event.repo_name
    author = event.author
    mr_url = event.object_attributes.url

    try:
        # 1. Fetch diffs
        diffs = gl.get_mr_diffs(project_id, mr_iid)
        if not diffs:
            logger.info("No diffs found for MR — skipping analysis", mr_iid=mr_iid)
            return
        diff_text = gl.extract_diff_text(diffs)

        # 2. AI analysis (async)
        analysis = await ai.analyze_diff(diff_text, repo_name, author)

        # 3. Autonomous interception if threshold crossed
        status_code = "approved"
        if analysis.requires_intervention(settings.risk_score_threshold):
            logger.warning(
                "🛡️ JEDI INTERCEPTION TRIGGERED",
                mr_iid=mr_iid,
                risk_score=analysis.risk_score,
                threat_level=analysis.threat_level,
            )
            # Run GitLab blocking actions in thread (python-gitlab is sync)
            await asyncio.to_thread(
                gl.intercept_mr,
                project_id,
                mr_iid,
                analysis,
                mr_url,
            )
            status_code = "intercepted"

        # 4. Persist to Firestore (offloaded to thread)
        await asyncio.to_thread(
            fb.push_security_event,
            repo_name=repo_name,
            author=author,
            diff_text=diff_text,
            analysis=analysis,
            status_code=status_code,
            mr_url=mr_url,
            mr_iid=mr_iid,
        )

    except Exception as exc:  # noqa: BLE001
        logger.error(
            "MR pipeline failed",
            mr_iid=mr_iid,
            repo=repo_name,
            error=str(exc),
            exc_info=True,
        )


async def _run_push_pipeline(
    ai: AISecurityService,
    fb: FirebaseService,
    event: GitLabPushEvent,
) -> None:
    """
    Lightweight pipeline for Push events.
    Push events don't have an MR to comment on, so we just analyse
    the commit messages and log the result to Firestore.
    """
    repo_name = event.repo_name
    author = event.author

    try:
        # Build a synthetic diff from commit messages + file lists
        diff_parts: list[str] = []
        for commit in event.commits:
            part = f"Commit: {commit.id[:8]} — {commit.message.strip()}"
            if commit.added:
                part += f"\nAdded: {', '.join(commit.added)}"
            if commit.modified:
                part += f"\nModified: {', '.join(commit.modified)}"
            if commit.removed:
                part += f"\nRemoved: {', '.join(commit.removed)}"
            diff_parts.append(part)

        diff_text = "\n\n".join(diff_parts) or "No commit details available."

        analysis = await ai.analyze_diff(diff_text, repo_name, author)

        await asyncio.to_thread(
            fb.push_security_event,
            repo_name=repo_name,
            author=author,
            diff_text=diff_text,
            analysis=analysis,
            status_code="push_analysed",
        )

    except Exception as exc:  # noqa: BLE001
        logger.error(
            "Push pipeline failed",
            repo=repo_name,
            error=str(exc),
            exc_info=True,
        )


# ── Route handlers ────────────────────────────────────────────

@router.post(
    "/gitlab",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Receive GitLab webhook events",
    description=(
        "Secure endpoint for GitLab Push and Merge Request webhooks. "
        "Performs real-time AI security analysis and autonomous remediation."
    ),
)
async def gitlab_webhook(
    request: Request,
    background_tasks: BackgroundTasks,
    x_gitlab_token: str | None = Header(default=None, alias="X-Gitlab-Token"),
    x_gitlab_event: str | None = Header(default=None, alias="X-Gitlab-Event"),
) -> dict:
    # ── 1. Authenticate ──────────────────────────────────────
    _validate_gitlab_token(x_gitlab_token)

    # ── 2. Parse raw body ────────────────────────────────────
    try:
        body = await request.json()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid JSON payload: {exc}",
        ) from exc

    event_type = x_gitlab_event or body.get("object_kind", "")
    logger.info("Webhook received", event_type=event_type)

    ai, gl, fb = _get_services()

    # ── 3. Route by event type ───────────────────────────────

    if "Merge Request" in str(event_type) or body.get("object_kind") == "merge_request":
        try:
            event = GitLabMREvent(**body)
        except ValidationError as exc:
            logger.warning("MR payload validation failed", errors=exc.errors())
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=exc.errors(),
            ) from exc

        if not event.is_actionable():
            logger.info(
                "MR event not actionable — skipping",
                action=str(event.object_attributes.action),
            )
            return {"status": "skipped", "reason": "non-scannable event type"}

        background_tasks.add_task(_run_mr_pipeline, ai, gl, fb, event)
        return {
            "status": "accepted",
            "event": "merge_request",
            "mr_iid": event.mr_iid,
            "repo": event.repo_name,
        }

    elif "Push" in str(event_type) or body.get("object_kind") == "push":
        try:
            event = GitLabPushEvent(**body)
        except ValidationError as exc:
            logger.warning("Push payload validation failed", errors=exc.errors())
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=exc.errors(),
            ) from exc

        if not event.is_actionable():
            logger.info("Push event not actionable — deletion push, skipping")
            return {"status": "skipped", "reason": "deletion push"}

        background_tasks.add_task(_run_push_pipeline, ai, fb, event)
        return {
            "status": "accepted",
            "event": "push",
            "commits": event.total_commits_count,
            "repo": event.repo_name,
        }

    else:
        logger.info("Unhandled event type — ignoring", event_type=event_type)
        return {"status": "ignored", "event_type": event_type}
