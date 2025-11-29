# Grande Trading System - Profit-Critical Code

## Overview

Profit-critical modules handle profit calculation, risk management, performance tracking, signal quality assessment, and position optimization.

## Module Architecture

### 1. GrandeProfitCalculator

**Location:** `Include/GrandeProfitCalculator.mqh`

**Purpose:** Centralized profit calculation and performance metrics.

**Key Functions:**
- `CalculatePositionProfitPips()` - Position profit in pips
- `CalculatePositionProfitCurrency()` - Position profit in currency
- `CalculateAccountProfit()` - Total account profit
- `CalculateProfitFactor()` - Win/loss ratio calculation
- `GetPerformanceMetrics()` - Comprehensive performance summary

**Usage:**
```mql5
CGrandeProfitCalculator* profitCalc = new CGrandeProfitCalculator();
profitCalc.Initialize(_Symbol);

double profitPips = profitCalc.CalculatePositionProfitPips(ticket);
double profitCurrency = profitCalc.CalculatePositionProfitCurrency(ticket);
PerformanceMetrics metrics = profitCalc.GetPerformanceMetrics();
```

**Profit Calculation:**
- Pip calculations handle different symbol types (JPY pairs, standard pairs)
- Currency calculations account for swap costs and commissions
- Supports both open positions and historical trade analysis

### 2. GrandeRiskManager

**Location:** `../VSol/GrandeRiskManager.mqh` (existing)

**Purpose:** Risk management and position sizing.

**Key Functions:**
- `CalculateLotSize()` - Risk-based position sizing
- `CheckDrawdown()` - Drawdown protection
- `CheckMaxPositions()` - Position limit validation
- `ValidateMarginBeforeTrade()` - Margin availability checks
- `CalculateStopLoss()` - Stop loss calculation
- `CalculateTakeProfit()` - Take profit calculation

**Note:** This module exists in VSol folder and is fully integrated.

### 3. GrandePerformanceTracker

**Location:** `Include/GrandePerformanceTracker.mqh`

**Purpose:** Track trade outcomes and generate performance reports.

**Key Functions:**
- `RecordTradeOutcome()` - Log trade result
- `CalculateWinRate()` - Win rate by category
- `GetPerformanceBySignalType()` - Signal type analysis
- `GetPerformanceBySymbol()` - Symbol performance
- `GetPerformanceByRegime()` - Regime-based performance
- `GeneratePerformanceReport()` - Comprehensive report

**Usage:**
```mql5
CGrandePerformanceTracker* perfTracker = new CGrandePerformanceTracker();
perfTracker.Initialize(_Symbol, dbManager, profitCalculator);

perfTracker.RecordTradeOutcome(ticket, "TP_HIT", closePrice);
double winRate = perfTracker.CalculateWinRate("TREND");
string report = perfTracker.GeneratePerformanceReport(30);
```

**Performance Tracking:**
- Tracks outcomes: TP_HIT, SL_HIT, TRAILING_STOP, MANUAL_CLOSE
- Categorizes performance by signal type, symbol, and regime
- Generates markdown-formatted reports

### 4. GrandeSignalQualityAnalyzer

**Location:** `Include/GrandeSignalQualityAnalyzer.mqh`

**Purpose:** Score signal quality and validate signal conditions.

**Key Functions:**
- `ScoreSignalQuality()` - Calculate signal confidence score
- `ValidateSignalConditions()` - Check all signal prerequisites
- `GetSignalSuccessRate()` - Historical signal performance
- `FilterLowQualitySignals()` - Reject weak signals
- `GetOptimalSignalThreshold()` - Dynamic threshold adjustment

**Usage:**
```mql5
CGrandeSignalQualityAnalyzer* qualityAnalyzer = new CGrandeSignalQualityAnalyzer();
qualityAnalyzer.Initialize(_Symbol, stateManager, eventBus);

SignalQualityScore score = qualityAnalyzer.ScoreSignalQuality(
    "TREND", regimeConfidence, confluenceScore, rsi, adx, sentimentConfidence);

if(!qualityAnalyzer.FilterLowQualitySignals(score.overallScore))
{
    // Execute trade
}
```

**Quality Scoring:**
- Overall score is weighted average: Regime 40%, Confluence 25%, Technical 20%, Sentiment 15%
- Dynamic threshold adjustment based on historical performance
- Tracks signal success rates for continuous improvement

### 5. Position Optimization

**Location:** `Include/GrandePositionOptimizer.mqh`

**Purpose:** Position management and optimization wrapper.

**Key Functions:**
- `UpdateTrailingStops()` - Trailing stop logic
- `UpdateBreakevenStops()` - Breakeven stop placement
- `ExecutePartialCloses()` - Partial close logic
- `ManageAllPositions()` - Comprehensive position management

**Note:** Wraps GrandeRiskManager position management functions and adds event publishing.

## Common Patterns

### 1. Always Use Profit Calculator

**Pattern:** All profit calculations use GrandeProfitCalculator

**Rule:** No inline profit calculations in trading logic

```mql5
// DO:
double profit = profitCalc.CalculatePositionProfitPips(ticket);

// DON'T:
double profit = (currentPrice - entryPrice) / _Point; // Inline calculation
```

### 2. Always Validate Risk

**Pattern:** All risk checks go through GrandeRiskManager

**Rule:** No trading without risk validation

```mql5
// DO:
if(!g_riskManager.CheckDrawdown() || !g_riskManager.CheckMaxPositions())
    return;

// DON'T:
// Skip risk checks
```

### 3. Always Track Performance

**Pattern:** All trade outcomes recorded via GrandePerformanceTracker

**Rule:** Every trade outcome must be tracked

```mql5
// DO:
perfTracker.RecordTradeOutcome(ticket, outcome, closePrice);

// DON'T:
// Skip performance tracking
```

### 4. Always Score Signal Quality

**Pattern:** All signals scored via GrandeSignalQualityAnalyzer

**Rule:** Low-quality signals rejected before execution

```mql5
// DO:
SignalQualityScore score = qualityAnalyzer.ScoreSignalQuality(...);
if(qualityAnalyzer.FilterLowQualitySignals(score.overallScore))
    return; // Reject low-quality signal

// DON'T:
// Execute signals without quality scoring
```

## Profit Calculation Patterns

### Pip Calculation

Pip calculations handle different symbol types:

```mql5
// For 5-digit pairs: pip = 10 * _Point
// For 3-digit pairs (JPY): pip = 10 * _Point
// For other pairs: uses tick size as fallback
double pipSize = GetPipSize();
double profitPips = (currentPrice - entryPrice) / pipSize;
```

### Currency Calculation

Currency calculations account for all costs:

```mql5
double profit = PositionGetDouble(POSITION_PROFIT);
double swap = PositionGetDouble(POSITION_SWAP);
double commission = PositionGetDouble(POSITION_COMMISSION);
double totalProfit = profit + swap + commission;
```

## Risk Management Patterns

### Position Sizing

All position sizing goes through GrandeRiskManager:

```mql5
double stopDistancePips = rs.atr_current * 1.2 / GetPipSize();
double lotSize = g_riskManager.CalculateLotSize(stopDistancePips, rs.regime);
```

### Risk Validation

All risk checks go through GrandeRiskManager:

```mql5
if(!g_riskManager.CheckDrawdown())
    return; // Trading disabled due to drawdown

if(!g_riskManager.CheckMaxPositions())
    return; // Maximum positions reached

if(!ValidateMarginBeforeTrade(orderType, lotSize, entryPrice))
    return; // Insufficient margin
```

## Performance Tracking Patterns

### Recording Trade Outcomes

All trade outcomes must be recorded:

```mql5
// When position closes
perfTracker.RecordTradeOutcome(ticket, "TP_HIT", closePrice);

// Or with full outcome structure
TradeOutcome outcome;
outcome.ticket = ticket;
outcome.outcome = "TP_HIT";
outcome.profitPips = profitPips;
perfTracker.RecordTradeOutcome(outcome);
```

### Performance Analysis

Performance can be analyzed by category:

```mql5
// By signal type
PerformanceByCategory trendPerf = perfTracker.GetPerformanceBySignalType("TREND");

// By symbol
PerformanceByCategory eurusdPerf = perfTracker.GetPerformanceBySymbol("EURUSD");

// By regime
PerformanceByCategory trendingPerf = perfTracker.GetPerformanceByRegime("TRENDING_BULL");
```

## Signal Quality Patterns

### Quality Scoring

All signals should be scored before execution:

```mql5
SignalQualityScore score = qualityAnalyzer.ScoreSignalQuality(
    signalType, regimeConfidence, confluenceScore, rsi, adx, sentimentConfidence);

if(score.isValid && !qualityAnalyzer.FilterLowQualitySignals(score.overallScore))
{
    // Execute trade
}
else
{
    // Reject signal
    Print("Signal rejected: ", score.rejectionReason);
}
```

### Dynamic Thresholds

Signal thresholds adjust based on performance:

```mql5
double threshold = qualityAnalyzer.GetOptimalSignalThreshold();
// Threshold automatically adjusts based on recent signal success rates
```

## Integration Points

### State Manager
- Profit metrics stored in State Manager
- Performance cache managed by State Manager
- Signal quality history tracked in State Manager

### Event Bus
- Profit milestone events published
- Performance report events published
- Signal quality events published
- Risk warning events published

### Database Manager
- Trade outcomes stored in database
- Performance metrics persisted
- Signal quality history recorded

### Component Registry
- All profit-critical modules registered
- Health monitoring enabled
- Performance tracking integrated

## Troubleshooting

### Issue: Profit calculations incorrect

**Solution:**
- Verify symbol is correctly initialized in profit calculator
- Check pip size calculation for symbol type
- Ensure swap and commission are included in currency calculations

### Issue: Performance metrics not updating

**Solution:**
- Verify trade outcomes are being recorded
- Check database connection for performance tracker
- Ensure cache is being invalidated on new trades

### Issue: Signal quality scores too low

**Solution:**
- Review quality scoring components (regime, confluence, technical, sentiment)
- Check if thresholds are set too high
- Verify signal history is being populated for dynamic thresholds

### Issue: Risk checks blocking all trades

**Solution:**
- Check drawdown limits
- Verify position limits
- Review margin requirements
- Check if risk manager is properly initialized

---

**Related:** [ARCHITECTURE.md](ARCHITECTURE.md) | [DEVELOPMENT.md](DEVELOPMENT.md)
