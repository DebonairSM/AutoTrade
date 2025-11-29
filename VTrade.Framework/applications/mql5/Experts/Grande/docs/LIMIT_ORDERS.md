# Grande Trading System - Limit Order System

## Overview

Limit order system uses confluence analysis to place orders at optimal entry zones (support/resistance, Fibonacci levels, round numbers, EMAs) rather than market prices. Designed to improve entry prices and reduce slippage, particularly in ranging or pullback scenarios.

## Architecture

### Components

- **CGrandeLimitOrderManager** (`GrandeLimitOrderManager.mqh`) - Central limit order placement and lifecycle management
- **CGrandeConfluenceDetector** (`GrandeConfluenceDetector.mqh`) - Identifies high-probability entry zones
- **CGrandeKeyLevelDetector** (`GrandeKeyLevelDetector.mqh`) - Support/resistance levels
- **CGrandeFibonacciCalculator** (`GrandeFibonacciCalculator.mqh`) - Fibonacci retracement/extension levels
- **CGrandeCandleAnalyzer** (`GrandeCandleAnalyzer.mqh`) - Candle pattern analysis

### Data Flow

```
Signal Generation → Confluence Analysis → Limit Price Selection → Order Validation → Order Placement
                                                      ↓
                                              Regime Filtering
                                                      ↓
                                              Multi-Timeframe Validation
```

## Current Implementation

### Entry Conditions

**Trend Trades:**
- Regime: `REGIME_TREND_BULL` or `REGIME_TREND_BEAR` with confidence > threshold
- Price in pullback (distance from EMA within acceptable range)
- RSI in acceptable range (40-60 for entries)
- EMA alignment across timeframes (H1, H4, D1)
- Volume confirmation
- Key level proximity
- Signal quality score > minimum threshold
- No active cool-off period
- Risk checks pass

**Breakout Trades:**
- Regime: `REGIME_BREAKOUT_SETUP` or transitioning to trending
- Key level identified (resistance for buy, support for sell)
- Price approaching or near breakout level
- Volume spike confirmation
- Not a "strong momentum surge"
- Signal quality score > minimum threshold
- Risk checks pass

### Limit Price Placement

**Primary Method: Confluence Analysis**

`CGrandeConfluenceDetector::FindConfluenceZones()` analyzes:
- Key support/resistance levels
- Fibonacci retracement levels (23.6%, 38.2%, 50%, 61.8%, 78.6%)
- Round numbers (50-pip, 100-pip, major round numbers)
- EMA levels (20, 50, 200)
- Recent candle rejection wicks

**Selection Process:**
1. Zones scored based on confluence factors (weighted scoring)
2. Best zone selected: `GetBestConfluenceZone()` → `GetBestLimitOrderPrice()`
3. Zone must be within `maxLimitDistancePips` (default: 30 pips) from current price
4. Zone must align with trade direction

**Fallback:**
- If no confluence zone found, limit order is rejected (returns `NO_CONFLUENCE` error)
- System does NOT fall back to market orders when limit orders are enabled

### Order Lifecycle

**Duration:**
- Orders expire after `expirationHours` (default: 4 hours) from placement time

**Cancellation:**
- Stale orders cancelled if price moves > `staleOrderDistancePips` (default: 50 pips) away
- Expired orders cancelled
- Both methods run on every `OnTick()` cycle

**Adjustment:**
- Orders are NOT adjusted/repositioned when price moves away
- Orders are cancelled and must be re-placed if conditions still valid
- No dynamic price adjustment logic exists

**Fill Tracking:**
- No explicit fill tracking or fill rate metrics
- System relies on MT5's order status (filled orders become positions)

## Known Issues (From Analysis)

### Critical Issues

1. **No Multi-Timeframe Limit Price Validation**
   - Limit price determined solely from current timeframe confluence
   - Higher timeframes may invalidate zones
   - **Impact:** Orders may never fill if H4/D1 shows rejection

2. **No Regime-Based Limit Price Filtering**
   - Confluence zones selected without checking regime alignment
   - **Impact:** Orders may fill in wrong direction during strong trends

3. **No Limit Order Risk Aggregation**
   - Risk calculations don't account for pending limit orders
   - **Impact:** May over-leverage if multiple orders fill simultaneously

4. **Breakout Limit Orders Use Current Price as Base**
   - In `BreakoutTrade()`, limit order `basePrice` is set to current market price
   - **Impact:** Confluence analysis may find zones near current price instead of breakout level

### Important Issues

5. **Stale Order Cancellation Too Aggressive**
   - Orders cancelled if price moves >50 pips away
   - Not based on ATR or volatility
   - **Impact:** May prevent fills during legitimate pullbacks

6. **No Fill Rate Tracking or Analysis**
   - No metrics on fill rate, average time to fill, or reasons for non-fills
   - **Impact:** Cannot optimize limit price placement without data

7. **Limit Price Distance Validation Too Restrictive**
   - `maxLimitDistancePips` (30 pips) may be too small for volatile pairs
   - No ATR-based scaling
   - **Impact:** May reject valid confluence zones

### Minor Issues

8. **No Dynamic Limit Price Adjustment**
   - Once placed, limit orders never adjusted
   - **Impact:** Missed fills when price approaches but doesn't reach limit

9. **Duplicate Order Detection Too Simple**
   - Only checks if another order exists within 3 points
   - Does not consider order age or context
   - **Impact:** May prevent placing better-located orders

10. **No Limit Order Expiration Based on Market Conditions**
    - Orders expire after fixed 4 hours regardless of market conditions
    - **Impact:** Orders may expire before valid pullback or remain active during news

## Recommended Improvements

### Regime and Filters

**Regime-Based Limit Price Filtering:**
- Filter zones based on regime before selection
- Trending Bull: Only zones below current price (support levels)
- Trending Bear: Only zones above current price (resistance levels)
- Ranging: Zones at range boundaries
- Breakout Setup: Zones at breakout levels
- High Volatility: Avoid limit orders, use market orders

**Multi-Timeframe Regime Alignment:**
- Require regime alignment across H1, H4, D1 before placing limit orders
- Use D1 regime as "filter" - only place limit orders in direction of D1 trend

**Regime Confidence Thresholds:**
- Minimum regime confidence: 0.65 for limit orders (higher than market orders)
- If confidence < threshold, skip limit orders or use market orders

### Signal Formation

**Signal Quality Integration:**
- Require minimum signal quality score: 75/100 for limit orders (higher than market orders: 60/100)
- Limit orders are "premium" entries - only use for highest-quality setups

**Confluence Zone Validation:**
- Minimum confluence score: 6/10 (configurable)
- Require at least 3 confluence factors
- Zone must align with trade direction

**Multi-Timeframe Confluence:**
- Check confluence zones on H1, H4, D1
- Prefer zones that appear on multiple timeframes
- Weight zones by timeframe (D1 zones > H4 zones > H1 zones)

### Limit Price Formula

**Base Formula:**
```
limitPrice = bestConfluenceZone.price

Where bestConfluenceZone is selected from:
1. Filter zones by regime alignment
2. Filter zones by multi-timeframe validation
3. Filter zones within maxDistance (ATR-scaled)
4. Score zones with enhanced scoring (regime-weighted)
5. Select highest-scoring zone
```

**ATR-Based Distance Scaling:**
```
maxLimitDistancePips = baseMaxDistancePips * (currentATR / averageATR)

Where:
- baseMaxDistancePips = 30 (configurable)
- currentATR = current ATR value
- averageATR = 20-period average ATR
```

**Fill Probability Estimation:**
```
fillProbability = baseProbability * regimeFactor * confluenceFactor * timeframeFactor

Where:
- baseProbability = 0.5 (50% baseline)
- regimeFactor = 1.2 if regime strongly supports direction, 0.8 otherwise
- confluenceFactor = min(1.0, confluenceScore / 10.0)
- timeframeFactor = 1.0 if zone appears on multiple timeframes, 0.7 otherwise

Only place orders if fillProbability > 0.4 (40% minimum)
```

### Order Lifecycle

**Placement:**
1. Validate regime, signal quality, confluence
2. Calculate limit price using enhanced formula
3. Estimate fill probability
4. Check risk (including pending orders)
5. Place order with expiration based on market conditions

**Monitoring:**
- Track order age, distance from current price, fill probability
- Update fill probability as market conditions change
- Log all order state changes (placed, adjusted, cancelled, filled)

**Adjustment (Optional):**
- If price approaches within 5 pips and fill probability > 0.6, adjust limit price closer
- Maximum 2 adjustments per order
- Only adjust if regime and confluence still valid

**Cancellation:**
- Cancel if price moves > (ATR-scaled stale distance) away
- Cancel if regime changes and no longer supports order direction
- Cancel if fill probability drops below 0.2
- Cancel if order age > (expiration hours) AND price not approaching
- Cancel before high-impact news events (if configured)

**Expiration:**
- Base expiration: 4 hours (configurable)
- Adjust based on market conditions:
  - High volatility: reduce to 2 hours
  - Low volatility: extend to 6 hours
  - Before news: expire 30 minutes before event
  - Weekend: extend to cover weekend gap

**Fill Tracking:**
- Record fill time, fill price, slippage
- Calculate fill rate: (filled orders / total orders) * 100
- Analyze fill patterns: which confluence factors lead to fills
- Track average time to fill
- Identify zones with high/low fill rates

### Risk and Management

**Pending Order Risk Aggregation:**
- Track total "reserved margin" for all pending limit orders
- Calculate total exposure if all pending orders fill
- Enforce maximum pending order exposure: 2x max position exposure (configurable)
- Reject new limit orders if pending exposure would exceed limit

**Position + Pending Risk:**
- When calculating risk for new order, include:
  - Current open positions risk
  - Pending limit orders risk (assume all will fill)
  - New order risk
- Total must not exceed account risk limits

**Order Slot Management:**
- Maximum pending limit orders: 5 per symbol (configurable)
- If at limit, cancel lowest-priority order (oldest, lowest fill probability, or furthest from price)
- Priority ranking: fill probability > confluence score > order age

**News Event Handling:**
- Cancel all pending limit orders 30 minutes before high-impact news
- Resume limit order placement 15 minutes after news
- During news: disable limit orders, use market orders only (if trading enabled)

## Configuration Parameters

**Current Parameters:**
- `InpUseLimitOrders` - Enable/disable limit orders
- `InpMaxLimitDistancePips` - Maximum distance from current price (default: 30)
- `InpLimitOrderExpirationHours` - Order expiration time (default: 4)
- `InpStaleOrderDistancePips` - Distance threshold for stale cancellation (default: 50)
- `InpDuplicateTolerancePoints` - Duplicate detection tolerance (default: 3)

**Recommended Additional Parameters:**
- `InpMinRegimeConfidence` - Minimum regime confidence for limit orders (default: 0.65)
- `InpMinSignalQualityScore` - Minimum signal quality for limit orders (default: 75.0)
- `InpMinConfluenceScore` - Minimum confluence score (default: 6.0)
- `InpMinConfluenceFactors` - Minimum confluence factors required (default: 3)
- `InpUseATRScaling` - Enable ATR-based distance scaling (default: true)
- `InpMaxPendingOrdersPerSymbol` - Maximum pending orders (default: 5)
- `InpMaxPendingOrderExposureMultiplier` - Max pending exposure vs positions (default: 2.0)
- `InpCancelOrdersBeforeNews` - Cancel before high-impact news (default: true)
- `InpTrackFillMetrics` - Enable fill rate tracking (default: true)
- `InpMinFillProbability` - Minimum fill probability to place order (default: 0.4)

## Backtesting Configuration

**Instruments:** EURUSD, GBPUSD, USDJPY, AUDUSD, NZDUSD  
**Timeframes:** H1 (primary), H4, M15 (validation)  
**Period:** 2020-01-01 to 2024-12-31 (5 years)  
**Model:** "Every tick"  
**Spread:** Current or fixed (2 pips for EURUSD)  
**Commission:** $7 per lot round turn

## Key Metrics

**Primary Metrics:**
1. Fill Rate: (Filled Limit Orders / Total Limit Orders) × 100 (Target: > 60%)
2. Slippage: Difference between limit price and fill price (Target: < 2 pips average)
3. Average Time to Fill: Time from placement to fill (Target: < 2 hours)
4. Win Rate: (Winning Trades / Total Trades) × 100 (Target: > 55% for limit orders)

**Secondary Metrics:**
5. Confluence Factor Effectiveness: Which factors lead to best fills
6. Regime-Based Performance: Win rate by market regime
7. Profit Factor: Total Wins / Total Losses (Target: > 1.5)

## Implementation Files

**Core Files:**
- `Include/GrandeLimitOrderManager.mqh` - Limit order management
- `Include/GrandeConfluenceDetector.mqh` - Confluence zone detection
- `GrandeTradingSystem.mq5` - Signal generation and order placement

**Related Files:**
- `Include/GrandeMarketRegimeDetector.mqh` - Regime detection
- `Include/GrandeKeyLevelDetector.mqh` - Key level detection
- `Include/GrandeFibonacciCalculator.mqh` - Fibonacci calculations
- `Include/GrandeCandleAnalyzer.mqh` - Candle pattern analysis

---

**Related:** [BACKTESTING.md](BACKTESTING.md) | [PROFIT_CRITICAL.md](PROFIT_CRITICAL.md)

