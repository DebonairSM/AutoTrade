# Grande Trading System - Daily Performance Analysis Script
# Purpose: Generate daily analysis report with EA optimization recommendations

param(
    [Parameter(Mandatory=$false)]
    [string]$DatabasePath = "$env:APPDATA\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5\Files\Data\GrandeTradingData.db",
    [Parameter(Mandatory=$false)]
    [int]$MinimumTrades = 20,
    [Parameter(Mandatory=$false)]
    [int]$DaysToAnalyze = 30
)

$ErrorActionPreference = "Stop"
$reportDate = Get-Date -Format "yyyyMMdd"
$scriptRoot = Split-Path -Parent $PSCommandPath
$workspaceRoot = Split-Path -Parent $scriptRoot
$reportPath = Join-Path $workspaceRoot "docs\DAILY_ANALYSIS_REPORT_$reportDate.md"

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
**Database**: Data/GrandeTradingData.db

---

"@

# 1. Overall Performance Summary
Write-Host "  Overall performance..." -ForegroundColor Gray

$overallQuery = "SELECT COUNT(*) as total_trades, SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) as tp_hits, SUM(CASE WHEN outcome = 'SL_HIT' THEN 1 ELSE 0 END) as sl_hits, SUM(CASE WHEN pips_gained > 0 THEN 1 ELSE 0 END) as winning_trades, SUM(CASE WHEN pips_gained < 0 THEN 1 ELSE 0 END) as losing_trades, ROUND(100.0 * SUM(CASE WHEN pips_gained > 0 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN outcome IN ('TP_HIT', 'SL_HIT') THEN 1 ELSE 0 END), 0), 2) as win_rate, ROUND(SUM(CASE WHEN pips_gained > 0 THEN pips_gained ELSE 0 END), 2) as total_win_pips, ROUND(SUM(CASE WHEN pips_gained < 0 THEN ABS(pips_gained) ELSE 0 END), 2) as total_loss_pips, ROUND(AVG(CASE WHEN pips_gained > 0 THEN pips_gained END), 2) as avg_win_pips, ROUND(AVG(CASE WHEN pips_gained < 0 THEN ABS(pips_gained) END), 2) as avg_loss_pips FROM trades WHERE timestamp >= datetime('now', '-$DaysToAnalyze days');"

$overall = Invoke-SqliteQuery -DataSource $DatabasePath -Query $overallQuery

$closedTrades = $overall.tp_hits + $overall.sl_hits

$report += @"
## Executive Summary

| Metric | Value |
|--------|-------|
| Total Trades | $($overall.total_trades) |
| Closed Trades | $closedTrades |
| Winning Trades | $(if($overall.winning_trades) { $overall.winning_trades } else { '0' }) |
| Losing Trades | $(if($overall.losing_trades) { $losing_trades } else { '0' }) |
| TP Hits | $($overall.tp_hits) |
| SL Hits | $($overall.sl_hits) (includes profitable trailing stops) |
| Win Rate | $(if($closedTrades -gt 0) { $overall.win_rate } else { 'N/A' })% |
| Total Pips | $(if($overall.total_win_pips) { [math]::Round($overall.total_win_pips - $overall.total_loss_pips, 2) } else { '0' }) |
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

$signalQuery = "SELECT signal_type, COUNT(*) as trades, SUM(CASE WHEN pips_gained > 0 THEN 1 ELSE 0 END) as wins, SUM(CASE WHEN pips_gained < 0 THEN 1 ELSE 0 END) as losses, ROUND(100.0 * SUM(CASE WHEN pips_gained > 0 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN outcome IN ('TP_HIT', 'SL_HIT') THEN 1 ELSE 0 END), 0), 2) as win_rate, ROUND(SUM(pips_gained), 2) as total_pips FROM trades WHERE timestamp >= datetime('now', '-$DaysToAnalyze days') GROUP BY signal_type ORDER BY trades DESC;"

$signalPerf = Invoke-SqliteQuery -DataSource $DatabasePath -Query $signalQuery

if ($signalPerf.Count -gt 0) {
    $report += @"
## Signal Type Performance

| Signal Type | Trades | Wins | Losses | Win Rate | Total Pips |
|-------------|--------|------|--------|----------|------------|
"@

    foreach ($sig in $signalPerf) {
        $closedForSignal = $sig.wins + $sig.losses
        $winRateDisplay = if ($closedForSignal -gt 0) { "$($sig.win_rate)%" } else { "N/A" }
        $totalPipsDisplay = if ($sig.total_pips) { $sig.total_pips } else { "0" }
        $winsDisplay = if ($sig.wins) { $sig.wins } else { "0" }
        $lossesDisplay = if ($sig.losses) { $sig.losses } else { "0" }
        $report += "| $($sig.signal_type) | $($sig.trades) | $winsDisplay | $lossesDisplay | $winRateDisplay | $totalPipsDisplay |`n"
    }
    
    $report += "`n"
}

# 3. Symbol Performance
Write-Host "  Analyzing symbols..." -ForegroundColor Gray

$symbolQuery = "SELECT symbol, COUNT(*) as trades, SUM(CASE WHEN pips_gained > 0 THEN 1 ELSE 0 END) as wins, SUM(CASE WHEN pips_gained < 0 THEN 1 ELSE 0 END) as losses, ROUND(100.0 * SUM(CASE WHEN pips_gained > 0 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN outcome IN ('TP_HIT', 'SL_HIT') THEN 1 ELSE 0 END), 0), 2) as win_rate, ROUND(SUM(pips_gained), 2) as total_pips FROM trades WHERE timestamp >= datetime('now', '-$DaysToAnalyze days') GROUP BY symbol ORDER BY trades DESC;"

$symbolPerf = Invoke-SqliteQuery -DataSource $DatabasePath -Query $symbolQuery

if ($symbolPerf.Count -gt 0) {
    $report += @"
## Symbol Performance

| Symbol | Trades | Wins | Losses | Win Rate | Total Pips |
|--------|--------|------|--------|----------|------------|
"@

    foreach ($sym in $symbolPerf) {
        $closedForSymbol = $sym.wins + $sym.losses
        $winRateDisplay = if ($closedForSymbol -gt 0) { "$($sym.win_rate)%" } else { "N/A" }
        $totalPipsDisplay = if ($sym.total_pips) { $sym.total_pips } else { "0" }
        $winsDisplay = if ($sym.wins) { $sym.wins } else { "0" }
        $lossesDisplay = if ($sym.losses) { $sym.losses } else { "0" }
        $report += "| $($sym.symbol) | $($sym.trades) | $winsDisplay | $lossesDisplay | $winRateDisplay | $totalPipsDisplay |`n"
    }
    
    $report += "`n"
}

# 4. FinBERT Performance Analysis
Write-Host "  Analyzing FinBERT performance..." -ForegroundColor Gray

$report += @"
## FinBERT Performance

"@

# Check if we have FinBERT data
$finbertCheckQuery = "SELECT COUNT(*) as count FROM decisions WHERE calendar_signal IS NOT NULL AND calendar_signal != '' AND timestamp >= datetime('now', '-$DaysToAnalyze days');"
$finbertCheck = Invoke-SqliteQuery -DataSource $DatabasePath -Query $finbertCheckQuery

if ($finbertCheck.count -gt 0) {
    # Signal Distribution
    $signalDistQuery = @"
SELECT 
    calendar_signal,
    COUNT(*) as count,
    ROUND(AVG(calendar_confidence), 3) as avg_confidence
FROM decisions
WHERE timestamp >= datetime('now', '-$DaysToAnalyze days')
    AND calendar_signal IS NOT NULL 
    AND calendar_signal != ''
GROUP BY calendar_signal
ORDER BY count DESC;
"@

    $finbertSignals = Invoke-SqliteQuery -DataSource $DatabasePath -Query $signalDistQuery
    
    if ($finbertSignals -and $finbertSignals.Count -gt 0) {
        $report += @"
### Signal Distribution

| Signal | Count | Avg Confidence |
|--------|-------|----------------|
"@

        foreach ($sig in $finbertSignals) {
            $report += "| $($sig.calendar_signal) | $($sig.count) | $($sig.avg_confidence) |`n"
        }
        
        $report += "`n"
    }
    
    # Performance by Alignment
    $alignmentQuery = @"
SELECT 
    CASE 
        WHEN d.calendar_signal IN ('BUY','STRONG_BUY') AND t.direction='BUY' THEN 'ALIGNED'
        WHEN d.calendar_signal IN ('SELL','STRONG_SELL') AND t.direction='SELL' THEN 'ALIGNED'
        WHEN d.calendar_signal='NEUTRAL' THEN 'NEUTRAL'
        ELSE 'OPPOSED'
    END as alignment,
    COUNT(*) as trades,
    SUM(CASE WHEN t.outcome IN ('TP_HIT','SL_HIT') THEN 1 ELSE 0 END) as closed,
    ROUND(100.0 * SUM(CASE WHEN t.pips_gained > 0 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN t.outcome IN ('TP_HIT','SL_HIT') THEN 1 ELSE 0 END), 0), 2) as win_rate,
    ROUND(AVG(t.pips_gained), 2) as avg_pips
FROM trades t
INNER JOIN decisions d ON t.timestamp = d.timestamp AND t.symbol = d.symbol
WHERE t.timestamp >= datetime('now', '-$DaysToAnalyze days')
    AND d.calendar_signal IS NOT NULL 
    AND d.calendar_signal != ''
    AND d.decision = 'EXECUTED'
GROUP BY alignment
ORDER BY trades DESC;
"@

    $finbertAlignment = Invoke-SqliteQuery -DataSource $DatabasePath -Query $alignmentQuery
    
    if ($finbertAlignment -and $finbertAlignment.Count -gt 0) {
        $report += @"
### Performance by FinBERT Alignment

| Alignment | Trades | Closed | Win Rate | Avg Pips |
|-----------|--------|--------|----------|----------|
"@

        $bestAlignment = $null
        $bestWinRate = 0
        
        foreach ($align in $finbertAlignment) {
            $winRateDisplay = if ($align.closed -gt 0) { "$($align.win_rate)%" } else { "N/A" }
            $avgPipsDisplay = if ($null -ne $align.avg_pips) { $align.avg_pips } else { "0" }
            $report += "| $($align.alignment) | $($align.trades) | $($align.closed) | $winRateDisplay | $avgPipsDisplay |`n"
            
            if ($align.closed -ge 5 -and $align.win_rate -gt $bestWinRate) {
                $bestWinRate = $align.win_rate
                $bestAlignment = $align.alignment
            }
        }
        
        $report += "`n"
        
        if ($bestAlignment) {
            $report += "**Key Finding**: $bestAlignment trades show $bestWinRate% win rate.`n`n"
        }
    }
    
    # High Confidence Performance
    $highConfQuery = @"
SELECT 
    COUNT(*) as trades,
    SUM(CASE WHEN t.outcome IN ('TP_HIT','SL_HIT') THEN 1 ELSE 0 END) as closed,
    ROUND(100.0 * SUM(CASE WHEN t.pips_gained > 0 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN t.outcome IN ('TP_HIT','SL_HIT') THEN 1 ELSE 0 END), 0), 2) as win_rate,
    ROUND(AVG(t.pips_gained), 2) as avg_pips
FROM trades t
INNER JOIN decisions d ON t.timestamp = d.timestamp AND t.symbol = d.symbol
WHERE t.timestamp >= datetime('now', '-$DaysToAnalyze days')
    AND d.calendar_confidence >= 0.7
    AND d.decision = 'EXECUTED';
"@

    $highConf = Invoke-SqliteQuery -DataSource $DatabasePath -Query $highConfQuery
    
    if ($highConf -and $highConf.trades -gt 0) {
        $winRateDisplay = if ($highConf.closed -gt 0) { "$($highConf.win_rate)%" } else { "N/A" }
        $avgPipsDisplay = if ($null -ne $highConf.avg_pips) { $highConf.avg_pips } else { "0" }
        
        $report += @"
### High Confidence Signals (>0.7)

- **Trades**: $($highConf.trades)
- **Closed**: $($highConf.closed)
- **Win Rate**: $winRateDisplay
- **Avg Pips**: $avgPipsDisplay

"@
    }
    
    Write-Host "    FinBERT decisions: $($finbertCheck.count)" -ForegroundColor White
} else {
    $report += "**Status**: No FinBERT data available in this period.`n`n"
    $report += "Enable FinBERT in EA settings (InpEnableCalendarAI = true) to track sentiment analysis performance.`n`n"
    Write-Host "    No FinBERT data available" -ForegroundColor Yellow
}

# 5. Generate Recommendations
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
