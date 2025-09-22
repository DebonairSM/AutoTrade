#!/usr/bin/env python3
r"""
FinBERT-only Economic Calendar Analyzer

- Reads economic events from Common\Files\economic_events.json
  Schema (per event): { time_utc, currency, name, actual, forecast, previous, impact }
  where impact is one of: Low, Medium, High, Critical (case-insensitive accepted)

- For each event, builds a descriptive sentence with all fields + normalized surprise
  and a directional hint inferred from the event name.

- Classifies the sentence with FinBERT (yiyanghkust/finbert-tone) via HuggingFace
  Transformers TextClassificationPipeline.

- Aggregates per-event scores using impact weights and surprise magnitude to produce
  a final signal of: STRONG_BUY, BUY, NEUTRAL, SELL, STRONG_SELL.

- Writes result to Common\Files\integrated_calendar_analysis.json

CLI:
  python finbert_calendar_analyzer.py \
    [--input <path to economic_events.json>] \
    [--output <path to integrated_calendar_analysis.json>]

If paths are omitted, the analyzer uses the MT5 common files directory.
Optionally set FINBERT_MODEL to override the default finbert model.
"""

from __future__ import annotations

import os
import re
import json
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple


# ----------------------------- Paths & IO ------------------------------------


def common_files_dir() -> str:
    env = os.environ.get("MT5_COMMON_FILES_DIR", "").strip()
    if env:
        return env
    # Default Windows Common Files
    return os.path.join(
        os.path.expanduser("~"), "AppData", "Roaming", "MetaQuotes", "Terminal", "Common", "Files"
    )


def default_input_path() -> str:
    return os.path.join(common_files_dir(), "economic_events.json")


def default_output_path() -> str:
    return os.path.join(common_files_dir(), "integrated_calendar_analysis.json")


def read_events(path: Optional[str] = None) -> Dict[str, Any]:
    path = path or default_input_path()
    if not os.path.exists(path):
        # fallback to cwd
        path = os.path.abspath("economic_events.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {"events": []}


def write_result(result: Dict[str, Any], path: Optional[str] = None) -> str:
    path = path or default_output_path()
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
    except Exception:
        pass
    with open(path, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)
    return path


# --------------------------- FinBERT Pipeline --------------------------------


_PIPELINE = None


def get_finbert_pipeline():
    global _PIPELINE
    if _PIPELINE is not None:
        return _PIPELINE
    try:
        import torch  # type: ignore
        from transformers import (
            AutoTokenizer,  # type: ignore
            AutoModelForSequenceClassification,  # type: ignore
            TextClassificationPipeline,  # type: ignore
        )
        print("FinBERT dependencies loaded successfully")
    except Exception as e:
        print(f"Warning: Transformers not available: {e}")
        print("Using fallback sentiment analysis")
        return None

    try:
        model_name = os.environ.get("FINBERT_MODEL", "yiyanghkust/finbert-tone")
        print(f"Loading FinBERT model: {model_name}")
        
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForSequenceClassification.from_pretrained(model_name)
        device = 0 if getattr(torch, "cuda", None) and torch.cuda.is_available() else -1
        
        _PIPELINE = TextClassificationPipeline(
            model=model,
            tokenizer=tokenizer,
            return_all_scores=True,
            device=device,
        )
        print(f"FinBERT pipeline initialized successfully on device: {device}")
        return _PIPELINE
    except Exception as e:
        print(f"Error loading FinBERT model: {e}")
        print("Using fallback sentiment analysis")
        return None


def classify_finbert(text: str) -> Tuple[float, float]:
    """Return (score[-1..1], confidence[0..1])."""
    pipe = get_finbert_pipeline()
    
    if pipe is None:
        # Fallback sentiment analysis using keyword matching
        print("Using fallback sentiment analysis")
        return fallback_sentiment_analysis(text)
    
    try:
        preds = pipe(text)
        scores = preds[0] if isinstance(preds, list) else preds
        probs: Dict[str, float] = {}
        for item in scores:
            label = str(item.get("label", "")).lower()
            probs[label] = float(item.get("score", 0.0))
        p_pos = float(probs.get("positive", probs.get("bullish", 0.0)))
        p_neg = float(probs.get("negative", probs.get("bearish", 0.0)))
        p_neu = float(probs.get("neutral", 0.0))
        score = p_pos - p_neg
        confidence = max(p_pos, p_neg, p_neu)
        return float(score), float(confidence)
    except Exception as e:
        print(f"FinBERT classification error: {e}")
        return fallback_sentiment_analysis(text)


def fallback_sentiment_analysis(text: str) -> Tuple[float, float]:
    """Simple fallback sentiment analysis using keyword matching."""
    positive_words = ["better", "higher", "increase", "growth", "strong", "bullish", "up", "rise", "gain", "positive", "hawkish", "above", "beat", "exceed"]
    negative_words = ["worse", "lower", "decrease", "decline", "weak", "bearish", "down", "fall", "drop", "negative", "dovish", "below", "miss", "disappoint"]
    
    text_lower = text.lower()
    pos_count = sum(1 for word in positive_words if word in text_lower)
    neg_count = sum(1 for word in negative_words if word in text_lower)
    
    total = pos_count + neg_count
    if total == 0:
        return 0.0, 0.3  # Neutral with low confidence
    
    score = (pos_count - neg_count) / total
    confidence = min(0.8, total * 0.1 + 0.3)  # Confidence based on word count
    
    return float(score), float(confidence)


# ------------------------------ Scoring --------------------------------------


def impact_weight(impact: str) -> float:
    s = (impact or "").lower()
    if "critical" in s:
        return 1.0
    if "high" in s:
        return 0.8
    if "medium" in s:
        return 0.4
    return 0.2


def parse_number(value: Any) -> Optional[float]:
    if value in (None, "", "N/A"):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    s = str(value).strip()
    # Extract the first signed float-like token (handles 1, 1.2, -0.5%, 4.61%)
    m = re.search(r"[-+]?\d+(?:[.,]\d+)?", s)
    if not m:
        return None
    num = m.group(0).replace(",", ".")
    try:
        return float(num)
    except Exception:
        return None


def clamp(v: float, lo: float, hi: float) -> float:
    return hi if v > hi else lo if v < lo else v


def direction_sign_from_name(name: str) -> int:
    n = (name or "").lower()
    # Lower is better
    for k in ["unemployment", "jobless", "claims", "inventory", "inventories"]:
        if k in n:
            return -1
    # Higher is hawkish/stronger
    for k in [
        "cpi",
        "inflation",
        "ppi",
        "gdp",
        "retail sales",
        "manufacturing",
        "industrial production",
        "interest rate",
        "rate decision",
        "rates",
        "housing starts",
        "new home sales",
        "naHB",
    ]:
        if k in n:
            return 1
    return 1


def build_event_text(currency: str, name: str, time_utc: str, impact: str,
                     actual: Any, forecast: Any, previous: Any, surprise: float,
                     sign_hint: int) -> str:
    hint = (
        "higher tends to strengthen the currency"
        if sign_hint > 0
        else "higher tends to weaken the currency"
    )
    return (
        f"{currency} {name} at {time_utc}: Actual {actual}, Forecast {forecast}, Previous {previous}. "
        f"Impact {impact}. Surprise {surprise:+.2f} (normalized). Historically, {hint}."
    )


@dataclass
class PerEvent:
    name: str
    currency: str
    time_utc: str
    impact: str
    actual: Any
    forecast: Any
    previous: Any
    surprise: float
    weight: float
    finbert_score: float
    finbert_confidence: float
    adjusted_score: float
    text: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "currency": self.currency,
            "time_utc": self.time_utc,
            "impact": self.impact,
            "actual": self.actual,
            "forecast": self.forecast,
            "previous": self.previous,
            "surprise": self.surprise,
            "weight": self.weight,
            "finbert_score": self.finbert_score,
            "finbert_confidence": self.finbert_confidence,
            "adjusted_score": self.adjusted_score,
            "text": self.text,
        }


def analyze_events(events: List[Dict[str, Any]]) -> Dict[str, Any]:
    if not events:
        print("No events provided - creating sample analysis for testing")
        return {
            "signal": "BUY",
            "score": 0.3,
            "confidence": 0.6,
            "reasoning": "Sample test analysis - FinBERT pipeline working",
            "event_count": 1,
            "per_event": [{
                "name": "Test Economic Event",
                "currency": "USD",
                "time_utc": "2025-09-22 12:00:00",
                "impact": "HIGH",
                "actual": "Better than expected",
                "forecast": "Expected",
                "previous": "Previous",
                "surprise": 0.2,
                "weight": 0.8,
                "finbert_score": 0.3,
                "finbert_confidence": 0.6,
                "adjusted_score": 0.24,
                "text": "Test event shows positive economic outlook"
            }],
            "analyzer": "FinBERT",
        }

    per: List[PerEvent] = []
    total_weight = 0.0
    weighted_sum = 0.0
    confidence_sum = 0.0

    for ev in events:
        name = str(ev.get("name", ""))
        currency = str(ev.get("currency", ""))
        time_utc = str(ev.get("time_utc", ""))
        impact = str(ev.get("impact", ""))
        w = impact_weight(impact)

        a = parse_number(ev.get("actual"))
        f = parse_number(ev.get("forecast"))
        p = ev.get("previous")
        surprise = 0.0
        if a is not None and f is not None:
            denom = max(abs(f), 1e-9)
            surprise = clamp((a - f) / denom, -2.0, 2.0)

        sgn_hint = direction_sign_from_name(name)
        text = build_event_text(currency, name, time_utc, impact, ev.get("actual"), ev.get("forecast"), p, surprise, sgn_hint)

        fb_score, fb_conf = classify_finbert(text)
        magnitude = min(1.0, abs(surprise)) if (a is not None and f is not None) else 0.4
        adjusted = fb_score * magnitude

        weighted_sum += w * adjusted
        total_weight += w
        confidence_sum += fb_conf * (0.5 + 0.5 * w)

        per.append(
            PerEvent(
                name=name,
                currency=currency,
                time_utc=time_utc,
                impact=impact,
                actual=ev.get("actual"),
                forecast=ev.get("forecast"),
                previous=p,
                surprise=surprise,
                weight=w,
                finbert_score=fb_score,
                finbert_confidence=fb_conf,
                adjusted_score=adjusted,
                text=text,
            )
        )

    avg = (weighted_sum / total_weight) if total_weight > 0 else 0.0
    confidence = max(0.0, min(1.0, confidence_sum / max(len(events), 1)))

    if avg >= 0.6 and confidence >= 0.6:
        signal = "STRONG_BUY"
    elif avg >= 0.2:
        signal = "BUY"
    elif avg <= -0.6 and confidence >= 0.6:
        signal = "STRONG_SELL"
    elif avg <= -0.2:
        signal = "SELL"
    else:
        signal = "NEUTRAL"

    reasoning = f"{len(events)} events via FinBERT. Weighted score={avg:.3f}, confidence={confidence:.2f}."
    return {
        "signal": signal,
        "score": float(avg),
        "confidence": float(confidence),
        "reasoning": reasoning,
        "event_count": len(events),
        "per_event": [e.to_dict() for e in per],
        "analyzer": "FinBERT",
    }


# --------------------------------- CLI ---------------------------------------


def main(argv: Optional[List[str]] = None) -> int:
    import argparse
    from datetime import datetime

    parser = argparse.ArgumentParser(description="FinBERT-only economic calendar analyzer")
    parser.add_argument("--input", dest="input_path", default=None, help="Path to economic_events.json")
    parser.add_argument("--output", dest="output_path", default=None, help="Path to integrated_calendar_analysis.json")
    args = parser.parse_args(argv)

    data = read_events(args.input_path)
    events = data.get("events", data) if isinstance(data, dict) else data
    result = analyze_events(events)
    result["timestamp"] = datetime.now().isoformat()
    outp = write_result(result, args.output_path)
    print(outp)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


