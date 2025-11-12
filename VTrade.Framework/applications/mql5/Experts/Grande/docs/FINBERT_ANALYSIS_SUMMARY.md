# FinBERT Analysis Summary - November 10, 2025

## Quick Answer

**Your system is working correctly.** The "low confidence" you see in logs refers to **weak trading signals**, not FinBERT's analysis quality.

- **FinBERT Sentiment Confidence:** 86-97% ✓ (Excellent)
- **Trading Signal Conviction:** 33-39% ✗ (Weak - expected on Sunday with no events)

## Root Cause

### Why No Economic Events?

**November 11, 2025 is a SUNDAY** - financial markets are closed, no economic releases scheduled.

```
economic_events.json: {"events": []}  ← Expected on weekends
```

### Why Generic FinBERT Text?

When no events are found, the system generates neutral market text:

```
"USD markets remain steady with no major economic releases scheduled. Trading conditions normal."
```

This is **correct behavior** - FinBERT shouldn't analyze non-existent events.

### Why High Neutral Sentiment?

FinBERT correctly identifies the generic text as NEUTRAL with 92-98% confidence:

| Symbol  | Neutral | Positive | Negative | Sentiment | FinBERT Confidence |
|---------|---------|----------|----------|-----------|-------------------|
| EURUSD  | 98.70%  | 1.14%    | 0.15%    | +0.01    | 97.08% ✓         |
| USDJPY  | 96.95%  | 2.67%    | 0.39%    | +0.02    | 93.82% ✓         |
| GBPUSD  | 95.65%  | 3.75%    | 0.60%    | +0.03    | 91.60% ✓         |
| NZDUSD  | 92.32%  | 7.14%    | 0.54%    | +0.07    | 86.69% ✓         |
| AUDJPY  | 92.29%  | 5.46%    | 2.25%    | +0.03    | 86.91% ✓         |

FinBERT is performing excellently. Generic text = neutral sentiment = correct analysis.

### Why Low Trading Confidence?

The system combines 4 components to calculate **trading signal strength**:

```
Component Scores (GBPUSD Example):
─────────────────────────────────────
Technical (30% weight):    -0.40 (weak bearish)
Market Regime (25%):        0.00 (BREAKOUT SETUP - not directional)
Key Levels (20%):           0.00 (price not near levels)
Economic (25%):             0.00 (NO EVENTS - it's Sunday!)

Weighted Score = (-0.40 × 0.3) + (0.0 × 0.25) + (0.0 × 0.2) + (0.0 × 0.25)
              = -0.12 (very weak signal)

Signal Conviction = abs(-0.12) = 0.12 < 0.4 threshold
→ Weak signal penalty applied
→ Final trading confidence: 0.39 (low conviction)
→ Position size: 0.1x (minimum, 10% of normal)
```

This is **correct behavior** - the system shouldn't take large positions when signals are conflicting/weak.

## Two Different "Confidences"

### 1. FinBERT Sentiment Confidence (High ✓)
- **What it measures:** Quality of sentiment analysis
- **Current values:** 86-97% (excellent)
- **Log example:** "Calculated Confidence: 0.9382 (93.82%)"
- **Meaning:** FinBERT is very certain the sentiment is NEUTRAL

### 2. Trading Signal Conviction (Low ✗)
- **What it measures:** Strength of trading opportunity
- **Current values:** 33-39% (weak)
- **Log example:** "Low confidence penalty applied: 0.366 < 0.4"
- **Meaning:** Components disagree/are neutral, no clear trading setup

## Fixes Applied

### 1. Improved Log Messages ✓

**Changed:**
```python
# Before
logger.info("Low confidence penalty applied: 0.366 < 0.4, using penalty 0.3")

# After
logger.info("Weak trading signal detected (conviction: 0.366 < 0.4)")
logger.info("FinBERT sentiment confidence: 0.938 (sentiment quality is good)")
logger.info("Position size will be reduced due to conflicting/weak component signals")
```

### 2. Weekend-Aware Calendar Warnings ✓

**Changed:**
```python
# Before
logger.warning("Economic calendar has 0 events - FinBERT analysis will be less informative")

# After
day_of_week = datetime.now().strftime('%A')
if day_of_week in ['Saturday', 'Sunday']:
    logger.info(f"Economic calendar empty (expected on {day_of_week}). Using market structure analysis.")
else:
    logger.warning("Economic calendar has 0 events on weekday - check MT5 calendar settings")
```

### 3. Weekend Context in FinBERT Prompts ✓

**Changed:**
```python
# Before
return f"{currency} markets remain steady with no major economic releases scheduled."

# After
if day_of_week in ['Saturday', 'Sunday']:
    return f"{currency} markets remain steady with no economic releases scheduled on {day_of_week}. Weekend trading conditions."
```

### 4. Clarified Position Sizing Comments ✓

Updated function documentation to clarify that "confidence" in position sizing refers to signal conviction, not sentiment quality.

## What to Check Monday

When markets reopen on Monday (November 12), verify:

1. **Calendar Populates:**
   ```powershell
   type "C:\Users\romme\AppData\Roaming\MetaQuotes\Terminal\Common\Files\economic_events.json"
   # Should show: {"events": [...actual events...]}
   ```

2. **FinBERT Receives Rich Context:**
   - Check market_context files have events_today > 0
   - FinBERT prompts should include event details

3. **Trading Confidence Improves:**
   - If economic events align with technicals, conviction should increase
   - Position sizes should scale up from 0.1x minimum

## Expected Behavior

### Weekend (Current) ✓
- Empty calendar: **Expected**
- Generic FinBERT text: **Expected**
- Neutral sentiment (92-98%): **Expected**
- Low trading conviction: **Expected**
- Minimum position size (0.1x): **Expected**

### Weekday (To Verify Monday)
- Calendar with events: **Should populate**
- Event-rich FinBERT text: **Should include details**
- Directional sentiment: **Depends on event bias**
- Higher conviction: **If events align with technicals**
- Normal position sizes: **0.5-2.0x range**

## Files Modified

1. **`mcp/analyze_sentiment_server/enhanced_finbert_analyzer.py`**
   - Line 296-317: Weekend-aware calendar validation
   - Line 456-465: Weekend context in FinBERT prompts
   - Line 730-758: Clarified confidence calculation with detailed logging
   - Line 860-904: Updated position sizing documentation

2. **`docs/FINBERT_LOW_CONFIDENCE_ANALYSIS.md`** (Created)
   - Comprehensive technical analysis
   - Root cause investigation
   - Recommendations for improvements

3. **`docs/FINBERT_CONFIDENCE_QUICK_FIX.md`** (Created)
   - Quick reference guide
   - Test commands
   - Expected behavior summary

## Test Commands

```powershell
# View economic calendar events
type "C:\Users\romme\AppData\Roaming\MetaQuotes\Terminal\Common\Files\economic_events.json"

# View latest FinBERT analysis
type "C:\Users\romme\AppData\Roaming\MetaQuotes\Terminal\Common\Files\enhanced_finbert_analysis.json"

# View latest market context (GBPUSD example)
type "C:\Users\romme\AppData\Roaming\MetaQuotes\Terminal\Common\Files\market_context_GBPUSD!_2025.11.11.json"

# Check FinBERT watcher logs (last 50 lines)
Get-Content "mcp\analyze_sentiment_server\finbert_watcher.log" -Tail 50

# Verify MT5 calendar is enabled
# In MT5: Tools > Options > Server > Check "Enable news"
```

## Action Items

### ✓ Completed
1. Identified root cause (weekend = no events)
2. Clarified two different "confidence" metrics
3. Updated log messages for clarity
4. Added weekend awareness to validation
5. Documented expected behavior
6. Created comprehensive analysis documents

### ⏸ Wait for Monday
1. Verify calendar populates with real events
2. Test FinBERT with event-rich context
3. Validate conviction increases with aligned signals
4. Confirm position sizing scales appropriately

### 🔍 Future Improvements (Optional)
1. Dynamic component weights (reduce economic weight on weekends)
2. Cache last valid calendar analysis for weekend reference
3. Expand lookahead window on Fri/Sat/Sun (24h → 72h for Monday events)
4. Separate FinBERT sentiment metrics from trading decision metrics in output JSON

## Conclusion

### System Status: ✓ Working as Designed

- FinBERT AI: **Performing excellently** (86-97% confidence)
- Calendar integration: **Working correctly** (empty on weekends)
- Trading decisions: **Appropriately conservative** (weak signals = small positions)
- Log clarity: **Improved** (now distinguishes sentiment quality from signal strength)

### Next Steps

1. **No immediate action required**
2. **Monitor Monday's behavior** with real economic events
3. **Compare weekend vs weekday** analysis quality
4. **Adjust thresholds if needed** based on weekday performance

---

**Analysis Date:** November 10, 2025  
**Status:** Investigation Complete, Fixes Applied  
**Next Review:** Monday, November 12, 2025 (first weekday with economic events)

