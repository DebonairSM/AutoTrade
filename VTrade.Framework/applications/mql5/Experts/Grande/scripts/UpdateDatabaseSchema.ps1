# Grande Trading System - Database Schema Update Script
# Purpose: Add missing tables to existing database without losing data

param(
    [Parameter(Mandatory=$false)]
    [string]$DatabasePath = "",
    [Parameter(Mandatory=$false)]
    [switch]$Detailed
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

Write-Host "=== GRANDE DATABASE SCHEMA UPDATE ===" -ForegroundColor Cyan
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
    Write-Host "The database will be created automatically when the EA runs with InpEnableDatabase = true" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n=== CHECKING EXISTING SCHEMA ===" -ForegroundColor Cyan

# Check which tables exist
function Test-TableExists {
    param($tableName)
    try {
        $checkQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName';"
        $result = Invoke-SqliteQuery -DataSource $DatabasePath -Query $checkQuery -ErrorAction Stop
        return ($result -ne $null -and $result.Count -gt 0)
    } catch {
        return $false
    }
}

$tablesToCreate = @()

# Check trades table
if (-not (Test-TableExists "trades")) {
    Write-Host "  trades: MISSING - will create" -ForegroundColor Yellow
    $tablesToCreate += "trades"
} else {
    Write-Host "  trades: EXISTS" -ForegroundColor Green
}

# Check trade_decisions table
if (-not (Test-TableExists "trade_decisions")) {
    Write-Host "  trade_decisions: MISSING - will create" -ForegroundColor Yellow
    $tablesToCreate += "trade_decisions"
} else {
    Write-Host "  trade_decisions: EXISTS" -ForegroundColor Green
}

# Check limit_orders table
if (-not (Test-TableExists "limit_orders")) {
    Write-Host "  limit_orders: MISSING - will create" -ForegroundColor Yellow
    $tablesToCreate += "limit_orders"
} else {
    Write-Host "  limit_orders: EXISTS" -ForegroundColor Green
}

# Check market_data table
if (-not (Test-TableExists "market_data")) {
    Write-Host "  market_data: MISSING - will create" -ForegroundColor Yellow
    $tablesToCreate += "market_data"
} else {
    Write-Host "  market_data: EXISTS" -ForegroundColor Green
}

# Check other standard tables
$otherTables = @("market_regimes", "key_levels", "performance_metrics", "sentiment_data", "economic_events", "config_snapshots")
foreach ($table in $otherTables) {
    if (-not (Test-TableExists $table)) {
        Write-Host "  $table : MISSING - will create" -ForegroundColor Yellow
        $tablesToCreate += $table
    } else {
        Write-Host "  $table : EXISTS" -ForegroundColor Green
    }
}

if ($tablesToCreate.Count -eq 0) {
    Write-Host "`n✅ All tables already exist. No updates needed." -ForegroundColor Green
    exit 0
}

Write-Host "`n=== CREATING MISSING TABLES ===" -ForegroundColor Cyan

# Create trades table
if ($tablesToCreate -contains "trades") {
    Write-Host "Creating trades table..." -ForegroundColor Gray
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
CREATE TABLE IF NOT EXISTS trades (
    trade_id INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_number INTEGER UNIQUE,
    timestamp DATETIME NOT NULL,
    symbol TEXT NOT NULL,
    signal_type TEXT NOT NULL,
    direction TEXT NOT NULL,
    entry_price REAL NOT NULL,
    stop_loss REAL NOT NULL,
    take_profit REAL NOT NULL,
    lot_size REAL NOT NULL,
    risk_reward_ratio REAL NOT NULL,
    risk_percent REAL,
    outcome TEXT DEFAULT 'PENDING',
    close_price REAL,
    close_timestamp DATETIME,
    profit_loss REAL,
    pips_gained REAL,
    duration_minutes INTEGER,
    execution_slippage REAL DEFAULT 0.0,
    account_equity_at_open REAL,
    account_equity_at_close REAL,
    finbert_multiplier REAL DEFAULT 1.0,
    finbert_rejected BOOLEAN DEFAULT 0,
    lot_size_base REAL,
    lot_size_adjusted REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null
    
    # Create indexes for trades table
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_trades_ticket ON trades(ticket_number);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_trades_timestamp ON trades(timestamp);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_trades_symbol ON trades(symbol);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_trades_signal_type ON trades(signal_type);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_trades_outcome ON trades(outcome);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_trades_finbert_rejected ON trades(finbert_rejected);" | Out-Null
    Write-Host "  ✅ trades table created with indexes" -ForegroundColor Green
}

# Create trade_decisions table
if ($tablesToCreate -contains "trade_decisions") {
    Write-Host "Creating trade_decisions table..." -ForegroundColor Gray
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
CREATE TABLE IF NOT EXISTS trade_decisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    timestamp DATETIME NOT NULL,
    signal_type TEXT NOT NULL,
    decision TEXT NOT NULL,
    rejection_reason TEXT,
    entry_price REAL,
    stop_loss REAL,
    take_profit REAL,
    lot_size REAL,
    risk_percent REAL,
    regime_at_entry TEXT,
    rsi_at_entry REAL,
    adx_at_entry REAL,
    key_level_distance REAL,
    volume_ratio REAL,
    outcome TEXT,
    pnl REAL,
    duration_minutes INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null
    
    # Create indexes
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_trade_decisions_symbol_time ON trade_decisions(symbol, timestamp);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_trade_decisions_signal ON trade_decisions(signal_type);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_trade_decisions_decision ON trade_decisions(decision);" | Out-Null
    Write-Host "  ✅ trade_decisions table created with indexes" -ForegroundColor Green
}

# Create limit_orders table
if ($tablesToCreate -contains "limit_orders") {
    Write-Host "Creating limit_orders table..." -ForegroundColor Gray
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
CREATE TABLE IF NOT EXISTS limit_orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    ticket INTEGER NOT NULL UNIQUE,
    placed_time DATETIME NOT NULL,
    filled_time DATETIME,
    cancelled_time DATETIME,
    base_price REAL NOT NULL,
    filled_price REAL,
    limit_price REAL NOT NULL,
    stop_loss REAL NOT NULL,
    take_profit REAL NOT NULL,
    lot_size REAL NOT NULL,
    order_type TEXT NOT NULL,
    regime_at_placement TEXT,
    regime_confidence REAL,
    signal_quality_score REAL,
    confluence_score REAL,
    fill_probability_at_placement REAL,
    fill_probability_at_cancel REAL,
    atr_at_placement REAL,
    average_atr REAL,
    distance_pips REAL,
    slippage_pips REAL,
    time_to_fill_minutes INTEGER,
    cancel_reason TEXT,
    adjustment_count INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null
    
    # Create indexes
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_limit_orders_symbol_time ON limit_orders(symbol, placed_time);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_limit_orders_ticket ON limit_orders(ticket);" | Out-Null
    Write-Host "  ✅ limit_orders table created with indexes" -ForegroundColor Green
}

# Create market_data table (if missing)
if ($tablesToCreate -contains "market_data") {
    Write-Host "Creating market_data table..." -ForegroundColor Gray
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
CREATE TABLE IF NOT EXISTS market_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    timeframe INTEGER NOT NULL,
    timestamp DATETIME NOT NULL,
    open_price REAL NOT NULL,
    high_price REAL NOT NULL,
    low_price REAL NOT NULL,
    close_price REAL NOT NULL,
    volume REAL,
    atr REAL,
    adx_h1 REAL,
    adx_h4 REAL,
    adx_d1 REAL,
    rsi_current REAL,
    rsi_h4 REAL,
    rsi_d1 REAL,
    ema_20 REAL,
    ema_50 REAL,
    ema_200 REAL,
    stoch_k REAL,
    stoch_d REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null
    
    # Create indexes
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_market_data_symbol_time ON market_data(symbol, timestamp);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_market_data_timeframe ON market_data(timeframe);" | Out-Null
    Write-Host "  ✅ market_data table created with indexes" -ForegroundColor Green
}

# Create market_regimes table
if ($tablesToCreate -contains "market_regimes") {
    Write-Host "Creating market_regimes table..." -ForegroundColor Gray
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
CREATE TABLE IF NOT EXISTS market_regimes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    timestamp DATETIME NOT NULL,
    regime TEXT NOT NULL,
    confidence REAL NOT NULL,
    adx_h1 REAL,
    adx_h4 REAL,
    adx_d1 REAL,
    atr_current REAL,
    volatility_level TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null
    
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_regimes_symbol_time ON market_regimes(symbol, timestamp);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_regimes_regime ON market_regimes(regime);" | Out-Null
    Write-Host "  ✅ market_regimes table created" -ForegroundColor Green
}

# Create key_levels table
if ($tablesToCreate -contains "key_levels") {
    Write-Host "Creating key_levels table..." -ForegroundColor Gray
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
CREATE TABLE IF NOT EXISTS key_levels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    timestamp DATETIME NOT NULL,
    price REAL NOT NULL,
    level_type TEXT NOT NULL,
    strength INTEGER NOT NULL,
    touches INTEGER NOT NULL,
    touch_zone REAL NOT NULL,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null
    
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_key_levels_symbol_time ON key_levels(symbol, timestamp);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_key_levels_type ON key_levels(level_type);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_key_levels_active ON key_levels(is_active);" | Out-Null
    Write-Host "  ✅ key_levels table created" -ForegroundColor Green
}

# Create performance_metrics table
if ($tablesToCreate -contains "performance_metrics") {
    Write-Host "Creating performance_metrics table..." -ForegroundColor Gray
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
CREATE TABLE IF NOT EXISTS performance_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    timestamp DATETIME NOT NULL,
    metric_type TEXT NOT NULL,
    value REAL NOT NULL,
    period_start DATETIME,
    period_end DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null
    
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_performance_symbol_time ON performance_metrics(symbol, timestamp);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_performance_type ON performance_metrics(metric_type);" | Out-Null
    Write-Host "  ✅ performance_metrics table created" -ForegroundColor Green
}

# Create sentiment_data table
if ($tablesToCreate -contains "sentiment_data") {
    Write-Host "Creating sentiment_data table..." -ForegroundColor Gray
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
CREATE TABLE IF NOT EXISTS sentiment_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    timestamp DATETIME NOT NULL,
    sentiment_type TEXT NOT NULL,
    signal TEXT NOT NULL,
    score REAL NOT NULL,
    confidence REAL NOT NULL,
    reasoning TEXT,
    article_count INTEGER,
    event_count INTEGER,
    surprise_magnitude REAL,
    economic_significance TEXT,
    market_impact_score REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null
    
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_sentiment_symbol_time ON sentiment_data(symbol, timestamp);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_sentiment_type ON sentiment_data(sentiment_type);" | Out-Null
    Write-Host "  ✅ sentiment_data table created" -ForegroundColor Green
}

# Create economic_events table
if ($tablesToCreate -contains "economic_events") {
    Write-Host "Creating economic_events table..." -ForegroundColor Gray
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
CREATE TABLE IF NOT EXISTS economic_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL,
    currency TEXT NOT NULL,
    event_name TEXT NOT NULL,
    actual_value REAL,
    forecast_value REAL,
    previous_value REAL,
    impact_level TEXT NOT NULL,
    surprise_score REAL,
    finbert_signal TEXT,
    finbert_confidence REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null
    
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_economic_events_time ON economic_events(timestamp);" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_economic_events_currency ON economic_events(currency);" | Out-Null
    Write-Host "  ✅ economic_events table created" -ForegroundColor Green
}

# Create config_snapshots table
if ($tablesToCreate -contains "config_snapshots") {
    Write-Host "Creating config_snapshots table..." -ForegroundColor Gray
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
CREATE TABLE IF NOT EXISTS config_snapshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL,
    config_type TEXT NOT NULL,
    config_data TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null
    Write-Host "  ✅ config_snapshots table created" -ForegroundColor Green
}

Write-Host "`n=== UPDATE SUMMARY ===" -ForegroundColor Cyan
Write-Host "✅ Created $($tablesToCreate.Count) missing table(s):" -ForegroundColor Green
foreach ($table in $tablesToCreate) {
    Write-Host "  - $table" -ForegroundColor White
}

Write-Host "`n✅ Database schema update complete!" -ForegroundColor Green
Write-Host "You can now run the EA to collect trade data." -ForegroundColor Yellow
Write-Host "Or run: .\scripts\CheckBacktestData.ps1 -Detailed to verify" -ForegroundColor Yellow
