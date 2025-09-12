import os
import re
import json
import logging
from typing import Any, Dict

from mcp.server.fastmcp import FastMCP, Context
import httpx
from functools import lru_cache


# Basic logging (no secrets)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("mcp-analyze-sentiment")
# Lazy FinBERT loading
_finbert_ready = False

def _load_finbert_pipeline():
    global _finbert_ready
    if _finbert_ready:
        return
    try:
        import torch  # type: ignore
        from transformers import (
            AutoTokenizer,  # type: ignore
            AutoModelForSequenceClassification,  # type: ignore
            TextClassificationPipeline,  # type: ignore
        )
    except Exception as e:
        raise RuntimeError(f"FinBERT dependencies missing: {e}")

    model_name = os.environ.get("FINBERT_MODEL", "yiyanghkust/finbert-tone")
    logger.info("Loading FinBERT model: %s", model_name)
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForSequenceClassification.from_pretrained(model_name)
    device = 0 if getattr(torch, "cuda", None) and torch.cuda.is_available() else -1

    # cache pipeline on the function attribute to avoid globals clutter
    _load_finbert_pipeline.pipeline = TextClassificationPipeline(
        model=model,
        tokenizer=tokenizer,
        return_all_scores=True,
        device=device,
    )
    _finbert_ready = True

def _get_finbert_pipeline():
    _load_finbert_pipeline()
    return getattr(_load_finbert_pipeline, "pipeline")


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
    provider = os.environ.get("SENTIMENT_PROVIDER", "openai_compat").strip().lower()
    model = os.environ.get("OPENAI_MODEL", "gpt-4o-mini")

    # Provider-specific config
    base_url = os.environ.get("OPENAI_BASE_URL", "").strip()
    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    classifier_url = os.environ.get("CLASSIFIER_URL", "").strip()

    # Minimal PII scan + redacted log
    pii = detect_pii(text)
    if pii:
        logger.info("PII detected in request: %s", json.dumps(pii))
    logger.info("analyze_sentiment called with text(redacted): %s", redact(text)[:500])

    # Branch: dedicated classifier endpoint
    if provider == "classifier":
        if not classifier_url:
            await ctx.error("Missing CLASSIFIER_URL for classifier provider")
            return {"error": "Missing CLASSIFIER_URL"}
        try:
            with httpx.Client(timeout=30.0) as client:
                r = client.post(classifier_url, json={"text": text})
                r.raise_for_status()
                resp = r.json()
            # Flexible response parsing
            sentiment = str(resp.get("sentiment") or resp.get("label") or "").strip() or ""
            # score: prefer normalized [-1,1], else map class probs/conf to score if present
            score = resp.get("score")
            confidence = resp.get("confidence")
            # Attempt to map string probabilities if present
            if score is None:
                # try probs dict like {positive: p, neutral: p, negative: p}
                probs = resp.get("probs") or resp.get("probabilities") or {}
                if isinstance(probs, dict) and probs:
                    p_pos = float(probs.get("positive", 0.0))
                    p_neg = float(probs.get("negative", 0.0))
                    p_neu = float(probs.get("neutral", 0.0))
                    # heuristic score in [-1,1]
                    score = (p_pos - p_neg)
                    confidence = max(p_pos, p_neg, p_neu)
            # Fallbacks
            if score is None:
                score = 1.0 if sentiment.lower() == "positive" else -1.0 if sentiment.lower() == "negative" else 0.0
            if confidence is None:
                confidence = 1.0 if sentiment else 0.5
            return {
                "sentiment": sentiment,
                "score": float(score),
                "confidence": float(confidence),
            }
        except Exception as e:
            await ctx.error(f"Classifier call failed: {e}")
            return {"error": "Upstream failure"}

    # Branch: local FinBERT provider
    if provider == "finbert_local":
        try:
            pipe = _get_finbert_pipeline()
            preds = pipe(text)
            # preds is List[List[{label, score}]]; take first sample
            scores = preds[0] if isinstance(preds, list) else preds
            probs_by_label: Dict[str, float] = {}
            for item in scores:
                label = str(item.get("label", "")).lower()
                score_val = float(item.get("score", 0.0))
                probs_by_label[label] = score_val
            p_pos = float(probs_by_label.get("positive", probs_by_label.get("bullish", 0.0)))
            p_neg = float(probs_by_label.get("negative", probs_by_label.get("bearish", 0.0)))
            p_neu = float(probs_by_label.get("neutral", 0.0))
            # sentiment = argmax
            sentiment = "positive" if p_pos >= p_neg and p_pos >= p_neu else ("negative" if p_neg >= p_pos and p_neg >= p_neu else "neutral")
            score = p_pos - p_neg  # map to [-1,1] heuristically
            confidence = max(p_pos, p_neg, p_neu)
            return {
                "sentiment": sentiment.capitalize(),
                "score": float(score),
                "confidence": float(confidence),
            }
        except Exception as e:
            await ctx.error(f"FinBERT inference failed: {e}")
            return {"error": "Local model failure"}

    # Default branch: OpenAI-compatible HTTP server
    if not base_url:
        await ctx.error("Missing OPENAI_BASE_URL for local LLM endpoint (e.g., http://localhost:11434/v1)")
        return {"error": "Missing OPENAI_BASE_URL"}
    url = base_url.rstrip("/") + "/chat/completions"
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    # Ask for strict JSON output
    user_prompt = (
        "You are a precise sentiment classifier. "
        "Return strict JSON with keys sentiment(one of Positive, Neutral, Negative), "
        "score(a real number in [-1,1]), confidence(a real number in [0,1]). "
        "Text: " + text
    )

    try:
        payload = {
            "model": model,
            "messages": [{"role": "user", "content": user_prompt}],
            "response_format": {"type": "json_object"},
            "temperature": 0,
        }
        with httpx.Client(timeout=60.0) as client:
            r = client.post(url, headers=headers, json=payload)
            r.raise_for_status()
            resp = r.json()
        # Support both OpenAI and Ollama OpenAI-compat structures
        content = None
        try:
            content = resp["choices"][0]["message"]["content"]
        except Exception:
            # Some servers may return alternative fields; fall back to raw
            content = resp
        data = content if isinstance(content, dict) else json.loads(content)
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
    
    # Set environment variables for HTTP binding
    if transport == "streamable-http":
        os.environ["MCP_HOST"] = "0.0.0.0"
        os.environ["MCP_PORT"] = "8000"
    
    mcp.run(transport=transport)


if __name__ == "__main__":
    main()


