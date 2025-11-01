# Grande Trading System - Daily Performance Analysis Script
# Purpose: Generate daily analysis report with EA optimization recommendations

param(
    [Parameter(Mandatory=$false)]
    [string]$DatabasePath = "$env:APPDATA\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5\Files\GrandeTradingData.db",
    
    [Parameter(Mandatory=$false)]
    [int]$MinimumTrades = 20,
    
    [Parameter(Mandatory=$false)]
    [int]$DaysToAnalyze = 30
)

$ErrorActionPreference = "Stop"
$reportDate = Get-Date -Format "yyyyMMdd"
$reportPath = ".\docs\DAILY_ANALYSIS_REPORT_$reportDate.md"

Write-Host "=== GRANDE DAILY PERFORMANCE ANALYSIS ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host "Report: $reportPath" -ForegroundColor Yellow

# Connect to database
try {
    Add-Type -AssemblyName System.Data
    $connection = New-Object System.Data.SQLite.SQLiteConnection
    $connection.ConnectionString = "Data Source=$DatabasePath;Version=3;"
    $connection.Open()
    Write-Host "✅ Database connected" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Could not connect to database" -ForegroundColor Red
    Write-Host "   Path: $DatabasePath" -ForegroundColor Yellow
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Helper function
function Invoke-SQLiteQuery {
    param([string]$Query)
    $command = $connection.CreateCommand()
    $command.CommandText = $Query
    $adapter = New-Object System.Data.SQLite.SQLiteDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataset) | Out-Null
    return $dataset.Tables[0]
}

# Initialize report
$report = @"
# Grande Trading System - Daily Analysis Report
**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Analysis Period**: Last $DaysToAnalyze days  
**Minimum Sample Size**: $MinimumTrades trades

---

"@

Write-Host "`n📊 Running performance analysis..." -ForegroundColor Cyan

# 1. Overall Performance Summary
$overallQuery = @"
SELECT 
    COUNT(*) as total_trades,
    SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) as tp_hits,
    SUM(CASE WHEN outcome = 'SL_HIT' THEN 1 ELSE 0 END) as sl_hits,
    ROUND(100.0 * SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) / 
        NULLIF(COUNT(*), 0), 2) as win_rate,
    ROUND(SUM(CASE WHEN outcome = 'TP_HIT' THEN pips_gained ELSE 0 END), 2) as total_win_pips,
    ROUND(SUM(CASE WHEN outcome = 'SL_HIT' THEN ABS(pips_gained) ELSE 0 END), 2) as total_loss_pips,
    ROUND(AVG(CASE WHEN outcome = 'TP_HIT' THEN pips_gained END), 2) as avg_win_pips,
    ROUND(AVG(CASE WHEN outcome = 'SL_HIT' THEN ABS(pips_gained) END), 2) as avg_loss_pips
FROM trades
WHERE outcome IN ('TP_HIT', 'SL_HIT')
  AND timestamp >= datetime('now', '-$DaysToAnalyze days');
"@

$overall = Invoke-SQLiteQuery -Query $overallQuery

$report += @"
## Executive Summary

| Metric | Value |
|--------|-------|
| Total Trades | $($overall.total_trades) |
| TP Hits | $($overall.tp_hits) |
| SL Hits | $($overall.sl_hits) |
| Win Rate | $($overall.win_rate)% |
| Avg Win | $($overall.avg_win_pips) pips |
| Avg Loss | $($overall.avg_loss_pips) pips |
| Profit Factor | $(if($overall.total_loss_pips -gt 0) { [math]::Round($overall.total_win_pips / $overall.total_loss_pips, 2) } else { 'N/A' }) |

"@

$statusColor = if ($overall.win_rate -ge 60) { 'Green' } elseif ($overall.win_rate -ge 50) { 'Yellow' } else { 'Red' }
Write-Host "  Win Rate: $($overall.win_rate)%" -ForegroundColor $statusColor

# 2. Signal Type Performance
Write-Host "  Analyzing signal types..." -ForegroundColor Gray

$signalQuery = @"
SELECT 
    signal_type,
    COUNT(*) as total_trades,
    SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) as wins,
    SUM(CASE WHEN outcome = 'SL_HIT' THEN 1 ELSE 0 END) as losses,
    ROUND(100.0 * SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate,
    ROUND(AVG(CASE WHEN outcome = 'TP_HIT' THEN pips_gained END), 2) as avg_win_pips,
    ROUND(AVG(CASE WHEN outcome = 'SL_HIT' THEN ABS(pips_gained) END), 2) as avg_loss_pips,
    ROUND(AVG(risk_reward_ratio), 2) as avg_rr
FROM trades
WHERE outcome IN ('TP_HIT', 'SL_HIT')
  AND timestamp >= datetime('now', '-$DaysToAnalyze days')
GROUP BY signal_type
ORDER BY win_rate DESC;
"@

$signalPerf = Invoke-SQLiteQuery -Query $signalQuery

$report += @"
## Signal Type Performance

| Signal Type | Trades | Wins | Losses | Win Rate | Avg Win | Avg Loss | Avg R:R |
|-------------|--------|------|--------|----------|---------|----------|---------|
"@

$recommendations = @()

foreach ($row in $signalPerf) {
    $report += "| $($row.signal_type) | $($row.total_trades) | $($row.wins) | $($row.losses) | $($row.win_rate)% | $($row.avg_win_pips) | $($row.avg_loss_pips) | $($row.avg_rr) |`n"
    
    if ($row.total_trades -ge $MinimumTrades) {
        if ($row.win_rate -lt 40) {
            $recommendations += @{
                Priority = 'HIGH'
                Type = 'DISABLE_SIGNAL'
                Parameter = "InpEnable$($row.signal_type)Signals"
                OldValue = 'true'
                NewValue = 'false'
                Reason = "$($row.signal_type) signals have low win rate ($($row.win_rate)%) over $($row.total_trades) trades"
                Confidence = 'HIGH'
            }
        } elseif ($row.win_rate -gt 70) {
            $recommendations += @{
                Priority = 'INFO'
                Type = 'PRIORITIZE_SIGNAL'
                Parameter = "InpRiskPercent$($row.signal_type)"
                OldValue = 'current'
                NewValue = 'increase'
                Reason = "$($row.signal_type) signals have excellent win rate ($($row.win_rate)%) - consider increasing risk allocation"
                Confidence = 'MEDIUM'
            }
        }
    }
}

$report += "`n"

# 3. Regime Analysis
Write-Host "  Analyzing market regimes..." -ForegroundColor Gray

$regimeQuery = @"
SELECT 
    mc.regime,
    t.signal_type,
    COUNT(*) as trades,
    ROUND(100.0 * SUM(CASE WHEN t.outcome = 'TP_HIT' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate,
    ROUND(AVG(i.adx_h4), 2) as avg_adx,
    ROUND(AVG(i.rsi_h4), 2) as avg_rsi
FROM trades t
JOIN market_conditions mc ON t.trade_id = mc.trade_id
JOIN indicators i ON t.trade_id = i.trade_id
WHERE t.outcome IN ('TP_HIT', 'SL_HIT')
  AND t.timestamp >= datetime('now', '-$DaysToAnalyze days')
GROUP BY mc.regime, t.signal_type
HAVING COUNT(*) >= 5
ORDER BY mc.regime, win_rate DESC;
"@

$regimePerf = Invoke-SQLiteQuery -Query $regimeQuery

$report += @"
## Regime-Specific Performance

| Regime | Signal Type | Trades | Win Rate | Avg ADX | Avg RSI |
|--------|-------------|--------|----------|---------|---------|
"@

foreach ($row in $regimePerf) {
    $report += "| $($row.regime) | $($row.signal_type) | $($row.trades) | $($row.win_rate)% | $($row.avg_adx) | $($row.avg_rsi) |`n"
}

$report += "`n"

# 4. RSI Threshold Analysis
Write-Host "  Analyzing RSI thresholds..." -ForegroundColor Gray

$rsiQuery = @"
WITH rsi_buckets AS (
    SELECT 
        t.outcome,
        t.signal_type,
        t.direction,
        CASE 
            WHEN i.rsi_h4 < 30 THEN 'OVERSOLD'
            WHEN i.rsi_h4 < 40 THEN 'BEARISH'
            WHEN i.rsi_h4 < 60 THEN 'NEUTRAL'
            WHEN i.rsi_h4 < 70 THEN 'BULLISH'
            ELSE 'OVERBOUGHT'
        END as rsi_zone
    FROM trades t
    JOIN indicators i ON t.trade_id = i.trade_id
    WHERE t.outcome IN ('TP_HIT', 'SL_HIT')
      AND t.timestamp >= datetime('now', '-$DaysToAnalyze days')
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

$rsiAnalysis = Invoke-SQLiteQuery -Query $rsiQuery

$report += @"
## RSI Threshold Analysis

| Signal Type | Direction | RSI Zone | Trades | Win Rate |
|-------------|-----------|----------|--------|----------|
"@

foreach ($row in $rsiAnalysis) {
    $report += "| $($row.signal_type) | $($row.direction) | $($row.rsi_zone) | $($row.trades) | $($row.win_rate)% |`n"
    
    if ($row.trades -ge 5 -and $row.win_rate -ge 65) {
        $recommendations += @{
            Priority = 'MEDIUM'
            Type = 'RSI_THRESHOLD'
            Parameter = 'RSI_Zone_Optimization'
            OldValue = 'current'
            NewValue = "$($row.rsi_zone)"
            Reason = "$($row.signal_type) $($row.direction) performs best in RSI $($row.rsi_zone) zone ($($row.win_rate)% over $($row.trades) trades)"
            Confidence = 'MEDIUM'
        }
    }
}

$report += "`n"

# 5. Stop Loss Analysis
Write-Host "  Analyzing stop loss patterns..." -ForegroundColor Gray

$slQuery = @"
SELECT 
    t.signal_type,
    mc.regime,
    COUNT(*) as sl_hits,
    ROUND(AVG(t.duration_minutes), 0) as avg_duration_mins,
    ROUND(AVG(i.adx_h4), 2) as avg_adx,
    ROUND(AVG(mc.atr), 5) as avg_atr
FROM trades t
JOIN market_conditions mc ON t.trade_id = mc.trade_id
JOIN indicators i ON t.trade_id = i.trade_id
WHERE t.outcome = 'SL_HIT'
  AND t.timestamp >= datetime('now', '-$DaysToAnalyze days')
GROUP BY t.signal_type, mc.regime
HAVING COUNT(*) >= 3
ORDER BY sl_hits DESC;
"@

$slAnalysis = Invoke-SQLiteQuery -Query $slQuery

$report += @"
## Stop Loss Hit Pattern Analysis

| Signal Type | Regime | SL Hits | Avg Duration (mins) | Avg ADX | Avg ATR |
|-------------|--------|---------|---------------------|---------|---------|
"@

foreach ($row in $slAnalysis) {
    $report += "| $($row.signal_type) | $($row.regime) | $($row.sl_hits) | $($row.avg_duration_mins) | $($row.avg_adx) | $($row.avg_atr) |`n"
}

$report += "`n"

# 6. Rejection Analysis
Write-Host "  Analyzing rejection reasons..." -ForegroundColor Gray

$rejectionQuery = @"
SELECT 
    rejection_category,
    COUNT(*) as occurrences,
    ROUND(100.0 * COUNT(*) / (
        SELECT COUNT(*) FROM decisions 
        WHERE decision = 'REJECTED' 
        AND timestamp >= datetime('now', '-7 days')
    ), 2) as percentage
FROM decisions
WHERE decision = 'REJECTED'
  AND timestamp >= datetime('now', '-7 days')
GROUP BY rejection_category
ORDER BY occurrences DESC;
"@

$rejectionAnalysis = Invoke-SQLiteQuery -Query $rejectionQuery

$report += @"
## Rejection Analysis (Last 7 Days)

| Rejection Reason | Count | Percentage |
|------------------|-------|------------|
"@

foreach ($row in $rejectionAnalysis) {
    $report += "| $($row.rejection_category) | $($row.occurrences) | $($row.percentage)% |`n"
    
    if ($row.percentage -gt 30) {
        $recommendations += @{
            Priority = 'HIGH'
            Type = 'REJECTION_CRITERIA'
            Parameter = $row.rejection_category
            OldValue = 'current'
            NewValue = 'relax'
            Reason = "High rejection rate for $($row.rejection_category) ($($row.percentage)%) - may be too strict"
            Confidence = 'MEDIUM'
        }
    }
}

$report += "`n"

# Generate Recommendations Section
$report += @"
---

## EA Parameter Recommendations

"@

if ($recommendations.Count -eq 0) {
    $report += "No parameter changes recommended at this time. System is performing within acceptable ranges.`n`n"
    $report += "**Note**: Continue collecting data. More comprehensive recommendations require at least $MinimumTrades trades per signal type.`n"
} else {
    $highPriority = $recommendations | Where-Object { $_.Priority -eq 'HIGH' }
    $mediumPriority = $recommendations | Where-Object { $_.Priority -eq 'MEDIUM' }
    $infoPriority = $recommendations | Where-Object { $_.Priority -eq 'INFO' }
    
    if ($highPriority) {
        $report += "### HIGH PRIORITY CHANGES`n`n"
        foreach ($rec in $highPriority) {
            $report += "#### $($rec.Type)`n"
            $report += "- **Parameter**: ``$($rec.Parameter)```n"
            $report += "- **Current**: $($rec.OldValue)`n"
            $report += "- **Recommended**: $($rec.NewValue)`n"
            $report += "- **Reason**: $($rec.Reason)`n"
            $report += "- **Confidence**: $($rec.Confidence)`n`n"
        }
    }
    
    if ($mediumPriority) {
        $report += "### MEDIUM PRIORITY OPTIMIZATIONS`n`n"
        foreach ($rec in $mediumPriority) {
            $report += "#### $($rec.Type)`n"
            $report += "- **Parameter**: ``$($rec.Parameter)```n"
            $report += "- **Current**: $($rec.OldValue)`n"
            $report += "- **Recommended**: $($rec.NewValue)`n"
            $report += "- **Reason**: $($rec.Reason)`n"
            $report += "- **Confidence**: $($rec.Confidence)`n`n"
        }
    }
    
    if ($infoPriority) {
        $report += "### INFORMATIONAL`n`n"
        foreach ($rec in $infoPriority) {
            $report += "- $($rec.Reason)`n"
        }
    }
}

# Add implementation guide
$report += @"
---

## Implementation Steps

1. **Backup Current EA Settings**: Document current input parameters
2. **Apply Recommended Changes**: Update parameters in MT5 EA settings
3. **Recompile EA**: Press F7 in MetaEditor after making changes
4. **Document Changes**: Log changes in optimization_history table
5. **Monitor Results**: Run this analysis again after 10-20 new trades
6. **Measure Effectiveness**: Compare win rate before/after optimization

### SQL to Log This Optimization

``````sql
INSERT INTO optimization_history (
    timestamp, parameter_name, old_value, new_value, 
    change_reason, trades_analyzed, win_rate_before, applied_by
) VALUES (
    datetime('now'), 'PARAMETER_NAME', OLD_VALUE, NEW_VALUE,
    'REASON', $($overall.total_trades), $($overall.win_rate), 'Manual'
);
``````

---

**Generated by Grande Daily Analysis Script**  
**Next Analysis**: Run this script daily to track performance trends
"@

# Write report to file
$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "✅ Analysis complete" -ForegroundColor Green
Write-Host "   Report saved: $reportPath" -ForegroundColor Cyan

# Display summary in console
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total Trades: $($overall.total_trades)" -ForegroundColor Yellow
Write-Host "Win Rate: $($overall.win_rate)%" -ForegroundColor $statusColor
Write-Host "Recommendations: $($recommendations.Count)" -ForegroundColor Yellow

if ($recommendations.Count -gt 0) {
    Write-Host "`nTop Recommendations:" -ForegroundColor Cyan
    $recommendations | Select-Object -First 3 | ForEach-Object {
        Write-Host "  [$($_.Priority)] $($_.Type): $($_.Reason)" -ForegroundColor Yellow
    }
}

Write-Host "`nOpen report: $reportPath" -ForegroundColor Green

# Close database
$connection.Close()

Write-Host "`n✅ Analysis session complete" -ForegroundColor Green

