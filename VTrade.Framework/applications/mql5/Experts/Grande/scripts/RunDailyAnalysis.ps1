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

# Import PSSQLite module
Import-Module PSSQLite -ErrorAction Stop
Write-Host "[OK] Database module loaded" -ForegroundColor Green

# Check if database exists
if (-not (Test-Path $DatabasePath)) {
    Write-Host "ERROR: Database not found at $DatabasePath" -ForegroundColor Red
    Write-Host "Run: .\scripts\SeedTradingDatabase.ps1 first" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nAnalyzing trades..." -ForegroundColor Cyan

# Initialize report
$report = @"
# Grande Trading System - Daily Analysis Report

**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Analysis Period**: Last $DaysToAnalyze days  
**Database**: GrandeTradingData.db

---

"@

# 1. Overall Performance Summary
Write-Host "  Overall performance..." -ForegroundColor Gray

$overallQuery = "SELECT COUNT(*) as total_trades, SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) as tp_hits, SUM(CASE WHEN outcome = 'SL_HIT' THEN 1 ELSE 0 END) as sl_hits, ROUND(100.0 * SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN outcome IN ('TP_HIT', 'SL_HIT') THEN 1 ELSE 0 END), 0), 2) as win_rate, ROUND(SUM(CASE WHEN outcome = 'TP_HIT' THEN pips_gained ELSE 0 END), 2) as total_win_pips, ROUND(SUM(CASE WHEN outcome = 'SL_HIT' THEN ABS(pips_gained) ELSE 0 END), 2) as total_loss_pips, ROUND(AVG(CASE WHEN outcome = 'TP_HIT' THEN pips_gained END), 2) as avg_win_pips, ROUND(AVG(CASE WHEN outcome = 'SL_HIT' THEN ABS(pips_gained) END), 2) as avg_loss_pips FROM trades WHERE timestamp >= datetime('now', '-$DaysToAnalyze days');"

$overall = Invoke-SqliteQuery -DataSource $DatabasePath -Query $overallQuery

$closedTrades = $overall.tp_hits + $overall.sl_hits

$report += @"
## Executive Summary

| Metric | Value |
|--------|-------|
| Total Trades | $($overall.total_trades) |
| Closed Trades | $closedTrades |
| TP Hits | $($overall.tp_hits) |
| SL Hits | $($overall.sl_hits) |
| Win Rate | $(if($closedTrades -gt 0) { $overall.win_rate } else { 'N/A' })% |
| Avg Win | $(if($overall.avg_win_pips) { $overall.avg_win_pips } else { '0' }) pips |
| Avg Loss | $(if($overall.avg_loss_pips) { $overall.avg_loss_pips } else { '0' }) pips |
| Profit Factor | $(if($overall.total_loss_pips -gt 0) { [math]::Round($overall.total_win_pips / $overall.total_loss_pips, 2) } else { 'N/A' }) |

"@

if ($closedTrades -gt 0) {
    $statusColor = if ($overall.win_rate -ge 60) { 'Green' } elseif ($overall.win_rate -ge 50) { 'Yellow' } else { 'Red' }
    Write-Host "  Win Rate: $($overall.win_rate)%" -ForegroundColor $statusColor
} else {
    Write-Host "  No closed trades yet" -ForegroundColor Yellow
}

# 2. Signal Type Performance
Write-Host "  Analyzing signal types..." -ForegroundColor Gray

$signalQuery = "SELECT signal_type, COUNT(*) as trades, SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) as tp_hits, SUM(CASE WHEN outcome = 'SL_HIT' THEN 1 ELSE 0 END) as sl_hits, ROUND(100.0 * SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN outcome IN ('TP_HIT', 'SL_HIT') THEN 1 ELSE 0 END), 0), 2) as win_rate, ROUND(AVG(pips_gained), 2) as avg_pips FROM trades WHERE timestamp >= datetime('now', '-$DaysToAnalyze days') GROUP BY signal_type ORDER BY trades DESC;"

$signalPerf = Invoke-SqliteQuery -DataSource $DatabasePath -Query $signalQuery

if ($signalPerf.Count -gt 0) {
    $report += @"
## Signal Type Performance

| Signal Type | Trades | TP | SL | Win Rate | Avg Pips |
|-------------|--------|----|----|----------|----------|
"@

    foreach ($sig in $signalPerf) {
        $closedForSignal = $sig.tp_hits + $sig.sl_hits
        $winRateDisplay = if ($closedForSignal -gt 0) { "$($sig.win_rate)%" } else { "N/A" }
        $avgPipsDisplay = if ($sig.avg_pips) { $sig.avg_pips } else { "0" }
        $report += "| $($sig.signal_type) | $($sig.trades) | $($sig.tp_hits) | $($sig.sl_hits) | $winRateDisplay | $avgPipsDisplay |`n"
    }
    
    $report += "`n"
}

# 3. Symbol Performance
Write-Host "  Analyzing symbols..." -ForegroundColor Gray

$symbolQuery = "SELECT symbol, COUNT(*) as trades, SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) as tp_hits, SUM(CASE WHEN outcome = 'SL_HIT' THEN 1 ELSE 0 END) as sl_hits, ROUND(100.0 * SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN outcome IN ('TP_HIT', 'SL_HIT') THEN 1 ELSE 0 END), 0), 2) as win_rate FROM trades WHERE timestamp >= datetime('now', '-$DaysToAnalyze days') GROUP BY symbol ORDER BY trades DESC;"

$symbolPerf = Invoke-SqliteQuery -DataSource $DatabasePath -Query $symbolQuery

if ($symbolPerf.Count -gt 0) {
    $report += @"
## Symbol Performance

| Symbol | Trades | TP | SL | Win Rate |
|--------|--------|----|----|----------|
"@

    foreach ($sym in $symbolPerf) {
        $closedForSymbol = $sym.tp_hits + $sym.sl_hits
        $winRateDisplay = if ($closedForSymbol -gt 0) { "$($sym.win_rate)%" } else { "N/A" }
        $report += "| $($sym.symbol) | $($sym.trades) | $($sym.tp_hits) | $($sym.sl_hits) | $winRateDisplay |`n"
    }
    
    $report += "`n"
}

# 4. Generate Recommendations
Write-Host "  Generating recommendations..." -ForegroundColor Gray

$report += @"
## Recommendations

"@

$recommendations = 0

# Check each signal type for poor performance
foreach ($sig in $signalPerf) {
    $closedForSignal = $sig.tp_hits + $sig.sl_hits
    if ($closedForSignal -ge $MinimumTrades -and $sig.win_rate -lt 40) {
        $recommendations++
        $report += @"
### [$recommendations] DISABLE SIGNAL: $($sig.signal_type)
- **Confidence**: HIGH (based on $closedForSignal closed trades)
- **Win Rate**: $($sig.win_rate)% (below 40% threshold)
- **Recommendation**: Consider disabling $($sig.signal_type) signals
- **Action**: Set input parameter for $($sig.signal_type) to false in EA

"@
    }
}

# Check for low overall performance
if ($closedTrades -ge $MinimumTrades -and $overall.win_rate -lt 50) {
    $recommendations++
    $report += @"
### [$recommendations] OVERALL PERFORMANCE ALERT
- **Confidence**: HIGH
- **Win Rate**: $($overall.win_rate)% (below 50%)
- **Recommendation**: Review risk management settings and entry criteria
- **Action**: Consider reducing lot sizes or tightening entry filters

"@
}

if ($recommendations -eq 0) {
    if ($closedTrades -lt $MinimumTrades) {
        $report += "**Status**: Insufficient data for recommendations (need $MinimumTrades closed trades, have $closedTrades)`n`n"
        $report += "**Action**: Continue trading to collect more data. Current trades are:`n"
        
        # Show pending trades
        $pendingQuery = "SELECT timestamp, symbol, signal_type, direction, entry_price FROM trades WHERE outcome = 'PENDING' ORDER BY timestamp DESC LIMIT 10;"
        $pending = Invoke-SqliteQuery -DataSource $DatabasePath -Query $pendingQuery
        
        if ($pending.Count -gt 0) {
            $report += "`n| Timestamp | Symbol | Signal | Direction | Entry |`n"
            $report += "|-----------|--------|--------|-----------|-------|`n"
            foreach ($p in $pending) {
                $report += "| $($p.timestamp) | $($p.symbol) | $($p.signal_type) | $($p.direction) | $($p.entry_price) |`n"
            }
        }
    } else {
        $report += "**Status**: No issues detected. System performing within acceptable parameters.`n`n"
    }
}

$report += @"

---

## Next Steps

1. **Monitor**: Wait for pending trades to close
2. **Re-analyze**: Run this script again after more trades close
3. **Apply**: Implement recommendations with confidence level HIGH
4. **Track**: Log any parameter changes in optimization_history table

**Last Updated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@

# Save report
$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "`n=== ANALYSIS COMPLETE ===" -ForegroundColor Cyan
Write-Host "Report saved: $reportPath" -ForegroundColor Green
Write-Host "`nSummary:" -ForegroundColor Yellow
Write-Host "  Total Trades: $($overall.total_trades)" -ForegroundColor White
Write-Host "  Closed Trades: $closedTrades" -ForegroundColor White
Write-Host "  Recommendations: $recommendations" -ForegroundColor White

if ($closedTrades -eq 0) {
    Write-Host "`nNote: All trades are still pending. Re-run this script after trades close." -ForegroundColor Yellow
}
