# Grande Trading System - Limit Orders vs Market Orders Comparison
# Purpose: Analyze and compare performance of limit orders vs market orders

param(
    [Parameter(Mandatory=$false)]
    [string]$DatabasePath = "",
    [Parameter(Mandatory=$false)]
    [switch]$ExportToCsv,
    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "backtest_comparison.csv",
    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)

# Auto-detect database path if not provided
if ([string]::IsNullOrEmpty($DatabasePath)) {
    # Try MT5 Files folder first
    $mt5FilesPath = Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Files\Data\GrandeTradingData.db" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($mt5FilesPath) {
        $DatabasePath = $mt5FilesPath.FullName
    } else {
        # Try workspace Data folder
        $workspacePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "applications\mql5\Experts\Grande\Data\GrandeTradingData.db"
        if (Test-Path $workspacePath) {
            $DatabasePath = $workspacePath
        } else {
            # Default to workspace
            $DatabasePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "applications\mql5\Experts\Grande\Data\GrandeTradingData.db"
        }
    }
}

$ErrorActionPreference = "Stop"

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "LIMIT ORDERS vs MARKET ORDERS COMPARISON" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Database: $DatabasePath" -ForegroundColor Yellow

# Import PSSQLite module
try {
    Import-Module PSSQLite -ErrorAction Stop
    Write-Host "[OK] Database module loaded" -ForegroundColor Green
} catch {
    Write-Host "ERROR: PSSQLite module not found. Install with: Install-Module PSSQLite" -ForegroundColor Red
    exit 1
}

# Check if database exists
if (-not (Test-Path $DatabasePath)) {
    Write-Host "`nERROR: Database not found at $DatabasePath" -ForegroundColor Red
    Write-Host "Run the EA with InpEnableDatabase = true to generate trade data." -ForegroundColor Yellow
    exit 1
}

# Check if required tables exist
$tablesQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('trades', 'limit_orders', 'trade_decisions');"
$tables = Invoke-SqliteQuery -DataSource $DatabasePath -Query $tablesQuery -ErrorAction SilentlyContinue

if ($null -eq $tables -or $tables.Count -eq 0) {
    Write-Host "`nERROR: Required tables not found in database" -ForegroundColor Red
    Write-Host "Make sure the EA has been running with database logging enabled." -ForegroundColor Yellow
    exit 1
}

Write-Host "`n=== DATA AVAILABILITY ===" -ForegroundColor Cyan

# Check data counts
$tradesCount = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) as count FROM trades;" -ErrorAction SilentlyContinue).count
$limitOrdersCount = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) as count FROM limit_orders;" -ErrorAction SilentlyContinue).count
$decisionsCount = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) as count FROM trade_decisions;" -ErrorAction SilentlyContinue).count

Write-Host "Trades: $tradesCount records" -ForegroundColor White
Write-Host "Limit Orders: $limitOrdersCount records" -ForegroundColor White
Write-Host "Trade Decisions: $decisionsCount records" -ForegroundColor White

if ($tradesCount -eq 0 -and $limitOrdersCount -eq 0) {
    Write-Host "`nNot enough data for comparison analysis." -ForegroundColor Yellow
    Write-Host "Run the EA to generate trade and limit order data." -ForegroundColor Yellow
    exit 0
}

# ============================================================================
# LIMIT ORDERS ANALYSIS
# ============================================================================
Write-Host "`n=== LIMIT ORDERS PERFORMANCE ===" -ForegroundColor Cyan

if ($limitOrdersCount -gt 0) {
    # Fill rate analysis
    $fillRateQuery = @"
SELECT 
    COUNT(*) as total_orders,
    COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) as filled,
    COUNT(CASE WHEN cancelled_time IS NOT NULL THEN 1 END) as cancelled,
    COUNT(CASE WHEN filled_time IS NULL AND cancelled_time IS NULL THEN 1 END) as pending,
    ROUND(100.0 * COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) / COUNT(*), 2) as fill_rate,
    ROUND(AVG(CASE WHEN filled_time IS NOT NULL THEN slippage_pips END), 2) as avg_slippage,
    ROUND(AVG(CASE WHEN filled_time IS NOT NULL THEN time_to_fill_minutes END), 1) as avg_time_to_fill
FROM limit_orders;
"@
    $fillRateData = Invoke-SqliteQuery -DataSource $DatabasePath -Query $fillRateQuery

    Write-Host "Total Limit Orders: $($fillRateData.total_orders)" -ForegroundColor White
    Write-Host "Filled: $($fillRateData.filled) ($($fillRateData.fill_rate)%)" -ForegroundColor $(if ($fillRateData.fill_rate -ge 60) { "Green" } else { "Yellow" })
    Write-Host "Cancelled: $($fillRateData.cancelled)" -ForegroundColor White
    Write-Host "Pending: $($fillRateData.pending)" -ForegroundColor White
    
    if ($fillRateData.avg_slippage) {
        Write-Host "Avg Slippage: $($fillRateData.avg_slippage) pips" -ForegroundColor $(if ($fillRateData.avg_slippage -lt 2) { "Green" } else { "Yellow" })
    }
    if ($fillRateData.avg_time_to_fill) {
        Write-Host "Avg Time to Fill: $($fillRateData.avg_time_to_fill) minutes" -ForegroundColor White
    }

    # Fill probability accuracy
    if ($Detailed) {
        Write-Host "`n--- Fill Probability Accuracy ---" -ForegroundColor Gray
        $probAccuracyQuery = @"
SELECT 
    CASE 
        WHEN fill_probability_at_placement < 0.3 THEN '< 30%'
        WHEN fill_probability_at_placement < 0.5 THEN '30-50%'
        WHEN fill_probability_at_placement < 0.7 THEN '50-70%'
        ELSE '> 70%'
    END as predicted_prob,
    COUNT(*) as orders,
    COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) as actual_filled,
    ROUND(100.0 * COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) / COUNT(*), 2) as actual_fill_rate
FROM limit_orders
WHERE fill_probability_at_placement IS NOT NULL
GROUP BY predicted_prob
ORDER BY predicted_prob;
"@
        $probData = Invoke-SqliteQuery -DataSource $DatabasePath -Query $probAccuracyQuery -ErrorAction SilentlyContinue
        if ($probData -and $probData.Count -gt 0) {
            foreach ($row in $probData) {
                Write-Host "  Predicted $($row.predicted_prob): $($row.orders) orders, $($row.actual_filled) filled ($($row.actual_fill_rate)% actual)" -ForegroundColor Gray
            }
        }
    }

    # Performance by regime
    if ($Detailed) {
        Write-Host "`n--- Fill Rate by Market Regime ---" -ForegroundColor Gray
        $regimeQuery = @"
SELECT 
    regime_at_placement,
    COUNT(*) as orders,
    COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) as filled,
    ROUND(100.0 * COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) / COUNT(*), 2) as fill_rate
FROM limit_orders
WHERE regime_at_placement IS NOT NULL AND regime_at_placement != ''
GROUP BY regime_at_placement
ORDER BY fill_rate DESC;
"@
        $regimeData = Invoke-SqliteQuery -DataSource $DatabasePath -Query $regimeQuery -ErrorAction SilentlyContinue
        if ($regimeData -and $regimeData.Count -gt 0) {
            foreach ($row in $regimeData) {
                Write-Host "  $($row.regime_at_placement): $($row.orders) orders, $($row.fill_rate)% fill rate" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Host "No limit order data available" -ForegroundColor Yellow
}

# ============================================================================
# TRADES PERFORMANCE COMPARISON
# ============================================================================
Write-Host "`n=== TRADES PERFORMANCE ===" -ForegroundColor Cyan

if ($tradesCount -gt 0) {
    # Overall trade statistics
    $tradesStatsQuery = @"
SELECT 
    COUNT(*) as total_trades,
    COUNT(CASE WHEN outcome = 'TP_HIT' THEN 1 END) as tp_hits,
    COUNT(CASE WHEN outcome = 'SL_HIT' THEN 1 END) as sl_hits,
    COUNT(CASE WHEN outcome = 'PENDING' THEN 1 END) as pending,
    SUM(CASE WHEN pnl > 0 THEN pnl ELSE 0 END) as gross_profit,
    SUM(CASE WHEN pnl < 0 THEN ABS(pnl) ELSE 0 END) as gross_loss,
    SUM(pnl) as net_profit,
    AVG(pnl) as avg_pnl,
    ROUND(100.0 * COUNT(CASE WHEN pnl > 0 THEN 1 END) / COUNT(CASE WHEN pnl != 0 THEN 1 END), 2) as win_rate
FROM trades
WHERE outcome IN ('TP_HIT', 'SL_HIT');
"@
    $tradesStats = Invoke-SqliteQuery -DataSource $DatabasePath -Query $tradesStatsQuery -ErrorAction SilentlyContinue

    if ($tradesStats -and $tradesStats.total_trades -gt 0) {
        Write-Host "Total Closed Trades: $($tradesStats.total_trades)" -ForegroundColor White
        Write-Host "TP Hits: $($tradesStats.tp_hits)" -ForegroundColor Green
        Write-Host "SL Hits: $($tradesStats.sl_hits)" -ForegroundColor Red
        Write-Host "Win Rate: $($tradesStats.win_rate)%" -ForegroundColor $(if ($tradesStats.win_rate -ge 55) { "Green" } else { "Yellow" })
        Write-Host "Net Profit: `$$([math]::Round($tradesStats.net_profit, 2))" -ForegroundColor $(if ($tradesStats.net_profit -gt 0) { "Green" } else { "Red" })
        Write-Host "Avg PnL per Trade: `$$([math]::Round($tradesStats.avg_pnl, 2))" -ForegroundColor White
        
        if ($tradesStats.gross_loss -gt 0) {
            $profitFactor = [math]::Round($tradesStats.gross_profit / $tradesStats.gross_loss, 2)
            Write-Host "Profit Factor: $profitFactor" -ForegroundColor $(if ($profitFactor -ge 1.5) { "Green" } else { "Yellow" })
        }
    }
} else {
    Write-Host "No trades data available" -ForegroundColor Yellow
}

# ============================================================================
# LIMIT ORDERS vs MARKET ORDERS COMPARISON
# ============================================================================
Write-Host "`n=== LIMIT vs MARKET ORDERS COMPARISON ===" -ForegroundColor Cyan

if ($limitOrdersCount -gt 0 -and $tradesCount -gt 0) {
    # Limit order trades (trades that originated from limit orders)
    $limitTradesQuery = @"
SELECT 
    'LIMIT' as order_type,
    COUNT(*) as total_trades,
    SUM(CASE WHEN t.pnl > 0 THEN 1 ELSE 0 END) as wins,
    SUM(CASE WHEN t.pnl < 0 THEN 1 ELSE 0 END) as losses,
    SUM(t.pnl) as total_pnl,
    AVG(t.pnl) as avg_pnl,
    ROUND(100.0 * SUM(CASE WHEN t.pnl > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate,
    AVG(lo.slippage_pips) as avg_slippage
FROM trades t
INNER JOIN limit_orders lo ON t.ticket = lo.ticket
WHERE lo.filled_time IS NOT NULL
AND t.outcome IN ('TP_HIT', 'SL_HIT');
"@
    $limitTrades = Invoke-SqliteQuery -DataSource $DatabasePath -Query $limitTradesQuery -ErrorAction SilentlyContinue

    # Market order trades (trades not in limit_orders)
    $marketTradesQuery = @"
SELECT 
    'MARKET' as order_type,
    COUNT(*) as total_trades,
    SUM(CASE WHEN pnl > 0 THEN 1 ELSE 0 END) as wins,
    SUM(CASE WHEN pnl < 0 THEN 1 ELSE 0 END) as losses,
    SUM(pnl) as total_pnl,
    AVG(pnl) as avg_pnl,
    ROUND(100.0 * SUM(CASE WHEN pnl > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate
FROM trades
WHERE ticket NOT IN (SELECT ticket FROM limit_orders WHERE filled_time IS NOT NULL)
AND outcome IN ('TP_HIT', 'SL_HIT');
"@
    $marketTrades = Invoke-SqliteQuery -DataSource $DatabasePath -Query $marketTradesQuery -ErrorAction SilentlyContinue

    # Display comparison table
    Write-Host ""
    Write-Host "Metric                  LIMIT ORDERS    MARKET ORDERS    DIFFERENCE" -ForegroundColor White
    Write-Host "----------------------------------------------------------------------" -ForegroundColor Gray

    $limitCount = if ($limitTrades.total_trades) { $limitTrades.total_trades } else { 0 }
    $marketCount = if ($marketTrades.total_trades) { $marketTrades.total_trades } else { 0 }
    Write-Host ("Total Trades:           {0,-15} {1,-16} {2}" -f $limitCount, $marketCount, ($limitCount - $marketCount))

    $limitWinRate = if ($limitTrades.win_rate) { $limitTrades.win_rate } else { 0 }
    $marketWinRate = if ($marketTrades.win_rate) { $marketTrades.win_rate } else { 0 }
    $winRateDiff = [math]::Round($limitWinRate - $marketWinRate, 2)
    $winRateColor = if ($winRateDiff -gt 0) { "Green" } elseif ($winRateDiff -lt 0) { "Red" } else { "White" }
    Write-Host ("Win Rate:               {0,-15}% {1,-15}% {2}%" -f $limitWinRate, $marketWinRate, $(if ($winRateDiff -gt 0) { "+$winRateDiff" } else { $winRateDiff })) -ForegroundColor $winRateColor

    $limitPnl = if ($limitTrades.total_pnl) { [math]::Round($limitTrades.total_pnl, 2) } else { 0 }
    $marketPnl = if ($marketTrades.total_pnl) { [math]::Round($marketTrades.total_pnl, 2) } else { 0 }
    $pnlDiff = [math]::Round($limitPnl - $marketPnl, 2)
    $pnlColor = if ($pnlDiff -gt 0) { "Green" } elseif ($pnlDiff -lt 0) { "Red" } else { "White" }
    Write-Host ("Total PnL:              `${0,-14} `${1,-15} `${2}" -f $limitPnl, $marketPnl, $(if ($pnlDiff -gt 0) { "+$pnlDiff" } else { $pnlDiff })) -ForegroundColor $pnlColor

    $limitAvgPnl = if ($limitTrades.avg_pnl) { [math]::Round($limitTrades.avg_pnl, 2) } else { 0 }
    $marketAvgPnl = if ($marketTrades.avg_pnl) { [math]::Round($marketTrades.avg_pnl, 2) } else { 0 }
    $avgPnlDiff = [math]::Round($limitAvgPnl - $marketAvgPnl, 2)
    $avgPnlColor = if ($avgPnlDiff -gt 0) { "Green" } elseif ($avgPnlDiff -lt 0) { "Red" } else { "White" }
    Write-Host ("Avg PnL/Trade:          `${0,-14} `${1,-15} `${2}" -f $limitAvgPnl, $marketAvgPnl, $(if ($avgPnlDiff -gt 0) { "+$avgPnlDiff" } else { $avgPnlDiff })) -ForegroundColor $avgPnlColor

    if ($limitTrades.avg_slippage) {
        Write-Host ("Avg Slippage (pips):    {0,-15}" -f [math]::Round($limitTrades.avg_slippage, 2)) -ForegroundColor $(if ($limitTrades.avg_slippage -lt 2) { "Green" } else { "Yellow" })
    }

    Write-Host ""
} else {
    Write-Host "Insufficient data for limit vs market comparison" -ForegroundColor Yellow
    Write-Host "Need data in both 'trades' and 'limit_orders' tables" -ForegroundColor Yellow
}

# ============================================================================
# TRADE DECISIONS ANALYSIS
# ============================================================================
if ($decisionsCount -gt 0 -and $Detailed) {
    Write-Host "`n=== TRADE DECISIONS ANALYSIS ===" -ForegroundColor Cyan
    
    $decisionsQuery = @"
SELECT 
    decision,
    COUNT(*) as count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM trade_decisions), 2) as percentage
FROM trade_decisions
GROUP BY decision
ORDER BY count DESC;
"@
    $decisions = Invoke-SqliteQuery -DataSource $DatabasePath -Query $decisionsQuery -ErrorAction SilentlyContinue
    
    if ($decisions) {
        foreach ($d in $decisions) {
            $color = if ($d.decision -eq 'EXECUTED') { "Green" } else { "Gray" }
            Write-Host "$($d.decision): $($d.count) ($($d.percentage)%)" -ForegroundColor $color
        }
    }

    # Top rejection reasons
    Write-Host "`n--- Top Rejection Reasons ---" -ForegroundColor Gray
    $rejectionsQuery = @"
SELECT 
    rejection_reason,
    COUNT(*) as count
FROM trade_decisions
WHERE decision = 'REJECTED' AND rejection_reason IS NOT NULL AND rejection_reason != ''
GROUP BY rejection_reason
ORDER BY count DESC
LIMIT 10;
"@
    $rejections = Invoke-SqliteQuery -DataSource $DatabasePath -Query $rejectionsQuery -ErrorAction SilentlyContinue
    
    if ($rejections -and $rejections.Count -gt 0) {
        foreach ($r in $rejections) {
            Write-Host "  $($r.rejection_reason): $($r.count)" -ForegroundColor Gray
        }
    }
}

# ============================================================================
# RECOMMENDATIONS
# ============================================================================
Write-Host "`n=== RECOMMENDATIONS ===" -ForegroundColor Cyan

$recommendations = @()

if ($limitOrdersCount -gt 0 -and $fillRateData.fill_rate -lt 60) {
    $recommendations += "Fill rate is below 60%. Consider adjusting limit order distance or confluence requirements."
}

if ($fillRateData.avg_slippage -and $fillRateData.avg_slippage -gt 2) {
    $recommendations += "Average slippage is above 2 pips. Review limit order placement strategy."
}

if ($tradesStats -and $tradesStats.win_rate -lt 55) {
    $recommendations += "Win rate is below 55%. Consider reviewing entry criteria and signal quality."
}

if ($limitTrades -and $marketTrades -and $limitWinRate -lt $marketWinRate) {
    $recommendations += "Limit orders are underperforming market orders. Review limit order strategy."
}

if ($limitCount -eq 0 -and $marketCount -gt 0) {
    $recommendations += "No limit order trades found. Enable limit orders with InpUseLimitOrders = true."
}

if ($recommendations.Count -eq 0) {
    Write-Host "No specific recommendations. Performance looks good!" -ForegroundColor Green
} else {
    foreach ($rec in $recommendations) {
        Write-Host "- $rec" -ForegroundColor Yellow
    }
}

# ============================================================================
# EXPORT TO CSV
# ============================================================================
if ($ExportToCsv) {
    Write-Host "`n=== EXPORTING DATA ===" -ForegroundColor Cyan
    
    $exportData = @()
    
    # Add summary row
    $exportData += [PSCustomObject]@{
        Category = "Summary"
        Metric = "Total Trades"
        LimitOrders = $limitCount
        MarketOrders = $marketCount
        Difference = $limitCount - $marketCount
    }
    $exportData += [PSCustomObject]@{
        Category = "Summary"
        Metric = "Win Rate (%)"
        LimitOrders = $limitWinRate
        MarketOrders = $marketWinRate
        Difference = $winRateDiff
    }
    $exportData += [PSCustomObject]@{
        Category = "Summary"
        Metric = "Total PnL"
        LimitOrders = $limitPnl
        MarketOrders = $marketPnl
        Difference = $pnlDiff
    }
    $exportData += [PSCustomObject]@{
        Category = "Summary"
        Metric = "Avg PnL/Trade"
        LimitOrders = $limitAvgPnl
        MarketOrders = $marketAvgPnl
        Difference = $avgPnlDiff
    }
    
    $exportData | Export-Csv -Path $ExportPath -NoTypeInformation
    Write-Host "Data exported to: $ExportPath" -ForegroundColor Green
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "COMPARISON COMPLETE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
