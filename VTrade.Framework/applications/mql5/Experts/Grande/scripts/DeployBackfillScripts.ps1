# Quick script to deploy backfill scripts to MT5
# Usage: .\DeployBackfillScripts.ps1

param(
    [string]$TerminalId = $env:MT5_TERMINAL_ID
)

$sourceDir = Split-Path $PSScriptRoot -Parent
$testingDir = Join-Path $sourceDir "Testing"

Write-Host "=== Deploying Backfill Scripts to MT5 ===" -ForegroundColor Cyan

# Find MT5 terminal
$mt5BaseDir = $null
if ($TerminalId) {
    $mt5BaseDir = Join-Path $env:APPDATA "MetaQuotes\Terminal\$TerminalId"
    if (-not (Test-Path $mt5BaseDir)) {
        Write-Host "Error: Terminal ID $TerminalId not found" -ForegroundColor Red
        $mt5BaseDir = $null
    }
}

if (-not $mt5BaseDir) {
    $mt5TerminalsPath = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (Test-Path $mt5TerminalsPath) {
        $terminalDirs = Get-ChildItem -Path $mt5TerminalsPath -Directory | Where-Object { 
            Test-Path (Join-Path $_.FullName "MQL5") 
        }
        
        if ($terminalDirs.Count -gt 0) {
            $mt5BaseDir = $terminalDirs[0].FullName
            Write-Host "Using MT5 terminal: $($terminalDirs[0].Name)" -ForegroundColor Green
        }
    }
}

if (-not $mt5BaseDir) {
    Write-Host "Error: Could not find MT5 terminal directory" -ForegroundColor Red
    Write-Host "Set MT5_TERMINAL_ID environment variable or ensure MT5 is installed" -ForegroundColor Yellow
    exit 1
}

$mt5ScriptsDir = Join-Path $mt5BaseDir "MQL5\Scripts\Grande"

# Create directory if it doesn't exist
if (-not (Test-Path $mt5ScriptsDir)) {
    New-Item -ItemType Directory -Path $mt5ScriptsDir -Force | Out-Null
    Write-Host "Created: $mt5ScriptsDir" -ForegroundColor Green
}

# Deploy BackfillHistoricalData.mq5
$backfillScript = Join-Path $testingDir "BackfillHistoricalData.mq5"
if (Test-Path $backfillScript) {
    $destScript = Join-Path $mt5ScriptsDir "BackfillHistoricalData.mq5"
    Copy-Item -Path $backfillScript -Destination $destScript -Force
    Write-Host "Deployed: BackfillHistoricalData.mq5" -ForegroundColor Green
    Write-Host "  From: $backfillScript" -ForegroundColor Gray
    Write-Host "  To:   $destScript" -ForegroundColor Gray
} else {
    Write-Host "Error: BackfillHistoricalData.mq5 not found at $backfillScript" -ForegroundColor Red
}

# Deploy TestDatabaseBackfill.mq5
$testScript = Join-Path $testingDir "TestDatabaseBackfill.mq5"
if (Test-Path $testScript) {
    $destTestScript = Join-Path $mt5ScriptsDir "TestDatabaseBackfill.mq5"
    Copy-Item -Path $testScript -Destination $destTestScript -Force
    Write-Host "Deployed: TestDatabaseBackfill.mq5" -ForegroundColor Green
    Write-Host "  From: $testScript" -ForegroundColor Gray
    Write-Host "  To:   $destTestScript" -ForegroundColor Gray
} else {
    Write-Host "Warning: TestDatabaseBackfill.mq5 not found at $testScript" -ForegroundColor Yellow
}

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host "Scripts are now available in MT5 Navigator:" -ForegroundColor Yellow
Write-Host "  Navigator → Scripts → Grande → BackfillHistoricalData" -ForegroundColor White
Write-Host "  Navigator → Scripts → Grande → TestDatabaseBackfill" -ForegroundColor White
Write-Host "`nIf scripts don't appear, refresh MT5 Navigator (F5)" -ForegroundColor Yellow

