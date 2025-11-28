# Grande Trading System - Limit Order Pipeline Analysis & Improvement Plan

**Date:** 2025-01-XX  
**Author:** AI Analysis  
**Purpose:** Comprehensive review and upgrade of limit order trading logic to meet professional quant standards

---

## 1) Architecture and Data Flow Map

### Overall Pipeline Description

The Grande Trading System is a modular MQL5 Expert Advisor that uses an event-driven architecture with centralized state management. The system flows from market analysis (regime detection, key levels, multi-timeframe analysis) through signal generation, quality filtering, and order execution. Limit orders are placed through a dedicated `GrandeLimitOrderManager` that uses confluence analysis to determine optimal entry prices. The system maintains state persistence, comprehensive logging, and database-backed performance tracking.

### Main Components and Roles

**Core Analysis Components:**
- `CGrandeMarketRegimeDetector` (`GrandeMarketRegimeDetector.mqh`): Detects market regime (trending, ranging, breakout, high volatility) using ADX and ATR across H1, H4, D1 timeframes. Provides `RegimeSnapshot` with confidence scores.
- `CGrandeKeyLevelDetector` (`GrandeKeyLevelDetector.mqh`): Identifies support/resistance levels using swing highs/lows, touch counts, volume confirmation. Provides `SKeyLevel` structures with strength metrics.
- `CGrandeMultiTimeframeAnalyzer` (`GrandeMultiTimeframeAnalyzer.mqh`): Analyzes H4, H1, M15 for consensus signals. Currently partially implemented and disabled in production.
- `CGrandeCandleAnalyzer` (`GrandeCandleAnalyzer.mqh`): Analyzes candle patterns (pin bars, engulfing, momentum candles) for entry validation.
- `CGrandeFibonacciCalculator` (`GrandeFibonacciCalculator.mqh`): Calculates Fibonacci retracement/extension levels from swing points.
- `CGrandeConfluenceDetector` (`GrandeConfluenceDetector.mqh`): Combines key levels, Fibonacci, round numbers, EMAs, and candle rejections to identify high-probability entry zones. Provides `ConfluenceZone` structures with scores.

**Signal Generation and Quality:**
- `CGrandeSignalQualityAnalyzer` (`GrandeSignalQualityAnalyzer.mqh`): Scores signals (0-100) based on regime confidence (40%), confluence (25%), technical indicators (20%), sentiment (15%). Filters low-quality signals.
- `CGrandeIntelligentReporter` (`GrandeIntelligentReporter.mqh`): Tracks all trading decisions (executed, rejected, blocked) and generates hourly reports.

**Order Management:**
- `CGrandeLimitOrderManager` (`GrandeLimitOrderManager.mqh`): Central limit order placement and lifecycle management. Uses `CGrandeConfluenceDetector` to find optimal prices. Validates, places, monitors, and cancels stale orders.
- `CTrade` (MQL5 standard): Wrapper for MT5 trade operations.

**Position and Risk Management:**
- `CGrandePositionOptimizer` (`GrandePositionOptimizer.mqh`): Manages trailing stops, breakeven stops, partial closes. Wraps risk manager functionality.
- `CGrandeRiskManager` (external, referenced but not in codebase): Calculates lot sizes, validates margin, manages drawdown limits.

**State and Configuration:**
- `CGrandeStateManager` (`GrandeStateManager.mqh`): Centralized state management with persistence. Tracks regime, key levels, ATR, cool-off periods, cached RSI values.
- `CGrandeConfigManager` (`GrandeConfigManager.mqh`): Centralizes all configuration parameters with validation and preset management.
- `CGrandeComponentRegistry` (`GrandeComponentRegistry.mqh`): Manages component registration, health monitoring, and execution statistics.

**Infrastructure:**
- `CGrandeEventBus` (`GrandeEventBus.mqh`): Decoupled event-driven communication between components.
- `CGrandeDatabaseManager` (`GrandeDatabaseManager.mqh`): SQLite database for trade history, market data, regime history, sentiment data.
- `CGrandePerformanceTracker` (`GrandePerformanceTracker.mqh`): Tracks trade outcomes and generates performance reports.
- `CGrandeHealthMonitor` (`GrandeHealthMonitor.mqh`): Monitors component health and enables graceful degradation.

**Main EA Orchestration:**
- `GrandeTradingSystem.mq5`: Main entry point. Initializes all components, orchestrates `OnTick()` flow: regime detection → signal generation (`TrendTrade()`, `BreakoutTrade()`, `RangeTrade()`) → limit order placement → position management.

### Specific Function Names and Files

**Limit Order Placement:**
- `CGrandeLimitOrderManager::PlaceLimitOrder()` (`GrandeLimitOrderManager.mqh:418`): Main entry point for placing limit orders
- `CGrandeLimitOrderManager::FindOptimalLimitPrice()` (`GrandeLimitOrderManager.mqh:310`): Calls `CGrandeConfluenceDetector::GetBestLimitOrderPrice()`
- `CGrandeConfluenceDetector::GetBestLimitOrderPrice()` (`GrandeConfluenceDetector.mqh:524`): Returns price of best confluence zone
- `CGrandeConfluenceDetector::FindConfluenceZones()` (`GrandeConfluenceDetector.mqh:200`): Main confluence analysis method

**Limit Order Validation:**
- `CGrandeLimitOrderManager::ValidateLimitOrder()` (`GrandeLimitOrderManager.mqh:369`): Validates distance, duplicates
- `CGrandeLimitOrderManager::HasSimilarOrder()` (`GrandeLimitOrderManager.mqh:336`): Checks for duplicate orders
- `CGrandeConfluenceDetector::IsValidConfluenceZone()` (`GrandeConfluenceDetector.mqh:485`): Validates zone alignment with trade direction

**Limit Order Lifecycle:**
- `CGrandeLimitOrderManager::ManageStaleOrders()` (`GrandeLimitOrderManager.mqh:565`): Cancels orders that are too far from price or expired
- `ManagePendingOrders()` (`GrandeTradingSystem.mq5:1265`): Additional stale order management in main EA

**Signal Generation (calls limit orders):**
- `TrendTrade()` (`GrandeTradingSystem.mq5:3158`): Places limit orders for trend trades (lines 3648-3699)
- `BreakoutTrade()` (`GrandeTradingSystem.mq5:4210`): Places limit orders for breakout trades (lines 4053-4107)

**Configuration:**
- `LimitOrderConfig` struct (`GrandeLimitOrderManager.mqh:143`): Configuration for limit order manager
- Input parameters (`GrandeTradingSystem.mq5:145-151`): `InpUseLimitOrders`, `InpMaxLimitDistancePips`, `InpLimitOrderExpirationHours`, etc.

---

## 2) Current LIMIT ORDER Logic Summary

### Strategy Intent

The system uses limit orders to enter trades at optimal confluence zones (support/resistance, Fibonacci levels, round numbers, EMAs) rather than market prices. This approach aims to improve entry prices and reduce slippage, particularly in ranging or pullback scenarios. Limit orders are used for trend trades (pullbacks to EMAs/key levels) and breakout trades (entries near breakout levels), but are skipped for strong momentum surges where immediate execution is preferred.

### Entry Conditions

**Trend Trades (`TrendTrade()`):**
- Regime must be `REGIME_TREND_BULL` or `REGIME_TREND_BEAR` with confidence > threshold
- Price must be in pullback (distance from EMA within acceptable range)
- RSI must be in acceptable range (typically 40-60 for entries, avoiding extremes)
- EMA alignment across timeframes (H1, H4, D1)
- Volume confirmation (volume ratio > threshold)
- Key level proximity (price near support for buys, resistance for sells)
- Signal quality score must exceed minimum threshold
- No active cool-off period
- Risk checks pass (margin, drawdown, max positions)

**Breakout Trades (`BreakoutTrade()`):**
- Regime must be `REGIME_BREAKOUT_SETUP` or transitioning to trending
- Key level (resistance for buy, support for sell) must be identified
- Price approaching or near breakout level
- Volume spike confirmation
- Not a "strong momentum surge" (if limit orders enabled, strong surges skip trades)
- Signal quality score must exceed minimum threshold
- Risk checks pass

### Limit Price Placement Rules

**Primary Method: Confluence Analysis**
- `CGrandeConfluenceDetector::FindConfluenceZones()` analyzes multiple factors:
  - Key support/resistance levels from `CGrandeKeyLevelDetector`
  - Fibonacci retracement levels (23.6%, 38.2%, 50%, 61.8%, 78.6%) from `CGrandeFibonacciCalculator`
  - Round numbers (50-pip, 100-pip, major round numbers)
  - EMA levels (20, 50, 200)
  - Recent candle rejection wicks (from `CGrandeCandleAnalyzer`)
- Zones are scored based on confluence factors (weighted scoring)
- Best zone is selected: `GetBestConfluenceZone()` → `GetBestLimitOrderPrice()`
- Zone must be within `maxLimitDistancePips` (default: 30 pips) from current price
- Zone must align with trade direction (not buying at resistance, not selling at support)

**Fallback:**
- If no confluence zone found, limit order is rejected (returns `NO_CONFLUENCE` error)
- System does NOT fall back to market orders when limit orders are enabled (trades are skipped)

### Order Lifecycle

**Duration:**
- Orders expire after `expirationHours` (default: 4 hours) from placement time
- Expiration calculated in `CGrandeLimitOrderManager::CalculateExpiration()` (`GrandeLimitOrderManager.mqh:410`)

**Cancellation:**
- Stale orders cancelled if price moves > `staleOrderDistancePips` (default: 50 pips) away from order price
- Expired orders cancelled (checked in `ManageStaleOrders()` and `ManagePendingOrders()`)
- Both methods run on every `OnTick()` cycle

**Adjustment:**
- Orders are NOT adjusted/repositioned when price moves away
- Orders are cancelled and must be re-placed if conditions still valid
- No dynamic price adjustment logic exists

**"Price Ran Away" Scenarios:**
- If price moves > `staleOrderDistancePips` away, order is cancelled
- If price moves > `maxLimitDistancePips` away before order placed, order is rejected
- No logic to "chase" price or adjust limit price dynamically

**Fill Tracking:**
- No explicit fill tracking or fill rate metrics
- System relies on MT5's order status (filled orders become positions)
- No analysis of why orders didn't fill (price never reached, expired, etc.)

### Risk and Sizing

**Lot Size Calculation:**
- Calculated by `CGrandeRiskManager` (external, referenced but not in codebase)
- Based on risk percentage (`InpRiskPctTrend`, `InpRiskPctBreakout`)
- Validated by `ValidateMarginBeforeTrade()` before order placement

**Stop Loss and Take Profit:**
- SL/TP calculated relative to `basePrice` (current market price) in signal generation
- Adjusted for limit price in `CGrandeLimitOrderManager::AdjustStopsForLimitPrice()` (`GrandeLimitOrderManager.mqh:391`)
- Adjustment formula: `sl = limitPrice - MathAbs(basePrice - sl)` for buys (maintains distance)
- TP adjusted similarly to maintain risk-reward ratio

**Risk with Pending Orders:**
- No explicit tracking of "reserved margin" for pending limit orders
- Margin validation only checks if order can be placed, not cumulative exposure
- No limit on total pending orders (only max open positions)
- Risk calculations do not account for pending orders that may fill

---

## 3) Critique Using Strict Quant Standards

### Issue 1: No Multi-Timeframe Limit Price Validation
**Problem:** Limit price is determined solely from current timeframe confluence, without validating alignment across H1, H4, D1.
**Why Risky:** A confluence zone on H1 may be invalidated by H4/D1 structure. Price may never reach the limit if higher timeframes show rejection.
**File/Function:** `CGrandeConfluenceDetector::GetBestLimitOrderPrice()` (`GrandeConfluenceDetector.mqh:524`)
**Criticality:** **CRITICAL**

### Issue 2: No Regime-Based Limit Price Filtering
**Problem:** Confluence zones are selected without checking if they align with current regime. For example, buying at a confluence zone during a bearish trend.
**Why Risky:** Limit orders may be placed at levels that are likely to be broken in the wrong direction, leading to fills that immediately go against the trade.
**File/Function:** `CGrandeConfluenceDetector::FindConfluenceZones()` (`GrandeConfluenceDetector.mqh:200`)
**Criticality:** **CRITICAL**

### Issue 3: Stale Order Cancellation Too Aggressive
**Problem:** Orders are cancelled if price moves >50 pips away, but this may be normal price action in volatile markets or during pullbacks.
**Why Risky:** Cancelling orders too early may prevent fills during legitimate pullbacks. The 50-pip threshold is arbitrary and not based on ATR or volatility.
**File/Function:** `CGrandeLimitOrderManager::ManageStaleOrders()` (`GrandeLimitOrderManager.mqh:565`)
**Criticality:** **IMPORTANT**

### Issue 4: No Fill Rate Tracking or Analysis
**Problem:** System does not track which orders filled, which expired, or which were cancelled. No metrics on fill rate, average time to fill, or reasons for non-fills.
**Why Risky:** Cannot optimize limit price placement without data on what works. May be placing orders at levels that rarely fill.
**File/Function:** None (missing functionality)
**Criticality:** **IMPORTANT**

### Issue 5: Limit Price Distance Validation Too Restrictive
**Problem:** `maxLimitDistancePips` (30 pips) may be too small for volatile pairs or higher timeframes. No ATR-based scaling.
**Why Risky:** May reject valid confluence zones that are slightly further away, especially on pairs with larger pip values or during high volatility.
**File/Function:** `CGrandeLimitOrderManager::ValidateLimitOrder()` (`GrandeLimitOrderManager.mqh:369`)
**Criticality:** **IMPORTANT**

### Issue 6: No Dynamic Limit Price Adjustment
**Problem:** Once placed, limit orders are never adjusted. If price approaches but doesn't reach the limit, order is not moved closer.
**Why Risky:** Missed fills when price comes close but doesn't quite reach the limit. No "chase" logic for high-probability setups.
**File/Function:** None (missing functionality)
**Criticality:** **MINOR** (can be addressed with better initial placement)

### Issue 7: Duplicate Order Detection Too Simple
**Problem:** Duplicate detection only checks if another order exists within `duplicateTolerancePoints` (3 points). Does not consider order age, context, or whether existing order is stale.
**Why Risky:** May prevent placing a new, better-located order when an old, stale order exists nearby.
**File/Function:** `CGrandeLimitOrderManager::HasSimilarOrder()` (`GrandeLimitOrderManager.mqh:336`)
**Criticality:** **MINOR**

### Issue 8: No Limit Order Risk Aggregation
**Problem:** Risk calculations do not account for pending limit orders. If 5 limit orders are pending, system may exceed intended risk exposure when they all fill.
**Why Risky:** May over-leverage account if multiple pending orders fill simultaneously, especially during volatile events.
**File/Function:** Risk validation in `GrandeTradingSystem.mq5` (various locations)
**Criticality:** **CRITICAL**

### Issue 9: Confluence Scoring Lacks Regime Context
**Problem:** Confluence zones are scored without considering current regime. A zone with high confluence score may be invalid during a strong trend in the opposite direction.
**Why Risky:** High-scoring zones may be placed at levels that are likely to break, leading to poor fills.
**File/Function:** `CGrandeConfluenceDetector::CalculateZoneStrength()` (`GrandeConfluenceDetector.mqh:520`)
**Criticality:** **CRITICAL**

### Issue 10: No Limit Order Expiration Based on Market Conditions
**Problem:** Orders expire after fixed 4 hours regardless of market conditions, time of day, or upcoming news events.
**Why Risky:** Orders may expire just before a valid pullback occurs, or may remain active during high-impact news when fills are undesirable.
**File/Function:** `CGrandeLimitOrderManager::CalculateExpiration()` (`GrandeLimitOrderManager.mqh:410`)
**Criticality:** **IMPORTANT**

### Issue 11: Breakout Limit Orders Use Current Price as Base
**Problem:** In `BreakoutTrade()`, limit order `basePrice` is set to current market price, but the intended entry is at the breakout level (which may be far away).
**Why Risky:** Confluence analysis may find zones near current price instead of near the breakout level, leading to orders placed at wrong levels.
**File/Function:** `BreakoutTrade()` (`GrandeTradingSystem.mq5:4059`)
**Criticality:** **CRITICAL**

### Issue 12: No Limit Order Fill Probability Estimation
**Problem:** System does not estimate the probability that a limit order will fill before expiration. All zones are treated equally.
**Why Risky:** May place orders at levels with low fill probability, wasting order slots and missing better opportunities.
**File/Function:** None (missing functionality)
**Criticality:** **IMPORTANT**

---

## 4) Improved LIMIT ORDER Framework Design

### a) Regime and Filters

**Regime-Based Limit Price Filtering:**
- Before selecting a confluence zone, filter zones based on regime:
  - **Trending Bull:** Only consider zones below current price (support levels, Fibonacci retracements from highs)
  - **Trending Bear:** Only consider zones above current price (resistance levels, Fibonacci retracements from lows)
  - **Ranging:** Consider zones at range boundaries (support/resistance)
  - **Breakout Setup:** Consider zones at breakout levels (above resistance for buys, below support for sells)
  - **High Volatility:** Avoid limit orders, use market orders or wider limits

**Multi-Timeframe Regime Alignment:**
- Require regime alignment across H1, H4, D1 before placing limit orders
- If H1 and H4 disagree, reduce limit order size or skip limit orders
- Use D1 regime as "filter" - only place limit orders in direction of D1 trend

**Regime Confidence Thresholds:**
- Minimum regime confidence: 0.65 for limit orders (higher than market orders)
- If confidence < threshold, skip limit orders or use market orders

### b) Signal Formation

**Signal Quality Integration:**
- Require minimum signal quality score: 75/100 for limit orders (higher than market orders: 60/100)
- Limit orders are "premium" entries - only use for highest-quality setups

**Confluence Zone Validation:**
- Minimum confluence score: 6/10 (configurable)
- Require at least 3 confluence factors (key level + Fibonacci + EMA, or key level + round number + candle rejection)
- Zone must align with trade direction (not buying at resistance, not selling at support)

**Multi-Timeframe Confluence:**
- Check confluence zones on H1, H4, D1
- Prefer zones that appear on multiple timeframes
- Weight zones by timeframe (D1 zones > H4 zones > H1 zones)

### c) Limit Price Formula

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

This allows wider limits during high volatility, tighter limits during low volatility.
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

**Dynamic Limit Price Adjustment (Optional):**
- If price approaches within 5 pips of limit but doesn't fill, and fill probability remains high, adjust limit price closer (within 2 pips)
- Maximum 2 adjustments per order
- Only adjust if regime and confluence still valid

### d) Timeframe Architecture

**Primary Timeframe (Current Chart):**
- Used for initial confluence analysis
- Limit price must be valid on primary timeframe

**Higher Timeframes (H4, D1):**
- Validate limit price does not conflict with H4/D1 structure
- If H4/D1 shows rejection at limit price level, reject the zone
- Prefer zones that align with H4/D1 trend direction

**Lower Timeframes (M15, M5):**
- Use for fine-tuning limit price (if enabled)
- Check for recent rejection wicks at limit price level
- Avoid zones with recent bearish rejection for buy limits, bullish rejection for sell limits

**Timeframe Consensus:**
- Use `CGrandeMultiTimeframeAnalyzer` to get consensus
- Only place limit orders if consensus supports the direction
- Weight limit order size by consensus strength

### e) Order Lifecycle

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

**Adjustment:**
- If price approaches within 5 pips and fill probability > 0.6, adjust limit price closer (optional, configurable)
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
- Record fill time, fill price, slippage (if any)
- Calculate fill rate: (filled orders / total orders) * 100
- Analyze fill patterns: which confluence factors lead to fills
- Track average time to fill
- Identify zones with high/low fill rates

### f) Risk and Management

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

**Limit Order Sizing:**
- Reduce lot size for limit orders vs market orders (e.g., 0.8x multiplier)
- Rationale: Limit orders may fill at better prices, so can use smaller size for same risk
- Alternatively: Use same size but tighter stops (better R:R)

**Order Slot Management:**
- Maximum pending limit orders: 5 per symbol (configurable)
- If at limit, cancel lowest-priority order (oldest, lowest fill probability, or furthest from price)
- Priority ranking: fill probability > confluence score > order age

**News Event Handling:**
- Cancel all pending limit orders 30 minutes before high-impact news
- Resume limit order placement 15 minutes after news
- During news: disable limit orders, use market orders only (if trading enabled)

---

## 5) Concrete Code Changes - File by File

### GrandeInterfaces.mqh

**Add Limit Order Tracking Structures:**
```mql5
// Add to GrandeInterfaces.mqh

// Limit order fill tracking
struct LimitOrderFillMetrics
{
    ulong ticket;
    datetime placedTime;
    datetime filledTime;
    double placedPrice;
    double filledPrice;
    double slippagePips;
    bool wasFilled;
    string cancelReason;  // If not filled
    double fillProbabilityAtPlacement;
    double fillProbabilityAtCancel;
};

// Enhanced limit order request with regime context
struct EnhancedLimitOrderRequest
{
    // Existing fields from LimitOrderRequest
    bool isBuy;
    double lotSize;
    double basePrice;
    double stopLoss;
    double takeProfit;
    string comment;
    string tradeContext;
    string logPrefix;
    
    // New fields
    RegimeSnapshot regimeSnapshot;      // Current regime for filtering
    double regimeConfidence;            // Regime confidence
    double signalQualityScore;          // Signal quality score
    double currentATR;                  // For ATR-based distance scaling
    double averageATR;                  // For ATR-based distance scaling
    datetime newsEventTime;             // Upcoming news event (0 if none)
    int newsImpactLevel;                // News impact level (0-3)
};
```

### GrandeConfigManager.mqh

**Add Enhanced Limit Order Configuration:**
```mql5
// Add to RegimeDetectionConfig or create LimitOrderConfig struct
struct EnhancedLimitOrderConfig
{
    // Existing
    bool useLimitOrders;
    int maxLimitDistancePips;
    int expirationHours;
    bool cancelStaleOrders;
    double staleOrderDistancePips;
    int duplicateTolerancePoints;
    
    // New
    double minRegimeConfidence;         // Minimum regime confidence for limit orders (default: 0.65)
    double minSignalQualityScore;       // Minimum signal quality for limit orders (default: 75.0)
    double minConfluenceScore;          // Minimum confluence score (default: 6.0)
    int minConfluenceFactors;           // Minimum confluence factors required (default: 3)
    bool useATRScaling;                 // Enable ATR-based distance scaling (default: true)
    double baseMaxDistancePips;         // Base max distance (default: 30)
    bool enableDynamicAdjustment;       // Enable dynamic limit price adjustment (default: false)
    double adjustmentTriggerPips;       // Distance to trigger adjustment (default: 5.0)
    int maxAdjustmentsPerOrder;         // Maximum adjustments (default: 2)
    bool requireMultiTimeframeAlignment; // Require H1/H4/D1 alignment (default: true)
    int maxPendingOrdersPerSymbol;      // Maximum pending orders (default: 5)
    double maxPendingOrderExposureMultiplier; // Max pending exposure vs positions (default: 2.0)
    bool cancelOrdersBeforeNews;        // Cancel before high-impact news (default: true)
    int newsCancelMinutesBefore;        // Minutes before news to cancel (default: 30)
    bool trackFillMetrics;              // Enable fill rate tracking (default: true)
    double minFillProbability;         // Minimum fill probability to place order (default: 0.4)
    
    void SetDefaults()
    {
        useLimitOrders = true;
        maxLimitDistancePips = 30;
        expirationHours = 4;
        cancelStaleOrders = true;
        staleOrderDistancePips = 50.0;
        duplicateTolerancePoints = 3;
        minRegimeConfidence = 0.65;
        minSignalQualityScore = 75.0;
        minConfluenceScore = 6.0;
        minConfluenceFactors = 3;
        useATRScaling = true;
        baseMaxDistancePips = 30.0;
        enableDynamicAdjustment = false;
        adjustmentTriggerPips = 5.0;
        maxAdjustmentsPerOrder = 2;
        requireMultiTimeframeAlignment = true;
        maxPendingOrdersPerSymbol = 5;
        maxPendingOrderExposureMultiplier = 2.0;
        cancelOrdersBeforeNews = true;
        newsCancelMinutesBefore = 30;
        trackFillMetrics = true;
        minFillProbability = 0.4;
    }
};
```

### GrandeMarketRegimeDetector.mqh

**Add Regime-Based Zone Filtering Method:**
```mql5
// Add to CGrandeMarketRegimeDetector class

// Check if a price level aligns with current regime
bool IsPriceLevelValidForRegime(double price, bool isBuy, double currentPrice)
{
    RegimeSnapshot snapshot = GetLastSnapshot();
    
    if(snapshot.regime == REGIME_TREND_BULL)
    {
        // For buys in bullish trend, price must be below current (pullback)
        return isBuy ? (price < currentPrice) : false;
    }
    else if(snapshot.regime == REGIME_TREND_BEAR)
    {
        // For sells in bearish trend, price must be above current (pullback)
        return isBuy ? false : (price > currentPrice);
    }
    else if(snapshot.regime == REGIME_RANGING)
    {
        // In ranging, can use both directions at range boundaries
        return true; // Further validation by key levels
    }
    else if(snapshot.regime == REGIME_BREAKOUT_SETUP)
    {
        // For breakouts, buys above resistance, sells below support
        // This is handled by breakout-specific logic
        return true;
    }
    else if(snapshot.regime == REGIME_HIGH_VOLATILITY)
    {
        // Avoid limit orders in high volatility
        return false;
    }
    
    return false;
}

// Get regime alignment score (0.0 to 1.0)
double GetRegimeAlignmentScore(bool isBuy, double price, double currentPrice)
{
    RegimeSnapshot snapshot = GetLastSnapshot();
    double alignment = 0.0;
    
    if(snapshot.regime == REGIME_TREND_BULL && isBuy && price < currentPrice)
        alignment = snapshot.confidence;
    else if(snapshot.regime == REGIME_TREND_BEAR && !isBuy && price > currentPrice)
        alignment = snapshot.confidence;
    else if(snapshot.regime == REGIME_RANGING)
        alignment = snapshot.confidence * 0.7; // Slightly lower for ranging
    else if(snapshot.regime == REGIME_BREAKOUT_SETUP)
        alignment = snapshot.confidence * 0.8; // Moderate for breakouts
    
    return alignment;
}
```

### GrandeMultiTimeframeAnalyzer.mqh

**Add Multi-Timeframe Limit Price Validation:**
```mql5
// Add to CMultiTimeframeAnalyzer class

// Validate limit price across multiple timeframes
bool ValidateLimitPriceMultiTimeframe(double limitPrice, bool isBuy, double currentPrice)
{
    // Check H1, H4, D1 for conflicts
    bool h1Valid = ValidateLimitPriceOnTimeframe(PERIOD_H1, limitPrice, isBuy, currentPrice);
    bool h4Valid = ValidateLimitPriceOnTimeframe(PERIOD_H4, limitPrice, isBuy, currentPrice);
    bool d1Valid = ValidateLimitPriceOnTimeframe(PERIOD_D1, limitPrice, isBuy, currentPrice);
    
    // Require at least H1 and H4 alignment (D1 is preferred but not required)
    return h1Valid && h4Valid;
}

// Validate limit price on specific timeframe
bool ValidateLimitPriceOnTimeframe(ENUM_TIMEFRAMES tf, double limitPrice, bool isBuy, double currentPrice)
{
    // Get key levels on this timeframe
    // Check if limit price is at a valid support (for buys) or resistance (for sells)
    // Check for recent rejection wicks at this level
    // This would require access to key level detector for each timeframe
    
    // Simplified: check if price is in valid direction relative to current
    if(isBuy)
        return limitPrice <= currentPrice; // Buy limits below current
    else
        return limitPrice >= currentPrice; // Sell limits above current
}

// Get multi-timeframe confluence score for a price level
double GetMultiTimeframeConfluenceScore(double price, bool isBuy)
{
    double score = 0.0;
    
    // Check if price appears as key level on multiple timeframes
    // Weight: D1 = 0.5, H4 = 0.3, H1 = 0.2
    // This is a placeholder - would need key level detector per timeframe
    
    return score;
}
```

### GrandeKeyLevelDetector.mqh

**Add Timeframe-Specific Key Level Access:**
```mql5
// Add to CGrandeKeyLevelDetector class (or create timeframe-specific instances)

// Get key levels for a specific timeframe (requires separate detector instances)
// This would be implemented by creating detector instances for H1, H4, D1
// and calling GetKeyLevel() on each
```

### GrandeCandleAnalyzer.mqh

**Add Recent Rejection Check at Price Level:**
```mql5
// Add to CGrandeCandleAnalyzer class

// Check if there was recent rejection at a specific price level
bool HasRecentRejectionAtPrice(double price, bool checkUpperWick, int lookbackBars = 10)
{
    double tolerance = GetPipSize() * 2; // Within 2 pips
    
    for(int i = 0; i < lookbackBars; i++)
    {
        CandleStructure candle = AnalyzeCandleStructure(i);
        
        if(checkUpperWick && candle.hasLongUpperWick)
        {
            double candleHigh = iHigh(m_symbol, m_timeframe, i);
            if(MathAbs(candleHigh - price) <= tolerance)
                return true; // Recent bearish rejection at this level
        }
        else if(!checkUpperWick && candle.hasLongLowerWick)
        {
            double candleLow = iLow(m_symbol, m_timeframe, i);
            if(MathAbs(candleLow - price) <= tolerance)
                return true; // Recent bullish rejection at this level
        }
    }
    
    return false;
}
```

### GrandeFibonacciCalculator.mqh

**No changes needed** - already provides Fibonacci levels for confluence analysis.

### GrandeConfluenceDetector.mqh

**Enhance Confluence Zone Scoring with Regime Context:**
```mql5
// Modify CGrandeConfluenceDetector::FindConfluenceZones()

// Add regime parameter to FindConfluenceZones()
bool FindConfluenceZones(bool isBuy, double currentPrice, double maxDistancePips, 
                         ConfluenceZone &zones[], RegimeSnapshot &regime, 
                         double regimeConfidence, double signalQualityScore)
{
    // Existing confluence analysis...
    
    // NEW: Filter zones by regime alignment
    for(int i = ArraySize(zones) - 1; i >= 0; i--)
    {
        // Check if zone aligns with regime
        if(!IsZoneValidForRegime(zones[i], isBuy, currentPrice, regime))
        {
            ArrayRemove(zones, i, 1);
            continue;
        }
        
        // Check if zone has minimum confluence factors
        int factorCount = CountConfluenceFactors(zones[i]);
        if(factorCount < m_minConfluenceFactors) // New config parameter
        {
            ArrayRemove(zones, i, 1);
            continue;
        }
        
        // Enhanced scoring with regime weight
        zones[i].score = CalculateEnhancedZoneStrength(zones[i], regime, regimeConfidence, signalQualityScore);
    }
    
    // Filter by minimum score
    for(int i = ArraySize(zones) - 1; i >= 0; i--)
    {
        if(zones[i].score < m_minConfluenceScore) // Use config parameter
        {
            ArrayRemove(zones, i, 1);
        }
    }
    
    return ArraySize(zones) > 0;
}

// New method: Check if zone is valid for regime
bool IsZoneValidForRegime(ConfluenceZone &zone, bool isBuy, double currentPrice, RegimeSnapshot &regime)
{
    if(regime.regime == REGIME_TREND_BULL)
    {
        // For buys, zone must be below current (pullback)
        if(isBuy && zone.price >= currentPrice)
            return false;
        // For sells, reject (trending up)
        if(!isBuy)
            return false;
    }
    else if(regime.regime == REGIME_TREND_BEAR)
    {
        // For sells, zone must be above current (pullback)
        if(!isBuy && zone.price <= currentPrice)
            return false;
        // For buys, reject (trending down)
        if(isBuy)
            return false;
    }
    else if(regime.regime == REGIME_HIGH_VOLATILITY)
    {
        // Avoid limit orders in high volatility
        return false;
    }
    
    return true;
}

// New method: Count confluence factors
int CountConfluenceFactors(ConfluenceZone &zone)
{
    int count = 0;
    if(zone.hasKeyLevel) count++;
    if(zone.hasFibLevel) count++;
    if(zone.hasRoundNumber) count++;
    if(zone.hasEMA) count++;
    if(zone.hasCandleRejection) count++;
    return count;
}

// Enhanced zone strength calculation
double CalculateEnhancedZoneStrength(ConfluenceZone &zone, RegimeSnapshot &regime, 
                                      double regimeConfidence, double signalQualityScore)
{
    double baseScore = CalculateZoneStrength(zone); // Existing method
    
    // Apply regime multiplier
    double regimeMultiplier = 1.0;
    if(regime.regime == REGIME_TREND_BULL || regime.regime == REGIME_TREND_BEAR)
        regimeMultiplier = 1.2 * regimeConfidence; // Boost for trending regimes
    else if(regime.regime == REGIME_RANGING)
        regimeMultiplier = 0.9 * regimeConfidence; // Slight reduction for ranging
    
    // Apply signal quality multiplier
    double qualityMultiplier = signalQualityScore / 100.0;
    
    return baseScore * regimeMultiplier * qualityMultiplier;
}
```

### GrandeLimitOrderManager.mqh

**Major Enhancements Required:**

**1. Add Enhanced Request Structure Support:**
```mql5
// Modify PlaceLimitOrder() to accept EnhancedLimitOrderRequest
LimitOrderResult PlaceLimitOrder(const EnhancedLimitOrderRequest &request)
{
    // Extract basic fields from enhanced request
    LimitOrderRequest basicRequest;
    basicRequest.isBuy = request.isBuy;
    basicRequest.lotSize = request.lotSize;
    basicRequest.basePrice = request.basePrice;
    basicRequest.stopLoss = request.stopLoss;
    basicRequest.takeProfit = request.takeProfit;
    basicRequest.comment = request.comment;
    basicRequest.tradeContext = request.tradeContext;
    basicRequest.logPrefix = request.logPrefix;
    
    // NEW: Validate regime confidence
    if(request.regimeConfidence < m_config.minRegimeConfidence)
    {
        return LimitOrderResult::Failure("LOW_REGIME_CONFIDENCE",
            StringFormat("Regime confidence %.2f below minimum %.2f",
            request.regimeConfidence, m_config.minRegimeConfidence));
    }
    
    // NEW: Validate signal quality
    if(request.signalQualityScore < m_config.minSignalQualityScore)
    {
        return LimitOrderResult::Failure("LOW_SIGNAL_QUALITY",
            StringFormat("Signal quality %.1f below minimum %.1f",
            request.signalQualityScore, m_config.minSignalQualityScore));
    }
    
    // NEW: Check pending order exposure
    if(!ValidatePendingOrderExposure(request.lotSize, request.basePrice))
    {
        return LimitOrderResult::Failure("EXCEEDS_PENDING_EXPOSURE",
            "Pending order exposure limit exceeded");
    }
    
    // NEW: Check for upcoming news events
    if(m_config.cancelOrdersBeforeNews && request.newsEventTime > 0)
    {
        datetime timeToNews = request.newsEventTime - TimeCurrent();
        if(timeToNews < (m_config.newsCancelMinutesBefore * 60))
        {
            return LimitOrderResult::Failure("NEWS_EVENT_NEAR",
                "High-impact news event too close");
        }
    }
    
    // Continue with existing logic...
    return PlaceLimitOrder(basicRequest, request);
}
```

**2. Add ATR-Based Distance Scaling:**
```mql5
// Add to class
double CalculateATRScaledMaxDistance(double baseMaxDistancePips, double currentATR, double averageATR)
{
    if(!m_config.useATRScaling || averageATR <= 0)
        return baseMaxDistancePips;
    
    double atrRatio = currentATR / averageATR;
    double scaledDistance = baseMaxDistancePips * atrRatio;
    
    // Clamp to reasonable bounds (0.5x to 2.0x)
    scaledDistance = MathMax(baseMaxDistancePips * 0.5, MathMin(scaledDistance, baseMaxDistancePips * 2.0));
    
    return scaledDistance;
}

// Modify FindOptimalLimitPrice()
double FindOptimalLimitPrice(bool isBuy, double currentPrice, int maxDistancePips, 
                             double currentATR = 0, double averageATR = 0)
{
    // Apply ATR scaling
    double scaledMaxDistance = CalculateATRScaledMaxDistance(maxDistancePips, currentATR, averageATR);
    
    // Use scaled distance for confluence analysis
    return m_confluenceDetector.GetBestLimitOrderPrice(isBuy, currentPrice, (int)scaledMaxDistance);
}
```

**3. Add Fill Probability Estimation:**
```mql5
// Add to class
double EstimateFillProbability(double limitPrice, bool isBuy, double currentPrice,
                               RegimeSnapshot &regime, double regimeConfidence,
                               double confluenceScore, double signalQualityScore)
{
    double baseProbability = 0.5; // 50% baseline
    
    // Regime factor
    double regimeFactor = 1.0;
    if(regime.regime == REGIME_TREND_BULL && isBuy && limitPrice < currentPrice)
        regimeFactor = 1.2 * regimeConfidence;
    else if(regime.regime == REGIME_TREND_BEAR && !isBuy && limitPrice > currentPrice)
        regimeFactor = 1.2 * regimeConfidence;
    else if(regime.regime == REGIME_RANGING)
        regimeFactor = 0.9 * regimeConfidence;
    else
        regimeFactor = 0.6; // Low probability if regime doesn't support
    
    // Confluence factor
    double confluenceFactor = MathMin(1.0, confluenceScore / 10.0);
    
    // Signal quality factor
    double qualityFactor = signalQualityScore / 100.0;
    
    // Distance factor (closer = higher probability)
    double pipSize = GetPipSize();
    double distancePips = MathAbs(limitPrice - currentPrice) / pipSize;
    double distanceFactor = 1.0 - (distancePips / (maxDistancePips * 2.0)); // Linear decay
    distanceFactor = MathMax(0.3, distanceFactor); // Minimum 30%
    
    double fillProbability = baseProbability * regimeFactor * confluenceFactor * qualityFactor * distanceFactor;
    
    // Clamp to 0.0 - 1.0
    return MathMax(0.0, MathMin(1.0, fillProbability));
}
```

**4. Add Pending Order Risk Aggregation:**
```mql5
// Add to class
double CalculatePendingOrderExposure()
{
    double totalExposure = 0.0;
    int total = OrdersTotal();
    
    for(int i = 0; i < total; i++)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!OrderSelect(ticket)) continue;
        if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
        if((int)OrderGetInteger(ORDER_MAGIC) != m_magicNumber) continue;
        
        ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT)
            continue;
        
        double lotSize = OrderGetDouble(ORDER_VOLUME_CURRENT);
        double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
        double sl = OrderGetDouble(ORDER_SL);
        
        // Calculate risk per order
        double riskPerOrder = 0.0;
        if(sl > 0)
        {
            double riskPips = MathAbs(orderPrice - sl) / GetPipSize();
            double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
            double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
            if(tickSize > 0)
                riskPerOrder = (riskPips * GetPipSize() / tickSize) * tickValue * lotSize;
        }
        
        totalExposure += riskPerOrder;
    }
    
    return totalExposure;
}

bool ValidatePendingOrderExposure(double newOrderLotSize, double newOrderPrice)
{
    // Calculate current pending exposure
    double currentExposure = CalculatePendingOrderExposure();
    
    // Calculate new order exposure (estimate - would need SL)
    // For now, use lot size as proxy
    double newOrderExposure = newOrderLotSize * 10000; // Rough estimate
    
    // Get current open positions exposure
    double positionsExposure = 0.0; // Would need risk manager to calculate
    
    // Check if adding new order would exceed limit
    double maxPendingExposure = positionsExposure * m_config.maxPendingOrderExposureMultiplier;
    
    if((currentExposure + newOrderExposure) > maxPendingExposure)
        return false;
    
    return true;
}
```

**5. Add Dynamic Limit Price Adjustment:**
```mql5
// Add to class
void AdjustLimitOrderPrice(ulong ticket)
{
    if(!m_config.enableDynamicAdjustment)
        return;
    
    if(!OrderSelect(ticket)) return;
    if(OrderGetString(ORDER_SYMBOL) != m_symbol) return;
    if((int)OrderGetInteger(ORDER_MAGIC) != m_magicNumber) return;
    
    ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
    if(orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT)
        return;
    
    // Check adjustment count
    int adjustmentCount = GetOrderAdjustmentCount(ticket);
    if(adjustmentCount >= m_config.maxAdjustmentsPerOrder)
        return;
    
    double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
    double pipSize = GetPipSize();
    double distance = MathAbs(currentPrice - orderPrice) / pipSize;
    
    // Check if price is approaching
    if(distance <= m_config.adjustmentTriggerPips && distance > 2.0)
    {
        // Move limit price closer (within 2 pips)
        bool isBuy = (orderType == ORDER_TYPE_BUY_LIMIT);
        double newLimitPrice = 0.0;
        
        if(isBuy)
            newLimitPrice = currentPrice - (2.0 * pipSize); // 2 pips below current
        else
            newLimitPrice = currentPrice + (2.0 * pipSize); // 2 pips above current
        
        // Validate new price is still valid
        // (would need to re-check confluence, regime, etc.)
        
        // Modify order
        if(m_trade.OrderModify(ticket, newLimitPrice, OrderGetDouble(ORDER_SL), 
                              OrderGetDouble(ORDER_TP), OrderGetInteger(ORDER_TIME_EXPIRATION)))
        {
            IncrementOrderAdjustmentCount(ticket);
            Print(StringFormat("[LIMIT-ORDER] Adjusted order #%lld from %.5f to %.5f",
                  ticket, orderPrice, newLimitPrice));
        }
    }
}
```

**6. Enhanced Stale Order Management:**
```mql5
// Modify ManageStaleOrders() to use ATR-based distance
void ManageStaleOrders(double currentATR = 0, double averageATR = 0)
{
    if(!m_config.cancelStaleOrders)
        return;
    
    double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double pipSize = GetPipSize();
    
    // Use ATR-scaled stale distance if available
    double maxStaleDistance = m_config.staleOrderDistancePips;
    if(m_config.useATRScaling && averageATR > 0 && currentATR > 0)
    {
        double atrRatio = currentATR / averageATR;
        maxStaleDistance = m_config.staleOrderDistancePips * atrRatio;
        maxStaleDistance = MathMax(m_config.staleOrderDistancePips * 0.5, 
                                   MathMin(maxStaleDistance, m_config.staleOrderDistancePips * 2.0));
    }
    
    double maxStaleDistancePoints = maxStaleDistance * pipSize;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!OrderSelect(ticket)) continue;
        if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
        if((int)OrderGetInteger(ORDER_MAGIC) != m_magicNumber) continue;
        
        ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT)
            continue;
        
        double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
        double distance = MathAbs(currentPrice - orderPrice);
        
        bool shouldCancel = false;
        string cancelReason = "";
        
        // Check distance (using ATR-scaled threshold)
        if(distance > maxStaleDistancePoints)
        {
            shouldCancel = true;
            cancelReason = StringFormat("Price moved %.1f pips away (max: %.1f)", 
                                       distance / pipSize, maxStaleDistance);
        }
        
        // Check expiration
        datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
        if(expiration > 0 && TimeCurrent() >= expiration)
        {
            shouldCancel = true;
            cancelReason = "Order expired";
        }
        
        // NEW: Check fill probability (if tracking enabled)
        if(m_config.trackFillMetrics)
        {
            // Would need to recalculate fill probability
            // If probability dropped below threshold, cancel
            // (Implementation would require regime snapshot, etc.)
        }
        
        if(shouldCancel)
        {
            if(m_trade.OrderDelete(ticket))
            {
                Print(StringFormat("[LIMIT-ORDER] Cancelled limit order #%I64u: %s", 
                      ticket, cancelReason));
                
                // Log cancellation
                if(m_config.trackFillMetrics && m_dbManager != NULL)
                {
                    LogLimitOrderCancel(ticket, cancelReason);
                }
            }
        }
        else if(m_config.enableDynamicAdjustment)
        {
            // Try to adjust order if price is approaching
            AdjustLimitOrderPrice(ticket);
        }
    }
}
```

**7. Add Fill Tracking:**
```mql5
// Add to class (requires database manager dependency)
void LogLimitOrderPlacement(const LimitOrderRequest &request, const LimitOrderResult &result,
                           RegimeSnapshot &regime, double regimeConfidence, 
                           double signalQualityScore, double confluenceScore,
                           double fillProbability)
{
    if(!m_config.trackFillMetrics || m_dbManager == NULL)
        return;
    
    // Store in database
    m_dbManager->InsertLimitOrder(
        m_symbol,
        result.ticket,
        TimeCurrent(),
        0, // filled_time
        request.basePrice,
        0, // filled_price
        result.limitPrice,
        result.adjustedSL,
        result.adjustedTP,
        request.lotSize,
        request.isBuy ? "BUY" : "SELL",
        regime.regime,
        regimeConfidence,
        signalQualityScore,
        confluenceScore,
        fillProbability
    );
}

void LogLimitOrderFill(ulong ticket, double fillPrice)
{
    if(!m_config.trackFillMetrics || m_dbManager == NULL)
        return;
    
    // Update database
    m_dbManager->UpdateLimitOrderFill(ticket, TimeCurrent(), fillPrice);
    
    // Calculate slippage
    // (Would need to retrieve original limit price from database)
    double slippage = 0.0; // Calculate from stored data
    
    Print(StringFormat("[LIMIT-ORDER] Order #%lld filled at %.5f (slippage: %.1f pips)", 
          ticket, fillPrice, slippage));
}

void LogLimitOrderCancel(ulong ticket, string reason)
{
    if(!m_config.trackFillMetrics || m_dbManager == NULL)
        return;
    
    m_dbManager->UpdateLimitOrderCancel(ticket, TimeCurrent(), reason);
}
```

**8. Add Order Slot Management:**
```mql5
// Add to class
int GetPendingOrderCount()
{
    int count = 0;
    int total = OrdersTotal();
    
    for(int i = 0; i < total; i++)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!OrderSelect(ticket)) continue;
        if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
        if((int)OrderGetInteger(ORDER_MAGIC) != m_magicNumber) continue;
        
        ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT)
            count++;
    }
    
    return count;
}

bool CanPlaceNewOrder()
{
    int pendingCount = GetPendingOrderCount();
    return pendingCount < m_config.maxPendingOrdersPerSymbol;
}

void CancelLowestPriorityOrder()
{
    // Find order with lowest priority (oldest, lowest fill probability, or furthest)
    // Cancel it to make room for new order
    // (Implementation would require tracking priority metrics)
}
```

### GrandePositionOptimizer.mqh

**No changes needed** - position optimization is separate from limit order placement.

### GrandeProfitCalculator.mqh

**No changes needed** - profit calculation is independent of order type.

### GrandePerformanceTracker.mqh

**Add Limit Order Fill Metrics Tracking:**
```mql5
// Add to CGrandePerformanceTracker class

// Track limit order fill metrics
void RecordLimitOrderFill(const LimitOrderFillMetrics &metrics)
{
    if(!m_isInitialized || m_dbManager == NULL)
        return;
    
    // Store in database (would require schema addition)
    // Track fill rate, average time to fill, etc.
}

// Get fill rate statistics
double GetLimitOrderFillRate(string signalType = "", int days = 30)
{
    // Query database for fill rate
    // Return: (filled orders / total orders) * 100
    return 0.0; // Placeholder
}
```

### GrandeHealthMonitor.mqh

**No changes needed** - health monitoring is component-agnostic.

### GrandeDatabaseManager.mqh

**Add Limit Order Tracking Tables:**
```mql5
// Add to CreateTables() method

// Limit order tracking table
sql = "CREATE TABLE IF NOT EXISTS limit_orders ("
      "id INTEGER PRIMARY KEY AUTOINCREMENT, "
      "symbol TEXT NOT NULL, "
      "ticket INTEGER NOT NULL, "
      "placed_time DATETIME NOT NULL, "
      "filled_time DATETIME, "
      "placed_price REAL NOT NULL, "
      "filled_price REAL, "
      "limit_price REAL NOT NULL, "
      "stop_loss REAL, "
      "take_profit REAL, "
      "lot_size REAL NOT NULL, "
      "direction TEXT NOT NULL, "
      "regime_at_placement TEXT, "
      "regime_confidence REAL, "
      "signal_quality_score REAL, "
      "confluence_score REAL, "
      "fill_probability REAL, "
      "was_filled BOOLEAN DEFAULT 0, "
      "cancel_reason TEXT, "
      "cancel_time DATETIME, "
      "adjustment_count INTEGER DEFAULT 0, "
      "created_at DATETIME DEFAULT CURRENT_TIMESTAMP)";

if(!ExecuteSQL(sql)) return false;

// Create indexes
ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_limit_orders_symbol_time ON limit_orders(symbol, placed_time)");
ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_limit_orders_ticket ON limit_orders(ticket)");
ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_limit_orders_filled ON limit_orders(was_filled)");
```

### GrandeIntelligentReporter.mqh

**Add Limit Order Metrics to Reports:**
```mql5
// Add to GenerateHourlyReport() method

// Limit Order Performance Section
report += StringPadCenter(" LIMIT ORDER PERFORMANCE ", 60, "-") + "\n";
report += StringFormat("Total Limit Orders Placed: %d\n", GetTotalLimitOrdersPlaced());
report += StringFormat("Filled: %d (%.1f%%)\n", GetFilledLimitOrders(), GetFillRate());
report += StringFormat("Cancelled: %d (%.1f%%)\n", GetCancelledLimitOrders(), GetCancelRate());
report += StringFormat("Expired: %d (%.1f%%)\n", GetExpiredLimitOrders(), GetExpireRate());
report += StringFormat("Average Time to Fill: %.1f minutes\n", GetAverageTimeToFill());
report += StringFormat("Average Slippage: %.1f pips\n", GetAverageSlippage());
```

---

## 6) Backtest and Evaluation Plan

### Strategy Tester Configuration

**Instruments:**
- Primary: EURUSD, GBPUSD, USDJPY, AUDUSD
- Secondary: EURJPY, GBPJPY, USDCHF, NZDUSD
- Rationale: Major pairs with good liquidity and clear limit order behavior

**Timeframes:**
- Primary: H1 (1-hour charts)
- Secondary: H4, M15 (for validation)
- Rationale: H1 provides good balance between signal frequency and quality

**Period:**
- Start: 2020-01-01
- End: 2024-12-31
- Rationale: 5 years provides multiple market regimes (trending, ranging, high volatility, COVID, recovery)

**Settings:**
- Model: "Every tick" (most accurate)
- Optimization: Genetic algorithm for key parameters
- Spread: Use current spread or fixed spread (e.g., 2 pips for EURUSD)
- Commission: Include realistic commission (e.g., $7 per lot round turn)

### Key Metrics

**Primary Metrics:**
1. **Expectancy:** Average profit per trade
   - Formula: (Win Rate × Avg Win) - (Loss Rate × Avg Loss)
   - Target: > 0 (positive expectancy)
   - Track separately for limit orders vs market orders

2. **Risk-Reward Ratio (R:R):**
   - Formula: Average Win / Average Loss
   - Target: > 1.5:1
   - Track for limit orders (should be better due to better entries)

3. **Maximum Drawdown:**
   - Peak-to-trough decline
   - Target: < 20% of account
   - Compare limit order strategy vs market order strategy

4. **Fill Rate:**
   - Formula: (Filled Limit Orders / Total Limit Orders) × 100
   - Target: > 60% (60% of limit orders fill before expiration)
   - Track by confluence score, regime, timeframe

5. **Slippage:**
   - Difference between limit price and fill price
   - Target: < 2 pips average (limit orders should have minimal slippage)
   - Compare to market order slippage

**Secondary Metrics:**
6. **Average Time to Fill:**
   - Time from order placement to fill
   - Target: < 2 hours (50% of expiration time)
   - Identify zones with fast fills

7. **Win Rate:**
   - (Winning Trades / Total Trades) × 100
   - Target: > 55% for limit orders (better entries should improve win rate)
   - Compare limit orders vs market orders

8. **Profit Factor:**
   - Total Wins / Total Losses
   - Target: > 1.5
   - Track separately for limit orders

9. **Confluence Factor Effectiveness:**
   - Which confluence factors (key level, Fibonacci, EMA, round number) lead to best fills and wins
   - Track fill rate and win rate by factor combination

10. **Regime-Based Performance:**
    - Win rate and profit factor by regime (trending, ranging, breakout)
    - Identify which regimes are best for limit orders

### Instrumentation

**Add Logging to GrandeLimitOrderManager:**
```mql5
// Log every limit order placement
void LogLimitOrderPlacement(const LimitOrderRequest &request, const LimitOrderResult &result)
{
    if(!m_config.trackFillMetrics)
        return;
    
    // Log to database
    m_dbManager->InsertLimitOrder(
        m_symbol,
        result.ticket,
        TimeCurrent(),
        0, // filled_time (0 = not filled yet)
        request.basePrice,
        0, // filled_price (0 = not filled yet)
        result.limitPrice,
        result.adjustedSL,
        result.adjustedTP,
        request.lotSize,
        request.isBuy ? "BUY" : "SELL",
        // ... other fields
    );
}

// Log order fill
void LogLimitOrderFill(ulong ticket, double fillPrice)
{
    // Update database record
    m_dbManager->UpdateLimitOrderFill(ticket, TimeCurrent(), fillPrice);
    
    // Calculate slippage
    double slippage = MathAbs(fillPrice - originalLimitPrice) / GetPipSize();
    
    // Log metrics
    Print(StringFormat("[LIMIT-ORDER] Order #%lld filled at %.5f (slippage: %.1f pips)", 
          ticket, fillPrice, slippage));
}

// Log order cancellation
void LogLimitOrderCancel(ulong ticket, string reason)
{
    // Update database record
    m_dbManager->UpdateLimitOrderCancel(ticket, TimeCurrent(), reason);
}
```

**Add Performance Tracking:**
```mql5
// Track fill rate in real-time
struct LimitOrderStats
{
    int totalPlaced;
    int totalFilled;
    int totalCancelled;
    int totalExpired;
    double averageTimeToFill;
    double averageSlippage;
    double fillRate;
};

LimitOrderStats GetLimitOrderStats(int days = 30)
{
    // Query database for statistics
    // Return aggregated metrics
}
```

### Evaluation Criteria

**Success Criteria:**
1. Fill rate > 60% (majority of orders fill)
2. Win rate for limit orders > 55% (better than market orders)
3. Average slippage < 2 pips (better entry prices)
4. Profit factor > 1.5 (profitable strategy)
5. Maximum drawdown < 20% (acceptable risk)

**Comparison:**
- Run same strategy with limit orders enabled vs disabled
- Compare metrics side-by-side
- Identify scenarios where limit orders outperform market orders

**Optimization Parameters:**
- `maxLimitDistancePips`: Test 20, 30, 40, 50 pips
- `minConfluenceScore`: Test 5, 6, 7, 8
- `minRegimeConfidence`: Test 0.60, 0.65, 0.70
- `expirationHours`: Test 2, 4, 6, 8 hours
- `staleOrderDistancePips`: Test 40, 50, 60, 70 pips

---

## 7) Production Readiness Checklist

### Configuration Sanity

- [ ] All limit order parameters validated on startup
- [ ] `maxLimitDistancePips` is reasonable for symbol (check ATR)
- [ ] `expirationHours` is appropriate for trading session
- [ ] `staleOrderDistancePips` > `maxLimitDistancePips` (prevent immediate cancellation)
- [ ] `minRegimeConfidence` > 0.5 (avoid low-confidence regimes)
- [ ] `minSignalQualityScore` > 60 (only high-quality signals)
- [ ] `maxPendingOrdersPerSymbol` is set (prevent order slot exhaustion)
- [ ] `maxPendingOrderExposureMultiplier` is set (prevent over-leverage)

### Risk and Exposure Limits

- [ ] Pending order risk aggregation implemented and tested
- [ ] Maximum pending exposure enforced (2x position exposure)
- [ ] Margin validation includes pending orders
- [ ] Drawdown limits account for pending orders
- [ ] Position size limits account for pending orders
- [ ] Risk percentage per trade is reasonable (< 2% per trade)
- [ ] Maximum daily loss limit is set and enforced
- [ ] Maximum positions per symbol is set and enforced

### Broker Constraints

- [ ] Minimum distance from current price validated (broker requirement)
- [ ] Maximum distance from current price validated (broker requirement)
- [ ] Order expiration handled correctly (broker may auto-expire)
- [ ] Slippage tolerance set (for market order fallback)
- [ ] Maximum orders per symbol checked (broker limit)
- [ ] Order modification supported (for dynamic adjustment)
- [ ] Partial fills handled (if broker supports)

### Logging and Monitoring

- [ ] All limit order placements logged with full context
- [ ] All limit order fills logged with slippage
- [ ] All limit order cancellations logged with reason
- [ ] Fill rate metrics calculated and reported hourly
- [ ] Performance metrics tracked (win rate, profit factor, R:R)
- [ ] Database logging enabled for historical analysis
- [ ] Alert system for low fill rates (< 50%)
- [ ] Alert system for high cancellation rates (> 40%)

### Behavior on Restarts/Reconnects

- [ ] Pending orders are restored from broker on EA restart
- [ ] Order tracking is re-synchronized with broker state
- [ ] No duplicate orders placed after reconnect
- [ ] Stale order management resumes correctly
- [ ] Fill tracking continues after restart (query broker for fills)
- [ ] State persistence works (orders tracked in database)

### Behavior During News/Extreme Spread

- [ ] High-impact news events detected (economic calendar integration)
- [ ] Pending orders cancelled 30 minutes before high-impact news
- [ ] Limit order placement disabled during news window
- [ ] Spread monitoring enabled (skip limit orders if spread > threshold)
- [ ] Volatility-based distance scaling works (ATR-based)
- [ ] Emergency cancellation if spread spikes unexpectedly

### Migration Steps

**Phase 1: Preparation (Week 1)**
1. Backup current EA and database
2. Review and approve enhanced limit order framework
3. Set up test environment with historical data
4. Implement database schema changes
5. Add new configuration parameters

**Phase 2: Implementation (Week 2-3)**
1. Implement enhanced confluence detector with regime filtering
2. Implement multi-timeframe validation
3. Implement ATR-based distance scaling
4. Implement fill probability estimation
5. Implement pending order risk aggregation
6. Implement fill tracking and metrics

**Phase 3: Testing (Week 4)**
1. Unit tests for each new component
2. Integration tests for limit order pipeline
3. Backtest on historical data (5 years)
4. Compare limit order vs market order performance
5. Optimize parameters using genetic algorithm

**Phase 4: Validation (Week 5)**
1. Forward test on demo account (2 weeks)
2. Monitor fill rates, win rates, slippage
3. Validate risk aggregation works correctly
4. Validate news event handling works
5. Validate restart/reconnect behavior

**Phase 5: Deployment (Week 6)**
1. Deploy to live account with reduced position sizes (50% of normal)
2. Monitor closely for first week
3. Gradually increase position sizes if performance is good
4. Continue monitoring and optimization

**Rollback Plan:**
- Keep old EA version available
- Database changes are additive (no data loss)
- Can disable enhanced features via configuration flags
- Can revert to market orders if limit orders underperform

---

**END OF DOCUMENT**

