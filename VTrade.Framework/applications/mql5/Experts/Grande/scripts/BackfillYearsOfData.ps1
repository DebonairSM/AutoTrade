# Grande Trading System - Backfill Years of Historical Data
# Purpose: Backfill multiple years of historical data for comprehensive backtesting

param(
    [Parameter(Mandatory=$false)]
    [string]$Symbol = "EURUSD",
    [Parameter(Mandatory=$false)]
    [int]$Years = 5,
    [Parameter(Mandatory=$false)]
    [switch]$AllTimeframes
)

Write-Host "=== GRANDE HISTORICAL DATA BACKFILL ===" -ForegroundColor Cyan
Write-Host "Symbol: $Symbol" -ForegroundColor Yellow
Write-Host "Years: $Years" -ForegroundColor Yellow
Write-Host ""

Write-Host "INSTRUCTIONS:" -ForegroundColor Green
Write-Host "1. Open MT5 Terminal" -ForegroundColor White
Write-Host "2. Navigate to: Scripts/Testing/BackfillHistoricalData.mq5" -ForegroundColor White
Write-Host "3. Set parameters:" -ForegroundColor White
Write-Host "   - InpBackfillYears = $Years" -ForegroundColor Gray
Write-Host "   - InpSymbol = `"$Symbol`"" -ForegroundColor Gray
Write-Host "   - InpTimeframe = PERIOD_H1" -ForegroundColor Gray
if ($AllTimeframes) {
    Write-Host "   - InpBackfillMultipleTimeframes = true" -ForegroundColor Gray
}
Write-Host "4. Run the script" -ForegroundColor White
Write-Host "5. Wait for completion (may take 5-15 minutes for $Years years)" -ForegroundColor White
Write-Host ""

Write-Host "ALTERNATIVE: Use MT5 Strategy Tester" -ForegroundColor Cyan
Write-Host "The Strategy Tester has built-in historical data and can backtest directly." -ForegroundColor White
Write-Host "No database backfill needed for Strategy Tester backtests." -ForegroundColor White
Write-Host ""

Write-Host "For more information, see: docs/FREE_DATA_SOURCES.md" -ForegroundColor Yellow


