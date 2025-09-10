import os
import re
import json
import logging
from typing import Any, Dict

from mcp.server.fastmcp import FastMCP, Context
from openai import OpenAI


# Basic logging (no secrets)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("mcp-analyze-sentiment")


def detect_pii(text: str) -> Dict[str, int]:
    """Very small PII heuristic: email and phone patterns.
    Returns counts per PII type (minimal, best-effort only).
    """
    findings: Dict[str, int] = {}
    email_matches = re.findall(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", text or "")
    phone_matches = re.findall(r"(?:\+?\d{1,3}[\s-]?)?(?:\(?\d{3}\)?[\s-]?)?\d{3}[\s-]?\d{4}", text or "")
    if email_matches:
        findings["email"] = len(email_matches)
    if phone_matches:
        findings["phone"] = len(phone_matches)
    return findings


def redact(text: str) -> str:
    """Redact email and phone-like patterns in logs only."""
    if not text:
        return text
    text = re.sub(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", "[REDACTED_EMAIL]", text)
    text = re.sub(r"(?:\+?\d{1,3}[\s-]?)?(?:\(?\d{3}\)?[\s-]?)?\d{3}[\s-]?\d{4}", "[REDACTED_PHONE]", text)
    return text


# Create MCP server
mcp = FastMCP("Grande Sentiment Server")


@mcp.tool()
async def analyze_sentiment(text: str, ctx: Context) -> Dict[str, Any]:
    """Analyze sentiment of text. Returns { sentiment, score[-1..1], confidence[0..1] }"""
    # Allow local OpenAI-compatible servers (e.g., Ollama/vLLM/NIM) via base URL
    base_url = os.environ.get("OPENAI_BASE_URL", "").strip()
    api_key = os.environ.get("OPENAI_API_KEY", "")
    if not api_key and base_url:
        # Many OpenAI-compatible servers ignore the key; provide a harmless placeholder
        api_key = os.environ.get("OPENAI_DUMMY_KEY", "EMPTY")
    if not api_key and not base_url:
        await ctx.error("Missing OPENAI_API_KEY (or set OPENAI_BASE_URL for local server)")
        return {"error": "Missing OPENAI_API_KEY"}

    model = os.environ.get("OPENAI_MODEL", "gpt-4o-mini")

    # Minimal PII scan + redacted log
    pii = detect_pii(text)
    if pii:
        logger.info("PII detected in request: %s", json.dumps(pii))
    logger.info("analyze_sentiment called with text(redacted): %s", redact(text)[:500])

    # Instantiate OpenAI client with optional base_url
    if base_url:
        logger.info("Using OpenAI-compatible endpoint: %s", base_url)
        client = OpenAI(api_key=api_key, base_url=base_url)
    else:
        client = OpenAI(api_key=api_key)

    # Ask for strict JSON output
    user_prompt = (
        "You are a precise sentiment classifier. "
        "Return strict JSON with keys sentiment(one of Positive, Neutral, Negative), "
        "score(a real number in [-1,1]), confidence(a real number in [0,1]). "
        "Text: " + text
    )

    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": user_prompt}],
            response_format={"type": "json_object"},
            temperature=0,
        )
        content = resp.choices[0].message.content
        data = json.loads(content)
        # Validate minimal keys
        sentiment = str(data.get("sentiment", ""))
        score = float(data.get("score", 0.0))
        confidence = float(data.get("confidence", 0.0))
        return {
            "sentiment": sentiment,
            "score": score,
            "confidence": confidence,
        }
    except Exception as e:
        await ctx.error(f"OpenAI call failed: {e}")
        return {"error": "Upstream failure"}


def main() -> None:
    # Default to stdio transport; switch by setting MCP_TRANSPORT=streamable-http
    transport = os.environ.get("MCP_TRANSPORT", "stdio").lower()
    if transport not in {"stdio", "streamable-http", "streamable_http"}:
        transport = "stdio"
    transport = "streamable-http" if transport.startswith("streamable") else "stdio"
    mcp.run(transport=transport)


if __name__ == "__main__":
    main()


