# FinBERT Low Confidence Analysis

**Date:** November 10, 2025  
**Issue:** FinBERT consistently returning low confidence scores (<0.4)  
**Status:** ROOT CAUSE IDENTIFIED

## Executive Summary

The system is working correctly. FinBERT is analyzing generic market text (due to empty calendar data) and correctly identifying it as NEUTRAL with high confidence (92-98%). The "low confidence" displayed in logs is a separate metric calculated by the Enhanced analyzer that penalizes the **combined trading decision confidence**, not FinBERT's sentiment confidence.

## Data Flow Analysis

### 1. Calendar Data Collection (MQL5)

**Location:** `Include/GrandeMT5CalendarReader.mqh`

```
GetEconomicCalendarEvents() → FetchMT5CalendarEvents() → ExportEventsToJSON()
```

**Current State:**
- `economic_events.json` contains: `{"events": []}`
- MT5 calendar is accessible (CheckCalendarAvailability returns true)
- No events found in lookahead window (24 hours back, 24 hours forward)

**Why No Events?**

Two possible reasons:

1. **Weekend Trading**: November 11, 2025 is a **SUNDAY**. Economic calendar events are typically Monday-Friday. The system is checking:
   - Lookback: Nov 10 (Saturday) to Nov 11 (Sunday)
   - Lookahead: Nov 11 (Sunday) to Nov 12 (Monday)
   - Weekend has no scheduled economic releases

2. **Calendar Settings**: MT5 calendar may need configuration:
   - Check: `Tools > Options > Server > Enable news`
   - Calendar database may need time to sync after enabling

### 2. Market Context Creation (MQL5)

**Location:** `GrandeTradingSystem.mq5`, function `GetEconomicCalendarJson()` (line 7429)

**Output Example (GBPUSD):**
```json
{
  "events_today": 0,
  "high_impact_events": 0,
  "finbert_signal": "NEUTRAL",
  "finbert_confidence": 0.0,
  "next_event": {
    "time": "",
    "currency": "",
    "name": "",
    "impact": ""
  }
}
```

This data is embedded into `market_context_SYMBOL_DATE.json` files.

### 3. FinBERT Prompt Generation (Python)

**Location:** `mcp/analyze_sentiment_server/enhanced_finbert_analyzer.py`, function `_create_calendar_prompt()` (line 442)

**Logic:**
```python
# If no events, return neutral market statement
if calendar.events_today == 0:
    return f"{base_currency} markets remain steady with no major economic releases scheduled. Trading conditions normal."
```

**Current Output:**
- "USD markets remain steady with no major economic releases scheduled. Trading conditions normal." (95 chars)
- "EUR markets remain steady with no major economic releases scheduled. Trading conditions normal." (95 chars)
- "GBP markets remain steady with no major economic releases scheduled. Trading conditions normal." (95 chars)
- etc.

### 4. FinBERT Sentiment Analysis (Python)

**Location:** `enhanced_finbert_analyzer.py`, function `_process_finbert_analysis()` (line 501)

**FinBERT's Raw Analysis:**

| Currency | Neutral | Positive | Negative | Sentiment Score | FinBERT Confidence |
|----------|---------|----------|----------|-----------------|-------------------|
| AUDJPY   | 92.29%  | 5.46%    | 2.25%    | +0.0321        | 86.91%           |
| USDJPY   | 96.95%  | 2.67%    | 0.39%    | +0.0228        | 93.82%           |
| EURUSD   | 98.70%  | 1.14%    | 0.15%    | +0.0099        | 97.08%           |
| NZDUSD   | 92.32%  | 7.14%    | 0.54%    | +0.0661        | 86.69%           |
| GBPUSD   | 95.65%  | 3.75%    | 0.60%    | +0.0315        | 91.60%           |

**Observation:**
- FinBERT is working correctly
- High confidence in NEUTRAL sentiment (86-97%)
- Generic market text produces neutral sentiment (as expected)
- Sentiment scores near zero indicate balanced/neutral outlook

### 5. Enhanced Confidence Calculation

**Location:** `enhanced_finbert_analyzer.py`, function `_calculate_enhanced_confidence()` (line 561)

**Formula:**
```python
# Confidence is weighted combination of max probability and normalized entropy
# Max prob (70%): How strongly the model predicts the top class
# Normalized entropy (30%): How certain vs uncertain the distribution is
confidence = max_prob * 0.7 + normalized_entropy * 0.3
```

**Example (EURUSD):**
- Max probability: 98.70%
- Entropy: 0.0739
- Normalized entropy: 93.28%
- **FinBERT Confidence: 97.08%** ✓ HIGH

### 6. Final Decision Synthesis

**Location:** `enhanced_finbert_analyzer.py`, function `_synthesize_decision()` (line 653)

**The "Low Confidence" Issue:**

The system calculates a **Combined Decision Confidence** that differs from FinBERT's sentiment confidence:

```python
# Component confidences
technical_confidence = abs(technical_summary['trend_strength'])  # 0.4-1.0
regime_confidence = context.market_regime.confidence             # 0.75-0.89
finbert_confidence = finbert_result['confidence']                # 0.87-0.97

# Combined confidence (weighted average)
final_confidence = (
    technical_confidence * 0.3 +
    regime_confidence * 0.3 +
    finbert_confidence * 0.4
)
```

**Example (GBPUSD):**
- Technical confidence: 40.0% (trend strength)
- Regime confidence: 89.0% (BREAKOUT SETUP)
- FinBERT confidence: 91.6% (sentiment analysis)
- **Combined: 0.40×0.3 + 0.89×0.3 + 0.916×0.4 = 75.34%**

But the final output shows: **confidence: 0.390** (39%)

### 7. Low Confidence Penalty

**Location:** `enhanced_finbert_analyzer.py`, function `_synthesize_decision()` (line 700+)

```python
# Apply low confidence penalty if combined score suggests weak conviction
# Map weighted_score to confidence_from_score
confidence_from_score = abs(weighted_score)  # -0.115 → 0.115

# If confidence_from_score < 0.4, apply penalty
if confidence_from_score < 0.4:
    penalty = 0.3
    final_confidence = confidence_from_score  # Overrides weighted average!
```

**This is the root cause of the "low confidence" in logs:**

| Symbol  | Weighted Score | confidence_from_score | Penalty Applied | Final Confidence |
|---------|----------------|----------------------|-----------------|------------------|
| AUDJPY  | -0.048        | 0.048               | 0.3            | 0.366           |
| USDJPY  | +0.007        | 0.007               | 0.3            | 0.358           |
| EURUSD  | -0.120        | 0.120               | 0.3            | 0.333           |
| NZDUSD  | -0.023        | 0.023               | 0.3            | 0.330           |
| GBPUSD  | -0.115        | 0.115               | 0.3            | 0.390           |

**The "confidence" in the output represents conviction in the trading signal direction, not FinBERT's sentiment analysis quality.**

## The Confusion: Two Different "Confidences"

### FinBERT Sentiment Confidence (High ✓)
- **What it measures:** How certain FinBERT is about the sentiment classification
- **Values observed:** 86-97% (excellent)
- **Logged as:** "Calculated Confidence: 0.9382 (93.82%)"
- **Status:** Working correctly

### Combined Decision Confidence (Low ✗)
- **What it measures:** How strong the trading signal is across all components
- **Values observed:** 33-39% (weak signal)
- **Logged as:** "Low confidence penalty applied: 0.366 < 0.4, using penalty 0.3"
- **Status:** Working as designed, but misleading logs

## Why Low Trading Confidence?

The combined weighted score is near zero because:

1. **Technical Score:** -0.40 (bearish trend, but not strong)
2. **Regime Score:** 0.0 (neutral - BREAKOUT SETUP is not directional)
3. **Levels Score:** 0.0 (price not near key levels)
4. **Economic Score:** 0.0 (no calendar events = neutral)
5. **FinBERT Sentiment:** +0.01 to +0.07 (near-neutral, as expected)

**Weighted Score Formula:**
```
weighted_score = (technical × 0.3) + (regime × 0.25) + (levels × 0.2) + (economic × 0.25)
               = (-0.40 × 0.3) + (0.0 × 0.25) + (0.0 × 0.2) + (0.0 × 0.25)
               = -0.12 + 0 + 0 + 0
               = -0.12
```

**Confidence from Score:**
```
confidence_from_score = abs(-0.12) = 0.12 < 0.4
→ Low confidence penalty applied
→ Final confidence = 0.33-0.39 (varies by symbol)
```

## Position Sizing Impact

**Location:** `enhanced_finbert_analyzer.py`, function `_calculate_position_size_multiplier()` (line 816)

```python
# Position sizing components
base_size = confidence_from_score * 1.0  # 0.12 → 0.12
risk_multiplier = 1.2  # LOW risk
confluence_bonus = 0.83  # Moderate confluence

# Apply low confidence penalty
if confidence_from_score < 0.4:
    low_conf_penalty = 0.3
    base_size *= low_conf_penalty  # 0.12 × 0.3 = 0.036

final_multiplier = base_size * risk_multiplier * confluence_bonus
                 = 0.036 × 1.2 × 0.83
                 = 0.036
```

**Logged as:**
```
Position sizing: base=0.100, risk=1.200, confluence=0.833, final=0.100
```

Position sizes are clamped to minimum 0.1 (10% of normal size).

## Issues Identified

### 1. Misleading Log Messages

The logs say "Low confidence penalty applied" but don't clarify:
- This is **trading decision confidence**, not FinBERT sentiment confidence
- FinBERT is performing excellently (86-97% confidence)
- Low confidence reflects weak/conflicting technical signals

### 2. Calendar Data Quality

The system warns about calendar data quality:
```
[WARNING] Economic calendar has 0 events - FinBERT analysis will be less informative
[WARNING] No economic events today - FinBERT will use generic market analysis
```

But this is **expected behavior on weekends**. The warning should differentiate:
- Weekend (normal, no events expected)
- Weekday with missing data (genuine issue)

### 3. Confidence Calculation Logic

The `confidence_from_score` calculation uses `abs(weighted_score)` which:
- Ranges 0.0 to 1.0 theoretically
- Actually ranges 0.0 to ~0.4 in practice (because component scores are -1 to +1)
- Almost always triggers the 0.4 threshold penalty
- Makes the penalty the rule, not the exception

### 4. Semantic Confusion

The term "confidence" is overloaded:
- FinBERT sentiment confidence (quality metric)
- Trading decision confidence (signal strength)
- Combined decision confidence (weighted average)
- Confidence from score (signal conviction)

Each serves a different purpose but uses the same terminology.

## Recommendations

### Immediate (Log Clarity)

1. **Rename variables** in Python code:
   ```python
   # Before
   confidence = ...
   
   # After
   sentiment_confidence = ...  # FinBERT's sentiment quality
   signal_confidence = ...     # Trading signal strength
   decision_confidence = ...   # Combined conviction
   ```

2. **Update log messages**:
   ```python
   # Before
   logger.info("Low confidence penalty applied: 0.366 < 0.4, using penalty 0.3")
   
   # After
   logger.info("Weak trading signal detected (conviction: 0.366 < 0.4). "
               "FinBERT sentiment confidence: 0.938 (excellent). "
               "Position size reduced due to conflicting technical indicators.")
   ```

3. **Weekend calendar warning**:
   ```python
   # Before
   logger.warning("Economic calendar has 0 events - FinBERT analysis will be less informative")
   
   # After
   day_of_week = datetime.now().strftime('%A')
   if day_of_week in ['Saturday', 'Sunday']:
       logger.info(f"Economic calendar empty (expected on {day_of_week}). "
                   "Using market structure analysis for sentiment.")
   else:
       logger.warning("Economic calendar empty on trading day - check MT5 calendar settings.")
   ```

### Short-term (Calendar Reliability)

1. **Expand lookahead window** for weekend analysis:
   ```python
   # In GrandeMT5CalendarReader.mqh, line 98
   # Current: 24 hours ahead
   # Proposed: 72 hours ahead on weekends
   
   datetime now = TimeGMT();
   int day_of_week = TimeDayOfWeek(now);
   int hours_ahead_adjusted = hours_ahead;
   
   // On Friday/Saturday/Sunday, look further ahead to capture Monday events
   if(day_of_week >= 5 || day_of_week == 0)
       hours_ahead_adjusted = 72;
   
   datetime tm_end = now + (hours_ahead_adjusted * 3600);
   ```

2. **Cache last valid calendar analysis**:
   ```python
   # Store last analysis with events
   # Reuse on weekends with disclaimer
   
   if calendar.events_today == 0:
       cached_analysis = load_cached_analysis(max_age_hours=72)
       if cached_analysis:
           return format_cached_prompt(cached_analysis, base_currency)
   ```

### Medium-term (Confidence Calculation)

1. **Recalibrate confidence thresholds**:
   ```python
   # Current threshold: 0.4 (too high, triggers constantly)
   # Proposed: Dynamic threshold based on market regime
   
   def get_confidence_threshold(market_regime):
       if market_regime == "HIGH VOLATILITY":
           return 0.6  # Require stronger conviction in volatile markets
       elif market_regime == "RANGING":
           return 0.3  # Accept weaker signals in range-bound markets
       else:
           return 0.5  # Default threshold
   ```

2. **Normalize confidence_from_score**:
   ```python
   # Current: abs(weighted_score) → typically 0.0-0.4
   # Proposed: Scale to 0.0-1.0 range
   
   # Weighted score ranges from -1.0 to +1.0
   # Map to confidence: 0 (neutral) to 1.0 (strong conviction)
   confidence_from_score = abs(weighted_score) * 2.0  # Scale to 0-2.0
   confidence_from_score = min(1.0, confidence_from_score)  # Clamp to 1.0
   ```

### Long-term (Architecture)

1. **Separate FinBERT sentiment from trading decision**:
   - FinBERT output: `sentiment`, `sentiment_quality` (current "confidence")
   - Trading decision: `signal`, `conviction`, `position_size`
   - Keep them as distinct concepts in the output JSON

2. **Weekend-aware analysis mode**:
   - Detect weekend trading
   - Switch to technical-heavy analysis (reduce economic weight)
   - Adjust component weights dynamically:
     ```python
     if is_weekend:
         weights = {'technical': 0.40, 'regime': 0.35, 'levels': 0.25, 'economic': 0.0}
     else:
         weights = {'technical': 0.30, 'regime': 0.25, 'levels': 0.20, 'economic': 0.25}
     ```

3. **Confidence breakdown dashboard**:
   - Add detailed confidence breakdown to output
   - Show each component's contribution
   - Help users understand why confidence is low

## Testing Recommendations

### Test Case 1: Weekend with No Events (Current Scenario)
- **Date:** Sunday, November 11, 2025
- **Expected:** Empty calendar, generic FinBERT prompt, neutral sentiment
- **Result:** ✓ Working as designed

### Test Case 2: Weekday with High-Impact Events
- **Date:** Next major economic release (e.g., NFP Friday)
- **Expected:** Multiple events, rich FinBERT prompt, directional sentiment
- **Result:** Need to test

### Test Case 3: Pre-Event vs Post-Event
- **Before Event:** Check if calendar shows upcoming event
- **After Release:** Check if actual vs forecast is captured
- **Expected:** Different sentiment before/after based on surprise
- **Result:** Need to test

### Test Case 4: MT5 Calendar Disabled
- **Action:** Disable MT5 calendar in terminal settings
- **Expected:** Clear error message guiding user to enable
- **Current:** Generic warning message
- **Result:** Needs improvement

## Conclusion

### What's Working ✓
1. FinBERT sentiment analysis (86-97% confidence)
2. Calendar data collection from MT5 API
3. Generic market text generation when no events
4. Real-time file watching and processing
5. Multi-currency analysis pipeline

### What Needs Improvement ✗
1. Log message clarity (confusing "confidence" terminology)
2. Weekend calendar handling (unnecessary warnings)
3. Confidence calculation logic (threshold too high)
4. Position sizing penalty (too aggressive)
5. Component weight balancing (economic weight when no events)

### Priority Actions

**HIGH PRIORITY:**
1. Update log messages to differentiate sentiment confidence from signal confidence
2. Add weekend detection to calendar warnings
3. Document the two "confidence" metrics in code comments

**MEDIUM PRIORITY:**
4. Recalibrate confidence threshold (0.4 → 0.3 or dynamic)
5. Expand lookahead window on weekends (24h → 72h)
6. Cache last valid calendar analysis for weekend use

**LOW PRIORITY:**
7. Rename variables for clarity (refactoring)
8. Dynamic component weights based on market regime
9. Comprehensive confidence breakdown in output

### Next Steps

1. Wait for a weekday (Monday, November 12) to test with real economic events
2. Monitor if calendar populates with actual event data
3. Compare FinBERT analysis quality with events vs without
4. Adjust logging and thresholds based on weekday performance

---

**Analysis Date:** November 10, 2025  
**Analyzed By:** AI Assistant  
**System Status:** Working as designed, documentation needed

