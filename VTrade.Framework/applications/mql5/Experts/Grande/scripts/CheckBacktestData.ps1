# Grande Trading System - Backtest Data Availability Check
# Purpose: Check what historical data exists in the database for backtesting

param(
    [Parameter(Mandatory=$false)]
    [string]$DatabasePath = "",
    [Parameter(Mandatory=$false)]
    [switch]$Detailed,
    [Parameter(Mandatory=$false)]
    [switch]$TruncateMarketData
)

# Auto-detect database path if not provided
if ([string]::IsNullOrEmpty($DatabasePath)) {
    # Try workspace Data folder first
    $workspacePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "applications\mql5\Experts\Grande\Data\GrandeTradingData.db"
    if (Test-Path $workspacePath) {
        $DatabasePath = $workspacePath
    } else {
        # Try MT5 Files folder
        $mt5FilesPath = Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Files\Data\GrandeTradingData.db" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($mt5FilesPath) {
            $DatabasePath = $mt5FilesPath.FullName
        } else {
            # Default to workspace
            $DatabasePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "applications\mql5\Experts\Grande\Data\GrandeTradingData.db"
        }
    }
}

$ErrorActionPreference = "Stop"

Write-Host "=== GRANDE BACKTEST DATA CHECK ===" -ForegroundColor Cyan
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
    Write-Host "The EA will create the database automatically when it runs." -ForegroundColor Yellow
    Write-Host "`nTo backfill historical market data, run the EA with InpEnableDatabase = true" -ForegroundColor Yellow
    exit 1
}

# Handle truncate option
if ($TruncateMarketData) {
    Write-Host "`n⚠️  WARNING: This will delete all market_data records!" -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to cancel, or any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    try {
        $truncateQuery = "DELETE FROM market_data;"
        Invoke-SqliteQuery -DataSource $DatabasePath -Query $truncateQuery -ErrorAction Stop
        Write-Host "`n✅ Market data table truncated successfully" -ForegroundColor Green
        Write-Host "You can now run the EA backfill to repopulate the data." -ForegroundColor Yellow
    } catch {
        Write-Host "`n❌ ERROR: Failed to truncate market_data table: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n=== DATABASE TABLES ===" -ForegroundColor Cyan

# Check all tables
$tables = @(
    "trades",
    "trade_decisions", 
    "limit_orders",
    "market_data",
    "market_regimes",
    "key_levels",
    "performance_metrics"
)

$dataSummary = @{}

foreach ($table in $tables) {
    try {
        $countQuery = "SELECT COUNT(*) as count FROM $table;"
        $result = Invoke-SqliteQuery -DataSource $DatabasePath -Query $countQuery -ErrorAction Stop
        $count = $result.count
        
        if ($count -gt 0) {
            Write-Host "  $table : $count records" -ForegroundColor Green
            $dataSummary[$table] = $count
        } else {
            Write-Host "  $table : 0 records (empty)" -ForegroundColor Gray
            $dataSummary[$table] = 0
        }
    } catch {
        Write-Host "  $table : Table doesn't exist" -ForegroundColor Yellow
        $dataSummary[$table] = -1
    }
}

Write-Host "`n=== BACKTEST DATA AVAILABILITY ===" -ForegroundColor Cyan

# 1. Trade Data (for comparing limit vs market orders)
if ($dataSummary["trades"] -gt 0) {
    $tradeQuery = @"
SELECT 
    COUNT(*) as total,
    COUNT(CASE WHEN outcome IN ('TP_HIT', 'SL_HIT') THEN 1 END) as closed,
    COUNT(CASE WHEN outcome = 'PENDING' THEN 1 END) as pending,
    MIN(timestamp) as first_trade,
    MAX(timestamp) as last_trade
FROM trades;
"@
    $tradeData = Invoke-SqliteQuery -DataSource $DatabasePath -Query $tradeQuery
    
    Write-Host "`n✅ TRADE DATA AVAILABLE" -ForegroundColor Green
    Write-Host "  Total Trades: $($tradeData.total)" -ForegroundColor White
    Write-Host "  Closed Trades: $($tradeData.closed)" -ForegroundColor White
    Write-Host "  Pending Trades: $($tradeData.pending)" -ForegroundColor White
    Write-Host "  Date Range: $($tradeData.first_trade) to $($tradeData.last_trade)" -ForegroundColor White
    
    if ($Detailed) {
        # Show signal type breakdown
        $signalQuery = "SELECT signal_type, COUNT(*) as count FROM trades GROUP BY signal_type ORDER BY count DESC;"
        $signals = Invoke-SqliteQuery -DataSource $DatabasePath -Query $signalQuery
        Write-Host "`n  Signal Type Breakdown:" -ForegroundColor Gray
        foreach ($sig in $signals) {
            Write-Host "    $($sig.signal_type): $($sig.count)" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "`n❌ NO TRADE DATA" -ForegroundColor Red
    Write-Host "  Run the EA to generate trade data" -ForegroundColor Yellow
}

# 2. Limit Order Data (newly added)
if ($dataSummary["limit_orders"] -gt 0) {
    $limitQuery = @"
SELECT 
    COUNT(*) as total,
    COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) as filled,
    COUNT(CASE WHEN cancelled_time IS NOT NULL THEN 1 END) as cancelled,
    COUNT(CASE WHEN filled_time IS NULL AND cancelled_time IS NULL THEN 1 END) as pending,
    MIN(placed_time) as first_order,
    MAX(placed_time) as last_order,
    ROUND(100.0 * COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) / COUNT(*), 2) as fill_rate
FROM limit_orders;
"@
    $limitData = Invoke-SqliteQuery -DataSource $DatabasePath -Query $limitQuery
    
    Write-Host "`n✅ LIMIT ORDER DATA AVAILABLE" -ForegroundColor Green
    Write-Host "  Total Orders: $($limitData.total)" -ForegroundColor White
    Write-Host "  Filled: $($limitData.filled)" -ForegroundColor White
    Write-Host "  Cancelled: $($limitData.cancelled)" -ForegroundColor White
    Write-Host "  Pending: $($limitData.pending)" -ForegroundColor White
    Write-Host "  Fill Rate: $($limitData.fill_rate)%" -ForegroundColor White
    Write-Host "  Date Range: $($limitData.first_order) to $($limitData.last_order)" -ForegroundColor White
    
    if ($Detailed) {
        # Show fill probability analysis
        $probQuery = @"
SELECT 
    CASE 
        WHEN fill_probability_at_placement < 0.3 THEN '< 30%'
        WHEN fill_probability_at_placement < 0.5 THEN '30-50%'
        WHEN fill_probability_at_placement < 0.7 THEN '50-70%'
        ELSE '> 70%'
    END as prob_range,
    COUNT(*) as orders,
    COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) as filled,
    ROUND(100.0 * COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) / COUNT(*), 2) as actual_fill_rate
FROM limit_orders
WHERE fill_probability_at_placement IS NOT NULL
GROUP BY prob_range
ORDER BY prob_range;
"@
        $probData = Invoke-SqliteQuery -DataSource $DatabasePath -Query $probQuery
        if ($probData.Count -gt 0) {
            Write-Host "`n  Fill Probability vs Actual Fill Rate:" -ForegroundColor Gray
            foreach ($prob in $probData) {
                Write-Host "    $($prob.prob_range): $($prob.orders) orders, $($prob.filled) filled ($($prob.actual_fill_rate)%)" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Host "`n❌ NO LIMIT ORDER DATA" -ForegroundColor Yellow
    Write-Host "  This table was just added. Run the EA with limit orders enabled to collect data." -ForegroundColor Yellow
    Write-Host "  Enable: InpUseLimitOrders = true, InpTrackFillMetrics = true" -ForegroundColor Yellow
}

# 3. Market Data (for backtesting)
if ($dataSummary["market_data"] -gt 0) {
    $marketQuery = @"
SELECT 
    COUNT(*) as total,
    COUNT(DISTINCT symbol) as symbols,
    COUNT(DISTINCT timeframe) as timeframes,
    MIN(timestamp) as first_bar,
    MAX(timestamp) as last_bar
FROM market_data;
"@
    $marketData = Invoke-SqliteQuery -DataSource $DatabasePath -Query $marketQuery
    
    # Calculate coverage period in days
    $firstBarDate = [DateTime]::Parse($marketData.first_bar)
    $lastBarDate = [DateTime]::Parse($marketData.last_bar)
    $coverageDays = ($lastBarDate - $firstBarDate).Days
    
    Write-Host "`n✅ MARKET DATA AVAILABLE" -ForegroundColor Green
    Write-Host "`n=== DATA COVERAGE STATISTICS ===" -ForegroundColor Cyan
    Write-Host "Total Records: $($marketData.total)" -ForegroundColor White
    Write-Host "Symbols: $($marketData.symbols)" -ForegroundColor White
    Write-Host "Timeframes: $($marketData.timeframes)" -ForegroundColor White
    Write-Host "Oldest Data: $($marketData.first_bar)" -ForegroundColor White
    Write-Host "Newest Data: $($marketData.last_bar)" -ForegroundColor White
    Write-Host "Coverage Period: $coverageDays days" -ForegroundColor White
    Write-Host "===============================" -ForegroundColor Cyan
    
    if ($Detailed) {
        # Show per-symbol/timeframe breakdown
        $symbolTimeframeQuery = @"
SELECT 
    symbol,
    timeframe,
    COUNT(*) as bars,
    MIN(timestamp) as first_bar,
    MAX(timestamp) as last_bar
FROM market_data
GROUP BY symbol, timeframe
ORDER BY symbol, timeframe;
"@
        $symbolTimeframes = Invoke-SqliteQuery -DataSource $DatabasePath -Query $symbolTimeframeQuery
        Write-Host "`n  Symbol/Timeframe Breakdown:" -ForegroundColor Gray
        foreach ($st in $symbolTimeframes) {
            $stFirstDate = [DateTime]::Parse($st.first_bar)
            $stLastDate = [DateTime]::Parse($st.last_bar)
            $stDays = ($stLastDate - $stFirstDate).Days
            Write-Host "    $($st.symbol) ($($st.timeframe)): $($st.bars) bars, $stDays days coverage" -ForegroundColor Gray
        }
    } else {
        # Show symbol breakdown (simpler)
        $symbolQuery = "SELECT symbol, COUNT(*) as bars FROM market_data GROUP BY symbol ORDER BY bars DESC;"
        $symbols = Invoke-SqliteQuery -DataSource $DatabasePath -Query $symbolQuery
        Write-Host "`n  Symbol Breakdown:" -ForegroundColor Gray
        foreach ($sym in $symbols) {
            Write-Host "    $($sym.symbol): $($sym.bars) bars" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "`n❌ NO MARKET DATA" -ForegroundColor Yellow
    Write-Host "  Run the EA with InpEnableDatabase = true to backfill market data" -ForegroundColor Yellow
    Write-Host "  Or use: g_databaseManager.BackfillHistoricalData() in OnInit()" -ForegroundColor Yellow
}

# 4. Trade Decisions (for analysis)
if ($dataSummary["trade_decisions"] -gt 0) {
    $decisionQuery = @"
SELECT 
    COUNT(*) as total,
    COUNT(CASE WHEN decision = 'EXECUTED' THEN 1 END) as executed,
    COUNT(CASE WHEN decision = 'REJECTED' THEN 1 END) as rejected,
    MIN(timestamp) as first_decision,
    MAX(timestamp) as last_decision
FROM trade_decisions;
"@
    $decisionData = Invoke-SqliteQuery -DataSource $DatabasePath -Query $decisionQuery
    
    Write-Host "`n✅ TRADE DECISION DATA AVAILABLE" -ForegroundColor Green
    Write-Host "  Total Decisions: $($decisionData.total)" -ForegroundColor White
    Write-Host "  Executed: $($decisionData.executed)" -ForegroundColor White
    Write-Host "  Rejected: $($decisionData.rejected)" -ForegroundColor White
    Write-Host "  Date Range: $($decisionData.first_decision) to $($decisionData.last_decision)" -ForegroundColor White
} else {
    Write-Host "`n❌ NO TRADE DECISION DATA" -ForegroundColor Yellow
}

# Summary
Write-Host "`n=== BACKTEST READINESS ===" -ForegroundColor Cyan

$canBacktest = $false
$backtestQuality = "NONE"

if ($dataSummary["trades"] -ge 20 -and $dataSummary["limit_orders"] -ge 10) {
    $canBacktest = $true
    $backtestQuality = "EXCELLENT"
    Write-Host "✅ EXCELLENT: Sufficient data for comprehensive backtesting" -ForegroundColor Green
    Write-Host "  - Compare limit orders vs market orders" -ForegroundColor White
    Write-Host "  - Analyze fill rates and win rates" -ForegroundColor White
    Write-Host "  - Optimize limit order parameters" -ForegroundColor White
} elseif ($dataSummary["trades"] -ge 10) {
    $canBacktest = $true
    $backtestQuality = "GOOD"
    Write-Host "✅ GOOD: Sufficient data for basic backtesting" -ForegroundColor Green
    Write-Host "  - Can analyze trade performance" -ForegroundColor White
    Write-Host "  - Need more limit order data for limit vs market comparison" -ForegroundColor Yellow
} elseif ($dataSummary["trades"] -gt 0) {
    $canBacktest = $true
    $backtestQuality = "LIMITED"
    Write-Host "⚠️  LIMITED: Some data available but need more trades" -ForegroundColor Yellow
    Write-Host "  - Minimum 10-20 trades recommended for meaningful analysis" -ForegroundColor Yellow
} else {
    Write-Host "❌ INSUFFICIENT: No trade data available" -ForegroundColor Red
    Write-Host "  - Run the EA to generate trade data" -ForegroundColor Yellow
    Write-Host "  - Enable database logging: InpEnableDatabase = true" -ForegroundColor Yellow
}

Write-Host "`n=== RECOMMENDATIONS ===" -ForegroundColor Cyan

if (-not $canBacktest) {
    Write-Host "1. Run the EA on a demo account to collect data" -ForegroundColor Yellow
    Write-Host "2. Enable database logging: InpEnableDatabase = true" -ForegroundColor Yellow
    Write-Host "3. Enable limit order tracking: InpTrackFillMetrics = true" -ForegroundColor Yellow
    Write-Host "4. Wait for at least 20-30 trades to accumulate" -ForegroundColor Yellow
} else {
    Write-Host "1. Run analysis: .\scripts\RunDailyAnalysis.ps1" -ForegroundColor Green
    Write-Host "2. Compare limit vs market orders using SQL queries" -ForegroundColor Green
    Write-Host "3. Analyze fill rates: SELECT * FROM limit_orders WHERE filled_time IS NOT NULL" -ForegroundColor Green
    
    if ($dataSummary["limit_orders"] -lt 10) {
        Write-Host "4. Collect more limit order data (currently: $($dataSummary['limit_orders']) orders)" -ForegroundColor Yellow
    }
}

Write-Host "`n=== SAMPLE QUERIES FOR BACKTESTING ===" -ForegroundColor Cyan
Write-Host "`n1. Limit Order Fill Rate Analysis:" -ForegroundColor White
Write-Host "   SELECT " -ForegroundColor Gray
Write-Host "     COUNT(*) as total_orders," -ForegroundColor Gray
Write-Host "     COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) as filled," -ForegroundColor Gray
Write-Host "     ROUND(100.0 * COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) / COUNT(*), 2) as fill_rate" -ForegroundColor Gray
Write-Host "   FROM limit_orders;" -ForegroundColor Gray

Write-Host "`n2. Compare Limit vs Market Order Performance:" -ForegroundColor White
Write-Host "   (Join limit_orders with trades table on ticket/symbol)" -ForegroundColor Gray

Write-Host "`n3. Fill Probability Accuracy:" -ForegroundColor White
Write-Host "   SELECT " -ForegroundColor Gray
Write-Host "     fill_probability_at_placement," -ForegroundColor Gray
Write-Host "     COUNT(*) as orders," -ForegroundColor Gray
Write-Host "     COUNT(CASE WHEN filled_time IS NOT NULL THEN 1 END) as actual_filled" -ForegroundColor Gray
Write-Host "   FROM limit_orders" -ForegroundColor Gray
Write-Host "   GROUP BY ROUND(fill_probability_at_placement, 1);" -ForegroundColor Gray

Write-Host "`n=== CHECK COMPLETE ===" -ForegroundColor Cyan

