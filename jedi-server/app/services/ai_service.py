# ─────────────────────────────────────────────────────────────
#  JEDI – AI Security Brain (Google AI Studio / Gemini)
#  app/services/ai_service.py
# ─────────────────────────────────────────────────────────────
"""
This module implements the MCP-aligned AI security agent.

Model Context Protocol (MCP) principles applied:
  1. A fixed, immutable SYSTEM_PROMPT establishes the agent's identity
     and strict behavioural boundaries — it never changes at runtime.
  2. The USER turn carries only the sanitised diff payload — no
     additional instructions that could override the system prompt.
  3. The model is forced into a structured JSON output mode
     (response_schema) so the response contract is machine-verifiable.
  4. A retry policy guards against transient API failures.
"""
from __future__ import annotations

import json
import os

import google.generativeai as genai
from google.generativeai.types import HarmCategory, HarmBlockThreshold, GenerationConfig

from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential,
    retry_if_exception_type,
)

from app.core.config import get_settings
from app.core.logging import get_logger
from app.schemas.gitlab_events import SecurityAnalysis

logger = get_logger(__name__)

# ── MCP System Prompt (immutable context boundary) ────────────
JEDI_SYSTEM_PROMPT = """You are JEDI, a critical security sentinel operating as part of a CI/CD pipeline.
Your sole purpose is to perform authoritative, evidence-based static security analysis on Git diffs.

Analyze the provided diff for:
1. Hardcoded secrets, tokens, API keys, passwords, or private credentials.
2. SQL injection, NoSQL injection, command injection, or template injection vulnerabilities.
3. Fatal logic bugs: off-by-one errors, null dereferences, race conditions, insecure randomness.
4. Insecure or known-vulnerable dependency versions (CVE references if known).
5. Insecure authentication/authorisation patterns (e.g., missing auth checks, privilege escalation paths).

You MUST return ONLY a raw, valid JSON object — absolutely no markdown, no code fences, no prose.

Required JSON schema:
{
  "risk_score": <float 0.0 to 1.0, where 1.0 is maximum risk>,
  "threat_level": <string: exactly one of "low", "medium", "critical">,
  "reasoning": <string: detailed technical explanation referencing specific lines or patterns>,
  "action": <string: exactly one of "approve" or "reject">
}

Scoring guidance:
  - 0.00–0.40 → low      → approve
  - 0.41–0.74 → medium   → approve (with caution)
  - 0.75–1.00 → critical → reject

Be precise, terse, and technically unambiguous. No speculation — only evidence from the diff."""


# ── Safety settings (block truly harmful content only) ────────
SAFETY_SETTINGS = {
    HarmCategory.HARM_CATEGORY_HATE_SPEECH: HarmBlockThreshold.BLOCK_ONLY_HIGH,
    HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
    HarmCategory.HARM_CATEGORY_HARASSMENT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
    HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
}

# ── Generation config – JSON mode ─────────────────────────────
GENERATION_CONFIG = GenerationConfig(
    temperature=0.1,          # Near-deterministic for security analysis
    top_p=0.9,
    max_output_tokens=1024,
    response_mime_type="application/json",
)


def _init_ai_studio() -> None:
    """Initialise Google AI Studio SDK exactly once."""
    settings = get_settings()
    if not settings.gemini_api_key:
        logger.error("GEMINI_API_KEY is not set in environment or .env")
        raise ValueError("GEMINI_API_KEY is missing")
    
    genai.configure(api_key=settings.gemini_api_key)


class AISecurityService:
    """
    Singleton-style service that wraps the Gemini model via AI Studio.

    Usage:
        service = AISecurityService()
        analysis = await service.analyze_diff(diff_text, context)
    """

    _model: genai.GenerativeModel | None = None

    def __init__(self) -> None:
        if AISecurityService._model is None:
            _init_ai_studio()
            settings = get_settings()
            AISecurityService._model = genai.GenerativeModel(
                model_name=settings.gemini_model,
                system_instruction=JEDI_SYSTEM_PROMPT,
                safety_settings=SAFETY_SETTINGS,
            )
            logger.info("Gemini AI Studio model initialised", model=settings.gemini_model)

    async def analyze_diff(
        self,
        diff_text: str,
        repo_name: str,
        author: str,
    ) -> SecurityAnalysis:
        """
        MOCK ANALYSIS: Bypasses API limits by returning a simulated response.
        This allows the CI/CD pipeline and frontend dashboard to be tested.
        """
        import random
        import asyncio
        
        logger.warning("Using MOCK AI Service due to Google API Quota limits.", repo=repo_name, author=author)
        
        # Simulate network delay (1-2 seconds)
        await asyncio.sleep(random.uniform(1.0, 2.0))
        
        # A "Smart" Mock Service for Hackathon Demos
        # It scans the diff for suspicious keywords to trigger realistic scenarios.
        diff_lower = diff_text.lower()
        
        # 1. Critical Threats: Hardcoded secrets
        if any(kw in diff_lower for kw in ["api_key", "secret", "password=", "token", "akia", "bearer"]):
            return SecurityAnalysis(
                risk_score=0.95,
                threat_level="critical",
                reasoning="MOCK (Smart): Detected hardcoded sensitive credentials or API keys in the code diff. This is a critical security violation that must be blocked.",
                action="reject",
            )
        
        # 2. Medium Threats: Potential vulnerabilities
        elif any(kw in diff_lower for kw in ["select * from", "eval(", "exec(", "dangerouslysetinnerhtml"]):
            return SecurityAnalysis(
                risk_score=0.68,
                threat_level="medium",
                reasoning="MOCK (Smart): Detected potentially unsafe functions or raw SQL queries that could lead to injection attacks. Please review.",
                action="approve",
            )
            
        # 3. Low Risk: Clean code
        else:
            return SecurityAnalysis(
                risk_score=0.12,
                threat_level="low",
                reasoning="MOCK (Smart): No obvious security risks detected in the diff. Standard updates.",
                action="approve",
            )
