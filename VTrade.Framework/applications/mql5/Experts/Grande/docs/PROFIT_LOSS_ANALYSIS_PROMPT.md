# GRANDE TRADING SYSTEM - DAILY PERFORMANCE ANALYSIS & OPTIMIZATION

## Purpose
This document provides **daily-runnable instructions** for analyzing Grande Trading System performance using structured database queries. The analysis identifies data-driven optimization opportunities to improve returns, reduce stop loss hits, and maximize take profit success rates.

## Prerequisites

1. **Database Setup**: Ensure GrandeTradingData.db exists and is populated
2. **PowerShell**: Windows PowerShell 5.1 or later
3. **SQLite**: Native support via System.Data.SQLite (auto-loaded in script)
4. **Historical Data**: At least 10 completed trades for meaningful analysis

## Daily Workflow

### STEP 1: Run Daily Analysis Script

Execute this PowerShell command from the workspace root:

```powershell
.\scripts\RunDailyAnalysis.ps1
```

This script will:
1. Check database connectivity
2. Calculate performance metrics since last analysis
3. Identify optimization opportunities
4. Generate EA parameter recommendations
5. Update analysis timestamp

### STEP 2: Review Analysis Report

The script generates: `docs\DAILY_ANALYSIS_REPORT_YYYYMMDD.md`

Report sections:
- **Executive Summary**: Win rates, profit factor, total P/L
- **Signal Type Performance**: TREND vs BREAKOUT vs RANGE vs TRIANGLE
- **Regime Analysis**: Performance by market regime
- **Rejection Analysis**: Why trades are being blocked
- **Parameter Optimization Recommendations**: Specific changes to EA settings

### STEP 3: Apply Recommendations

Based on statistical confidence (minimum 20 trades or 7 days):
1. **Review** each recommendation's supporting data
2. **Test** in MT5 Strategy Tester if major changes
3. **Apply** to EA input parameters
4. **Recompile** GrandeTradingSystem.mq5
5. **Monitor** results in next analysis cycle

---

## Manual Analysis Queries

If you prefer hands-on analysis, use these SQL queries directly.

### Setup Database Connection

```powershell
# Load SQLite
Add-Type -Path "$env:ProgramFiles\System.Data.SQLite\netstandard2.0\System.Data.SQLite.dll"

# Connect to database
$dbPath = "$env:APPDATA\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5\Files\GrandeTradingData.db"
$connection = New-Object System.Data.SQLite.SQLiteConnection
$connection.ConnectionString = "Data Source=$dbPath;Version=3;"
$connection.Open()

# Helper function to run queries
function Invoke-SQLiteQuery {
    param([string]$Query)
    $command = $connection.CreateCommand()
    $command.CommandText = $Query
    $adapter = New-Object System.Data.SQLite.SQLiteDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataset) | Out-Null
    return $dataset.Tables[0]
}
```

---

## ANALYSIS QUERIES

### 1. Overall Performance Summary

```powershell
$query = @"
SELECT 
    COUNT(*) as total_trades,
    SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) as tp_hits,
    SUM(CASE WHEN outcome = 'SL_HIT' THEN 1 ELSE 0 END) as sl_hits,
    ROUND(100.0 * SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate,
    ROUND(SUM(profit_loss), 2) as total_pl,
    ROUND(AVG(profit_loss), 2) as avg_pl_per_trade,
    ROUND(MAX(profit_loss), 2) as best_trade,
    ROUND(MIN(profit_loss), 2) as worst_trade
FROM trades
WHERE outcome IN ('TP_HIT', 'SL_HIT')
  AND timestamp >= datetime('now', '-30 days');
"@

$results = Invoke-SQLiteQuery -Query $query
$results | Format-Table -AutoSize

Write-Host "`n=== PERFORMANCE SUMMARY ===" -ForegroundColor Cyan
Write-Host "Win Rate: $($results.win_rate)%" -ForegroundColor $(if ($results.win_rate -ge 60) { 'Green' } else { 'Yellow' })
Write-Host "Total P/L: $$($results.total_pl)" -ForegroundColor $(if ($results.total_pl -gt 0) { 'Green' } else { 'Red' })
```

### 2. Signal Type Performance (CRITICAL)

**Purpose**: Identify which signal types are profitable and should be prioritized.

```powershell
$query = @"
SELECT 
    signal_type,
    COUNT(*) as total_trades,
    SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) as wins,
    SUM(CASE WHEN outcome = 'SL_HIT' THEN 1 ELSE 0 END) as losses,
    ROUND(100.0 * SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate,
    ROUND(SUM(profit_loss), 2) as net_pl,
    ROUND(AVG(CASE WHEN outcome = 'TP_HIT' THEN pips_gained END), 2) as avg_win_pips,
    ROUND(AVG(CASE WHEN outcome = 'SL_HIT' THEN ABS(pips_gained) END), 2) as avg_loss_pips,
    ROUND(AVG(risk_reward_ratio), 2) as avg_expected_rr
FROM trades
WHERE outcome IN ('TP_HIT', 'SL_HIT')
  AND timestamp >= datetime('now', '-30 days')
GROUP BY signal_type
ORDER BY win_rate DESC;
"@

$signalPerf = Invoke-SQLiteQuery -Query $query
$signalPerf | Format-Table -AutoSize

Write-Host "`n=== SIGNAL TYPE RECOMMENDATIONS ===" -ForegroundColor Yellow
foreach ($row in $signalPerf) {
    if ($row.win_rate -lt 40) {
        Write-Host "⚠️  DISABLE $($row.signal_type) - Win rate too low ($($row.win_rate)%)" -ForegroundColor Red
    } elseif ($row.win_rate -gt 70) {
        Write-Host "✅ PRIORITIZE $($row.signal_type) - High win rate ($($row.win_rate)%)" -ForegroundColor Green
    }
}
```

### 3. Regime-Specific Win Rates

**Purpose**: Optimize signal selection based on market regime.

```powershell
$query = @"
SELECT 
    mc.regime,
    t.signal_type,
    COUNT(*) as trades,
    ROUND(100.0 * SUM(CASE WHEN t.outcome = 'TP_HIT' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate,
    ROUND(AVG(i.adx_h4), 2) as avg_adx,
    ROUND(AVG(i.rsi_h4), 2) as avg_rsi,
    ROUND(AVG(mc.atr), 5) as avg_atr
FROM trades t
JOIN market_conditions mc ON t.trade_id = mc.trade_id
JOIN indicators i ON t.trade_id = i.trade_id
WHERE t.outcome IN ('TP_HIT', 'SL_HIT')
  AND t.timestamp >= datetime('now', '-30 days')
GROUP BY mc.regime, t.signal_type
HAVING COUNT(*) >= 3
ORDER BY win_rate DESC;
"@

$regimePerf = Invoke-SQLiteQuery -Query $query
$regimePerf | Format-Table -AutoSize

Write-Host "`n=== REGIME-SPECIFIC RECOMMENDATIONS ===" -ForegroundColor Yellow
# Identify best signal type per regime
$regimePerf | Group-Object regime | ForEach-Object {
    $regime = $_.Name
    $best = $_.Group | Sort-Object win_rate -Descending | Select-Object -First 1
    $worst = $_.Group | Sort-Object win_rate | Select-Object -First 1
    
    Write-Host "`nRegime: $regime" -ForegroundColor Cyan
    Write-Host "  Best: $($best.signal_type) ($($best.win_rate)% win rate)" -ForegroundColor Green
    if ($worst.win_rate -lt 40) {
        Write-Host "  Avoid: $($worst.signal_type) ($($worst.win_rate)% win rate)" -ForegroundColor Red
    }
}
```

### 4. Optimal RSI Thresholds

**Purpose**: Find RSI levels that maximize win rate for each signal type.

```powershell
$query = @"
WITH rsi_buckets AS (
    SELECT 
        t.outcome,
        t.signal_type,
        t.direction,
        i.rsi_h4,
        CASE 
            WHEN i.rsi_h4 < 30 THEN 'OVERSOLD (<30)'
            WHEN i.rsi_h4 < 40 THEN 'BEARISH (30-40)'
            WHEN i.rsi_h4 < 60 THEN 'NEUTRAL (40-60)'
            WHEN i.rsi_h4 < 70 THEN 'BULLISH (60-70)'
            ELSE 'OVERBOUGHT (>70)'
        END as rsi_zone
    FROM trades t
    JOIN indicators i ON t.trade_id = i.trade_id
    WHERE t.outcome IN ('TP_HIT', 'SL_HIT')
      AND t.timestamp >= datetime('now', '-30 days')
)
SELECT 
    signal_type,
    direction,
    rsi_zone,
    COUNT(*) as trades,
    ROUND(100.0 * SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate
FROM rsi_buckets
GROUP BY signal_type, direction, rsi_zone
HAVING COUNT(*) >= 3
ORDER BY signal_type, direction, win_rate DESC;
"@

$rsiAnalysis = Invoke-SQLiteQuery -Query $query
$rsiAnalysis | Format-Table -AutoSize

Write-Host "`n=== RSI THRESHOLD RECOMMENDATIONS ===" -ForegroundColor Yellow
$rsiAnalysis | Group-Object signal_type, direction | ForEach-Object {
    $key = $_.Name
    $best = $_.Group | Sort-Object win_rate -Descending | Select-Object -First 1
    
    if ($best.win_rate -ge 60) {
        Write-Host "✅ $key: Best RSI zone is $($best.rsi_zone) ($($best.win_rate)% win rate)" -ForegroundColor Green
    }
}
```

### 5. Stop Loss Hit Pattern Analysis

**Purpose**: Understand why SL hits occur and adjust placement.

```powershell
$query = @"
SELECT 
    t.signal_type,
    mc.regime,
    COUNT(*) as sl_hits,
    ROUND(AVG(t.duration_minutes), 0) as avg_duration_mins,
    ROUND(AVG(i.adx_h4), 2) as avg_adx,
    ROUND(AVG(mc.atr), 5) as avg_atr,
    ROUND(AVG(ABS(t.pips_gained)), 2) as avg_pips_lost,
    ROUND(AVG(t.stop_loss - t.entry_price) / AVG(mc.atr), 2) as avg_sl_atr_multiple
FROM trades t
JOIN market_conditions mc ON t.trade_id = mc.trade_id
JOIN indicators i ON t.trade_id = i.trade_id
WHERE t.outcome = 'SL_HIT'
  AND t.timestamp >= datetime('now', '-30 days')
GROUP BY t.signal_type, mc.regime
HAVING COUNT(*) >= 3
ORDER BY sl_hits DESC;
"@

$slAnalysis = Invoke-SQLiteQuery -Query $query
$slAnalysis | Format-Table -AutoSize

Write-Host "`n=== STOP LOSS OPTIMIZATION ===" -ForegroundColor Yellow
foreach ($row in $slAnalysis) {
    if ($row.avg_sl_atr_multiple -lt 1.5) {
        Write-Host "⚠️  $($row.signal_type) in $($row.regime): SL too tight ($($row.avg_sl_atr_multiple)x ATR)" -ForegroundColor Red
        Write-Host "   Recommendation: Increase to 1.5-2.0x ATR" -ForegroundColor Yellow
    }
}
```

### 6. Take Profit Analysis

**Purpose**: Optimize TP placement for maximum profit capture.

```powershell
$query = @"
SELECT 
    t.signal_type,
    COUNT(*) as tp_hits,
    ROUND(AVG(t.duration_minutes), 0) as avg_duration_mins,
    ROUND(AVG(t.pips_gained), 2) as avg_pips_gained,
    ROUND(AVG((t.take_profit - t.entry_price) / (t.stop_loss - t.entry_price)), 2) as avg_actual_rr,
    ROUND(AVG(t.risk_reward_ratio), 2) as avg_planned_rr,
    ROUND(AVG(i.adx_h4), 2) as avg_adx
FROM trades t
JOIN indicators i ON t.trade_id = i.trade_id
WHERE t.outcome = 'TP_HIT'
  AND t.timestamp >= datetime('now', '-30 days')
GROUP BY t.signal_type
ORDER BY avg_pips_gained DESC;
"@

$tpAnalysis = Invoke-SQLiteQuery -Query $query
$tpAnalysis | Format-Table -AutoSize

Write-Host "`n=== TAKE PROFIT RECOMMENDATIONS ===" -ForegroundColor Yellow
foreach ($row in $tpAnalysis) {
    if ($row.avg_actual_rr -gt 2.5) {
        Write-Host "✅ $($row.signal_type): R:R ratio is good ($($row.avg_actual_rr):1)" -ForegroundColor Green
    } elseif ($row.avg_actual_rr -lt 1.5) {
        Write-Host "⚠️  $($row.signal_type): R:R ratio too low ($($row.avg_actual_rr):1)" -ForegroundColor Red
        Write-Host "   Recommendation: Increase TP target or tighten SL" -ForegroundColor Yellow
    }
}
```

### 7. Rejection Reason Analysis

**Purpose**: Identify if rejection criteria are too strict or need adjustment.

```powershell
$query = @"
SELECT 
    rejection_category,
    COUNT(*) as occurrences,
    ROUND(100.0 * COUNT(*) / (
        SELECT COUNT(*) FROM decisions 
        WHERE decision = 'REJECTED' 
        AND timestamp >= datetime('now', '-7 days')
    ), 2) as percentage,
    symbol
FROM decisions
WHERE decision = 'REJECTED'
  AND timestamp >= datetime('now', '-7 days')
GROUP BY rejection_category, symbol
ORDER BY occurrences DESC
LIMIT 10;
"@

$rejectionAnalysis = Invoke-SQLiteQuery -Query $query
$rejectionAnalysis | Format-Table -AutoSize

Write-Host "`n=== REJECTION ANALYSIS ===" -ForegroundColor Yellow
foreach ($row in $rejectionAnalysis) {
    if ($row.percentage -gt 30) {
        Write-Host "⚠️  HIGH REJECTION RATE: $($row.rejection_category) ($($row.percentage)%)" -ForegroundColor Red
        
        switch ($row.rejection_category) {
            'MARGIN_LOW' { Write-Host "   → Consider reducing lot sizes or increasing account balance" -ForegroundColor Yellow }
            'PULLBACK_TOO_FAR' { Write-Host "   → Consider increasing pullback tolerance (InpPullbackToleranceATR)" -ForegroundColor Yellow }
            'RSI_EXTREME' { Write-Host "   → Adjust RSI thresholds for trending markets" -ForegroundColor Yellow }
            'EMA_MISALIGNED' { Write-Host "   → Consider disabling EMA alignment (InpRequireEmaAlignment=false)" -ForegroundColor Yellow }
        }
    }
}
```

### 8. Time-of-Day Performance

**Purpose**: Identify best trading hours for each pair.

```powershell
$query = @"
SELECT 
    symbol,
    strftime('%H', timestamp) as hour_utc,
    COUNT(*) as trades,
    ROUND(100.0 * SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate,
    ROUND(AVG(profit_loss), 2) as avg_pl
FROM trades
WHERE outcome IN ('TP_HIT', 'SL_HIT')
  AND timestamp >= datetime('now', '-30 days')
GROUP BY symbol, hour_utc
HAVING COUNT(*) >= 2
ORDER BY symbol, win_rate DESC;
"@

$timeAnalysis = Invoke-SQLiteQuery -Query $query
$timeAnalysis | Format-Table -AutoSize

Write-Host "`n=== TIME-OF-DAY RECOMMENDATIONS ===" -ForegroundColor Yellow
$timeAnalysis | Group-Object symbol | ForEach-Object {
    $pair = $_.Name
    $bestHours = $_.Group | Where-Object { $_.win_rate -ge 60 } | Select-Object -ExpandProperty hour_utc
    $worstHours = $_.Group | Where-Object { $_.win_rate -le 40 } | Select-Object -ExpandProperty hour_utc
    
    Write-Host "`n$pair:" -ForegroundColor Cyan
    if ($bestHours) {
        Write-Host "  Best Hours (UTC): $($bestHours -join ', ')" -ForegroundColor Green
    }
    if ($worstHours) {
        Write-Host "  Avoid Hours (UTC): $($worstHours -join ', ')" -ForegroundColor Red
    }
}
```

### 9. Pullback Tolerance Analysis

**Purpose**: Optimize pullback tolerance parameters.

```powershell
$query = @"
SELECT 
    CASE 
        WHEN i.ema20_distance_pips <= i.base_atr_limit THEN '0-1x ATR'
        WHEN i.ema20_distance_pips <= i.base_atr_limit * 1.5 THEN '1-1.5x ATR'
        WHEN i.ema20_distance_pips <= i.base_atr_limit * 2 THEN '1.5-2x ATR'
        WHEN i.ema20_distance_pips <= i.adjusted_atr_limit THEN '2x+ ATR (FinBERT Adjusted)'
        ELSE 'Beyond Adjusted Limit'
    END as pullback_range,
    COUNT(*) as trades,
    ROUND(100.0 * SUM(CASE WHEN t.outcome = 'TP_HIT' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate,
    ROUND(AVG(i.finbert_multiplier), 2) as avg_finbert_mult,
    ROUND(AVG(t.profit_loss), 2) as avg_pl
FROM trades t
JOIN indicators i ON t.trade_id = i.trade_id
WHERE t.outcome IN ('TP_HIT', 'SL_HIT')
  AND t.signal_type = 'TREND'
  AND t.timestamp >= datetime('now', '-30 days')
GROUP BY pullback_range
ORDER BY 
    CASE pullback_range
        WHEN '0-1x ATR' THEN 1
        WHEN '1-1.5x ATR' THEN 2
        WHEN '1.5-2x ATR' THEN 3
        WHEN '2x+ ATR (FinBERT Adjusted)' THEN 4
        ELSE 5
    END;
"@

$pullbackAnalysis = Invoke-SQLiteQuery -Query $query
$pullbackAnalysis | Format-Table -AutoSize

Write-Host "`n=== PULLBACK TOLERANCE RECOMMENDATIONS ===" -ForegroundColor Yellow
$optimal = $pullbackAnalysis | Sort-Object win_rate -Descending | Select-Object -First 1
Write-Host "✅ Optimal Range: $($optimal.pullback_range) ($($optimal.win_rate)% win rate)" -ForegroundColor Green

if ($optimal.pullback_range -like "*0-1x ATR*") {
    Write-Host "   → Current setting may be good. Monitor for missed opportunities." -ForegroundColor Yellow
} elseif ($optimal.pullback_range -like "*2x+ ATR*") {
    Write-Host "   → Consider increasing InpPullbackToleranceATR to 2.5 or 3.0" -ForegroundColor Yellow
}
```

### 10. Parameter Optimization History

**Purpose**: Track what optimizations have been applied and their effectiveness.

```powershell
$query = @"
SELECT 
    timestamp,
    parameter_name,
    old_value,
    new_value,
    ROUND(new_value - old_value, 2) as change,
    win_rate_before,
    win_rate_after,
    ROUND(win_rate_after - win_rate_before, 2) as improvement,
    trades_analyzed,
    change_reason
FROM optimization_history
ORDER BY timestamp DESC
LIMIT 20;
"@

$optHistory = Invoke-SQLiteQuery -Query $query
$optHistory | Format-Table -AutoSize

Write-Host "`n=== OPTIMIZATION EFFECTIVENESS ===" -ForegroundColor Cyan
$recentOpts = $optHistory | Select-Object -First 5
foreach ($opt in $recentOpts) {
    $color = if ($opt.improvement -gt 0) { 'Green' } else { 'Red' }
    Write-Host "$($opt.parameter_name): $($opt.old_value) → $($opt.new_value) | Impact: $($opt.improvement)%" -ForegroundColor $color
}
```

---

## GENERATING EA PARAMETER RECOMMENDATIONS

After running the analysis queries above, consolidate findings into actionable EA parameter changes.

### EA Input Parameters Reference

Current Grande EA parameters (GrandeTradingSystem.mq5):

```cpp
// Risk Management
input double InpRiskPercentTrend = 2.0;          // Risk % for Trend signals
input double InpRiskPercentBreakout = 1.5;       // Risk % for Breakout signals
input double InpRiskPercentRange = 0.8;          // Risk % for Range signals

// Indicator Thresholds
input double InpRSI_Overbought_Trending = 80.0;  // RSI overbought (trending)
input double InpRSI_Oversold_Trending = 20.0;    // RSI oversold (trending)
input double InpRSI_Overbought_Ranging = 70.0;   // RSI overbought (ranging)
input double InpRSI_Oversold_Ranging = 30.0;     // RSI oversold (ranging)
input double InpADX_Strong_Threshold = 25.0;     // ADX strong trend
input double InpADX_Range_Threshold = 20.0;      // ADX range max

// Pullback Tolerance
input double InpPullbackToleranceATR = 2.0;      // Max pullback (ATR multiple)

// Stop Loss / Take Profit
input double InpATR_SL_Multiplier = 1.5;         // SL distance (ATR multiple)
input double InpATR_TP_Multiplier_Trend = 3.0;   // TP for trend (ATR multiple)
input double InpATR_TP_Multiplier_Breakout = 2.5;// TP for breakout (ATR multiple)
input double InpATR_TP_Multiplier_Range = 2.0;   // TP for range (ATR multiple)

// Signal Enablers
input bool InpRequireEmaAlignment = true;        // Require EMA alignment
input bool InpEnableTrendSignals = true;
input bool InpEnableBreakoutSignals = true;
input bool InpEnableRangeSignals = true;
input bool InpEnableTriangleSignals = false;

// Margin Safety
input double InpMinMarginLevel = 200.0;          // Minimum margin %
```

### Example Recommendation Output

```markdown
## EA PARAMETER RECOMMENDATIONS (YYYY-MM-DD)

### SIGNAL ENABLEMENT
- ❌ DISABLE Triangle Signals (5% win rate, -$45 net P/L)
- ✅ KEEP Trend Signals (68% win rate, +$230 net P/L)
- ⚠️  REVIEW Breakout Signals (45% win rate, needs RSI optimization)

### RSI THRESHOLDS
- TREND SELLS: Best performance in RSI 60-70 zone
  → Change InpRSI_Overbought_Trending = 80.0 to 70.0
  
- TREND BUYS: Best performance in RSI 30-40 zone
  → Change InpRSI_Oversold_Trending = 20.0 to 30.0

### STOP LOSS ADJUSTMENTS
- TREND signals: Average SL hit at 1.2x ATR (too tight)
  → Change InpATR_SL_Multiplier from 1.5 to 2.0
  
### PULLBACK TOLERANCE
- TREND signals: 85% win rate at 2x+ ATR pullback distance
  → Change InpPullbackToleranceATR from 2.0 to 2.5

### REJECTION CRITERIA
- 45% of signals rejected for PULLBACK_TOO_FAR
  → Increase pullback tolerance as noted above
  
### TIME FILTERS (Consider adding)
- EURUSD: Avoid 00:00-04:00 UTC (20% win rate)
- GBPUSD: Best 08:00-12:00 UTC (75% win rate)
```

---

## IMPLEMENTATION WORKFLOW

### Apply Optimizations to EA

1. **Open** `GrandeTradingSystem.mq5` in MetaEditor
2. **Locate** input parameters at top of file
3. **Modify** based on recommendations
4. **Document** changes in `optimization_history` table:

```powershell
$query = @"
INSERT INTO optimization_history (
    timestamp, parameter_name, old_value, new_value, 
    change_reason, trades_analyzed, win_rate_before, win_rate_after, applied_by
) VALUES (
    datetime('now'),
    'InpATR_SL_Multiplier',
    1.5,
    2.0,
    'Analysis showed SL too tight - avg hit at 1.2x ATR',
    45,
    52.3,
    NULL,
    'Manual'
);
"@
Invoke-SQLiteQuery -Query $query
```

5. **Recompile** EA (F7 in MetaEditor)
6. **Restart** MT5 or reload chart
7. **Monitor** next 10-20 trades for effectiveness

### Track Optimization Results

After 7 days, run comparison query:

```powershell
$query = @"
WITH before_opt AS (
    SELECT AVG(CASE WHEN outcome = 'TP_HIT' THEN 1.0 ELSE 0.0 END) * 100 as win_rate
    FROM trades
    WHERE timestamp < (SELECT timestamp FROM optimization_history ORDER BY timestamp DESC LIMIT 1)
),
after_opt AS (
    SELECT AVG(CASE WHEN outcome = 'TP_HIT' THEN 1.0 ELSE 0.0 END) * 100 as win_rate
    FROM trades
    WHERE timestamp >= (SELECT timestamp FROM optimization_history ORDER BY timestamp DESC LIMIT 1)
      AND outcome IN ('TP_HIT', 'SL_HIT')
)
SELECT 
    b.win_rate as before_optimization,
    a.win_rate as after_optimization,
    ROUND(a.win_rate - b.win_rate, 2) as improvement
FROM before_opt b, after_opt a;
"@

$comparison = Invoke-SQLiteQuery -Query $query
$comparison | Format-Table -AutoSize
```

Update optimization_history:

```powershell
$query = @"
UPDATE optimization_history
SET win_rate_after = $($comparison.after_optimization),
    trades_analyzed = (
        SELECT COUNT(*) FROM trades 
        WHERE timestamp >= (SELECT MAX(timestamp) FROM optimization_history)
    )
WHERE timestamp = (SELECT MAX(timestamp) FROM optimization_history);
"@
Invoke-SQLiteQuery -Query $query
```

---

## STATISTICAL CONFIDENCE REQUIREMENTS

Before applying optimizations, ensure statistical significance:

| Metric | Minimum Sample Size | Notes |
|--------|---------------------|-------|
| Signal Type Win Rate | 20 trades | Less prone to variance |
| Regime Performance | 10 trades per regime | More specific context |
| RSI/ADX Thresholds | 30 trades total | Requires distribution |
| Time-of-Day | 5 trades per hour | Session patterns emerge |
| Pullback Tolerance | 15 trades | Enough variance coverage |

**Rule of Thumb**: If sample size is below minimum, note as "PRELIMINARY - Needs More Data"

---

## AUTOMATION SCRIPT

Create `scripts\RunDailyAnalysis.ps1` that:

1. Connects to database
2. Runs all 10 analysis queries
3. Generates markdown report
4. Identifies recommendations with statistical confidence
5. Outputs EA parameter changes
6. Updates analysis timestamp

(Full script provided in next section)

---

## TROUBLESHOOTING

### Database Locked
```powershell
# Close MT5 or wait for EA to release database
# Or copy database to temp location for analysis
Copy-Item $dbPath "$env:TEMP\GrandeTradingData_analysis.db"
# Then connect to temp copy
```

### No Data Since Last Analysis
```powershell
# Check last trade timestamp
$query = "SELECT MAX(timestamp) as last_trade FROM trades;"
Invoke-SQLiteQuery -Query $query
```

### Query Performance Issues
```sql
-- Ensure indexes exist
CREATE INDEX IF NOT EXISTS idx_trades_timestamp ON trades(timestamp);
CREATE INDEX IF NOT EXISTS idx_trades_outcome ON trades(outcome);
-- Vacuum database periodically
VACUUM;
```

---

## DAILY CHECKLIST

- [ ] Run daily analysis script
- [ ] Review win rates by signal type
- [ ] Check rejection reasons
- [ ] Identify any parameter recommendations
- [ ] Apply changes if confidence threshold met
- [ ] Document changes in optimization_history
- [ ] Recompile and reload EA
- [ ] Monitor next 10 trades for impact

---

## SUCCESS METRICS

Target performance indicators:

- **Win Rate**: >60% overall
- **Profit Factor**: >1.5 (total wins / total losses)
- **Signal Type Balance**: No single type >70% of trades
- **Rejection Rate**: <30% of decisions
- **SL Hit Rate**: <40%
- **TP Hit Rate**: >60%
- **Average R:R Achieved**: >2.0

Monitor these weekly and adjust strategies accordingly.

---

## NEXT STEPS

1. **Immediate**: Run first analysis using queries above
2. **Day 1-7**: Collect baseline data without changes
3. **Day 8+**: Apply first optimization based on data
4. **Day 15+**: Measure optimization effectiveness
5. **Ongoing**: Weekly optimization cycles with A/B tracking

This data-driven approach ensures every EA modification is backed by real performance data from your trading account.
