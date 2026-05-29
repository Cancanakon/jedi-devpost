# ─────────────────────────────────────────────
#  JEDI – Pydantic Schemas for GitLab Webhooks
#  app/schemas/gitlab_events.py
# ─────────────────────────────────────────────
"""
Strict Pydantic v2 models that mirror the exact shape of GitLab's
webhook payloads for Merge Request and Push events.

GitLab docs:
  - MR  : https://docs.gitlab.com/ee/user/project/integrations/webhook_events.html#merge-request-events
  - Push: https://docs.gitlab.com/ee/user/project/integrations/webhook_events.html#push-events
"""
from __future__ import annotations

from typing import Any
from pydantic import BaseModel, Field
from enum import Enum


class StrEnum(str, Enum):
    """Python 3.10-compatible StrEnum (identical behaviour to 3.11's StrEnum)."""
    pass


# ── Shared sub-models ────────────────────────────────────────


class GitLabProject(BaseModel):
    id: int
    name: str
    web_url: str
    path_with_namespace: str


class GitLabAuthor(BaseModel):
    name: str
    email: str | None = None


class GitLabCommit(BaseModel):
    id: str
    message: str
    title: str | None = None
    timestamp: str | None = None
    url: str | None = None
    author: GitLabAuthor | None = None
    added: list[str] = Field(default_factory=list)
    modified: list[str] = Field(default_factory=list)
    removed: list[str] = Field(default_factory=list)


class GitLabDiff(BaseModel):
    """Single file diff as returned by GitLab's MR changes API."""
    diff: str
    new_path: str
    old_path: str
    new_file: bool = False
    renamed_file: bool = False
    deleted_file: bool = False


# ── Merge Request event ──────────────────────────────────────


class MRObjectKind(StrEnum):
    merge_request = "merge_request"


class MRState(StrEnum):
    opened = "opened"
    closed = "closed"
    merged = "merged"
    locked = "locked"


class MRAction(StrEnum):
    open = "open"
    close = "close"
    reopen = "reopen"
    update = "update"
    approved = "approved"
    unapproved = "unapproved"
    approval = "approval"
    unapproval = "unapproval"
    merge = "merge"


class MRObjectAttributes(BaseModel):
    id: int
    iid: int                             # MR number within the project
    title: str
    description: str | None = None
    state: MRState
    action: MRAction | None = None
    source_branch: str
    target_branch: str
    last_commit: GitLabCommit | None = None
    url: str
    work_in_progress: bool = False
    author_id: int | None = None


class MRUser(BaseModel):
    id: int
    name: str
    username: str
    avatar_url: str | None = None


class GitLabMREvent(BaseModel):
    """Top-level GitLab Merge Request webhook payload."""
    object_kind: MRObjectKind
    user: MRUser
    project: GitLabProject
    object_attributes: MRObjectAttributes
    changes: dict[str, Any] = Field(default_factory=dict)

    # ── Helpers ──────────────────────────────────────────────

    def is_actionable(self) -> bool:
        """
        Return True only for events that warrant a full security scan.
        Ignore comments, approvals, and WIP updates to save compute.
        """
        if self.object_attributes.work_in_progress:
            return False
        non_scannable = {
            MRAction.approved,
            MRAction.unapproved,
            MRAction.approval,
            MRAction.unapproval,
            MRAction.merge,  # already merged – nothing to block
        }
        return self.object_attributes.action not in non_scannable

    @property
    def repo_name(self) -> str:
        return self.project.path_with_namespace

    @property
    def author(self) -> str:
        return self.user.username

    @property
    def mr_iid(self) -> int:
        return self.object_attributes.iid

    @property
    def project_id(self) -> int:
        return self.project.id


# ── Push event ───────────────────────────────────────────────


class PushObjectKind(StrEnum):
    push = "push"


class GitLabPushEvent(BaseModel):
    """Top-level GitLab Push webhook payload."""
    object_kind: PushObjectKind
    event_name: str | None = None
    before: str
    after: str
    ref: str
    checkout_sha: str | None = None
    user_id: int
    user_name: str
    user_email: str | None = None
    project_id: int
    project: GitLabProject
    commits: list[GitLabCommit] = Field(default_factory=list)
    total_commits_count: int = 0

    def is_actionable(self) -> bool:
        """Ignore deletion pushes (after == 000...000)."""
        return self.after != "0" * 40 and bool(self.commits)

    @property
    def repo_name(self) -> str:
        return self.project.path_with_namespace

    @property
    def author(self) -> str:
        return self.user_name


# ── AI response schema ───────────────────────────────────────


class ThreatLevel(StrEnum):
    low = "low"
    medium = "medium"
    critical = "critical"


class AIAction(StrEnum):
    approve = "approve"
    reject = "reject"


class SecurityAnalysis(BaseModel):
    """Structured response returned by the Gemini AI security agent."""
    risk_score: float = Field(..., ge=0.0, le=1.0)
    threat_level: ThreatLevel
    reasoning: str
    action: AIAction

    def requires_intervention(self, threshold: float = 0.75) -> bool:
        return self.risk_score >= threshold or self.threat_level == ThreatLevel.critical
