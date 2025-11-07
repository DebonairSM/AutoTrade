# Grande Trading System - FinBERT Impact Analysis
# Purpose: Measure the actual trading performance impact of FinBERT signals
#
# This script analyzes historical trading data to determine if FinBERT signals
# are improving trading performance through win rate, pips gained, and rejection patterns.

param(
    [Parameter(Mandatory=$false)]
    [string]$DatabasePath = "$env:APPDATA\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5\Files\Data\GrandeTradingData.db",
    [Parameter(Mandatory=$false)]
    [int]$DaysToAnalyze = 30,
    [Parameter(Mandatory=$false)]
    [int]$MinimumTrades = 10
)

$ErrorActionPreference = "Stop"
$reportDate = Get-Date -Format "yyyyMMdd"
$scriptRoot = Split-Path -Parent $PSCommandPath
$workspaceRoot = Split-Path -Parent $scriptRoot
$reportPath = Join-Path $workspaceRoot "docs\FINBERT_IMPACT_REPORT_$reportDate.md"

Write-Host "=== FINBERT IMPACT ANALYSIS ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host "Analysis Period: Last $DaysToAnalyze days" -ForegroundColor Yellow
Write-Host "Report: $reportPath" -ForegroundColor Yellow
Write-Host ""

# Import PSSQLite module
try {
    Import-Module PSSQLite -ErrorAction Stop
    Write-Host "[OK] Database module loaded" -ForegroundColor Green
} catch {
    Write-Host "ERROR: PSSQLite module not found" -ForegroundColor Red
    Write-Host "Install: Install-Module -Name PSSQLite -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

# Check if database exists
if (-not (Test-Path $DatabasePath)) {
    Write-Host "ERROR: Database not found at $DatabasePath" -ForegroundColor Red
    Write-Host "Run: .\scripts\SeedTradingDatabase.ps1 first" -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Database found" -ForegroundColor Green
Write-Host ""

# Initialize report
$report = @"
# FinBERT Impact Analysis Report

**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Analysis Period**: Last $DaysToAnalyze days  
**Database**: GrandeTradingData.db

This report analyzes the actual trading performance impact of FinBERT signals by comparing trades where FinBERT supported, opposed, or remained neutral on the trade direction.

---

"@

# 1. Check if we have FinBERT data
Write-Host "Checking for FinBERT data..." -ForegroundColor Cyan

$finbertDataQuery = @"
SELECT 
    COUNT(*) as total_decisions,
    COUNT(CASE WHEN calendar_signal IS NOT NULL AND calendar_signal != '' THEN 1 END) as decisions_with_finbert,
    COUNT(CASE WHEN calendar_signal IS NULL OR calendar_signal = '' THEN 1 END) as decisions_without_finbert
FROM decisions
WHERE timestamp >= datetime('now', '-$DaysToAnalyze days');
"@

$finbertCheck = Invoke-SqliteQuery -DataSource $DatabasePath -Query $finbertDataQuery

$report += @"
## Data Availability

| Metric | Count |
|--------|-------|
| Total Decisions | $($finbertCheck.total_decisions) |
| With FinBERT Data | $($finbertCheck.decisions_with_finbert) |
| Without FinBERT Data | $($finbertCheck.decisions_without_finbert) |

"@

if ($finbertCheck.decisions_with_finbert -eq 0) {
    $report += @"
**WARNING**: No FinBERT data found in the analysis period.

Possible reasons:
1. FinBERT integration is not enabled (check EA input parameter: InpEnableCalendarAI)
2. FinBERT analysis files are not being generated
3. Database does not contain recent trades with FinBERT data

**Action Required**: Enable FinBERT in EA settings and wait for trades to accumulate.

"@
    
    Write-Host "WARNING: No FinBERT data found" -ForegroundColor Yellow
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "Report saved: $reportPath" -ForegroundColor Green
    exit 0
}

Write-Host "  Found $($finbertCheck.decisions_with_finbert) decisions with FinBERT data" -ForegroundColor White

# 2. Overall FinBERT Signal Distribution
Write-Host "`nAnalyzing FinBERT signal distribution..." -ForegroundColor Cyan

$signalDistQuery = @"
SELECT 
    calendar_signal,
    COUNT(*) as count,
    ROUND(AVG(calendar_confidence), 3) as avg_confidence,
    ROUND(MIN(calendar_confidence), 3) as min_confidence,
    ROUND(MAX(calendar_confidence), 3) as max_confidence
FROM decisions
WHERE timestamp >= datetime('now', '-$DaysToAnalyze days')
    AND calendar_signal IS NOT NULL 
    AND calendar_signal != ''
GROUP BY calendar_signal
ORDER BY count DESC;
"@

$signalDist = Invoke-SqliteQuery -DataSource $DatabasePath -Query $signalDistQuery

if ($signalDist) {
    $report += @"

## FinBERT Signal Distribution

| Signal | Count | Avg Confidence | Min Confidence | Max Confidence |
|--------|-------|----------------|----------------|----------------|
"@

    foreach ($sig in $signalDist) {
        $report += "| $($sig.calendar_signal) | $($sig.count) | $($sig.avg_confidence) | $($sig.min_confidence) | $($sig.max_confidence) |`n"
    }
    
    $report += "`n"
}

# 3. Win Rate by FinBERT Signal Alignment
Write-Host "Analyzing win rates by FinBERT alignment..." -ForegroundColor Cyan

$alignmentQuery = @"
SELECT 
    CASE 
        WHEN d.calendar_signal IN ('BUY','STRONG_BUY') AND t.direction='BUY' THEN 'ALIGNED'
        WHEN d.calendar_signal IN ('SELL','STRONG_SELL') AND t.direction='SELL' THEN 'ALIGNED'
        WHEN d.calendar_signal='NEUTRAL' THEN 'NEUTRAL'
        WHEN d.calendar_signal IN ('BUY','STRONG_BUY') AND t.direction='SELL' THEN 'OPPOSED'
        WHEN d.calendar_signal IN ('SELL','STRONG_SELL') AND t.direction='BUY' THEN 'OPPOSED'
        ELSE 'UNKNOWN'
    END as finbert_alignment,
    COUNT(*) as total_trades,
    SUM(CASE WHEN t.outcome IN ('TP_HIT','SL_HIT') THEN 1 ELSE 0 END) as closed_trades,
    SUM(CASE WHEN t.pips_gained > 0 THEN 1 ELSE 0 END) as winning_trades,
    SUM(CASE WHEN t.pips_gained < 0 THEN 1 ELSE 0 END) as losing_trades,
    ROUND(100.0 * SUM(CASE WHEN t.pips_gained > 0 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN t.outcome IN ('TP_HIT','SL_HIT') THEN 1 ELSE 0 END), 0), 2) as win_rate,
    ROUND(AVG(t.pips_gained), 2) as avg_pips,
    ROUND(SUM(t.pips_gained), 2) as total_pips,
    ROUND(AVG(d.calendar_confidence), 3) as avg_confidence
FROM trades t
INNER JOIN decisions d ON t.timestamp = d.timestamp AND t.symbol = d.symbol
WHERE t.timestamp >= datetime('now', '-$DaysToAnalyze days')
    AND d.calendar_signal IS NOT NULL 
    AND d.calendar_signal != ''
    AND d.decision = 'EXECUTED'
GROUP BY finbert_alignment
ORDER BY total_trades DESC;
"@

$alignmentResults = Invoke-SqliteQuery -DataSource $DatabasePath -Query $alignmentQuery

if ($alignmentResults) {
    $report += @"

## Win Rate by FinBERT Signal Alignment

This analysis shows how trades perform when FinBERT signals align with, oppose, or are neutral to the trade direction.

| Alignment | Total | Closed | Wins | Losses | Win Rate | Avg Pips | Total Pips | Avg Confidence |
|-----------|-------|--------|------|--------|----------|----------|------------|----------------|
"@

    $bestAlignment = $null
    $bestWinRate = 0
    
    foreach ($align in $alignmentResults) {
        $winRateDisplay = if ($align.closed_trades -gt 0) { "$($align.win_rate)%" } else { "N/A" }
        $avgPipsDisplay = if ($null -ne $align.avg_pips) { $align.avg_pips } else { "0" }
        $totalPipsDisplay = if ($null -ne $align.total_pips) { $align.total_pips } else { "0" }
        $avgConfDisplay = if ($null -ne $align.avg_confidence) { $align.avg_confidence } else { "0" }
        
        $report += "| $($align.finbert_alignment) | $($align.total_trades) | $($align.closed_trades) | $($align.winning_trades) | $($align.losing_trades) | $winRateDisplay | $avgPipsDisplay | $totalPipsDisplay | $avgConfDisplay |`n"
        
        # Track best performing alignment
        if ($align.closed_trades -ge $MinimumTrades -and $align.win_rate -gt $bestWinRate) {
            $bestWinRate = $align.win_rate
            $bestAlignment = $align.finbert_alignment
        }
        
        # Display progress
        Write-Host "  $($align.finbert_alignment): $($align.closed_trades) closed, Win Rate: $winRateDisplay" -ForegroundColor White
    }
    
    $report += "`n"
    
    # Add interpretation
    $report += @"
**Interpretation**:
- **ALIGNED**: FinBERT signal matches trade direction (BUY signals for BUY trades, SELL signals for SELL trades)
- **OPPOSED**: FinBERT signal opposes trade direction
- **NEUTRAL**: FinBERT provided a NEUTRAL signal

"@

    if ($bestAlignment) {
        $report += "**Key Finding**: $bestAlignment trades show the best performance with $bestWinRate% win rate.`n`n"
    }
}

# 4. Performance by Confidence Level
Write-Host "`nAnalyzing performance by confidence level..." -ForegroundColor Cyan

$confidenceQuery = @"
SELECT 
    CASE 
        WHEN d.calendar_confidence >= 0.7 THEN 'HIGH (>0.7)'
        WHEN d.calendar_confidence >= 0.5 THEN 'MEDIUM (0.5-0.7)'
        WHEN d.calendar_confidence >= 0.3 THEN 'LOW (0.3-0.5)'
        ELSE 'VERY LOW (<0.3)'
    END as confidence_level,
    COUNT(*) as total_trades,
    SUM(CASE WHEN t.outcome IN ('TP_HIT','SL_HIT') THEN 1 ELSE 0 END) as closed_trades,
    SUM(CASE WHEN t.pips_gained > 0 THEN 1 ELSE 0 END) as winning_trades,
    ROUND(100.0 * SUM(CASE WHEN t.pips_gained > 0 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN t.outcome IN ('TP_HIT','SL_HIT') THEN 1 ELSE 0 END), 0), 2) as win_rate,
    ROUND(AVG(t.pips_gained), 2) as avg_pips,
    ROUND(SUM(t.pips_gained), 2) as total_pips,
    ROUND(AVG(d.calendar_confidence), 3) as avg_confidence
FROM trades t
INNER JOIN decisions d ON t.timestamp = d.timestamp AND t.symbol = d.symbol
WHERE t.timestamp >= datetime('now', '-$DaysToAnalyze days')
    AND d.calendar_signal IS NOT NULL 
    AND d.calendar_signal != ''
    AND d.decision = 'EXECUTED'
GROUP BY confidence_level
ORDER BY avg_confidence DESC;
"@

$confidenceResults = Invoke-SqliteQuery -DataSource $DatabasePath -Query $confidenceQuery

if ($confidenceResults) {
    $report += @"

## Performance by FinBERT Confidence Level

This shows if higher FinBERT confidence correlates with better trade outcomes.

| Confidence Level | Total | Closed | Wins | Win Rate | Avg Pips | Total Pips |
|------------------|-------|--------|------|----------|----------|------------|
"@

    foreach ($conf in $confidenceResults) {
        $winRateDisplay = if ($conf.closed_trades -gt 0) { "$($conf.win_rate)%" } else { "N/A" }
        $avgPipsDisplay = if ($null -ne $conf.avg_pips) { $conf.avg_pips } else { "0" }
        $totalPipsDisplay = if ($null -ne $conf.total_pips) { $conf.total_pips } else { "0" }
        
        $report += "| $($conf.confidence_level) | $($conf.total_trades) | $($conf.closed_trades) | $($conf.winning_trades) | $winRateDisplay | $avgPipsDisplay | $totalPipsDisplay |`n"
        
        Write-Host "  $($conf.confidence_level): Win Rate: $winRateDisplay" -ForegroundColor White
    }
    
    $report += "`n"
}

# 5. FinBERT Rejection Analysis
Write-Host "`nAnalyzing FinBERT rejections..." -ForegroundColor Cyan

$rejectionQuery = @"
SELECT 
    COUNT(*) as total_rejections,
    d.calendar_signal,
    ROUND(AVG(d.calendar_confidence), 3) as avg_confidence
FROM decisions d
WHERE d.timestamp >= datetime('now', '-$DaysToAnalyze days')
    AND d.decision = 'REJECTED'
    AND d.rejection_reason LIKE '%FinBERT%'
    AND d.calendar_signal IS NOT NULL
GROUP BY d.calendar_signal
ORDER BY total_rejections DESC;
"@

$rejectionResults = Invoke-SqliteQuery -DataSource $DatabasePath -Query $rejectionQuery

$report += @"

## FinBERT-Based Trade Rejections

Trades that were rejected specifically because FinBERT signal opposed the trade direction with high confidence.

"@

if ($rejectionResults -and $rejectionResults.Count -gt 0) {
    $report += @"
| FinBERT Signal | Rejections | Avg Confidence |
|----------------|------------|----------------|
"@

    $totalRejections = 0
    foreach ($rej in $rejectionResults) {
        $report += "| $($rej.calendar_signal) | $($rej.total_rejections) | $($rej.avg_confidence) |`n"
        $totalRejections += $rej.total_rejections
        Write-Host "  $($rej.calendar_signal): $($rej.total_rejections) rejections" -ForegroundColor White
    }
    
    $report += "`n**Total FinBERT-based rejections**: $totalRejections`n`n"
} else {
    $report += "No trades were rejected by FinBERT in this period.`n`n"
    Write-Host "  No FinBERT rejections found" -ForegroundColor Yellow
}

# 6. Signal Type Performance with FinBERT
Write-Host "`nAnalyzing signal type performance with FinBERT..." -ForegroundColor Cyan

$signalTypeQuery = @"
SELECT 
    t.signal_type,
    CASE 
        WHEN d.calendar_signal IN ('BUY','STRONG_BUY') AND t.direction='BUY' THEN 'ALIGNED'
        WHEN d.calendar_signal IN ('SELL','STRONG_SELL') AND t.direction='SELL' THEN 'ALIGNED'
        WHEN d.calendar_signal='NEUTRAL' THEN 'NEUTRAL'
        ELSE 'OPPOSED'
    END as finbert_alignment,
    COUNT(*) as trades,
    SUM(CASE WHEN t.outcome IN ('TP_HIT','SL_HIT') THEN 1 ELSE 0 END) as closed_trades,
    ROUND(100.0 * SUM(CASE WHEN t.pips_gained > 0 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN t.outcome IN ('TP_HIT','SL_HIT') THEN 1 ELSE 0 END), 0), 2) as win_rate,
    ROUND(AVG(t.pips_gained), 2) as avg_pips
FROM trades t
INNER JOIN decisions d ON t.timestamp = d.timestamp AND t.symbol = d.symbol
WHERE t.timestamp >= datetime('now', '-$DaysToAnalyze days')
    AND d.calendar_signal IS NOT NULL 
    AND d.calendar_signal != ''
    AND d.decision = 'EXECUTED'
GROUP BY t.signal_type, finbert_alignment
HAVING closed_trades >= 3
ORDER BY t.signal_type, closed_trades DESC;
"@

$signalTypeResults = Invoke-SqliteQuery -DataSource $DatabasePath -Query $signalTypeQuery

if ($signalTypeResults -and $signalTypeResults.Count -gt 0) {
    $report += @"

## Signal Type Performance with FinBERT Alignment

Shows how different signal types (TREND_BULL, BREAKOUT, etc.) perform with FinBERT alignment.

| Signal Type | FinBERT Alignment | Trades | Closed | Win Rate | Avg Pips |
|-------------|-------------------|--------|--------|----------|----------|
"@

    foreach ($st in $signalTypeResults) {
        $winRateDisplay = if ($st.closed_trades -gt 0) { "$($st.win_rate)%" } else { "N/A" }
        $avgPipsDisplay = if ($null -ne $st.avg_pips) { $st.avg_pips } else { "0" }
        
        $report += "| $($st.signal_type) | $($st.finbert_alignment) | $($st.trades) | $($st.closed_trades) | $winRateDisplay | $avgPipsDisplay |`n"
    }
    
    $report += "`n"
}

# 7. Generate Recommendations
Write-Host "`nGenerating recommendations..." -ForegroundColor Cyan

$report += @"

## Recommendations

"@

$recommendations = 0

# Analyze if FinBERT improves overall performance
if ($alignmentResults) {
    $alignedData = $alignmentResults | Where-Object { $_.finbert_alignment -eq 'ALIGNED' }
    $opposedData = $alignmentResults | Where-Object { $_.finbert_alignment -eq 'OPPOSED' }
    $neutralData = $alignmentResults | Where-Object { $_.finbert_alignment -eq 'NEUTRAL' }
    
    # Check if aligned trades significantly outperform
    if ($alignedData -and $alignedData.closed_trades -ge $MinimumTrades) {
        $alignedWinRate = $alignedData.win_rate
        $opposedWinRate = if ($opposedData -and $opposedData.closed_trades -ge 5) { $opposedData.win_rate } else { 0 }
        
        if ($alignedWinRate -gt 55 -and $alignedWinRate - $opposedWinRate -gt 10) {
            $recommendations++
            $report += @"
### [$recommendations] FINBERT PROVIDES POSITIVE VALUE
- **Confidence**: HIGH (based on $($alignedData.closed_trades) aligned trades)
- **Finding**: FinBERT-aligned trades show $alignedWinRate% win rate
- **Impact**: +$([math]::Round($alignedWinRate - $opposedWinRate, 1))% improvement vs opposed trades
- **Recommendation**: Continue using FinBERT with current settings
- **Action**: Monitor FinBERT confidence levels for optimal threshold tuning

"@
        } elseif ($alignedWinRate -lt 45) {
            $recommendations++
            $report += @"
### [$recommendations] FINBERT PERFORMANCE CONCERNS
- **Confidence**: MEDIUM (based on $($alignedData.closed_trades) aligned trades)
- **Finding**: FinBERT-aligned trades only show $alignedWinRate% win rate
- **Recommendation**: Review FinBERT configuration and input data quality
- **Action**: Check if FinBERT is using keyword fallback instead of real AI model
- **Tool**: Run .\scripts\AssessFinBERTQuality.ps1 to verify

"@
        }
    }
    
    # Check confidence calibration
    if ($confidenceResults) {
        $highConfData = $confidenceResults | Where-Object { $_.confidence_level -eq 'HIGH (>0.7)' }
        $lowConfData = $confidenceResults | Where-Object { $_.confidence_level -like 'LOW*' -or $_.confidence_level -like 'VERY LOW*' }
        
        if ($highConfData -and $highConfData.closed_trades -ge 5) {
            $highConfWinRate = $highConfData.win_rate
            $lowConfWinRate = if ($lowConfData -and $lowConfData.closed_trades -ge 5) { $lowConfData.win_rate } else { 0 }
            
            if ($highConfWinRate -gt $lowConfWinRate + 15) {
                $recommendations++
                $report += @"
### [$recommendations] HIGH CONFIDENCE SIGNALS ARE VALUABLE
- **Confidence**: HIGH
- **Finding**: High confidence FinBERT signals (>0.7) show $highConfWinRate% win rate
- **Recommendation**: Increase position size multiplier for high-confidence signals
- **Action**: Consider adjusting sentiment_multiplier formula in EA (currently max 1.5x)

"@
            }
        }
    }
}

# Check if we have enough data
$totalExecutedTrades = ($alignmentResults | Measure-Object -Property total_trades -Sum).Sum
if ($totalExecutedTrades -lt $MinimumTrades) {
    $recommendations++
    $report += @"
### [$recommendations] INSUFFICIENT DATA FOR STRONG CONCLUSIONS
- **Confidence**: N/A
- **Finding**: Only $totalExecutedTrades executed trades with FinBERT data
- **Recommendation**: Continue trading to accumulate at least $MinimumTrades trades
- **Action**: Re-run this analysis after more trading activity

"@
}

if ($recommendations -eq 0) {
    $report += "**Status**: No significant findings. FinBERT is performing as expected with current data.`n`n"
}

# Final Summary
$report += @"

---

## Analysis Summary

- **Total Decisions with FinBERT**: $($finbertCheck.decisions_with_finbert)
- **Executed Trades Analyzed**: $totalExecutedTrades
- **Recommendations Generated**: $recommendations

### Next Steps

1. **Monitor**: Continue trading and re-run this analysis weekly
2. **Verify Quality**: Run .\scripts\AssessFinBERTQuality.ps1 to check FinBERT model status
3. **Review Data**: Run .\scripts\AnalyzeFinBERTData.ps1 to inspect input/output pairs
4. **Daily Tracking**: Enable FinBERT section in daily analysis reports

**Last Updated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@

# Save report
$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "`n=== ANALYSIS COMPLETE ===" -ForegroundColor Cyan
Write-Host "Report saved: $reportPath" -ForegroundColor Green
Write-Host "`nKey Findings:" -ForegroundColor Yellow
Write-Host "  Decisions with FinBERT: $($finbertCheck.decisions_with_finbert)" -ForegroundColor White
Write-Host "  Recommendations: $recommendations" -ForegroundColor White

if ($totalExecutedTrades -lt $MinimumTrades) {
    Write-Host "`nNote: Insufficient data for strong conclusions. Need at least $MinimumTrades trades." -ForegroundColor Yellow
}

Write-Host ""

