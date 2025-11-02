# Grande Trading System - Historical Data Seeding Script

param(
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "$env:APPDATA\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5",
    [Parameter(Mandatory=$false)]
    [string]$DatabasePath = "$env:APPDATA\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5\Files\Data\GrandeTradingData.db",
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

Write-Host "=== GRANDE TRADING DATABASE SEEDER ===" -ForegroundColor Cyan
Write-Host "Database: $DatabasePath" -ForegroundColor Yellow

Import-Module PSSQLite -ErrorAction Stop

$filesDir = Split-Path $DatabasePath -Parent
if (-not (Test-Path $filesDir)) {
    New-Item -ItemType Directory -Path $filesDir -Force | Out-Null
}

# Drop tables if Force is specified
if ($Force) {
    Write-Host "`nDropping existing tables..." -ForegroundColor Yellow
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "DROP TABLE IF EXISTS trades;" | Out-Null
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "DROP TABLE IF EXISTS decisions;" | Out-Null
}

Write-Host "`nInitializing database schema..." -ForegroundColor Cyan

# Create trades table without CHECK constraints
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
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null

Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_trades_timestamp ON trades(timestamp);" | Out-Null
Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_trades_symbol ON trades(symbol);" | Out-Null
Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_trades_signal_type ON trades(signal_type);" | Out-Null
Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_trades_outcome ON trades(outcome);" | Out-Null

# Create decisions table
Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
CREATE TABLE IF NOT EXISTS decisions (
    decision_id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL,
    symbol TEXT NOT NULL,
    signal_type TEXT NOT NULL,
    direction TEXT,
    decision TEXT NOT NULL,
    rejection_reason TEXT,
    rejection_category TEXT,
    calculated_lot_size REAL,
    calculated_sl REAL,
    calculated_tp REAL,
    calculated_rr REAL,
    margin_level_current REAL,
    margin_level_after_trade REAL,
    margin_required_percent REAL,
    account_equity REAL NOT NULL,
    open_positions INTEGER DEFAULT 0,
    calendar_signal TEXT,
    calendar_confidence REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null

Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_decisions_timestamp ON decisions(timestamp);" | Out-Null
Invoke-SqliteQuery -DataSource $DatabasePath -Query "CREATE INDEX IF NOT EXISTS idx_decisions_decision ON decisions(decision);" | Out-Null

Write-Host "[OK] Schema initialized" -ForegroundColor Green

# Parse log files
Write-Host "`nParsing log files..." -ForegroundColor Cyan

$logFiles = Get-ChildItem "$LogPath\Logs\*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime
$totalTrades = 0
$tradesInserted = 0
$tradePattern = '\[([A-Z]+)\] FILLED (BUY|SELL) @([\d.]+) SL=([\d.]+) TP=([\d.]+) lot=([\d.]+) rr=([\d.]+)'

foreach ($logFile in $logFiles) {
    Write-Host "  $($logFile.Name)" -ForegroundColor Gray
    $content = Get-Content $logFile.FullName -ErrorAction SilentlyContinue
    
    foreach ($line in $content) {
        if ($line -match $tradePattern) {
            $totalTrades++
            $timestamp = if ($line -match '^(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})') {
                [datetime]::ParseExact($matches[1], 'yyyy.MM.dd HH:mm:ss', $null).ToString('yyyy-MM-dd HH:mm:ss')
            } else { Get-Date -Format 'yyyy-MM-dd HH:mm:ss' }
            
            $symbol = if ($line -match '\(([A-Z]+!),') { $matches[1] } else { 'UNKNOWN' }
            $signalType = $matches[1]
            $direction = $matches[2]
            $entryPrice = [double]$matches[3]
            $stopLoss = [double]$matches[4]
            $takeProfit = [double]$matches[5]
            $lotSize = [double]$matches[6]
            $riskReward = [double]$matches[7]
            
            $checkQuery = "SELECT COUNT(*) as count FROM trades WHERE timestamp = '$timestamp' AND symbol = '$symbol' AND entry_price = $entryPrice;"
            $existing = Invoke-SqliteQuery -DataSource $DatabasePath -Query $checkQuery
            
            if ($existing.count -eq 0) {
                try {
                    $insertSQL = "INSERT INTO trades (timestamp, symbol, signal_type, direction, entry_price, stop_loss, take_profit, lot_size, risk_reward_ratio, outcome) VALUES ('$timestamp', '$symbol', '$signalType', '$direction', $entryPrice, $stopLoss, $takeProfit, $lotSize, $riskReward, 'PENDING');"
                    Invoke-SqliteQuery -DataSource $DatabasePath -Query $insertSQL | Out-Null
                    $tradesInserted++
                } catch {
                    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }
}

Write-Host "[OK] Found $totalTrades trades, inserted $tradesInserted" -ForegroundColor Green

# Match outcomes
Write-Host "`nMatching outcomes..." -ForegroundColor Cyan
$outcomeUpdates = 0

foreach ($logFile in $logFiles) {
    $content = Get-Content $logFile.FullName -ErrorAction SilentlyContinue
    foreach ($line in $content) {
        $timestamp = if ($line -match '^(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})') {
            [datetime]::ParseExact($matches[1], 'yyyy.MM.dd HH:mm:ss', $null).ToString('yyyy-MM-dd HH:mm:ss')
        } else { continue }
        
        $symbol = if ($line -match '\(([A-Z]+!),') { $matches[1] } else { continue }
        
        if ($line -match 'TAKE PROFIT|TP HIT') {
            try {
                $updateSQL = "UPDATE trades SET outcome = 'TP_HIT', close_timestamp = '$timestamp' WHERE trade_id = (SELECT trade_id FROM trades WHERE symbol = '$symbol' AND outcome = 'PENDING' AND timestamp < '$timestamp' ORDER BY timestamp DESC LIMIT 1);"
                Invoke-SqliteQuery -DataSource $DatabasePath -Query $updateSQL | Out-Null
                $outcomeUpdates++
            } catch {}
        } elseif ($line -match 'STOP LOSS|SL HIT') {
            try {
                $updateSQL = "UPDATE trades SET outcome = 'SL_HIT', close_timestamp = '$timestamp' WHERE trade_id = (SELECT trade_id FROM trades WHERE symbol = '$symbol' AND outcome = 'PENDING' AND timestamp < '$timestamp' ORDER BY timestamp DESC LIMIT 1);"
                Invoke-SqliteQuery -DataSource $DatabasePath -Query $updateSQL | Out-Null
                $outcomeUpdates++
            } catch {}
        }
    }
}

Write-Host "[OK] Updated $outcomeUpdates outcomes" -ForegroundColor Green

# Calculate pips
Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
UPDATE trades SET 
    pips_gained = CASE
        WHEN direction = 'BUY' AND outcome = 'TP_HIT' THEN (take_profit - entry_price) / 0.0001
        WHEN direction = 'BUY' AND outcome = 'SL_HIT' THEN (stop_loss - entry_price) / 0.0001
        WHEN direction = 'SELL' AND outcome = 'TP_HIT' THEN (entry_price - take_profit) / 0.0001
        WHEN direction = 'SELL' AND outcome = 'SL_HIT' THEN (entry_price - stop_loss) / 0.0001
        ELSE 0 END,
    duration_minutes = CASE WHEN close_timestamp IS NOT NULL THEN CAST((julianday(close_timestamp) - julianday(timestamp)) * 24 * 60 AS INTEGER) ELSE NULL END
WHERE outcome IN ('TP_HIT', 'SL_HIT');
"@ | Out-Null

# Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
$summary = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT (SELECT COUNT(*) FROM trades) as total_trades, (SELECT COUNT(*) FROM trades WHERE outcome = 'TP_HIT') as tp_hits, (SELECT COUNT(*) FROM trades WHERE outcome = 'SL_HIT') as sl_hits, (SELECT COUNT(*) FROM trades WHERE outcome = 'PENDING') as pending;"

Write-Host "Trades: $($summary.total_trades) (TP: $($summary.tp_hits), SL: $($summary.sl_hits), Pending: $($summary.pending))" -ForegroundColor Yellow

if ($summary.total_trades -gt 0 -and ($summary.tp_hits + $summary.sl_hits) -gt 0) {
    $winRate = [math]::Round(($summary.tp_hits / ($summary.tp_hits + $summary.sl_hits)) * 100, 2)
    Write-Host "Win Rate: $winRate%" -ForegroundColor $(if ($winRate -ge 60) { 'Green' } else { 'Yellow' })
}

Write-Host "`n[OK] Complete! Run: .\scripts\RunDailyAnalysis.ps1" -ForegroundColor Green
