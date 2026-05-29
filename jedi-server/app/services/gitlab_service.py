# ─────────────────────────────────────────────────────────────
#  JEDI – GitLab Integration Service
#  app/services/gitlab_service.py
# ─────────────────────────────────────────────────────────────
"""
Handles all interactions with the GitLab API:
  - Fetching the full diff for a Merge Request
  - Posting a JEDI security interception comment
  - Closing / requesting changes on an MR
"""
from __future__ import annotations

import gitlab
from gitlab.exceptions import GitlabError

from app.core.config import get_settings
from app.core.logging import get_logger
from app.schemas.gitlab_events import GitLabDiff, SecurityAnalysis

logger = get_logger(__name__)


def _build_comment(analysis: SecurityAnalysis, mr_url: str) -> str:
    """
    Format the professional JEDI interception comment with full markdown.
    """
    icon_map = {
        "low": "🟢",
        "medium": "🟡",
        "critical": "🔴",
    }
    threat_icon = icon_map.get(analysis.threat_level, "⚠️")

    lines = [
        "## 🛡️ JEDI Security Interception",
        "",
        f"> **Autonomous security scan triggered by JEDI** — Just-in-time Execution & Defense Interface",
        "",
        "---",
        "",
        f"### {threat_icon} Threat Assessment",
        "",
        f"| Field | Value |",
        f"|---|---|",
        f"| **Risk Score** | `{analysis.risk_score:.2f} / 1.00` |",
        f"| **Threat Level** | `{analysis.threat_level.upper()}` |",
        f"| **Decision** | `{analysis.action.upper()}` |",
        "",
        "### 🔍 Technical Reasoning",
        "",
        analysis.reasoning,
        "",
        "---",
        "",
        "⚡ *This MR has been automatically **closed** pending security review.*",
        "*A human security engineer must review and re-open this MR after remediation.*",
        "",
        f"🔗 [View MR]({mr_url})",
    ]
    return "\n".join(lines)


class GitLabService:
    """
    Service class wrapping `python-gitlab` for JEDI's autonomous actions.
    """

    def __init__(self) -> None:
        settings = get_settings()
        self._gl = gitlab.Gitlab(
            url=settings.gitlab_url,
            private_token=settings.gitlab_private_token,
            timeout=30,
        )
        logger.info("GitLab client initialised", url=settings.gitlab_url)

    def get_mr_diffs(self, project_id: int, mr_iid: int) -> list[GitLabDiff]:
        """
        Fetch the file-level diffs for a specific MR.
        Returns a list of GitLabDiff objects (one per changed file).
        """
        try:
            project = self._gl.projects.get(project_id)
            mr = project.mergerequests.get(mr_iid)
            changes = mr.changes()
            raw_diffs = changes.get("changes", [])
            diffs = [GitLabDiff(**d) for d in raw_diffs]
            logger.info(
                "Fetched MR diffs",
                project_id=project_id,
                mr_iid=mr_iid,
                file_count=len(diffs),
            )
            return diffs
        except GitlabError as exc:
            logger.error(
                "Failed to fetch MR diffs",
                project_id=project_id,
                mr_iid=mr_iid,
                error=str(exc),
            )
            raise

    def extract_diff_text(self, diffs: list[GitLabDiff]) -> str:
        """
        Concatenate all file diffs into a single text block
        for the AI to analyse holistically.
        """
        parts: list[str] = []
        for d in diffs:
            header = (
                f"File: {d.new_path}"
                + (" [NEW FILE]" if d.new_file else "")
                + (" [DELETED]" if d.deleted_file else "")
                + (" [RENAMED from " + d.old_path + "]" if d.renamed_file else "")
            )
            parts.append(f"{header}\n{d.diff}")
        return "\n\n".join(parts)

    def intercept_mr(
        self,
        project_id: int,
        mr_iid: int,
        analysis: SecurityAnalysis,
        mr_url: str,
    ) -> None:
        """
        Execute the full JEDI interception on a high-risk MR:
          1. Post a detailed security comment.
          2. Close the MR (state_event='close').
        """
        try:
            project = self._gl.projects.get(project_id)
            mr = project.mergerequests.get(mr_iid)

            # 1️⃣  Post the JEDI comment
            comment_body = _build_comment(analysis, mr_url)
            mr.notes.create({"body": comment_body})
            logger.info(
                "JEDI interception comment posted",
                project_id=project_id,
                mr_iid=mr_iid,
            )

            # 2️⃣  Close the MR
            mr.state_event = "close"
            mr.save()
            logger.warning(
                "MR automatically CLOSED by JEDI",
                project_id=project_id,
                mr_iid=mr_iid,
                risk_score=analysis.risk_score,
                threat_level=analysis.threat_level,
            )

        except GitlabError as exc:
            logger.error(
                "GitLab interception action failed",
                project_id=project_id,
                mr_iid=mr_iid,
                error=str(exc),
            )
            raise
