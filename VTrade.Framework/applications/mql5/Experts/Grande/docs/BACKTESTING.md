# Grande Trading System - Backtesting Guide

## Overview

Hybrid backtesting approach using MT5 Strategy Tester (primary) with SQLite database for analysis and validation.

## Backtesting Architecture

1. **MT5 Strategy Tester** - Primary backtesting engine (built-in, high performance)
2. **SQLite Database** - Data storage, analysis, and custom queries
3. **PowerShell Scripts** - Data validation and coverage analysis

## Current Status

**Completed:**
- ✅ Historical data backfill system (`BackfillHistoricalData.mq5`)
- ✅ Database schema with `market_data` table
- ✅ Data coverage statistics (`GetDataCoverageStats()`)
- ✅ Backup and safety checks
- ✅ PowerShell validation scripts (`CheckBacktestData.ps1`)

**Planned:**
- 🔄 Custom backtesting engine using database data (optional)
- 🔄 Database query methods for historical data retrieval
- 🔄 Performance comparison tools (limit orders vs market orders)

## Backtesting Workflow

### Step 1: Data Preparation

1. **Backfill historical data:**
   ```mql5
   // Run BackfillHistoricalData.mq5 script
   // Set InpBackfillYears = 5
   // Set InpBackfillMultipleTimeframes = true
   ```

2. **Verify data coverage:**
   ```powershell
   .\scripts\CheckBacktestData.ps1 -Detailed
   ```

3. **Check data quality:**
   - Verify no gaps in data
   - Check oldest/newest timestamps
   - Confirm all required symbols/timeframes are present

### Step 2: Configure Strategy Tester

1. **Open Strategy Tester** (View → Strategy Tester)

2. **Select EA:**
   - Expert Advisor: `GrandeTradingSystem`

3. **Set Parameters:**
   - Symbol: EURUSD (or your test symbol)
   - Period: 2020-01-01 to 2024-12-31
   - Model: "Every tick" (most accurate)
   - Optimization: Disabled (for initial test)

4. **EA Inputs:**
   - `InpEnableDatabase = true` (to log results)
   - `InpUseLimitOrders = true` (to test limit orders)
   - `InpTrackFillMetrics = true` (to track fill rates)
   - Other parameters as needed

### Step 3: Run Backtest

1. Click "Start" in Strategy Tester
2. Monitor progress in the "Journal" tab
3. Wait for completion

### Step 4: Analyze Results

1. **MT5 Backtest Report:**
   - Review key metrics (profit, drawdown, win rate)
   - Check trade history
   - Analyze equity curve

2. **Database Analysis:**
   ```powershell
   .\scripts\CheckBacktestData.ps1 -Detailed
   ```

3. **SQL Queries:**
   ```sql
   -- Fill rate
   SELECT 
       COUNT(*) as total,
       COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) as filled,
       ROUND(100.0 * COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) / COUNT(*), 2) as fill_rate
   FROM limit_orders;
   ```

## Key Metrics

### Primary Metrics

1. **Expectancy:** (Win Rate × Avg Win) - (Loss Rate × Avg Loss)
   - Target: > 0

2. **Risk-Reward Ratio:** Average Win / Average Loss
   - Target: > 1.5:1

3. **Maximum Drawdown:** Peak-to-trough decline
   - Target: < 20%

4. **Fill Rate:** (Filled Limit Orders / Total Limit Orders) × 100
   - Target: > 60%

5. **Slippage:** Difference between limit price and fill price
   - Target: < 2 pips average

### Secondary Metrics

6. **Average Time to Fill:** < 2 hours
7. **Win Rate:** > 55% for limit orders
8. **Profit Factor:** > 1.5
9. **Confluence Factor Effectiveness:** Which factors lead to best fills
10. **Regime-Based Performance:** Win rate by market regime

## Comparison: Limit Orders vs Market Orders

### Methodology

1. **Run two backtests:**
   - Test 1: `InpUseLimitOrders = true`
   - Test 2: `InpUseLimitOrders = false`

2. **Compare metrics:**
   - Win rate
   - Average slippage
   - Profit factor
   - Maximum drawdown
   - Fill rate (for limit orders)

3. **Identify scenarios:**
   - When limit orders outperform market orders
   - When market orders are better
   - Optimal conditions for each approach

### SQL Queries for Comparison

```sql
-- Limit order performance
SELECT 
    'LIMIT' as order_type,
    COUNT(*) as total_trades,
    AVG(pnl) as avg_pnl,
    SUM(CASE WHEN pnl > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as win_rate
FROM trades t
JOIN limit_orders lo ON t.ticket = lo.ticket
WHERE lo.filled_time IS NOT NULL;

-- Market order performance
SELECT 
    'MARKET' as order_type,
    COUNT(*) as total_trades,
    AVG(pnl) as avg_pnl,
    SUM(CASE WHEN pnl > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as win_rate
FROM trades
WHERE ticket NOT IN (SELECT ticket FROM limit_orders);
```

## Optimization Strategy

### Parameters to Optimize

1. **Limit Order Parameters:**
   - `maxLimitDistancePips`: Test 20, 30, 40, 50 pips
   - `minConfluenceScore`: Test 5, 6, 7, 8
   - `minRegimeConfidence`: Test 0.60, 0.65, 0.70
   - `expirationHours`: Test 2, 4, 6, 8 hours

2. **Trading Parameters:**
   - Risk per trade
   - Stop loss distance
   - Take profit distance
   - Position sizing

### Optimization Process

1. **Use MT5 Genetic Algorithm:**
   - Strategy Tester → Optimization tab
   - Select parameters to optimize
   - Set ranges
   - Run optimization

2. **Analyze Results:**
   - Review optimization graph
   - Identify best parameter sets
   - Validate on out-of-sample data

3. **Forward Testing:**
   - Test optimized parameters on demo account
   - Monitor for 2-4 weeks
   - Compare with backtest results

## Data Validation

### Before Backtesting

1. **Check data coverage:**
   ```powershell
   .\scripts\CheckBacktestData.ps1 -Detailed
   ```

2. **Verify no gaps:**
   ```sql
   SELECT 
       timestamp,
       LAG(timestamp) OVER (ORDER BY timestamp) as prev_timestamp,
       (julianday(timestamp) - julianday(LAG(timestamp) OVER (ORDER BY timestamp))) * 24 as hours_gap
   FROM market_data
   WHERE symbol = 'EURUSD!' AND timeframe = 16385
   ORDER BY timestamp;
   ```

3. **Validate data quality:**
   - Check for zero/null values
   - Verify price ranges are reasonable
   - Confirm timestamps are sequential

### After Backtesting

1. **Compare MT5 data with database:**
   - Verify backtest used correct data
   - Check for discrepancies

2. **Validate trade logging:**
   - All trades logged to database
   - Limit orders tracked correctly
   - Fill metrics recorded

## Troubleshooting

### Issue: Insufficient Historical Data

**Solution:**
1. Run `BackfillHistoricalData.mq5` script
2. Increase `InpBackfillYears` parameter
3. Enable `InpBackfillMultipleTimeframes` for more data

### Issue: Backtest Results Don't Match Database

**Possible causes:**
- MT5 using different data source
- Database data gaps
- Timing differences

**Solution:**
1. Verify data coverage matches backtest period
2. Check for gaps in database
3. Compare MT5 data with database records

### Issue: Database Locked During Backtest

**Solution:**
- Close other applications using database
- Use backup before backtest
- Run backtest with database logging disabled if needed

## Configuration

**Instruments:** EURUSD, GBPUSD, USDJPY, AUDUSD, NZDUSD  
**Timeframes:** H1 (primary), H4, M15 (validation)  
**Period:** 2020-01-01 to 2024-12-31 (5 years)  
**Model:** "Every tick"  
**Spread:** Current or fixed (2 pips for EURUSD)  
**Commission:** $7 per lot round turn

## Resources

- **Backfill Script:** `Testing/BackfillHistoricalData.mq5`
- **Data Check Script:** `scripts/CheckBacktestData.ps1`
- **Database Manager:** `Include/GrandeDatabaseManager.mqh`
- **Analysis Documentation:** [LIMIT_ORDERS.md](LIMIT_ORDERS.md)

---

**Related:** [LIMIT_ORDERS.md](LIMIT_ORDERS.md) | [DATA_SOURCES.md](DATA_SOURCES.md)

