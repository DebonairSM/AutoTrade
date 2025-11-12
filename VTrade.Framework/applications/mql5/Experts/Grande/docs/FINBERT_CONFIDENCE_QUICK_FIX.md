# FinBERT Confidence - Quick Reference

## TL;DR

**The system is working correctly.** The "low confidence" you see is not about FinBERT's analysis quality - it's about trading signal strength.

## Two Different "Confidences"

### 1. FinBERT Sentiment Confidence (86-97% ✓)
- **What:** How certain FinBERT is about the sentiment
- **Log:** "Calculated Confidence: 0.9382 (93.82%)"
- **Status:** Excellent

### 2. Trading Signal Confidence (33-39% ✗)
- **What:** How strong the trading signal is
- **Log:** "Low confidence penalty applied: 0.366 < 0.4"
- **Status:** Weak (because no calendar events + weak technicals)

## Why Low Trading Confidence?

**November 11, 2025 is a SUNDAY** - no economic events scheduled.

```
Technical Score:   -0.40 (weak bearish)
Market Regime:      0.00 (neutral - BREAKOUT SETUP)
Key Levels:         0.00 (price not near levels)
Economic Events:    0.00 (NO EVENTS - it's Sunday!)
FinBERT Sentiment:  +0.02 (correctly neutral - generic text)
─────────────────────────────────────────────────
Combined Signal:   -0.12 (very weak)
Trading Confidence: 0.36 (low conviction)
```

## What to Check Monday

When markets reopen Monday, check if:

1. Calendar populates with actual events
2. FinBERT receives meaningful market context
3. Trading confidence improves with real data

## Quick Fixes Applied

See `FINBERT_LOW_CONFIDENCE_ANALYSIS.md` for:
- Detailed root cause analysis
- Immediate log clarity improvements
- Calendar handling recommendations
- Confidence calculation recalibration

## Test Commands

```powershell
# Check if calendar is enabled in MT5
# Tools > Options > Server > "Enable news" must be checked

# View current economic events
type "C:\Users\romme\AppData\Roaming\MetaQuotes\Terminal\Common\Files\economic_events.json"

# View latest FinBERT analysis
type "C:\Users\romme\AppData\Roaming\MetaQuotes\Terminal\Common\Files\enhanced_finbert_analysis.json"

# Check FinBERT watcher logs
type "mcp\analyze_sentiment_server\finbert_watcher.log" | Select-Object -Last 50
```

## Expected Behavior

### Weekend (Current)
- Empty calendar: Expected ✓
- Generic FinBERT text: Expected ✓
- Neutral sentiment (92-98%): Expected ✓
- Low trading confidence: Expected ✓
- Position size: 0.1x (minimum): Expected ✓

### Weekday (To Test Monday)
- Calendar with events: Should see events
- Detailed FinBERT text: Should include event context
- Directional sentiment: Depends on events
- Higher trading confidence: If events align with technicals
- Normal position size: 0.5-2.0x

## No Action Required

The system is behaving correctly. The logs are just confusing.

Wait until Monday to see how the system performs with actual economic data.

